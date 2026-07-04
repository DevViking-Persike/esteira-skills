---
name: scaffold-spec
description: >-
  Monta a base operacional .spec de um projeto e orquestra as skills da esteira
  (discovery, arquitetura, desenvolvimento, qa/qa-rpa, seguranca/redteam, deploy)
  para construir um projeto inteiro e bem estruturado. Cria cadência de sprints,
  MANIFEST, STATE, RUNBOOK, reference, rules, commands, tools e hooks. Use quando
  o usuário pedir "criar estrutura .spec", "scaffold spec", "montar um projeto do
  zero", "bootstrap operacional", "preparar projeto pra criar/refatorar/documentar
  um sistema", ou "/scaffold-spec [criar|refatorar|documentar]".
---

# Skill: scaffold-spec

Monta a **base operacional** de um projeto: o diretório `.spec/` (cadência de
sprints por disciplina + índice + estado + runbook), as **rules** de engenharia,
os **commands** do Claude Code e a **skill de deploy**. Generaliza o padrão
validado em produção. Funciona em projeto novo (greenfield) ou existente.

> **Princípio do projeto:** `rule` = fonte de verdade (conhecimento); `skill` =
> runbook que aplica. O `.spec/` é o manual operacional; roteadores como
> `CLAUDE.md` só apontam pra ele.

## Compatibilidade Claude Code + Codex

- Mantenha as skills do Claude Code como fonte de verdade.
- Para Codex, no projeto consumidor, crie `.codex/skills` como symlink para
  `.claude/skills`.
- Não crie cópias divergentes de `SKILL.md`; se precisar ajustar uma skill,
  ajuste a fonte e deixe o symlink refletir.
- Arquivos TOML não são necessários para skills Codex neste formato. Use
  `SKILL.md` com frontmatter YAML e, quando existir, `agents/openai.yaml`.

## Ecossistema — `scaffold-spec` é o hub

Esta skill **monta a base e relaciona todas as outras** para construir um projeto
inteiro e bem estruturado. Cada disciplina da esteira tem sua skill; o `scaffold`
as **instala** e o `RUNBOOK` as **invoca na ordem**:

```
/scaffold-spec [criar|refatorar|documentar]   ← monta .spec/ + rules + commands + skills + tools + hooks
        │
        ▼   a esteira, dirigida pelas skills (gates bloqueantes):
00  /discovery [negocio|dev|refatoracao]   → contexto (seletor de modos: skills/discovery/SKILL.md)
10  /arquitetura design                    → gate: a abordagem é sã?
20  /desenvolvimento                       → implementa (testes junto)
10  /arquitetura review                    → gate: o diff bate com plano/ADR? 0 violação de camada
25  /review-codigo-subagents               → review técnico por lanes/subagents
30  /qa  →  /qa-rpa                         → validação real front+back de cada tela (RPA)
40  /seguranca  →  /redteam                → pentest autorizado (próprio local/dev)
    /deploy                                → build → registry → apply → smoke
    .claude/tools/spec-check.sh            → valida a entrega (estrutura + links)
```

| Skill | Papel | Etapa |
|---|---|---|
| **scaffold-spec** | monta a base + orquestra (o **hub**) | — |
| `discovery` | levanta o contexto (3 modos — seletor em [`discovery/SKILL.md`](../discovery/SKILL.md)) | 00 |
| `arquitetura` | gate de **design** (antes) e **review** (depois do dev) | 10 |
| `desenvolvimento` | implementa conforme spec + plano | 20 |
| `review-codigo-subagents` | sprint de review de código por subagents independentes | 25 |
| `qa` / `qa-rpa` | gate de QA / **RPA front+back** automatizado de cada tela | 30 |
| `seguranca` / `redteam` | gate de segurança / **pentest** do próprio local-dev | 40 |
| `deploy` | sobe o projeto (build → apply → smoke) | transversal |

