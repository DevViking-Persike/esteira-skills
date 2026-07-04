# Regras de Fluxo de Desenvolvimento

> Como o trabalho atravessa a esteira de `.spec/sprints/` (Discovery → Arquitetura
> → Dev → Review de Código → QA → Segurança). Há **2 eixos ortogonais** — ver
> seção "Os 2 eixos" abaixo. Este arquivo detalha o eixo **scaffold-mode**
> (CRIAR/REFATORAR/DOCUMENTAR); o eixo **discovery-mode**
> (negocio/dev/refatoracao) é definido e detalhado na skill `discovery`
> (`skills/discovery/SKILL.md`, seção "Seletor de modos") — não repetido aqui.

## Os 2 eixos

O trabalho é governado por **dois eixos independentes**, escolhidos em
momentos diferentes:

| Eixo | Valores | Responde | Onde se escolhe |
|---|---|---|---|
| **scaffold-mode** | `criar` / `refatorar` / `documentar` | **como executar** cada sprint (ênfase de cada disciplina 00→40, ver tabelas abaixo) | `/scaffold-spec [criar\|refatorar\|documentar]` |
| **discovery-mode** | `negocio` / `dev` / `refatoracao` | **o que investigar** antes de executar (banco de perguntas da Discovery) | seletor de `/discovery`, com default por scaffold-mode |

Os eixos são **ortogonais**: combinações não-contíguas (ex.: scaffold-mode
`criar` com discovery-mode `{negocio, refatoracao}`) são permitidas — o
scaffold-mode não restringe quais discovery-modes podem rodar, só sugere o
default. A ordem canônica dos discovery-modes (negocio→dev→refatoracao) fixa
apenas a **sequência de execução** quando mais de um é selecionado.

## Regra de fan-in: 1 rodada de Discovery → N sprints

Uma rodada de Discovery (os discovery-modes selecionados, rodados em ordem
canônica) fecha com **um único artefato de consolidação**:
`.spec/discovery/plano-de-sprints-NN.md` — 1 linha por sprint derivado
(scaffold-mode do sprint + ACs + discoveries-fonte + ordem/dependências).

A partir daí, **cada sprint do plano é uma esteira própria**: começa sempre
em **Arquitetura** (não repete a Discovery), reaproveitando os artefatos da
rodada compartilhada:

```
1 Discovery (negocio/dev/refatoracao) → plano-de-sprints-NN.md
        │
        ├─ sprint 1 → 10 Arquitetura → 20 Dev → 10 Arquitetura(review) → 25 → 30 → 40
        ├─ sprint 2 → 10 Arquitetura → 20 Dev → 10 Arquitetura(review) → 25 → 30 → 40
        └─ sprint N → 10 Arquitetura → 20 Dev → 10 Arquitetura(review) → 25 → 30 → 40
```

O **gate de saída da Discovery** é o "Plano de Sprints aprovado pelo usuário"
— bloqueante: só com o backlog fatiado (cada item com ACs verificáveis +
scaffold-mode definido) abre a 1ª Arquitetura.

## A esteira de um sprint (comum aos 3 scaffold-modes)

```
00 DISCOVERY → 10 ARQUITETURA(design) → 20 DEV → 10 ARQUITETURA(review) → 25 REVIEW CÓDIGO → 30 QA → 40 SEGURANÇA → release
```

- **Arquitetura é gate transversal** (roda 2×: valida o plano antes do dev e
  revisa o que o dev entregou). Cada gate é **bloqueante**: reprovou, volta uma casa.
- **Mesmo `NN`** em todas as disciplinas de um incremento (rastreia ponta a ponta).
- Estado vivo em `.spec/STATE.md`; como rodar em `.spec/sprints/RUNBOOK.md`.
- **Discovery e Arquitetura expandem nas fases LionClaw** (PRD, Tech, Spec); o **DEV
  é o Execution**: o **Planner** quebra a SPEC em sprints (`desenvolvimento-NN-<tema>.md`,
  um `NN` por sprint), o **Sprint Validator** é o gate do plano, e o loop **Coder/Evaluator**
  implementa e avalia cada sprint. Ver a tabela de mapeamento em `scaffold-spec/SKILL.md`.

