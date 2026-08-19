# RUNBOOK — Esteira de PROCESSO (.spec/) rodada autonomamente

> **Duas esteiras, não confunda (GAP-I):** ESTE é o RUNBOOK da esteira de
> **PROCESSO** — move o produto pelas disciplinas 00→40 por sprint, dirigido pelo
> cursor `.spec/esteira-state.yaml`. A esteira de **QUALIDADE de código** (stages
> `Q00-check…Q30-review`) é outra: vive em `.opennjord/esteira/RUNBOOK.md` e valida
> a saúde de um diff. Um `/loop` que abre "o RUNBOOK" precisa saber qual é qual.

## Fonte de estado (precedência)

- **Cursor — fonte ÚNICA de decisão do tick:** `.spec/esteira-state.yaml`.
- **Diário humano (append):** `.spec/STATE.md` — espelho narrativo, não decide.
- **Espelhos write-only:** `✅` no `plano-de-sprints-NN.md`, `Status:` nas tasks.
  O tick ESCREVE neles; **nunca decide por eles**. Reconciliação `plano/task →
  yaml` só no **bootstrap** (yaml ausente). Depois disso, o yaml vence.

## Contrato do tick

```
1. LÊ .spec/esteira-state.yaml
     ausente ⇒ BOOTSTRAP: valida .spec, deriva sprint_ativa/etapa do plano.
                sem plano-de-sprints ainda ⇒ etapa: 00-discovery.
2. SE awaiting != null ⇒ verifica liberação (humano limpou o campo / ambiente
     subiu). Não liberado ⇒ PARK: pinga e encerra o tick. Liberado ⇒ limpa
     awaiting e segue.
3. DECIDE por LOOKUP (cursor + ordem canônica abaixo). Guardas de idempotência,
     lendo SÓ o yaml (nunca a prosa):
       veredito: PASS da etapa            ⇒ avança etapa;
       sprint_ativa com | NN ✅ | no plano ⇒ avança sprint_ativa;
       task com Status: entregue           ⇒ pula essa task (dev).
4. EXECUTA UMA etapa (ou UMA fatia: 1 task do dev) em modo não-interativo.
5. TRADUZ o veredito da skill p/ PASS|FAIL:
       FAIL ⇒ tentativa += 1; tentativa == 2 ⇒ awaiting: humano:<etapa>-2x.
6. UPSERT do yaml (etapa/tentativa/awaiting/veredito/atualizado)
     + 1 linha no STATE.md
     + marca os espelhos que fecha (Status: da task, | NN ✅ | do plano).
7. ENCERRA o tick. Terminais: GO (avançou) | PARK(awaiting)
     | DONE(sprint→próxima) | DONE(backlog vazio).
```

## Ordem canônica (por sprint)

```
00s → 10a → 20-dev → 25-review → 10b → 30-qa (qa-rpa→qa) → 40-seg (redteam→seguranca) → deploy
```

- **`00s` abre o sprint** e é o **dono do `mkdir .spec/sprints/sprint-NN-<tema>/`**
  (já criando `tasks/` dentro). **1 task = 1 arquivo** `tasks/task-NN-<slug>.md`
  (template `desenvolvimento/templates/task.md`), materializadas pelo Planner do
  `20-dev`; **`tasks.md` chapado é proibido** — o `spec-check` reprova.
  O `NN` é alocado lendo a **próxima linha SEM `✅`** do `plano-de-sprints-NN.md`.
- **`00s` NUNCA dá VERDICT** — avança por **EXISTÊNCIA** de `discovery-sprint.md`.
  Quem reprova contexto não-aterrado é o `10a` (o 00s não é gate).
- Par **executor→gate**: `25`→`10b`, `qa-rpa`→`qa`, `redteam`→`seguranca`. Dentro
  de `30-qa` o tick roda o executor e depois o gate; idem `40-seg`.
- **Fechamento do sprint:** o tick marca `| NN ✅ |` no plano, zera `sprint_ativa`
  e destrava quem dependia dele.

## Paradas humanas (awaiting)

| Gate | awaiting |
|---|---|
| H0 scaffold-mode ausente | `humano:scaffold-mode` |
| H1 Plano de Sprints aprovado | `humano:plano` (abre o loop) |
| H2 10a design (veredito autoral) | `humano:10a` |
| H3 dev não convergiu (max-rounds) | `humano:dev-convergencia` |
| H4 aplicar correções da 25 | no `/loop` os achados FAIL viram tasks; edição direta só FORA do loop |
| H5 aceite de risco no 40 | `humano:aceite-risco` |
| H6 deploy produção | `humano:deploy-prod` |
| gate reprovado 2× | `humano:<etapa>-2x` |
| fonte externa de padrões divergida | `humano:fonte-divergente` |
| ambiente indisponível (qa/seg) | `ambiente:qa` / `ambiente:seg` |

## Auto-commit no modo `/loop`

- Permitido auto-commitar **SÓ paths de estado/evidência**: `.spec/**` e
  `.spec/sprints/sprint-NN-<tema>/**` (cursor, STATE, discovery-sprint, tasks,
  relatórios de review/qa/seguranca). Mensagem:
  `chore(esteira): tick sprint-NN <etapa> <veredito>`.
- **NUNCA** commit de **código** sem passar por gate. O diff de código fecha junto
  da task pelo próprio `/desenvolvimento` (1 task = 1 commit), sob os gates
  25/10b/30/40 — não pelo tick de estado.

## Comandos reais por etapa

Os comandos concretos (build/lint/test/RPA, subir `dev_server`, alvo do redteam)
vivem no `.spec/MANIFEST.md` (*Maquinário de validação* + campos `dev_server` e
`redteam_target`). O tick consulta o MANIFEST antes de executar cada etapa.

## Manutenção da fonte externa de padrões (antes do 10a)

Quando o projeto referencia padrões que vivem **fora** do repo (skills de stack,
frameworks cognitivos, agentes de domínio), a atualização é passo de processo — não
de memória. Rodar **uma vez por sprint, antes do gate 10a (design)**, para o design
não ser ratificado contra padrão vencido:

```bash
# 1. Fonte por symlink (a esteira enxerga o clone direto):
git -C <clone-da-fonte> pull --ff-only

# 2. Fonte instalada por cópia (ex.: avt-frameworks-library-md):
make -C "$AVT_FRAMEWORKS_LIB_PATH" update-skills   # git pull --rebase + reinstala
```

**Por que os dois casos existem.** Instalação por cópia envelhece em silêncio: o hook
`SessionStart` desses instaladores costuma ser bootstrap de primeira vez (sai cedo num
marker) e nunca mais consulta o upstream. O clone pode estar atual e as skills antigas,
sem nada sinalizando a diferença. Symlink não tem esse modo de falha — mas também não
se atualiza sozinho: alguém precisa dar `pull`.

**Divergência bloqueia.** Se o `pull` não faz fast-forward, a fonte local divergiu do
remoto (commit local não publicado). Não reescreva histórico dentro da esteira: pare,
registre em `STATE.md` e trate como `humano:fonte-divergente`. Seguir com fonte
divergida significa validar o design contra um padrão que só existe nesta máquina.