> **Esteira de qualidade (transversal):** além da esteira de *processo* acima, o
> scaffold instala uma esteira de *qualidade de código* em `.claude/esteira/`
> (gates bloqueantes `00-check → 10-refactor → 20-test/cov/mutation → 30-review`),
> com presets de stack em `.claude/stacks/` e templates de orquestração multi-agente
> em `templates/agents/`. Roda autônoma sobre um diff/branch ou wired após
> `/desenvolvimento`, alimentando `/arquitetura review` e `/review-codigo-subagents`.
> Valide com `bash .claude/tools/esteira-check.sh`.

> **Relação bidirecional:** o `scaffold` instala e referencia todas; cada skill de
> etapa aponta de volta pra sua disciplina em `.spec/sprints/` e pras regras do projeto.
> Resultado: o projeto fica **íntegro da base à entrega validada**. O `RUNBOOK.md`
> gerado deve **invocar a skill de cada etapa** na ordem (ver blueprint no Passo 1).

## Fases do pipeline (LionClaw) → disciplinas da esteira

O orquestrador roda o pipeline com as **14 fases** do LionClaw, agrupadas em
**5 macro-stages**. A esteira `.spec/` é o **mesmo modelo em arquivos**: cada
macro-stage cai numa disciplina, e o **Execution é o que materializa as sprints de dev**.
Ao scaffoldar (modo `criar`/`refatorar`), o `.spec/sprints/` e o `RUNBOOK` devem refletir
esta expansão — não só as disciplinas nuas.

| Macro-stage LionClaw | Fases | Disciplina `.spec/` | Materializa |
|---|---|---|---|
| **1 Discovery** | Discovery | `00-discovery` | contexto (Mom Test / JTBD / 4 riscos) |
| **2 PRD** | PRD Generator → Validator → Completo | `00-discovery` (negócio) | PRD aprovado (gate no Validator) |
| **3 Tech** | Database, Backend, Frontend, Security (4 entrevistas de design) | `10-arquitetura` (design) | decisões técnicas por área (gate) |
| **4 Spec** | Spec Generation → Spec Enricher | `10-arquitetura` (saída) | a SPEC implementável (gate no Enricher) |
| **5 Execution** | **Planner → Sprint Validator → Coder → Evaluator** | `20-desenvolvimento` | **as sprints** — Planner quebra em `NN`, Coder/Evaluator executa+revisa cada uma |

> **Chave do vínculo:** o **Planner** (Execution) transforma a SPEC nas **sprints de
> `20-desenvolvimento`** (`desenvolvimento-NN-<tema>.md`, um `NN` por sprint); o **Sprint
> Validator** é o gate do plano; o loop **Coder/Evaluator** implementa e avalia cada sprint,
> que então fecha com `30-qa` + `40-seguranca`. É assim que "discovery + development viram
> as sprints de desenvolvimento" — o pipeline do orquestrador e o `.spec/` são um modelo só.
> Fases `conversation` (PRD Validator, as 4 Tech, Spec Enricher, Sprint Validator) são
> **gates bloqueantes** (`GateMode::Gated`); `auto` fluem sozinhas.

## Modo N/D/R → esteira derivada (+ foco opcional)

O **modo de discovery** (`negocio`/`dev`/`refatoracao`) não é só o que investigar —
ele **deriva a esteira de pipeline** que o orquestrador monta. Um **foco opcional**
(Segurança / Arquitetura / UI-Design) **injeta fases** numa esteira mais específica,
sem virar um "tipo" à parte. É assim que as pipelines especializadas (auditoria,
review de arquitetura) ficam alcançáveis a partir do modo, **sem uma tela de "tipo"**.

