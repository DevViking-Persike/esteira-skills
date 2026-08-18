# Regras de engenharia — índice

Cada arquivo neste diretório define uma regra de engenharia universal. Skills (`commands/`) e etapas da esteira (`esteira/stages/`) referenciam regras específicas. A instalação num projeto concreto escolhe o **preset de stack** (Camada 2) e preenche os `<preencher>`.

## Índice

| # | Regra | Verificação automatizada |
|---|-------|--------------------------|
| 1 | [Tamanho de arquivo (alvo ~300, teto ~500)](01-file-size.md) | sim (`find … wc -l … awk '$1>500'`) |
| 2 | [Testes unitários (≥ 84% cov + mutation)](02-unit-tests.md) | sim (cov + mutation tools por stack) |
| 3 | [SOLID](03-solid.md) | parcial (grep de markers de framework/IO) |
| 4 | [Clean Architecture](04-clean-architecture.md) | sim (grep de imports entre camadas) |
| 5 | [Simplicidade](05-simplicity.md) | não (code review) |
| 6 | [Refatoração contínua](06-continuous-refactoring.md) | não (disciplina + histórico git) |
| 7 | [Build e execução do app](07-build-and-run.md) | por stack (ver `stacks/`) |
| 8 | [Delegar execução ao usuário](08-delegate-execution.md) | não (disciplina) |
| 9 | [UI responsiva (mobile-first)](09-responsive-ui.md) | parcial (grep de larguras fixas + DevTools) |
| 10 | [Arquitetura de frontend (MVVM + Atomic)](10-frontend-architecture.md) | parcial (grep de camadas) |
| 11 | [Repositório-fonte / paridade externa](11-external-parity-source.md) | não (referência) |
| 12 | [Código sem comentários](12-no-comments.md) | sim (grep de marcador por stack) |
| 13 | [Contrato de borda (entrada do cliente nunca vira 5xx)](13-contrato-de-borda.md) | parcial (grep de parse que lança) |
| 14 | [Documentação de contrato bate com o código](14-doc-bate-com-o-codigo.md) | parcial (grep de rotas doc × código) |
| 15 | [Nenhuma falha desaparece em silêncio](15-falha-silenciosa.md) | sim (grep de handler vazio) |
| 16 | [Higiene de ignore](16-higiene-de-ignore.md) | sim (grep de glob de extensão na raiz) |
| 17 | [Integração verificada pelo caminho do cliente](17-integracao-verificada-pelo-cliente.md) | parcial (URL do cliente × rota do servidor) |
| 18 | [Loop de fundo é feature](18-loop-de-fundo.md) | parcial (grep de laço sem teto) |

> O conjunto completo é **01–18** e todas as regras têm template neste diretório. Uma instalação num projeto materializa as 11; podas exigem registro no `MANIFEST.md` do projeto e nunca removem regra referenciada por esteira/runbooks.

## Formato: 3 camadas

Cada regra segue uma estrutura de **3 camadas** para equilibrar princípio universal e prescrição concreta:

1. **Camada 1 — Princípio universal (agnóstico):** motivação, como aplicar e exceções. Neutro em linguagem/framework. Vale para qualquer stack.
2. **Camada 2 — Preset por stack:** comandos/markers concretos por stack (Rust, Node-TS, Python, Go, C#, KMP, Svelte/Angular/React, RPA). Só as stacks onde a regra tem comando/marker concreto. Veja `stacks/`.
3. **Camada 3 — Exemplo concreto:** um worked example curto.

E fecha com **Como verificar** (bash/verificação, concreto por stack quando couber).

### Marcadores `<preencher>`
`<preencher: o quês>` indicam campos a substituir ao instalar no projeto (ex.: roots de código, idioma do histórico, markers de framework). Regra: sempre descritivo, nunca `<>` nu.

## Exceções
Violação de qualquer regra exige **justificativa explícita** no commit/PR. Exceções aceitas por regra estão listadas no corpo de cada uma (ex.: código vendorizado na Regra 1, módulos banhados em SDK na Regra 2/3).

## Verificação conjunta (esteira)
A verificação de todas as regras roda na **etapa `Q00-check`** da esteira (`esteira/stages/Q00-check.md`) — gate bloqueante antes de qualquer merge. O runbook `commands/eng/check-rules.md` orquestra a auditoria manual + automatizada contra este diretório.

### Relação com skills
- `check-rules` — audita o repo contra todas as regras
- `refactor <arquivo>` — refatora um arquivo aplicando as regras relevantes

## Divisão por camada

As regras vivem num diretório só (o caminho é referenciado por skills e pelo validador),
mas nem todas se aplicam a todo repo. Use esta tabela para saber o que cobrar em cada
revisão — e `stacks/` para o preset técnico correspondente.

| Regra | Backend | Frontend | Observação |
|---|:---:|:---:|---|
| 01 tamanho de arquivo | ✅ | ✅ | no frontend conta script + markup + estilo do componente |
| 02 testes + mutation | ✅ | ✅ | |
| 03 SOLID | ✅ | ✅ | |
| 04 clean architecture | ✅ | ✅ | frontend: fluxo routes → components → boundary |
| 05 simplicidade | ✅ | ✅ | posse de recurso pesa mais no backend; estado local no frontend |
| 06 refatoração contínua | ✅ | ✅ | |
| 07 build & run | ✅ | ✅ | |
| 08 delegar execução | ✅ | ✅ | disciplina do agente |
| 09 UI responsiva | — | ✅ | |
| 10 arquitetura de frontend | — | ✅ | MVVM + Atomic |
| 11 paridade externa | ✅ | ✅ | opcional; só com repo-fonte |
| 12 sem comentários | ✅ | ✅ | |
| 13 contrato de borda | ✅ | 〰️ | backend: 4xx/502. Frontend herda ao consumir API |
| 14 doc bate com o código | ✅ | ✅ | rota e DTO no backend; token de config e rota no frontend |
| 15 nenhuma falha em silêncio | ✅ | ✅ | frontend: toast, polling, capacidade do browser |
| 16 higiene de ignore | ✅ | ✅ | |
| 17 integração pelo caminho do cliente | ✅ | ✅ | é a regra da fronteira: exige os dois lados |
| 18 loop de fundo | 〰️ | ✅ | frontend: polling de tela. Backend: retry com teto e jitter |
| segurança | ✅ | 〰️ | frontend: PII em seed, exportação, secure context |

Legenda: ✅ aplica · 〰️ aplica em parte · — não aplica.

**Regras de fronteira** (13, 14 e 17) são as que mais falham, porque cada lado passa nos
próprios testes enquanto o par não conversa. Em MR que atravessa camadas, cobre as três
explicitamente.
