# Regra 6 — Refatoração contínua

## Camada 1 — Princípio universal (agnóstico)

### Regra do escoteiro
Deixe o código melhor do que encontrou. Mas **no escopo apropriado** — nunca misture refatoração grande com bugfix/feature.

### Antes de adicionar feature
- Se o arquivo está > 280 linhas, refatorar primeiro (commit separado), feature depois.
- Se a função/componente alvo não tem teste, escrever **teste de caracterização** (cobre o comportamento atual), só então modificar.

### Antes de refatorar
- Os testes do projeto precisam passar.
- O typecheck/lint do projeto precisa passar.
- Testes existentes são **contrato** — não deletar. Se um teste ficou obsoleto, substituir por equivalente no novo código.

### Commits
- Um motivo por commit. Mensagens em conventional commits:
  - `refactor: ...` para mudança estrutural sem mudar comportamento
  - `test: ...` para testes isolados
  - `fix: ...` para bugfix
  - `feat: ...` para nova feature
  - `docs: ...` para documentação
  - `chore: ...` para config de build, deps, tooling
- `<preencher: idioma do histórico>` (ex.: pt-BR) — decida uma vez e mantenha.

### Corrija a classe, não o sintoma
Ao consertar um achado de review, procure os **irmãos** que compartilham o mesmo padrão e
conserte todos no mesmo commit. Aplicar a correção só onde apontaram devolve o problema
pelo próximo review, com o custo de mais uma rodada.

Grepe antes de fechar: outro client com o mesmo tratamento de erro, outro glob de ignore
com a mesma forma, a mesma promessa em outro trecho do doc.

### Reaproveitar exige inventariar
Reusar um método existente num contexto novo traz **todos** os efeitos dele, não só o que
você quer. Leia a função inteira antes de chamá-la de outro lugar: bloqueio de tela, reset
de estado, notificação e reordenação viajam junto e viram regressão no contexto novo.

### Mudança fora do escopo da história
Arquivo que não pertence ao card não entra no MR — nem para limpar código morto. Se a
limpeza vale, ela vale como commit próprio, com o motivo dela. Caso contrário o revisor
gasta tempo verificando regressão em algo que a história nem tocava.

### Bug descoberto no meio de refatoração
Parar, reportar ao usuário, perguntar se cria commit separado. **Não corrigir no mesmo commit** — ruído no histórico e dificulta revert.

### Motivação
Refactor contínuo evita a "big bang refactoração" que trava a equipe por semanas. Mas refactor misturado com feature/bugfix torna o PR irrevisível e o `git bisect` inútil. A disciplina é: refactor **sempre**, mas **isolado em commit próprio**.

### Exceções aceitas
- **Refactor de < 10 linhas** que é pré-requisito direto e inseparável da feature (ex.: extrair uma constante que a feature usa) — pode ir no commit da feature, desde que visível no diff.
- **Hotfix de produção**: a regra do escoteiro se aplica *depois* (commit de follow-up), não dentro do hotfix.

## Camada 2 — Preset por stack (escolha o do projeto)

> Veja `stacks/`. Os comandos de "antes de refatorar" são os mesmos de Regra 2.

### Rust
```bash
# Antes de refatorar — todos precisam passar
cargo test
cargo check
cargo clippy --all-targets -- -D warnings
# Pós-refactor de functions tocadas:
cargo mutants
```
Commits por camada: `refactor(backend): extrai trait X de module Y` / `test: caracteriza comportamento de Z` / `feat: usa trait X`.

### Node-TS
```bash
npm test
npm run check          # tsc / svelte-check / vue-tsc
npm run lint
# Pós-refactor: npx stryker run (nos arquivos tocados)
```
Commits: `refactor(frontend): ...` / `test: ...` / `feat: ...`.

### Python
```bash
pytest
mypy <pkg>             # ou pyright
ruff check <pkg>
# mutation: mutmut run --paths-to-mutate <files>
```

### Go
```bash
go test ./...
go vet ./...
golangci-lint run
# mutation: go-mutesting (nos packages tocados)
```

### C#
```bash
dotnet test
dotnet build
dotnet format --verify-no-changes
# mutation: Stryker.NET (dotnet stryker)
```

### KMP (Kotlin)
```bash
./gradlew test
./gradlew detekt
./gradlew ktlintCheck
# mutation: ./gradlew pitest
```

### Svelte/Angular/React
```bash
npm test
npm run check          # typecheck do framework
npm run lint
```

### RPA
- Antes de refatorar um fluxo: exportar versão atual + rodar fluxos de teste do vendor.
- Commits seguem o padrão: `refactor(rpa): extrai subfluxo X` / `fix(rpa): corrige condição Y`.

## Camada 3 — Exemplo concreto (referência)

Cenário: bug no cálculo de desconto (`calculate_discount`). Ao abrir o arquivo, vê que ele tem 380 linhas e mistura validação + cálculo + formatação.

**Sequência de commits (cada um verde):**
1. `test: caracteriza calculate_discount atual` — adiciona testes table-driven cobrindo o comportamento atual (incluindo o bug, marcado como esperado por agora).
2. `refactor: extrai validação de tier para tier_validation.ts` — puro split, sem mudar comportamento; testes ainda verdes.
3. `fix: corrige desconto gold quando price < 100` — ajusta o teste de caracterização (esperado muda), arruma o bug. Diff cirúrgico de 1-3 linhas.

Cada commit é revertível isoladamente. O `git bisect` consegue apontar exatamente o fix.

## Como verificar
```bash
# Não há automação direta para "refactor contínuo".
# Verificação indireta:
#   1. Histórico git com commits de refactor isolados (git log --oneline | grep '^refactor:')
#   2. Etapa Q00-check da esteira roda testes+lint+typecheck antes de qualquer merge.
#   3. Code review: PR com "refactor + feat" juntos é rejeitado até split.
```
