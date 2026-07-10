---
name: qa
description: >-
  Roda a etapa de QA da esteira (disciplina 30), com validação real além de unit,
  provando que o incremento funciona e não regrediu, cobrindo critérios de
  aceitação, caminhos de erro e autorização. Use quando o usuário pedir "rodar
  QA", "validar o incremento", "testar de verdade", ou "/qa". Gate com
  VERDICT=PASS e relatório.
---

# Skill: qa (disciplina 30)

Prova que o incremento **funciona de verdade** e que nada regrediu. Método em
`.spec/sprints/README.md`; regras em `rules/eng/02-unit-tests.md` (via
`.claude/rules/` no Claude Code, ou o equivalente do projeto no Codex). Para a
**automação** (RPA de navegador validando cada tela front+back), use a skill
**`/qa-rpa`** — este `/qa` é o gate; o `/qa-rpa` é a execução.

## Entrada
`VERDICT: PASS` da 25 (`.spec/sprints/sprint-NN-<tema>/review-codigo.md`) + diff
aprovado no review gate (Arquitetura 10b) + build verde.

## Montar o QA
1. Traduzir **cada critério de aceitação** (do `discovery-sprint.md` do sprint
   quando existir, senão da Discovery global — incluindo os ACs por task em
   `<sprint>/tasks/`) em uma checagem real.
2. Cobrir os **invariantes** tocados (regressão).
3. Cobrir **caminho de erro** (input inválido → 4xx, etc.).
4. **AuthZ/RBAC**: cada papel vê só o que deve.
5. **Smoke** no ambiente alvo (saúde + fluxo real).
> Modo **refatorar**: regressão pesada — comportamento observável **idêntico**.
> Modo **documentar**: os comandos/links da doc executam/resolvem (doc bate com código).

## Gate (DoD)
- [ ] **VERDICT=PASS** + relatório arquivado.
- [ ] Todos os critérios de aceitação cobertos.
- [ ] Invariantes tocados sem regressão. [ ] ≥1 caminho de erro por endpoint.
- [ ] AuthZ validado. [ ] Smoke verde (se deploy).
- [ ] `.spec/STATE.md` atualizado. FAIL → volta ao Dev.

## Anti-patterns
- ❌ Teste que passa com bug (falso negativo). ❌ Testar implementação interna.
- ❌ Aceitar PASS sem relatório.
