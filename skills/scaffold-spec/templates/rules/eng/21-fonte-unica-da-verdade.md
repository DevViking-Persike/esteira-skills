# Regra 21 — Uma fonte de verdade por conceito

> **3 camadas:** Camada 1 (Princípio) é universal · Camada 2 traz o preset por stack ·
> Camada 3 traz os casos que originaram a regra. Veja `_layer-guide.md`.

## Camada 1 — Princípio universal (agnóstico)

Todo conceito do sistema tem **um** lugar que o define. Quando a mesma definição existe em
dois lugares, ela não fica duplicada: ela fica **divergente**, e a divergência não quebra
build nem teste — ela aparece em produção, no dia em que alguém alterou um lado.

### As formas que mais aparecem

**Lista paralela de estados.** Se existe uma tabela de transições, ela é a fonte da verdade
do ciclo de vida. Conceitos como *pendente*, *terminal*, *reprocessável* e *despachável*
**derivam** dela — nunca de uma lista de valores escrita à mão. A lista paralela envelhece em
silêncio no dia em que um estado novo entra no enum, e quem paga é o agregado: com o conceito
errado de "acabou", ele vai cedo demais para um status terminal que o repositório depois se
recusa a atualizar, e o registro congela.

**Catálogo fixo em código × tabela no banco.** Se o banco guarda a mesma definição que o
código, decida **quem manda** e escreva a decisão. Quando a coleção fica fixa em código por
uma restrição de compilação (cada item exige uma coluna tipada, um `case` no mapeador, um
membro de enum), essa restrição vira o **nome** do método que constrói a coleção — não um
comentário (Regra 12). Sem isso, o próximo revisor faz de novo a pergunta "por que hardcode?".

**Reimplementar capacidade da plataforma.** Antes de escrever endpoint de infraestrutura
(health/liveness, versão, métricas, CORS, rate limit, tratamento global de exceção), confira o
que a lib de bootstrap ou o framework **já fornece** e apenas mapeie/configure. Reimplementar
cria rota duplicada e divergente — e a duplicata costuma ser a pior: um `ok` fixo que não
reflete o estado das dependências, ao lado do health real, sem ninguém saber qual probe
aponta para qual.

**Constante repetida.** O mesmo valor de negócio declarado em dois arquivos é divergência
esperando data.

### Quando a duplicata é inevitável, amarre com teste

Seed do banco × enum do código, contrato de planilha × colunas da tabela, catálogo × migration:
quando as duas pontas precisam existir, **um teste falha quando elas divergirem** — varrendo
`Enum.GetValues`/equivalente, ou comparando o catálogo com o que a migration semeia. Sem o
teste, "quem manda" é só uma intenção.

### Motivação
Duplicação de código custa edição. Duplicação de **fonte de verdade** custa correção errada:
o time altera o lado que encontra primeiro, o outro segue em produção, e o defeito
ressurge parecendo novo.

### Exceções aceitas
- Duplicação deliberada por decisão de design (dois primitivos visualmente distintos que
  parecem iguais) — Regra 5.
- Cópia vendorizada de repo-fonte externo — Regra 11.
- Cache/materialização explícita, com o caminho de invalidação escrito.

## Camada 2 — Preset por stack

```bash
# Lista de estados escrita à mão ao lado de uma tabela de transições
rg -n 'is\s+\w+\.\w+\s+or\s+|in \(.*Status\.|== Status\.' <domain-root>

# Constante de negócio declarada em mais de um arquivo
rg -on '(const|static readonly|final|#define)\s+\w+\s*=\s*\S+' <src-root> \
  | awk -F'=' '{print $2}' | sort | uniq -d

# Endpoint de infraestrutura reimplementado — confira antes o que a lib já mapeia
rg -n 'health|/alive|/ready|/live|/version|/metrics' <api-root>
```

| Stack | Onde a plataforma já resolve |
|---|---|
| C# / ASP.NET | `AddHealthChecks`/`MapHealthChecks`, `IExceptionHandler` + ProblemDetails, `UseRateLimiter`, lib de bootstrap da casa |
| Node-TS | middlewares do framework (helmet, cors, rate-limit), `terminus` para health |
| Python | `fastapi` dependencies, `starlette` middlewares |
| Go | `chi`/`echo` middlewares, `net/http/pprof` |

> Antes de reimplementar: **decompile/leia** o que a lib da casa faz no boot em vez de supor.
> Suposição sobre a lib é a origem mais comum da duplicata.

## Camada 3 — Exemplo concreto

Num MR de backend de atualização de apólice em lote, quatro faces do mesmo defeito:

| Duplicata | Consequência |
|---|---|
| `EstaPendente(s) => s is Pronto or EmProcessamento`, ao lado de uma tabela de transições que já sabia quais estados são terminais | dois estados não-terminais ficavam de fora; a planilha ia para *Erro* com retry ainda pendente e **congelava**, porque o repositório não atualiza a partir de status terminal — nem a tentativa bem-sucedida nem o redespacho a destravavam |
| a mesma lista escrita uma terceira vez no despachador (`EhDespachavel`/`EhRetentavel`) | três listas para o mesmo conceito |
| catálogo de templates fixo em código × tabela `template` no banco | duas definições para a mesma coisa, podendo divergir sem nenhum teste falhar |
| controller `live` devolvendo `Ok(true)` × health da lib de bootstrap (`/alive`, `/health/live`, `/health/ready`) | rota duplicada que **não** reflete o estado das dependências |

A correção do primeiro item foi derivar da tabela de transições
(`!TransicoesItem.EhTerminal(status)`) e somar um teste que varre todos os valores do enum —
para que um estado novo não passe batido.

## Como verificar
```bash
# 1. Para cada conceito de ciclo de vida citado no diff: ele deriva da tabela de transições?
# 2. Para cada coleção fixa em código: existe a mesma definição no banco/migration? Quem manda
#    está escrito (no nome, não em comentário)? Há teste amarrando as duas pontas?
# 3. Para cada endpoint/middleware de infraestrutura novo: a plataforma já fornecia?
```
