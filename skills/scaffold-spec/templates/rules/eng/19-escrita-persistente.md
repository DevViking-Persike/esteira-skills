# Regra 19 — Escrita persistente: alcance, atomicidade e ordem

> **3 camadas:** Camada 1 (Princípio) é universal · Camada 2 traz o mecanismo por stack ·
> Camada 3 traz os casos que originaram a regra. Veja `_layer-guide.md`.

## Camada 1 — Princípio universal (agnóstico)

Toda escrita que persiste estado responde três perguntas **antes de existir**:

1. **Alcance** — exatamente quais linhas ela toca?
2. **Atomicidade** — o que precisa gravar junto com ela, ou não gravar nada?
3. **Ordem** — o que só pode acontecer depois do commit?

Escrita que não responde as três funciona no teste e erra em produção, porque o teste roda
sozinho e a produção roda concorrente.

### 1. Alcance: o `WHERE` carrega todas as invariantes da tabela

- Tabela com **exclusão lógica** leva a guarda de não-excluído em todo `UPDATE`/`DELETE`,
  **inclusive quando uma consulta anterior já filtrou as excluídas**: validar e aplicar são
  dois momentos distintos, e entre eles o registro pode ter sido excluído (TOCTOU).
- Alcance que combina `OR` vai **entre parênteses** antes de receber o `AND` da guarda. Sem
  os parênteses o `AND` se liga só ao último disjunto e metade do alcance segue desprotegida —
  um erro que não aparece no teste feliz, porque o caminho protegido é o que o teste exercita.
- Filtro derivado de correlação/grupo (`OR chave_de_grupo = @x`) alcança linhas que a
  validação nunca viu: a guarda vale para o conjunto inteiro, não para a linha âncora.

Não só as invariantes da tabela: **toda pré-condição de negócio usada para escolher o alvo volta
à cláusula da escrita**. Se a validação selecionou o conjunto exigindo um método de pagamento
específico e a ausência de cancelamento, a reaplicação que só filtra por identificador e exclusão
lógica alcança linhas que deixaram de satisfazer a condição entre os dois momentos — e o
intervalo costuma incluir uma chamada de rede. A pergunta é sempre a mesma: se **agora** a linha
deixou de satisfazer a condição, esta escrita a alcança?

**E invariante de tabela alheia é levantada, não adivinhada.** Escrever em tabela de que outro
time é dono obriga a levantar as invariantes **daquele** schema — exclusão lógica, unicidade
parcial, colunas derivadas, gatilhos. Elas não aparecem em nenhum teste seu, porque o seu teste
cria a tabela do jeito que você imagina que ela é. O que não deu para verificar aparece nomeado no
MR (Regra 26).

Consulta que sustenta um "exatamente um" garante a cardinalidade **nela mesma**, com desempate
determinístico escrito: uma junção à esquerda com uma tabela de vínculo multiplica linhas no dia
em que o registro tiver dois vínculos vivos, e o erro chega como exceção de materialização, não
como regra de negócio.

### 2. Atomicidade: uma transação por unidade de negócio

- Escrita que abrange **mais de uma tabela** (agregado + itens, item + trilha de auditoria)
  roda numa transação única. Queda no meio do laço deixa lote parcial com contadores
  divergentes, sem rollback e sem forma de detectar.
- O enlistamento da transação mora num **único ponto** da camada de persistência (a sessão/
  conexão de trabalho decide se empresta a conexão em curso). Se cada repositório precisa
  lembrar de receber a transação, um dia um esquece — e o esquecimento é silencioso.

### 3. Ordem: efeito externo só depois do commit

Fila, evento, notificação, e-mail e webhook disparam **depois** do commit. Publicar dentro
da transação entrega ao consumidor uma referência para linha que ainda não existe — ou que
vai sumir no rollback. Em modo síncrono é pior: o próprio processo lê o que ainda não
commitou.

Se o efeito externo falhar depois do commit, isso é falha visível (Regra 15), não motivo
para publicar antes.

### 4. Estado derivado só se grava condicionado ao que foi lido

Agregado, contador e status apurado a partir de **outras linhas** seguem o ciclo
ler → calcular → gravar, que perde a corrida em silêncio quando dois processos terminam
juntos: o mais lento grava um cálculo feito sobre uma lista já velha, e o status exibido
regride.

O remédio é **update condicional** (compare-and-set) ao valor lido antes do recálculo, com
releitura e nova tentativa quando a gravação não aplica. E a ordem das leituras importa: o
**valor comparado é lido antes** dos dados que alimentam o cálculo — invertido, um vencedor
que gravou no meio vira o "esperado" e a agregação velha ganha a corrida com aparência de
sucesso.

O laço de reconciliação é um laço: vale a Regra 18 (teto, condição de parada, caminho de
erro).

### 5. Cardinalidade se confere; ler-o-anterior e escrever são uma unidade

- **Em lote, "afetou alguma linha" não é confirmação.** O compare-and-set de linha única da
  Camada 2 é o antipadrão aqui: comparar o retorno com zero deixa passar a escrita parcial, e a
  trilha emite "efeito aplicado" para linhas que a escrita não tocou. Compare com a
  **cardinalidade esperada** e falhe fechado — e a contagem esperada só é confiável se a leitura
  do conjunto e a escrita rodarem na mesma transação.
