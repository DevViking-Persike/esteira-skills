# Regra 2 — Testes unitários + mutation

## Camada 1 — Princípio universal (agnóstico)

Toda função pública nova precisa de teste. Funções privadas relevantes também. Vale para qualquer linguagem do projeto.

### Critérios (bloqueantes)
- **Cobertura por pacote/módulo testável: ≥ 84%**
- **Eficácia de mutation testing: ≥ 84%**. Na ausência de ferramenta de mutation, reforçar testes via revisão manual de assertivas (cenários limite, erros, branches).
- **Mutation roda sempre junto com os testes.** Se a eficácia cair abaixo de 84%, o teste precisa ser fortalecido antes do commit.
- **Quebra de teste bloqueia commit** — nunca desabilite (`#[ignore]`, `it.skip`, `test.skip`, `@Ignore`, `t.Skip`) para passar CI.
- **Filesystem em teste:** usar o diretório temporário da plataforma. Nunca escreva fora do tempdir.
- **Estilo table-driven** quando há múltiplos casos (vetor de structs; `it.each`; `@parametrized`/`[TestCase]`).

### Motivação
Cobertura sem mutation dá falsa segurança — um teste que não muda quando o production code é mutado não está protegendo nada. O binômio cov + mutation ≥ 84% garante que os testes discriminam comportamento real.

### O assert prova o discriminador

Cobertura mede se a linha executou; mutation mede se o mutante morreu. Nenhum dos dois enxerga um
assert que **passaria igual no cenário errado** — e assert que não discrimina soma cobertura sem
proteger nada.

- **Asserte o campo que difere.** Quando o caminho protegido e o caminho cru convergem no mesmo
  tipo de exceção ou no mesmo estado final, assertar esse estado é assertar o que já era igual
  antes da correção. O discriminador é a causa aninhada, a mensagem traduzida ou o efeito que só
  um dos ramos produz.
- **Igualdade, não prefixo.** `StartsWith`/`Contains`/`Any` sobre valor de contrato — tipo de
  conteúdo, cabeçalho, rota, código, mensagem — chega a passar **por causa** do defeito, quando o
  valor certo é uma extensão do errado.
- **Precedência entre duas fontes só trava com o caso que as contradiz.** Se o valor da fonte e o
  valor recalculado localmente coincidem nos dados de teste, nenhum assert diz quem manda.
- **Ramo cujo resultado é idêntico ao do fallback é imatável.** Se remover o ramo mantém a suíte
  verde, ou existe o caso que os separa, ou o ramo sai (Regra 20).
- **Assert de ausência de efeito desejável exige justificativa escrita.** Fixar "não grava
  trilha" transforma lacuna em requisito e, na rodada seguinte, bloqueia a correção certa: quem
  for consertar vê vermelho e acha que quebrou algo.

Sinal barato: **constante pública de mensagem sem nenhuma asserção no repositório** — o texto
existe, ninguém confere, e a Regra 20 já diz o que isso é.

**Exceção aceita:** assert por prefixo quando o sufixo é gerado (identificador, timestamp, hash)
— e aí o prefixo asserido vai até o último caractere estável, não até onde deu. Teste de fumaça
declarado como tal pode assertar só o tipo; ele não conta para o threshold nem fecha achado de
comportamento.

### Fidelidade do dublê e do ambiente

O dublê é parte do teste, não cenário de fundo. Se ele descarta um campo, o assert sobre esse
campo não existe — e mutation não pega, porque o mutante morre contra um fake que nunca teve o
dado.

1. **Tipo de retorno idêntico ao real.** Dublê que devolve nada onde o real devolve uma promessa
   faz o ramo de continuação — justamente onde o defeito mora — nunca ser percorrido, com a linha
   contando como coberta.
2. **Captura de todos os campos que algum assert afirma.** Dublê de registro de log que guarda só
   o texto renderizado torna decorativo todo assert sobre nível e sobre a exceção anexada:
   remover o argumento de exceção de **todas** as chamadas mantém a suíte inteira verde.
3. **Nenhuma relação fixada pelo construtor de dados.** Auxiliar de fixture que deriva um campo
   dos outros (total = quantidade de itens) torna **estruturalmente impossível** a condição que o
   teste existe para medir. O caso que mede a relação monta o dado inline.
4. **Progressão de estado.** Dublê de contrato com máquina de estados precisa convergir: uma
   linha que nasce na fila e nunca progride faz a tela ser validada contra um contrato que nunca
   termina.

E o dublê **não decide o que a produção pode fazer**: quando o fake impede a construção correta
(uma trava de linha, uma cláusula, um índice), quem muda é o fake — nunca o código.

**O ambiente do teste é o mesmo tipo de dublê.** Teste que roda em motor diferente do de produção
certifica o que não exercitou: dialeto, collation, tratamento de nulo, ordenação, trava de linha.
No navegador a diferença é sistemática e mais fácil de esquecer, porque o executor de testes roda
em `localhost`, que **é** contexto seguro: capacidades que dependem de contexto seguro, de
permissão do usuário ou de cabeçalho exposto por política de origem cruzada existem **sempre** no
teste e podem não existir no usuário. O README de testes diz qual ambiente cada dublê substitui e
que subconjunto ele garante.

| Ambiente do teste | O que ele não exercita |
|---|---|
| motor embarcado / em memória | dialeto, collation, nulo, ordenação, trava de linha, contagem de linhas afetadas |
| `localhost` no executor de testes | contexto seguro, permissão do usuário, cabeçalho exposto por origem cruzada |
| relógio e fuso da máquina | virada de dia, horário de verão, fim de mês |