| Modo | Foco | Esteira derivada | Fases | Racional |
|---|---|---|---|---|
| **Negócio** | — | **feature-first** | 14 (feature + cauda) | entregar valor a repo existente; discovery§negócio ≈ Feature Discovery |
| **Desenvolvimento** | — | **development** (base) | 14 | greenfield / build do zero (base canônica) |
| **Desenvolvimento** | **UI/Design** | **development + Open Design** | 17 | bloco de design (Design Plan → Studio → Lock) |
| **Refatoração** | — | **arch-review** | 11 | operar sobre código existente ≈ discovery§refatoração aprofundado |
| **Refatoração** / **Negócio** | **Segurança** | **security-audit** | 11 | auditoria estática repo-wide → spec de remediação |
| **Refatoração** / **Negócio** | **Arquitetura** | **arch-review** | 11 | review de arquitetura como foco transversal |

- **Precedência:** o foco, quando setado, **especializa** a base do modo.
- **Guarda por modo:** `UI/Design` só sob **Desenvolvimento**; `Segurança`/`Arquitetura`
  só sob **Refatoração** ou **Negócio-se-repo-existente** — o wizard **não** oferece
  combinações sem sentido (ex.: greenfield + Segurança).
- O modo escolhido **semeia** os discovery-modes (`[modo]` + refino opcional); modo =
  discovery-mode = **seletor de esteira** (mesmo vocabulário nativo N/D/R).

### Focos injetam fases, não são um "tipo"

Um **foco** especializa a esteira acrescentando/trocando fases da cabeça; ele **não**
é uma disciplina nova nem uma skill nova. Em particular, o **foco Segurança** é
distinto das duas skills de segurança da disciplina 40:

| Ator | O que é | Quando | Disciplina |
|---|---|---|---|
| **foco Segurança** (esteira) | análise **estática** repo-wide → gera tasks de remediação (spec) | design-time, ao derivar a esteira | 25 (lane Segurança em escopo de repo) |
| `/redteam` | exploração **dinâmica** do ambiente vivo (PoC de invasão) | pós-dev, ambiente local/dev | 40 |
| `/seguranca` | **gate** que confere cobertura/severidade contra os invariantes | último portão antes do release | 40 |

O "Security Audit" da esteira **reusa** a lane Segurança da disciplina 25 (ampliando o
escopo de *diff* para *repo*), **não** cria um 4º conceito. Idem foco Arquitetura: é a
esteira `arch-review`, que **reusa** o gate `/arquitetura` — não uma skill à parte.

## Entrada — MODO

> **Dois eixos ORTOGONAIS** (não confundir): o **scaffold-mode** abaixo
> (`criar`/`refatorar`/`documentar`) diz **como executar** cada sprint; o **modo
> N/D/R** (`negocio`/`dev`/`refatoracao`, seção anterior) diz **o que investigar /
> qual esteira derivar**. `refatorar` aparece nos dois eixos com sentidos diferentes.

A skill aceita um modo em ARGUMENTS (default: perguntar):

| Modo | Quando | Ênfase da esteira |
|---|---|---|
| **criar** | sistema novo (greenfield) | Discovery (escopo) → Arquitetura (design do zero) → Dev → QA → Segurança |
| **refatorar** | sistema existente | Discovery = inventário do estado atual + metas + critérios de **não-regressão**; Arquitetura = atual×alvo; Dev incremental; QA pesado em regressão; Segurança = re-auditoria |
| **documentar** | sistema existente sem docs | Discovery = engenharia reversa/inventário; "Dev" vira **escrever docs**; QA = doc bate com o código; produz `reference/` + mapa de arquitetura |

Se o usuário não passou o modo, **pergunte qual** antes de gerar (muda os
critérios de aceitação e a ênfase).

## Passo 1 — Gerar o esqueleto `.spec/`

Crie esta árvore na raiz do projeto-alvo (não sobrescreva o que já existir sem
confirmar):