- **Confira o que o driver conta antes de comparar.** "Linhas encontradas" e "linhas alteradas"
  são semânticas diferentes, ligadas por uma opção de conexão que costuma morar num arquivo de
  ambiente de outro repositório. Sob o modo *found rows*, `afetadas == esperado` fica verdadeiro
  **mesmo quando nenhuma linha mudou**, e a guarda inverte de sentido. Fixe a opção na fábrica de
  conexão em vez de herdá-la do ambiente (Regra 21).
- **Ler o valor anterior e sobrescrevê-lo é uma unidade transacional com trava de linha.** Leitura
  em autocommit e escrita depois deixam janela para outro escritor: a trilha grava um "antes" que
  não é o valor efetivamente sobrescrito, e a auditoria deixa de reconstituir a mudança. O nível
  de isolamento padrão não fecha essa janela sozinho.
- **Se o dublê de teste impede a trava, quem muda é o dublê** (Regra 02) — limitação de fake nunca
  decide o que a produção pode fazer.

### Motivação
Nenhum desses cinco defeitos falha em teste unitário. Todos falham em produção, sob
concorrência ou sob falha parcial, e todos deixam o banco num estado que ninguém consegue
explicar depois — que é o pior tipo de bug em base financeira ou regulada.

### Exceções aceitas
- Tabela append-only sem exclusão lógica (a guarda não existe).
- Escrita de linha que o próprio processo possui e ninguém mais deriva (o worker gravando o
  desfecho da sua própria linha) — mas se **outro** agregado é calculado a partir dela,
  entrega duplicada consegue regredir estado: aí a guarda de estado volta a ser necessária.
- Outbox no lugar do "publica depois do commit" é a versão forte da mesma regra, não uma
  alternativa a ela.
- Escrita idempotente de reconciliação, cujo contrato é "deixe todas essas linhas neste estado,
  quantas forem" — e aí o número esperado é registrado no log, não usado como guarda.

## Camada 2 — Preset por stack

| Stack | Transação/CAS | Observação |
|---|---|---|
| C# + Dapper | `IDbTransaction` propagada por uma sessão scoped; `ExecuteAsync` devolve linhas afetadas → `> 0` é o CAS | evite passar transação por parâmetro em cada repositório |
| C# + EF Core | `DbContext.SaveChanges` já é transacional; concorrência via token (`[Timestamp]`/`IsConcurrencyToken`) | `DbUpdateConcurrencyException` é o "não aplicou" |
| Node-TS | `knex.transaction` / `prisma.$transaction`; `updateMany({ where: { id, status: esperado } })` → `count` | |
| Python | `SQLAlchemy` `Session.begin()`; `UPDATE ... WHERE ... RETURNING` | |
| Go | `sql.Tx`; `Result.RowsAffected()` | |

```bash
# UPDATE/DELETE sem a guarda de exclusão lógica — cada achado exige justificativa
rg -n 'UPDATE |DELETE FROM ' <infra-root> | rg -v '<coluna-de-exclusao-logica>'

# Alcance com OR sem parênteses antes do AND
rg -n '=\s*@\w+\s+OR\s+.*\sAND\s' <infra-root>

# Estado derivado gravado sem condição (assinatura sem status esperado / sem retorno bool)
rg -n 'AtualizarStatus|UpdateStatus|SetStatus' <infra-root>

# Retorno de escrita comparado só a zero
find <infra-root> -name '*.cs' -print0 \
| xargs -0 grep -nA2 -E 'ExecuteAsync|Execute\(|execute\('      # inspecionar: > 0 ou == esperado?

# Leitura de valor anterior fora do bloco transacional da escrita
find <infra-root> -name '*.cs' -print0 \
| xargs -0 grep -nE 'LerValoresAnteriores|SelectBefore|snapshot|FOR UPDATE'

# A semântica de linhas afetadas está fixada em código, não no ambiente?
find <infra-root> -name '*.cs' -print0 | xargs -0 grep -nE 'UseAffectedRows|ConnectionString'
find . -name '*.env*' -print0 | xargs -0 grep -nE 'UseAffectedRows'
```

## Camada 3 — Exemplo concreto

Quatro achados no mesmo MR de um backend de atualização de apólice em lote, todos com a
suíte verde:

| Achado | O que acontecia |
|---|---|
| `UPDATE` no escopo de grupo sem a guarda de exclusão lógica | apólice excluída logicamente era mutada; a validação prévia só olhava a linha âncora |
| `WHERE id = @id OR correlacao = @c AND excluido IS NULL` | sem parênteses, a linha do `id` seguia desprotegida |
| planilha + N itens + publicação na fila, tudo solto | queda no meio do laço deixava lote parcial e contador divergente; o modo síncrono lia linha não commitada |
| status da planilha recalculado por cada item em paralelo | última escrita vencia com valor obsoleto e o status regredia de *Finalizado* para *Processando* |

A correção do último ponto também expôs a armadilha de ordem: ler a planilha **depois** de
listar os itens fazia o perdedor adotar como "esperado" um valor gravado no meio, e regravar
a agregação velha como se tivesse ganhado.

## Como verificar
```bash
# 1. Para cada UPDATE/DELETE do diff: listar as linhas alcançadas e conferir a guarda.
# 2. Para cada use case que escreve em 2+ tabelas: mostrar onde a transação abre e commita.
# 3. Para cada publicação/notificação: provar que está fora do bloco transacional.
# 4. Para cada estado derivado persistido: a assinatura recebe o valor esperado e devolve
#    "aplicou ou não"? Existe teste com dois escritores concorrentes?
```
