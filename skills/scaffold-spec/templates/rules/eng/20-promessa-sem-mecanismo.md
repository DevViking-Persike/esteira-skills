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

### Ao remover um comportamento, remova a máquina inteira

Quando uma decisão elimina um comportamento, saem no mesmo commit: o estado (valor de enum,
status), a opção de configuração, o laço, a flag do contrato, o dublê de teste que só existia
para ele, a **documentação** e — este é o que escapa — o **seed do banco**. Status semeado
que nenhum código mais produz continua chegando pela leitura e derruba o mapeamento em
runtime.

Remover só o símbolo apontado na revisão devolve o problema pela próxima rodada.

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
