# Regras de engenharia

Cada arquivo em `eng/` define uma regra em **3 camadas** (princípio universal →
preset por stack → exemplo). Skills e os runbooks em `../commands/eng/`
referenciam regras específicas. Veja `eng/_layer-guide.md` para autorar/ler as
camadas e `../stacks/` para os presets concretos de cada stack.

| # | Regra | Verificação automatizada |
|---|-------|--------------------------|
| 1 | [Tamanho de arquivo (alvo ~300, teto ~500)](eng/01-file-size.md) | sim |
| 2 | [Testes unitários (≥ 84% cov + mutation)](eng/02-unit-tests.md) | sim |
| 3 | [SOLID](eng/03-solid.md) | parcial (grep de markers) |
| 4 | [Clean Architecture](eng/04-clean-architecture.md) | sim (grep de imports) |
| 5 | [Simplicidade](eng/05-simplicity.md) | não (code review) |
| 6 | [Refatoração contínua](eng/06-continuous-refactoring.md) | não (disciplina) |
| 7 | [Build & Run do app](eng/07-build-and-run.md) | sim (comando de build da stack) |
| 8 | [Delegar execução ao usuário](eng/08-delegate-execution.md) | não (disciplina) |
| 9 | [UI responsiva (mobile-first)](eng/09-responsive-ui.md) | parcial (grep + DevTools) |
| 10 | [Arquitetura de frontend (MVVM + Atomic)](eng/10-frontend-architecture.md) | parcial (grep de camadas) |
| 11 | [Fonte de paridade externa (opcional)](eng/11-external-parity-source.md) | não (referência) |
| 12 | [Código sem comentários](eng/12-no-comments.md) | sim (grep de marcador por stack) |
| 13 | [Contrato de borda (entrada do cliente nunca vira 5xx)](eng/13-contrato-de-borda.md) | parcial (grep de parse que lança) |
| 14 | [Documentação de contrato bate com o código](eng/14-doc-bate-com-o-codigo.md) | parcial (grep de rotas doc × código) |
| 15 | [Nenhuma falha desaparece em silêncio](eng/15-falha-silenciosa.md) | sim (grep de handler vazio) |
| 16 | [Higiene de ignore](eng/16-higiene-de-ignore.md) | sim (grep de glob de extensão na raiz) |
| 17 | [Integração verificada pelo caminho do cliente](eng/17-integracao-verificada-pelo-cliente.md) | parcial |
| 18 | [Loop de fundo é feature](eng/18-loop-de-fundo.md) | parcial |
| — | [Segurança](seguranca.md) | parcial |
| — | [Fluxo de desenvolvimento](fluxo-desenvolvimento.md) | não (disciplina) |

## Comandos instalados
- `/check-rules` — audita o repo contra todas as regras (runbook em `../commands/eng/`)
- `/refactor <arquivo>` — refatora um arquivo aplicando as regras relevantes
- `/responsive-pass <rota>` — audita e refatora UI aplicando Regra 9
- `/dead-code-cleansing` — identifica e remove código morto após confirmação

## Esteira de qualidade
As regras são **aplicadas** pela esteira de qualidade em `../esteira/` (gates
bloqueantes: `Q00-check → Q10-refactor → Q20-test/cov/mutation → Q30-review`). Valide
os templates com `bash .claude/tools/esteira-check.sh`.

Violação exige justificativa explícita no commit/PR.

> **Divisão por camada:** a tabela de aplicabilidade (backend × frontend) está em
> [`eng/README.md`](eng/README.md#divisão-por-camada).
