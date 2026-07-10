---
name: desenvolvimento
description: >-
  Roda a etapa de Desenvolvimento da esteira (disciplina 20), implementando
  conforme a spec aceita e o plano aprovado no gate de Arquitetura, com testes
  junto e validação local verde antes do review. Use quando o usuário pedir
  "implementar", "desenvolver o incremento", "codar a sprint NN", "começar o
  dev", ou "/desenvolvimento". Não começa sem plano aprovado.
---

# Skill: desenvolvimento (disciplina 20)

Implementa o incremento. Método em `.spec/sprints/README.md`;
regras em `.claude/rules/` quando rodar no Claude Code, ou nas regras equivalentes
do projeto quando rodar no Codex (`rules/eng/03-solid.md`,
`rules/eng/04-clean-architecture.md`, `rules/eng/02-unit-tests.md`,
`rules/seguranca.md`, `rules/fluxo-desenvolvimento.md`).

## Definition of Ready (não começar sem)
- Spec aceita + critérios de aceitação (Discovery).
- **Discovery de sprint** aprovado quando existir (convenção e fallback: ver
  `fluxo-desenvolvimento.md`).
- Plano técnico aprovado (Arquitetura **10a design**): camadas, contratos, ADR.

## Fluxo
1. **Planner** — materializa as tasks propostas no `discovery-sprint.md` em
   `.spec/sprints/sprint-NN-<tema>/tasks/task-NN-<slug>.md` (template
   `templates/task.md`), **direto da tabela** de tasks propostas (sem
   re-transcrição), enriquecendo com as decisões do design gate 10a; é o
   macro-stage **Execution** do pipeline.
2. **Sprint Validator** (gate do plano) — o plano de tasks é são antes de
   codar? Valida também: **AC funcional verificável por task**, dependência
   declarada no próprio arquivo, escopo de escrita sem colisão. Reprovou →
   replaneja. (Ver o mapa Execution→sprints em `scaffold-spec/SKILL.md`.)
3. Implementar **por camada** (respeitar a direção de dependência), no **loop
   Coder ↔ Evaluator**: o Coder escreve o incremento, o Evaluator avalia; itera por
   rounds, com **gate humano no max-rounds** (não avança em fail silencioso).
4. **Testes junto** (não depois) — caminho feliz + erro; cobrir invariantes.
5. **Validação local verde** antes de pedir review: build + lint + teste + RPA
   (comandos no `.spec/MANIFEST.md`).
> Modo **refatorar**: mudanças pequenas/reversíveis + teste de caracterização
> antes de mexer (não-regressão). Modo **documentar**: o "dev" é escrever os docs.

## Definition of Done
- [ ] Tasks em `<sprint>/tasks/` · `## Resultado` (status + commit) preenchido
  em cada task entregue · [ ] testes novos verdes; sem regressão
- [ ] build/lint/teste verdes · [ ] validação local **PASS**
- [ ] diff pronto p/ review (Arquitetura 10b) · [ ] débito anotado
- [ ] `.spec/STATE.md` atualizado

## Anti-patterns
- ❌ Pedir review com build vermelho ou validação falhando.
- ❌ Lógica fora da camada certa. ❌ Refatoração + feature no mesmo incremento.
