# Regra 20 — Nada anunciado sem mecanismo por trás

> **3 camadas:** Camada 1 (Princípio) é universal · Camada 2 traz o grep por stack ·
> Camada 3 traz o caso que originou a regra. Veja `_layer-guide.md`.

## Camada 1 — Princípio universal (agnóstico)

Nome de tipo, nome de pasta, campo de decisão, valor de enum, status persistido, opção de
configuração e classe registrada no container são **promessas ao próximo leitor**. Cada
promessa precisa de mecanismo: alguém que produz e alguém que consome, **em código de
produção**.

Promessa sem mecanismo é pior que ausência. Ausência se percebe; promessa se acredita.

### As quatro formas

1. **Sinal calculado que ninguém lê.** Uma flag de decisão (`ExigeReadBack`, `DeveRetentar`,
   `ConsomeTentativa`) afirmada só em teste unitário não muda nenhum caminho: ou o consumidor
   está faltando — e o desfecho reportado ao operador está errado —, ou a flag é morta e sai.
   Refatoração que remove o consumidor **remove o sinal junto**.
2. **Nome que promete o que o sistema não faz.** Pasta `retry/`, tipo `PoliticaDeRetentativa`,
   campo `Retentavel` num sistema onde quem reprocessa é o usuário. O vocabulário sai no mesmo
   commit em que a decisão de produto sai.
3. **Peça registrada que não tem comportamento.** Classe, hosted service ou middleware cujo
   corpo inteiro é uma linha de log. Aviso sobre configuração incoerente se emite no próprio
   wiring, ou falha a subida — não por meio de um tipo dedicado a isso.
4. **Configuração que oferece um modo inexistente.** Chave de ambiente que seleciona um
   caminho já removido, ou que só funcionava com um processo de fundo que não existe mais.

### A quinta forma: promessa ao usuário final

As quatro formas acima falam com o próximo leitor do código. Rótulo, placeholder, nome do
controle, parâmetro enviado e texto de desfecho falam com **quem usa a tela** — e precisam de
mecanismo na cadeia inteira, não em um dos artefatos.

- **Rótulo, placeholder, controle e parâmetro descrevem o mesmo dado.** Campo rotulado com o nome
  de um identificador, placeholder de outro, controle de um terceiro e serviço resolvendo por um
  quarto entrega **lista vazia** a quem seguiu o rótulo: resposta legítima, nenhum teste vermelho,
  nenhum log. São quatro artefatos em quatro arquivos — exatamente o que a revisão de diff arquivo
  a arquivo não junta.
- **Descrição de desfecho vem do servidor ou é neutra.** Texto de sucesso fixo com o nome de uma
  variante, numa tela que atende N variantes, é verdadeiro em 100% dos dados simulados e falso em
  N-1 dos casos reais — na mesma coluna em que as linhas de erro trazem dado real do servidor.
- **O termo do produto tem uma grafia só.** Duas grafias entre menu, cabeçalho e botão o usuário
  lê como dois recursos. E o teste que asserta a grafia errada **congela** a divergência: a
  correção varre marcação, código e teste.

**Exceção:** rótulo deliberadamente mais amigável que o nome técnico, desde que o parâmetro
enviado e o valor que o sistema oferece para copiar continuem sendo o mesmo dado.

### Ao remover um comportamento, remova a máquina inteira

Quando uma decisão elimina um comportamento, saem no mesmo commit: o estado (valor de enum,
status), a opção de configuração, o laço, a flag do contrato, o dublê de teste que só existia
para ele, a **documentação** e — este é o que escapa — o **seed do banco**. Status semeado
que nenhum código mais produz continua chegando pela leitura e derruba o mapeamento em
runtime.

Remover só o símbolo apontado na revisão devolve o problema pela próxima rodada.

### Antes de remover, endurecer ou remapear, rastreie até a origem

Aplicar esta regra pelo grep do próprio repositório **produz regressão**. Campo sempre nulo tem
três causas, e só uma autoriza remoção:

1. **Sem produtor e sem consumidor** — morto, sai.
2. **Sem produtor, mas lido em produção** como valor alternativo — remover reintroduz o defeito
   que outra thread acabou de corrigir. O que falta é o produtor.
3. **Nulo porque o dado não existe na origem**, com o campo declarado no contrato de quem consome
   — o defeito é a origem.

Consumidor em outro repositório **é** mecanismo: o caminho dele é insumo da thread, e sem acesso a
thread fica aberta (Regra 25), com o MR par citado. A mesma disciplina vale para **endurecer** e
**remapear**, que são remoções disfarçadas: tornar cabeçalho ou campo obrigatório, introduzir uma
rejeição nova, ou traduzir em bloco um código de status que a tela usa para ramificar, derruba
consumidor com as duas suítes verdes.

Mais três faces:

- **A correção de review cria órfão quando adiciona a capacidade sem trocar o ponto de uso.**
  Parâmetro opcional que nenhum chamador passa, método seguro criado ao lado do inseguro sem
  exposição pela fachada: nascem sem mecanismo no commit que existia para dar mecanismo a alguma
  coisa.
