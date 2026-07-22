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
| `discovery` | levanta o contexto com perguntas pesquisadas (modos **produto** / **desenvolvimento**) | 00 |
| `arquitetura` | gate de **design** (antes do dev) e **review** (depois) | 10 |
| `desenvolvimento` | implementa conforme spec + plano | 20 |
| `review-codigo-subagents` | sprint de review de código por subagents independentes | 25 |
| `qa` / `qa-rpa` | gate de QA / **RPA** de navegador validando cada tela **front + back** | 30 |
| `seguranca` / `redteam` | gate de segurança / **pentest autorizado** do próprio local/dev | 40 |

O `scaffold-spec` também instala **rules de engenharia em 3 camadas** (princípio
universal + preset por stack + exemplo) para Rust, Node-TS, Python, Go, C#, KMP,
Svelte/Angular/React e RPA; um **catálogo de stacks** (`.claude/stacks/`); uma
**esteira de qualidade de código** com gates bloqueantes (`.claude/esteira/`:
`00-check → 10-refactor → 20-test/cov/mutation → 30-review`); **templates de
orquestração multi-agente** (`agents/`); **commands** do Claude Code
(`check-rules`, `refactor`, `responsive-pass`, `dead-code-cleansing`) — todos
LLM-agnostic (rodam no Claude Code e em outros LLMs, via prompt); uma **skill de
deploy**; e as **tools** de validação `spec-check.sh` e `esteira-check.sh`.

## Fluxo

```
/scaffold-spec [criar|refatorar|documentar]   ← monta .spec/ + rules + skills + tools + hooks
  → /discovery [produto|desenvolvimento]       → contexto (Mom Test / JTBD / 4 riscos / NFR)
  → /arquitetura design                        → gate: a abordagem é sã?
  → /desenvolvimento                           → implementa (testes junto)
  → /arquitetura review                        → gate: o diff bate com plano/ADR?
  → /review-codigo-subagents                   → sprint de review técnico por lanes/subagents
  → /qa  →  /qa-rpa                             → validação real front+back de cada tela
  → /seguranca  →  /redteam                    → pentest autorizado (achar a brecha, remediar)
  → /deploy  +  spec-check                      → sobe e valida a entrega
```

## Instalação

Use o `install.sh` — **a instalação já materializa a esteira completa** no projeto
(rules 01–11, commands, esteira, stacks, tools, sprints, esteira-state), então
nenhuma pasta fica de fora esperando o scaffold:

```bash
# skills no usuário (~/.claude/skills, via symlink — git pull atualiza sozinho)
./install.sh

# skills no usuário + esteira completa num projeto (.opennjord + espelhos .claude/.agents/.codex)
./install.sh --projeto <seu-projeto>

# opt-in (por design ficam de fora sem as flags)
./install.sh --projeto <seu-projeto> --com-agents --com-hooks
```

O instalador verifica ao final que todas as pastas e as 11 regras de engenharia
foram materializadas — falha ruidosamente se algo faltar.

Depois, no projeto, rode `/scaffold-spec criar` (ou `refatorar` / `documentar`):
com a estrutura já no lugar, o scaffold só **adapta** — preenche placeholders,
escolhe o preset de stack ativo e gera o `.spec/` (MANIFEST/STATE/RUNBOOK).
Poda de presets exige registro no `MANIFEST.md` e nunca remove `stacks/README.md`
nem o preset ativo.

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
