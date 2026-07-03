# <projeto> — roteador do agente

**Regra-mãe:** <1 linha: o que governa o escopo deste projeto>.

## Bootstrap (ler nesta ordem)
1. [.spec/MANIFEST.md](.spec/MANIFEST.md) — o que existe e onde
2. [.spec/STATE.md](.spec/STATE.md) — onde a esteira parou
3. [.spec/sprints/RUNBOOK.md](.spec/sprints/RUNBOOK.md) — como avançar

## Esteira (disciplinas — sempre nesta ordem)
- 00 `/discovery` (modos: negocio | dev | refatoracao — seletor na skill) → `.spec/discovery/`
- 10 `/arquitetura [design|review]` → gate bloqueante
- 20 `/desenvolvimento`
- 25 `/review-codigo-subagents`
- 30 `/qa` + `/qa-rpa`
- 40 `/seguranca` + `/redteam` — último portão antes do release

## Autoridades
- Regras de engenharia: [.claude/rules/README.md](.claude/rules/README.md)
- Skills: `.claude/skills/` (Codex: symlink `.codex/skills`)
- Esteira de qualidade (por diff): [.claude/esteira/RUNBOOK.md](.claude/esteira/RUNBOOK.md)
- Stack preset: [.claude/stacks/README.md](.claude/stacks/README.md)

## Segurança
Invariantes irredutíveis: [.claude/rules/seguranca.md](.claude/rules/seguranca.md)

> Nada operacional aqui — se precisou detalhar, vai pro `.spec/` ou pra uma rule.