- **Capacidade perigosa desativada continua sendo capacidade.** Fechar o acesso removendo a
  chamada e deixando o campo no contrato e a cláusula na consulta não fecha nada — basta alguém
  voltar a preencher. Quando o resíduo é de segurança, é bloqueante, não higiene.
- **Gatilho não pedido é caminho não especificado.** Um segundo disparador do mesmo trabalho,
  funcional e testado, que o refinamento não pediu, é modo sem decisão: sai, ou entra com decisão
  registrada e dono.

### Motivação
Código morto não custa CPU, custa **decisão errada**: o revisor assume que a flag protege
algo, o operador assume que o retry vai acontecer, o integrador assume que o modo existe.
Todo mundo confia numa capacidade que ninguém implementou.

### Exceções aceitas
- Ponto de extensão declarado como tal, com a data/lançamento em que será consumido registrado
  no card — e não mais que um ciclo.
- Membro de contrato público já publicado a terceiros: a remoção segue o processo de
  depreciação, mas o estado "sem consumidor" fica escrito.

## Camada 2 — Preset por stack

O teste é sempre o mesmo: **o símbolo aparece fora de `tests/`?**

```bash
# Membro sem consumidor de produção (troque <membro> pelo nome exato)
rg -n '<membro>' <src-root>            # esperado: produtor E consumidor
rg -n '<membro>' <tests-root>          # só teste = promessa sem mecanismo

# Chave de configuração órfã: existe no ambiente e não no código
rg -o '^[A-Z0-9_]+(?==)' <arquivo-de-ambiente-exemplo> | while read k; do
  rg -q "$k" <src-root> || echo "config órfã: $k"
done

# Valor de enum/status semeado no banco sem produtor no código
rg -n "'<STATUS>'" <migrations-root> && rg -n '<Status>' <src-root>

# Inventário de consumidores, um repositório por vez
for repo in <repo-atual> <repo-do-consumidor>; do
  find "$repo" -type f \( -name '*.ts' -o -name '*.cs' \) -print0 | xargs -0 grep -n '<simbolo>'
done

# Antes de remapear status: em quais códigos o cliente ramifica?
find <frontend-root> -name '*.ts' -print0 \
| xargs -0 grep -nE 'status *===? *[0-9]{3}|StatusCode *== *[0-9]{3}'

# Rótulo, placeholder, controle e parâmetro descrevem o mesmo dado?
find <components-root> -name '*.html' -print0 \
| xargs -0 grep -hoE 'formControlName="[A-Za-z]+"' | sed 's/.*"\(.*\)"/\1/' | sort -u \
| while read -r c; do
    echo "== $c"
    find <components-root> \( -name '*.html' -o -name '*.ts' \) -print0 | xargs -0 grep -n "$c"
  done

# Termo do produto com mais de uma grafia (inclui os specs na varredura)
find <src-root> \( -name '*.html' -o -name '*.ts' \) -print0 | xargs -0 grep -n '<termo-do-produto>'
```

| Stack | Ferramenta que ajuda |
|---|---|
| C# | analisadores de símbolo não usado (IDE0051/IDE0052), `dotnet build -warnaserror` |
| Node-TS | `knip`, `ts-prune`, `eslint no-unused-vars` com `varsIgnorePattern` desligado |
| Python | `vulture`, `ruff F401/F841` |
| Go | `deadcode`, `staticcheck U1000` |
| Rust | `#[warn(dead_code)]` (já é default) |

> A skill `/dead-code-cleansing` (`commands/eng/`) automatiza a varredura; esta regra define
> quando o achado é **bloqueante**: quando a promessa está no contrato, no status ou no nome.

## Camada 3 — Exemplo concreto

Num MR de backend de atualização de apólice em lote, a mesma classe de defeito apareceu cinco
vezes:

| Promessa | Mecanismo real |
|---|---|
| `DecisaoDespacho.ExigeReadBack` | nenhum consumidor: um refactor anterior removeu a consulta de confirmação e deixou o parâmetro fixo em `false` — item já aplicado que respondia 409 virava falha definitiva, e o operador reprocessava achando que não tinha ido |
| `DeveRetentar` / `ConsomeTentativa` / `RegraTipoErro` | afirmados só em teste |
| pasta/namespace `Retry` + status `FalhaReprocessavel` | a decisão de produto era "o usuário importa nova planilha", não retry automático |
| hosted service dedicado | corpo inteiro: um `LogWarning` na subida |
| chaves `MAXTENTATIVAS`, `MODO`, `CAPACIDADEFILA` | selecionavam um laço e uma fila em memória que saíram do código |

E a ponta que quase escapou: o seed de status no repositório de migrations continuava
semeando `FALHA_REPROCESSAVEL`. Nenhum código escrevia mais esse valor, mas qualquer linha
pré-existente com ele derrubaria a conversão na leitura.

## Como verificar
```bash
# Para cada símbolo novo de contrato (flag, enum, status, opção de config) introduzido no
# diff: mostrar o produtor e o consumidor, ambos fora de tests/.
# Para cada símbolo removido: grepar o nome em src/, tests/, migrations/, doc/ e ambiente.
```