```
.spec/
├── MANIFEST.md              # mapa read-first (índice de tudo)
├── STATE.md                 # estado vivo do incremento atual
├── reference/               # docs de referência do projeto (arquitetura, roadmap, etc.)
│   └── README.md
└── sprints/
    ├── README.md            # framework das 5 disciplinas + fluxo da esteira
    ├── RUNBOOK.md           # como rodar a esteira (ordem + gates bloqueantes)
    ├── 00-discovery/        { README.md, _TEMPLATE-discovery.md }
    ├── 10-arquitetura/      { README.md, _TEMPLATE-arquitetura.md }
    ├── 20-desenvolvimento/  { README.md, _TEMPLATE-desenvolvimento.md }
    ├── 25-review-codigo/    { README.md, _TEMPLATE-review-codigo.md }
    ├── 30-qa/               { README.md, _TEMPLATE-qa.md }
    └── 40-seguranca/        { README.md, _TEMPLATE-seguranca.md }
```

### Conteúdo de cada arquivo (blueprint)

**`MANIFEST.md`** — ponto de entrada único. Seções: *Bootstrap de sessão* (ordem
de leitura: MANIFEST → STATE → RUNBOOK → disciplina atual); *Mapa do `.spec/`*
(tabela caminho→o quê); *Disciplinas → onde olhar* (tabela etapa→README→docs de
referência); *Regras de execução* (tabela apontando `.claude/rules/*` e, no
Codex, para a regra equivalente do projeto);
*Maquinário de validação* (comandos de teste/build/lint do projeto); *Regra-mãe*
(o que governa o escopo — preencher com o contrato/escopo do projeto).

**`STATE.md`** — estado vivo. Campos: incremento ativo (NN, tema, etapa, branch,
atualizado em); tabela de progresso da esteira
(00→10→20→10-review→25-review-codigo→30→40 com
status ⬜🟡✅🔴); último resultado de validação; pendências; itens aguardando
aprovação; histórico de incrementos; protocolo de atualização (atualizar ao
entrar/sair de cada etapa; nunca avançar com gate reprovado).

**`sprints/README.md`** — as 6 disciplinas (00 Discovery, 10 Arquitetura [gate
transversal], 20 Desenvolvimento, 25 Review de Código, 30 QA, 40 Segurança), o
fluxo da esteira
(`00 → 10-design → 20 → 10-review → 25-review-codigo → 30 → 40 → release`,
Arquitetura roda 2× como gate bloqueante), os handoffs (contrato entre disciplinas) e a convenção de
instância (`<disciplina>-NN-<tema>.md`, mesmo NN em toda a esteira). O
**Discovery** (00) fecha com fan-in: emite `.spec/discovery/plano-de-sprints-NN.md`
(1 linha por sprint derivado — scaffold-mode + ACs + discoveries-fonte + ordem),
o backlog fatiado que o RUNBOOK consome a seguir.

**`sprints/RUNBOOK.md`** — como rodar a esteira autonomamente: no início, o
**seletor de modos do Discovery** (`/discovery [negocio|dev|refatoracao]`,
default por scaffold-mode — ver `discovery/SKILL.md`); ler STATE → retomar
etapa; depois do Discovery aprovar o `plano-de-sprints-NN.md`, **loop "para
cada item do backlog: `10→20→25→30→40`"** — cada sprint derivado do plano
entra na esteira pela Arquitetura, invocando a skill de cada etapa
(`/arquitetura` → `/desenvolvimento` → `/arquitetura review` →
`/review-codigo-subagents` → `/qa`+`/qa-rpa` → `/seguranca`+`/redteam` →
`/deploy`), com os **gates bloqueantes**; comandos reais por etapa; **paradas
obrigatórias** (pedir humano): item fora do escopo sem aprovação, ação destrutiva/
produção, gate reprovado 2×, decisão estrutural sem registro, segredo.

**Disciplinas (`NN-*/README.md`)** — cada uma com: Propósito; Quando roda
(gate/ordem); Definition of Ready (entrada); Atividades/Checklist; Definition of
Done (saída); Anti-patterns; link pro `_TEMPLATE`. Adapte a ênfase ao MODO
escolhido (ver tabela de modos). O `_TEMPLATE-*.md` é o molde fill-in-the-blank
de uma instância.