---

## scaffold-mode CRIAR (sistema novo / greenfield)

Construir algo que não existe.

| Etapa | Ênfase |
|---|---|
| Discovery | escopo contra o contrato/objetivo; critérios de aceitação verificáveis; o que é **baseline** vs **aditivo** |
| Arquitetura (design) | desenho do zero: camadas, contratos, stack, ADR das decisões estruturais |
| Dev | implementar por camada + testes junto; build/lint verdes |
| Arquitetura (review) | o entregue bate com o design/ADR? 0 violação de camada |
| Review de Código | subagents auditam diff, regras locais, testes, segurança básica, operabilidade e lacunas antes do QA |
| QA | cobre cada critério de aceitação + caminho de erro |
| Segurança | invadir pelo navegador o que subiu (token, authz, audit, CSP) |

**DoD do incremento:** funciona, testado, sem violação de camada, review de
código sem `FAIL`, sem achado crítico de segurança.

---

## scaffold-mode REFATORAR (sistema existente)

Mudar a estrutura interna **sem mudar o comportamento observável**.

| Etapa | Ênfase |
|---|---|
| Discovery | **inventário do estado atual** (medido, não suposto); metas do refactor; **critérios de não-regressão** (o que NÃO pode mudar) |
| Arquitetura (design) | **atual × alvo**: o que muda, o que se preserva; plano incremental (Strangler Fig se grande); ADR se decisão estrutural |
| Dev | mudanças **pequenas e reversíveis**; testes de caracterização cobrindo o comportamento antes de mexer |
| Arquitetura (review) | a refatoração atingiu a meta sem violar camada nem vazar comportamento? |
| Review de Código | subagents focam regressão, acoplamento novo, dívida criada e candidatos a código morto/deps |
| QA | **regressão pesada**: a suíte/RPA prova que o comportamento observável é idêntico |
| Segurança | re-auditoria das superfícies tocadas |

**DoD do incremento:** meta de refactor atingida, **0 regressão** comprovada,
reversível.

> ❌ Anti-pattern: refatorar e adicionar feature no mesmo incremento — separar.

---

## scaffold-mode DOCUMENTAR (sistema existente sem/com pouca doc)

Tornar o sistema entendível e operável, sem mudar código.

| Etapa | Ênfase |
|---|---|
| Discovery | **engenharia reversa**: mapear módulos, fluxos, integrações, infra reais (ler o código, não os docs antigos) |
| Arquitetura (design) | montar o **mapa de arquitetura** vigente (camadas, comunicação, deploy) → `.spec/reference/` |
| Dev → **escrever docs** | gerar `reference/` (arquitetura, roadmap, deploy, observabilidade), READMEs por módulo, runbooks |
| Arquitetura (review) | a doc **bate com o código real**? sem afirmação stale (stack morta, infra antiga) |
| Review de Código | subagents verificam docs contra código, comandos, exemplos, links e lacunas de operabilidade |
| QA | verificar comandos/links dos docs (executam? resolvem? smoke real) |
| Segurança | documentar os invariantes de segurança + 1 passada `/security-review` |

**DoD do incremento:** doc fiel ao código atual, sem referência quebrada/stale,
verificável; o roteador do agente (`CLAUDE.md`, `AGENTS.md` ou equivalente)
aponta para o `.spec/`.

> ❌ Anti-pattern: tratar doc histórica como verdade atual — validar contra o
> código; remover/arquivar o que está superado.

---

## Paradas obrigatórias (em qualquer scaffold-mode)

Pare e peça decisão humana quando:
1. Item fora do escopo/contrato sem aprovação escrita (registrar em `STATE.md`).
2. Ação destrutiva/irreversível ou deploy em **produção**.
3. Gate reprovado 2× seguidas na mesma etapa (não converge).
4. Decisão estrutural nova sem ADR.
5. Qualquer passo que exigiria abrir/expor segredo (`.claude/rules/seguranca.md`
   ou regra equivalente do projeto).