**Exceção aceita:** dublê deliberadamente magro ou degradado, desde que o nome diga isso e que
nenhum assert da suíte dependa do campo omitido.

### Exceções aceitas (não contam para o threshold)
- **Entry point/bootstrap fino** do app: a lógica deve estar em módulos testáveis.
- Wrappers de rota/composição pura (sem lógica).
- Tokens de design / config pura, sem lógica.
- Componentes de apresentação pura (UI): testar via snapshot quando crescerem.
- Módulos com ≥ 80% de chamadas a SDK/IO externo (gateways, adapters de framework): aplicar o threshold apenas nas funções puras do módulo.

## Camada 2 — Preset por stack (escolha o do projeto)

> Veja `stacks/`. Comandos concretos por stack.

### Rust
```bash
cargo test                                  # testes
cargo tarpaulin --out Stdout                # cobertura
cargo mutants                               # mutation

# Módulos sem #[cfg(test)]
rg -L '#\[cfg\(test\)\]' <root>
```

### Node-TS
```bash
npm test                                    # testes (vitest/jest)
npm run test -- --coverage                  # cobertura (vitest)
npx stryker run                             # mutation (stryker)

# Arquivos .ts sem *.test.ts
find <root> -name '*.ts' -not -name '*.test.ts' | while read f; do
  base="${f%.ts}"; [ -f "$base.test.ts" ] || echo "sem teste: $f"
done
```

### Python
```bash
pytest                                      # testes
pytest --cov=<pkg> --cov-report=term-missing  # cobertura (pytest-cov)
mutmut run                                  # mutation (mutmut)

# Módulos sem test_*.py correspondente
<prencher: script de verificação>
```

### Go
```bash
go test ./...                               # testes
go test -cover ./...                        # cobertura
go-mutesting ./...                          # mutation

# Arquivos sem _test.go
find <root> -name '*.go' -not -name '*_test.go' | while read f; do
  base="${f%.go}"; [ -f "${base}_test.go" ] || echo "sem teste: $f"
done
```

### C#
```bash
dotnet test                                 # testes (xUnit/NUnit)
dotnet test --collect:"XPlat Code Coverage" # cobertura (coverlet)
Stryker.CLI                                 # mutation (Stryker.NET)
```

### KMP (Kotlin)
```bash
./gradlew test                              # testes JVM/Common
./gradlew jacocoTestReport                  # cobertura (JaCoCo)
# mutation: PIT/PITest (./gradlew pitest)
```

### Svelte/Angular/React
```bash
npm test                                    # vitest/jest
npm run test -- --coverage
npx stryker run
```

### RPA
Testes de fluxo automatizado: framework do vendor (UiPath Test Manager, Blue Prism Automated Testing) ou testes de scripts auxiliares (PowerShell `Pester`, Python `pytest`). Cobertura mede-se sobre os scripts, não sobre o fluxo declarativo. Sem ferramenta de mutation aplicável, em geral — reforçar revisão manual de assertivas.

## Camada 3 — Exemplo concreto (referência)

Função `calculate_discount(price, tier)` com branches `tier == 'gold'`, `tier == 'silver'`, fallback. Teste table-driven:

```typescript
it.each([
  { price: 100, tier: 'gold',   expected: 80 },
  { price: 100, tier: 'silver', expected: 90 },
  { price: 100, tier: 'bronze', expected: 100 },
])('discount for $tier', ({ price, tier, expected }) => {
  expect(calculate_discount(price, tier)).toBe(expected);
});
```

Mutation que inverte `tier == 'gold'` faz o teste falhar → mutante morto.

## Como verificar
```bash
# Escolha o preset da stack em Camada 2.
# 1. Rodar testes + cobertura + mutation.
# 2. Verificar módulos sem teste (grep/script).
# Threshold: cov ≥ 84% E mutation ≥ 84% por pacote/módulo.

# Asserts que não discriminam sobre valor de contrato
find <tests-root> -type f -print0 | xargs -0 grep -nE 'StartsWith\(|Assert\.Contains|toContain\('

# Assert de ausência: comportamento desejado ou lacuna canonizada?
find <tests-root> -type f -print0 | xargs -0 grep -nE 'Assert\.Empty|Assert\.Null|toEqual\(\[\]\)'

# Constante de mensagem que ninguém asserta
find <src-root> -name '*.cs' -print0 | xargs -0 grep -hoE 'const string [A-Za-z_]+' \
| awk '{print $3}' | sort -u \
| while read -r c; do
    find <tests-root> -type f -print0 | xargs -0 grep -q "$c" || echo "discriminador sem assert: $c"
  done

# Dublê infiel: retorno vazio onde o real devolve promessa; log sem captura de exceção
find <tests-root> -type f -print0 \
| xargs -0 grep -nE 'returnValue\(undefined\)|and\.stub\(\)|jest\.fn\(\) *[,)]|Substitute\.For<ILogger|Mock<ILogger'

# Builder que deriva um campo dos outros
find <tests-root> -type f -print0 | xargs -0 grep -nE '(total|Total) *[:=] *[A-Za-z_.]+\.(length|Count)'
```

### Tratando mutantes sobreviventes
1. Abrir o arquivo na linha indicada pelo relatório de mutation.
2. Identificar qual condição/branch não é coberta.
3. Adicionar caso de teste que falharia se a condição fosse invertida.
4. Rodar mutation de novo — esperar eficácia ≥ 84%.