> Use o `.spec/` de referência (um projeto já estruturado) como referência de qualidade do
> conteúdo, **generalizando** o que for específico de domínio (regras fiscais,
> Zitadel, etc.) para placeholders `<...>`.

## Passo 2 — Instalar rules, commands, skills de etapa, deploy, tools e hooks

A esteira é **dirigida por skills** (uma por etapa) que o `scaffold` orquestra.
Copie tudo para o projeto-alvo em `.claude/skills` e, quando usar Codex, crie um
symlink para essa árvore canônica:

```bash
S=.claude/skills/scaffold-spec/templates
# rules de engenharia (3 camadas) + segurança/fluxo
mkdir -p .claude/{rules,commands,stacks,esteira,tools,skills}
cp -R $S/rules/eng/. .claude/rules/
cp $S/rules/seguranca.md $S/rules/fluxo-desenvolvimento.md $S/rules/README.md .claude/rules/ 2>/dev/null || true
# runbooks LLM-agnostic (ative o frontmatter comentado p/ Claude Code; cole como prompt em outros LLMs)
cp -R $S/commands/eng/. .claude/commands/
# catálogo de stacks — Camada 2 das rules referencia estes comandos concretos
cp -R $S/stacks/. .claude/stacks/
# esteira de qualidade de código (gates bloqueantes + stages + RUNBOOK)
cp -R $S/esteira/. .claude/esteira/
# skills da esteira de processo — copiar do repo-fonte, ou já globais em ~/.claude/skills/
cp -R .claude/skills/{discovery,arquitetura,desenvolvimento,qa,qa-rpa,seguranca,redteam,review-codigo-subagents} <dest>/.claude/skills/ 2>/dev/null || true
# skill de deploy (copiar a pasta para preservar agents/openai.yaml)
cp -R $S/skills/deploy .claude/skills/
# Codex: manter .claude/skills como fonte canônica e apontar para ela
mkdir -p .codex
[ -e .codex/skills ] || ln -s ../.claude/skills .codex/skills
# tools de validação
cp $S/tools/spec-check.sh $S/tools/esteira-check.sh .claude/tools/ && chmod +x .claude/tools/*.sh
# hooks (opt-in): ver $S/hooks/README.md
# agents/*.tpl NÃO são auto-instalados — instancie sob demanda substituindo {{...}} (ver agents/README.md)
```

**Skills de etapa — a esteira chama em ordem:**
| Etapa | Skill |
|---|---|
| 00 Discovery | `/discovery [negocio\|dev\|refatoracao]` — 3 modos, seletor + mapa default×scaffold-mode em [`discovery/SKILL.md`](../discovery/SKILL.md) (não repetido aqui) |
| 10 Arquitetura | `/arquitetura [design\|review]` — gate 2× |
| 20 Desenvolvimento | `/desenvolvimento` |
| 25 Review de Código | `/review-codigo-subagents` — pipeline read-only por lanes/subagents |
| 30 QA | `/qa` (gate) + `/qa-rpa` (automação RPA front+back de cada tela) |
| 40 Segurança | `/seguranca` (gate) + `/redteam` (pentest autorizado do próprio local/dev) |

> Se as skills de etapa já estiverem **globais** (`~/.claude/skills/` ou
> `~/.codex/skills/`), não precisa copiar — só garanta que existem. O `RUNBOOK.md`
> invoca cada uma na etapa certa.

- **`rules/eng/`** — 11 regras de engenharia em **3 camadas** (princípio universal
  + preset por stack + exemplo) + `seguranca.md` + `fluxo-desenvolvimento.md`.
  Preencha placeholders `<preencher: ...>` conforme o projeto.
- **`stacks/`** — catálogo de presets (backend/frontend/mobile/RPA); a Camada 2
  das rules referencia estes comandos concretos.
