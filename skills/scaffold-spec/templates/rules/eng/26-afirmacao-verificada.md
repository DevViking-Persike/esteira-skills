# Regra 26 — Toda afirmação de review carrega a verificação que a sustenta

> **3 camadas:** Camada 1 (Princípio) é universal · Camada 2 diz onde o comportamento mora fora
> do repositório, por stack · Camada 3 traz o caso que originou a regra. Veja `_layer-guide.md`.
>
> Vizinhas: Regra 25 (como a thread fecha), Regra 21 (não reimplemente o que a plataforma dá),
> Regra 24 (disputa de convenção se encerra com artefato).

## Camada 1 — Princípio universal (agnóstico)

Vale para os dois lados da mesa. Quem afirma — revisor ou autor — diz **como verificou**. Sem
isso a afirmação vira ordem: quem recebe não tem como conferir, e o caminho barato é obedecer,
inclusive quando obedecer piora o código.

### Ausência não se prova por busca no repositório
Quando parte do comportamento vem de dependência — biblioteca de bootstrap da casa, preset de
framework, middleware embutido —, a busca no código-fonte não vê nada porque não há nada para
ver: o registro mora no pacote. Antes de afirmar "não existe rate limit", "não existe tratamento
global de exceção", "não existe health check", **inspecione o artefato**: leia ou decompile o
pacote, liste o que o container registrou, ou bata no serviço no ar. O reflexo de "corrigir" a
ausência inventada é pior que o achado: cria uma segunda fonte registrando a mesma coisa
(Regra 21).

### Evidência apresentada encerra o achado até ser contestada no terreno dela
Refutação com artefato — pacote decompilado, mapa de políticas do container, requisição real
devolvendo o status — muda o ônus de lado. Reafirmar o mesmo achado sem tocar nessa evidência
não é insistência: é **achado novo**, e precisa de verificação nova. Repetir a busca no
repositório depois de o artefato ter sido inspecionado não conta como contestação.

### Diff renderizado não é o repositório
A visualização do MR trunca, colapsa e omite. Antes de afirmar que um arquivo subiu vazio, que
um símbolo sumiu ou que um teste não existe, confira no worktree e no objeto do git.

### Consequência afirmada se confere antes de ser herdada
"Isso é laço infinito", "isso vaza memória", "isso derruba o serviço" mudam prioridade,
mobilizam gente e entram no relato do MR. Se o laço tem teto e condição de parada, a correção
pode ser a mesma e a consequência não é. Herdar a consequência de outra pessoa sem abrir o
código propaga o erro dela com a sua assinatura — e vale igual para a **sugestão recebida**:
derivar comportamento de um campo cujo conteúdo real é outro produz defeito com dois autores.

### Premissa que sustenta a correção se verifica no código
Antes de traduzir um código de status, mudar o alcance de um `catch` ou trocar o dono de uma
responsabilidade: confirme por leitura quem propaga o quê e quem consome o quê, e escreva a
ressalva que sobrou. Premissa verificada é correção; premissa assumida é aposta.

### Disputa de convenção encerra com artefato apontável
Convenção não se ganha por argumento mais longo. Ela se encerra com o link para o padrão
publicado da casa ou para o projeto de referência. O pedido certo, dos dois lados, é "me aponta
o projeto de referência" — cada rodada gasta em argumentação de princípio é rodada que o
artefato teria evitado.

### Registre o que ficou por verificar
Nem toda garantia é verificável na hora: índice em repositório de migrations, comportamento do
motor de produção, contrato de outro time. O que não foi verificado aparece **nomeado** no MR.
"Não verifiquei o índice" é informação; a omissão é dívida invisível.

### Motivação
Uma afirmação sem verificação custa uma rodada quando está certa e custa regressão quando está
errada. Afirmação errada de revisor sênior vira requisito para quem lê depois.

### Exceções aceitas
- Afirmação sobre o próprio trecho citado, que o trecho prova sozinho (nome, formatação,
  duplicação visível no diff).
- Achado de convenção interna já escrita, cuja evidência é a própria convenção.
- Artefato indisponível para inspeção: aí a afirmação vira **pergunta**, sem severidade
  bloqueante, e a thread fica aberta (Regra 25).

## Camada 2 — Preset por stack

| Stack | O que a busca no repositório não vê | Como inspecionar o artefato |
|---|---|---|
| C# | registro feito pelo pacote da casa, filtros e middlewares embutidos | `dotnet list package`, decompilar (`ilspycmd`), dump do container no boot |
| Node-TS | preset de framework, plugin, config resolvida em `node_modules` | `npm ls <pkg>`, ler o `dist` do pacote, imprimir a config efetiva |
| Python | middleware de framework, dependência instalada | `pip show`, `python -c "import <pkg>; print(<pkg>.__file__)"` |
| Go | módulo em cache, `init()` de dependência | `go list -m all`, ler o módulo no `GOMODCACHE` |
| Angular | builder, schematic e interceptor registrados por lib | `ng config`, ler o `dist` da lib, listar interceptors no injector |

```bash
# Antes de afirmar que um wiring não existe
find <api-root> -name 'Program.cs' -print0 | xargs -0 grep -nE 'Add[A-Z]|Use[A-Z]'
<comando-de-inspecao-do-pacote>                      # decompilar / ler o artefato
curl -s -o /dev/null -w '%{http_code}\n' <url-que-exercita-a-capacidade>

# Antes de afirmar que um arquivo subiu vazio ou que um símbolo sumiu
wc -l <path>; git show HEAD:<path> | wc -l
```

## Camada 3 — Exemplo concreto

Dois achados de severidade alta bloquearam uma MR de BFF financeiro por **nove rodadas**,
afirmando que a API não tinha limitação de taxa nem tratamento global de exceção. Os dois vinham
da biblioteca de bootstrap da casa: a prova saiu da decompilação do pacote, da inspeção do
container (o mapa de políticas já trazia `default` e `public`) e de uma requisição real
devolvendo `429`. A busca no repositório estava correta e a conclusão estava errada — o wiring
não mora no código-fonte. Aplicar a "correção" pedida teria registrado a mesma política duas
vezes, com dois lugares para divergir.

A evidência foi apresentada na terceira rodada e o achado voltou idêntico em mais cinco, sempre
com nova busca no mesmo arquivo de composição e nunca tocando no artefato. Na mesma MR, um
achado acusou o arquivo de teste do componente mais complexo de ter subido vazio: ele tinha 644
linhas no worktree — o diff renderizado é que não o mostrava — e circulou por duas rodadas antes
de alguém rodar `wc -l`.

## Como verificar
```bash
# 1. Toda afirmação de ausência no MR aponta a inspeção do artefato, não a busca no repo.
# 2. Toda afirmação sobre arquivo/símbolo cita wc -l ou git show, não a tela do diff.
# 3. Todo achado reafirmado depois de refutação cita onde a evidência anterior falha.
# 4. Toda consequência afirmada cita o trecho que a produz (teto, parada, caminho de erro).
# 5. Toda garantia não verificada aparece nomeada no MR.
```
