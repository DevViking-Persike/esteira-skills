# Esteira — Skills para Claude Code e Codex

Um **ecossistema de skills** que monta a base operacional de um projeto (`.spec/`)
e roda uma **esteira de sprints por disciplina** — do discovery à entrega validada.
Genérico e reutilizável em qualquer projeto.

> Princípio: `rule` = fonte de verdade (conhecimento); `skill` = runbook que aplica.
> O `.spec/` é o manual operacional; roteadores como `CLAUDE.md` só apontam pra ele.

## Compatibilidade Codex

Os arquivos em `skills/` continuam sendo a fonte de verdade deste repositório.
Em um projeto consumidor, instale ou copie essas skills em `.claude/skills` e faça
o Codex apontar para essa mesma árvore com um symlink em `.codex/skills`. Não
crie uma cópia separada para Codex.

Cada skill também possui `agents/openai.yaml`, metadata opcional recomendada para
o Codex. Arquivos TOML não são necessários para este formato de skill.

## As skills

| Skill | Papel | Etapa |
|---|---|---|
| **`scaffold-spec`** | **hub** — monta a base `.spec/` + rules + tools + hooks e orquestra as demais | — |
| `discovery` | levanta o contexto com perguntas pesquisadas — **3 modos com seletor**: **negocio** (porquê/usuário/valor/regras de negócio), **desenvolvimento** (escopo/NFR/segurança de 1ª classe/apresentação/direção arquitetural/aceitação) e **refatoracao** (não-regressão/bugs/performance/design). O seletor roda 1, 2, os 3 ou os 2 primeiros na ordem canônica 1→2→3 e fecha num Plano de Sprints aprovado | 00 |
| `arquitetura` | **gate fino** — **design** (antes do dev: a abordagem é sã?) e **review** (depois do dev: o diff bate com plano/ADR/camadas?) | 10 |
| `desenvolvimento` | implementa conforme spec + plano | 20 |
| `review-codigo-subagents` | **execução por lanes** — pipeline de subagents independentes que produz os achados que o gate `/arquitetura review` (10b) julga; lane Segurança é análise **estática** do diff (não substitui o `/redteam`) | 25 |
| `qa` / `qa-rpa` | gate de QA (critérios de aceitação, caminhos de erro, autorização) / **executor RPA** de navegador validando cada tela **front + back** | 30 |
| `seguranca` / `redteam` | gate de segurança (confere cobertura/severidade contra `rules/seguranca.md`) / **executor** — pentest autorizado (exploração **dinâmica**) do próprio local/dev | 40 |

### Fronteira dos 3 "reviews" (10b / 25 / stage 30-review)

Três artefatos tocam revisão de diff, cada um com um papel distinto — nenhum
substitui o outro:

- **`/arquitetura review` (gate 10b)** — gate **fino**: julga camadas, ACs e ADR
  sobre o diff já pronto. Não produz os achados, consome/julga.
- **`/review-codigo-subagents` (disciplina 25)** — **execução** por lanes de
  subagents que produz os achados (camadas, cleanups, lane Segurança estática)
  que o gate 10b depois julga.
- **`esteira/stages/30-review.md`** (esteira de qualidade por diff) — runbook
  da lane de camadas que a disciplina 25 reusa (mesmo eixo, sem redefinir regra).

### Pares gate↔executor (triggers sem sobreposição)

`seguranca`/`redteam` (40) e `qa`/`qa-rpa` (30) seguem o mesmo padrão: o
**gate** (`seguranca`, `qa`) só ativa em linguagem de *validar/aprovar* ("gate
de segurança", "validar antes do release", "rodar QA", "/seguranca", "/qa"); o
**executor** (`redteam`, `qa-rpa`) só ativa em linguagem de *executar a ação*
("testar segurança", "tentar invadir", "/redteam", "criar RPA", "/qa-rpa").
Nenhum trigger do executor aparece na description do gate, e vice-versa —
evita disparar a skill errada.

O `scaffold-spec` também instala **rules de engenharia em 3 camadas** (princípio
universal + preset por stack + exemplo) para Rust, Node-TS, Python, Go, C#, KMP,
Svelte/Angular/React e RPA; um **catálogo de stacks** (`.claude/stacks/`); uma
**esteira de qualidade de código** com gates bloqueantes (`.claude/esteira/`:
`00-check → 10-refactor → 20-test/cov/mutation → 30-review`); **templates de
orquestração multi-agente** (`agents/`); **commands** do Claude Code
(`check-rules`, `refactor`, `responsive-pass`, `dead-code-cleansing`) — todos
LLM-agnostic (rodam no Claude Code e em outros LLMs, via prompt); uma **skill de
deploy**; um **roteador `CLAUDE.md`** (`scaffold-spec/templates/router/CLAUDE.md.tpl`,
instalado em `.claude/CLAUDE.md` + stub na raiz); e as **tools** de validação
`spec-check.sh` e `esteira-check.sh`.

## Fluxo

```
/scaffold-spec [criar|refatorar|documentar]        ← monta .spec/ + rules + skills + tools + hooks
  → /discovery [negocio|dev|refatoracao]...         → seletor de modos (ordem 1→2→3) → Plano de Sprints
  → /arquitetura design                             → gate fino: a abordagem é sã?
  → /desenvolvimento                                → implementa (testes junto)
  → /review-codigo-subagents                        → execução por lanes → achados
  → /arquitetura review                             → gate fino: julga os achados × plano/ADR/camadas
  → /qa  →  /qa-rpa                                  → gate de QA / execução RPA front+back de cada tela
  → /seguranca  →  /redteam                         → gate de segurança / execução dinâmica (pentest)
  → /deploy  +  spec-check                           → sobe e valida a entrega
```

Cada item do Plano de Sprints (saída do `/discovery`) reabre o ciclo
`10→20→25→30→40` como um novo sprint — ver `## Como os modos encadeiam` em
`discovery/SKILL.md`.

## Instalação

Copie as skills para o diretório de skills do Claude Code:

```bash
# global (todos os projetos)
cp -R skills/* ~/.claude/skills/
# ou por projeto
cp -R skills/* <seu-projeto>/.claude/skills/
```

Para usar no Codex em um projeto mantendo os arquivos do Claude Code como fonte
canônica, aponte `.codex/skills` para `.claude/skills` no projeto consumidor:

```bash
mkdir -p <seu-projeto>/.codex
ln -s ../.claude/skills <seu-projeto>/.codex/skills
```

Depois, num projeto, rode `/scaffold-spec criar` (ou `refatorar` / `documentar`).

## Fundamentos (discovery)

As perguntas do discovery vêm de frameworks consagrados:
- **The Mom Test** (Rob Fitzpatrick) — perguntar sobre comportamento/histórias, não opiniões.
- **Continuous Discovery / Opportunity Solution Tree** (Teresa Torres).
- **The Four Big Risks** (Marty Cagan / SVPG) — valor, usabilidade, viabilidade técnica e de negócio.
- **Jobs to be Done**.
- **NFR / atributos de qualidade** (Volere / arc42).

## Segurança (redteam)

A skill `redteam` é estritamente **defensiva e autorizada**: testa o **próprio**
sistema (local/dev) para achar brechas antes de um atacante, com guard-rails
explícitos (nunca produção sem aceite, sem DoS, sem exfiltração, sem segredo no
relatório). É metodologia de pentest padrão (estilo OWASP), focada em
**achar → PoC mínimo → remediar**.

## Licença

MIT — veja [`LICENSE`](./LICENSE).