- **`esteira/`** — esteira de qualidade de código (gates bloqueantes
  `00-check → 10-refactor → 20-test/cov/mutation → 30-review` + `RUNBOOK`).
- **`commands/eng/`** — runbooks LLM-agnostic (`check-rules`, `refactor`,
  `responsive-pass`, `dead-code-cleansing`). Para Claude Code, ative o frontmatter
  comentado no topo de cada um; em outros LLMs, cole o corpo como prompt.
- **`agents/`** — templates de orquestração multi-agente (`main-orchestrator`,
  `sub-orchestrator`, `worker-{build,test,validate}`). **Não auto-instalados** —
  instancie sob demanda substituindo `{{...}}` (ver `agents/README.md`).
- **`deploy/SKILL.md`** — runbook de deploy (build→registry→apply→smoke).
- **`tools/spec-check.sh`** + **`tools/esteira-check.sh`** — validam a entrega
  (`.spec/`) e a engenharia (agnosticidade LLM + estrutura + smoke install).
- **hooks** (`templates/hooks/`) — rodam o `spec-check` automaticamente (Stop /
  PostToolUse). **Opt-in:** mesclar no `.claude/settings.json` no Claude Code
  (não auto-aplicar). No Codex, use validação manual ou mecanismo equivalente.

## Passo 3 — Cabear o roteador do agente

**Não reescreva o roteador à mão.** Copie o template canônico e preencha os
`<...>`:

```bash
mkdir -p .claude
cp .claude/skills/scaffold-spec/templates/router/CLAUDE.md.tpl .claude/CLAUDE.md
# preencher <projeto>, <regra-mãe> etc. em .claude/CLAUDE.md
```

A **versão instalável pelo orchestrator é `.claude/CLAUDE.md`** (dentro de
`ROOTS` — o `CLAUDE.md` da raiz do projeto não é instalável pelo pipeline). O
template já traz, prontos e sem precisar redigitar: regra-mãe, bootstrap
(`MANIFEST.md` → `STATE.md` → `RUNBOOK.md`), a esteira 00→40 e as autoridades
(rules/skills/segurança). Não adicione conteúdo operacional aqui — se precisou
detalhar, o lugar é o `.spec/` ou uma `rule`.

Quando o scaffold roda **dentro do projeto-consumidor** (não no repo-fonte),
crie também o stub de 2 linhas na raiz apontando para o roteador real:

```bash
printf '# <projeto>\nEste projeto usa a esteira. Roteador: `.claude/CLAUDE.md` · Mapa: `.spec/MANIFEST.md`.\n' > CLAUDE.md
```

Para Codex, gere `AGENTS.md` a partir do **mesmo template** (gêmeo do
`CLAUDE.md.tpl`) — `spec-check.sh` valida os dois.

## Passo 4 — Fechar

- **Validar a entrega:** `bash .claude/tools/spec-check.sh` — deve dar OK (0 link
  quebrado, arquivos obrigatórios presentes). Corrija o que apontar.
- **Validar a engenharia:** `bash .claude/tools/esteira-check.sh` — valida
  agnosticidade LLM, resíduo de stack específica, estrutura (≤300 linhas) e
  smoke install dos templates de engenharia.
- Liste o que foi criado e o que tem placeholder `<...>` a preencher.
- Atualize `STATE.md` com o 1º incremento (ou deixe "nenhum ativo").
- Registre o que **não** rodou e por quê.
- **Não** commitar automaticamente — deixar para o usuário revisar.

## Anti-patterns

- ❌ Sobrescrever um `.spec/`/roteador existente sem confirmar.
- ❌ Gerar a esteira sem definir o MODO (criar/refatorar/documentar muda tudo).
- ❌ Copiar conteúdo específico de domínio de outro projeto
  para o projeto atual — generalize.
- ❌ Deixar o roteador gordo — ele só aponta; o manual vive no `.spec/`.
