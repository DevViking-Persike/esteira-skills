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

**E não presuma o que ela não dá.** A leitura natural do nome ("passa pelo cliente da casa, então
o contexto do usuário viaja") é a forma mais comum de inventar uma garantia: registro de log não é
propagação de credencial, correlação não é autenticação — e o teste do cliente só verifica a
requisição que o próprio código monta, não o que um componente inexistente deveria ter
acrescentado. Para cada comportamento que você **espera** da biblioteca, aponte no MR onde ele é
registrado, ou escreva que não existe (Regra 26). Pela mesma razão, valor derivado da biblioteca
se lê **da** biblioteca: copiar o padrão dela para uma constante local congela um número que ela
muda no próximo bump.

**Configuração aceita por duas vias descarta uma em silêncio.** Quando a API oferece a propriedade
e a sobrecarga, o método que escreve a saída costuma sobrescrever a propriedade
incondicionalmente: a via óbvia compila, roda, não lança — e o valor que chega ao cliente é o
outro. O teste asserta o **valor final da resposta**, não a atribuição no código.

**Exceção:** comportamento documentado no contrato público da biblioteca, com versão citada — aí a
doc é a fonte, e a divergência é defeito dela.

**Constante repetida.** O mesmo valor de negócio declarado em dois arquivos é divergência
esperando data.

**Família de irmãos.** Quando N caminhos respondem à **mesma pergunta de negócio** — detectar
cancelamento, classificar um erro, formatar uma frase, converter um número — ou gravam o **mesmo
grupo de colunas**, eles são uma família, e famílias divergem em silêncio: cada irmão tem teste
próprio, e cada teste passa. As três formas mais caras:

- **Predicado duplicado com alcance diferente.** O caminho por identificador único e o caminho por
  chave natural checam a mesma condição com cláusulas diferentes: a condição vale num e não vale
  no outro, e o registro que deveria ser barrado passa.
- **Fórmula duplicada com âncora diferente.** Dois efeitos que gravam as mesmas colunas derivam
  uma delas de origens distintas — e o irmão que grava só parte do grupo deixa a coluna restante
  ancorada num valor que não existe mais. Teste que asserta "exatamente uma atribuição"
  **confirma** o subconjunto em vez de pegá-lo.
- **Correção aplicada em um irmão só.** A conversão de resposta fora do contrato entrou num
  cliente e não no irmão; a frase de erro cobre todos os status menos justamente o que os dois
  clientes lançam.

**Como fechar a família:** um grep do nome do predicado, da coluna ou da frase nos irmãos antes de
fechar o achado; e um **teste de paridade** que roda os dois caminhos sobre o mesmo vetor de
entrada e exige resultado idêntico. Quando a família é um mapa (status → frase, código → tipo), o
teste tabelado se ancora nos valores que o **código produz**, não nos que o enum declara — senão o
mapa incompleto passa.

**Ressalva que a experiência cobra:** quando está aberta a pergunta de **qual irmão está certo**,
alinhar pelo mais numeroso é escolher sem autoridade. Em regra de cálculo financeiro isso é a
bifurcação de produto da Regra 25 escondida dentro de uma correção que parece mecânica — a
harmonização espera a resposta.

**Exceção:** irmãos que divergem de propósito por decisão de negócio, com a divergência nomeada
nos dois lados e um teste que a força.

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

# Predicado/coluna que aparece em mais de um caminho da mesma família
find <src-root> -name '*.cs' -print0 \
| xargs -0 grep -n '<nome-do-predicado>' | grep -v '[Tt]ests\?/'

# Dois conversores do mesmo formato discordando
find <mapper-root> -name '*.cs' -print0 | xargs -0 grep -nE 'TryParse|Convert\.|parse[A-Za-z]*\('

# Comportamento esperado da lib: onde ele é registrado?
find <api-root> -type f -print0 \
| xargs -0 grep -nE 'AddHttpMessageHandler|DelegatingHandler|<prefixo-da-lib-da-casa>'

# Propriedade atribuída antes da chamada que escreve a resposta: quem vence?
find <api-root> -name '*.cs' -print0 | xargs -0 grep -nA3 -E 'ContentType *=|Headers\['
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
