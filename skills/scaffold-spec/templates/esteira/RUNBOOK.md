# RUNBOOK — Como rodar a esteira de qualidade autonomamente

> **Duas esteiras, não confunda (GAP-I):** ESTE é o RUNBOOK da esteira de
> **QUALIDADE de código** — stages `Q00-check → Q10-refactor →
> Q20-test-cov-mutation → Q30-review`, valida a saúde de um diff (ortogonal às
> disciplinas do `.spec/`). A esteira de **PROCESSO** (00 Discovery → 40
> Segurança, por sprint) é outra: vive em `.spec/sprints/RUNBOOK.md` e é dirigida
> pelo cursor `.spec/esteira-state.yaml`.

> Executado pelo **Main Orchestrator** (nunca por worker isolado). Lê o estado,
> retoma o stage atual, delega ao runbook/skill de cada stage na ordem, respeita
> gates bloqueantes. Tudo em pt-BR; identificadores em inglês.

## Pré-requisitos

- `.spec/STATE.md` (ou equivalente) com o incremento ativo e etapa atual.
- `rules/eng/*` instaladas (auditoria do Q00-check se baseia nelas).
- `stacks/` com presets da stack do projeto (comandos concretos de test/cov/mutation/lint).
- Skill `graphify` disponível (opcional, para análise de impacto).

## Loop principal

```
1. Ler STATE → identificar stage atual (Q00/Q10/Q20/Q30) e contador de tentativas.
2. Invocar o runbook do stage (esteira/stages/0N-*.md — arquivos numéricos) na ordem:
     Q00-check → Q10-refactor → Q20-test-cov-mutation → Q30-review
3. Ao fim de cada stage, avaliar o gate (ver gates.md):
     ok   → avançar; atualizar STATE (status ✅, zerar contador).
     fail → voltar uma casa; incrementar contador; anotar achados no STATE.
     2× fail no MESMO gate → PARAR, escalar para humano com o histórico.
4. Fechado (Q30-review ok) → registrar no STATE e encerrar o incremento.
```

## Comandos por stage (genéricos)

> Os comandos **concretos** (test_cmd, cov_tool, mutation_tool, lint_cmd,
> typecheck_cmd, build_cmd, arch_violation_grep) vivem em `stacks/<grupo>/<stack>.md`.
> Consulte o preset da stack do projeto antes de executar — o que segue é o esqueleto.

### Q00-check (auditoria read-only)
- Rodar os greps de verificação de cada `rules/eng/*` (tamanho, SOLID, camadas).
- Rodar `lint_cmd` + `typecheck_cmd` (sinal de saúde, não bloqueante aqui salvo erro).
- **Não editar.** Saída = relatório de violações bloqueantes vs. warnings.

### Q10-refactor (corrige as violações)
- Para cada arquivo com violação bloqueante, aplicar o fluxo do `10-refactor.md`
  (rede de segurança → split → DIP → simplificar → validar).
- 1 commit = 1 motivo (Regra 6). Bug pré-existente descoberto → parar e perguntar.

### Q20-test-cov-mutation (testes + cobertura + mutation)
- Rodar `test_cmd` (deve estar verde antes de medir cobertura).
- Rodar `cov_tool` → reportar pacotes < 84%.
- Rodar `mutation_tool` → reportar eficácia < 84%.
- Reforçar testes onde mutantes sobrevivem; rerodar até ≥84%/≥84%.

### Q30-review (review do diff)
- Rodar os greps de camada/dependência de `rules/eng/*` sobre o diff.
- Confirmar que a lógica está na camada certa (domain puro, IO em infra, UI via invoke/port).
- Cruzar o diff com ACs/ADR/plano do `.spec/`.

## Respeitar gates bloqueantes

- `ok` avança; `fail` volta uma casa; `2× fail` no mesmo gate **para**.
- Nunca desabilitar teste (`#[ignore]`, `it.skip`, `test.skip`) para passar CI.
- Nunca usar `--no-verify` ou pular hooks.
- Atualizar o `STATE` em cada transição (stage, status, contador, achados).

## Composição com graphify (opcional)

Antes do Q10-refactor e no Q30-review, entender impacto ajuda a não quebrar invariantes:

```bash
graphify query "<pergunta sobre o que depende do módulo alvo>"
graphify path "<módulo A>" "<módulo B>"      # relação direta entre dois pontos
graphify explain "<conceito>"                 # subgrafo focado num conceito
```

Use para: escolher onde fazer split com menor impacto, confirmar que o diff não
introduziu dependência cíclica, validar que domain não passou a importar infra.

## Modo self-test

A esteira pode se validar. Ao gerar/atualizar estes templates, o orchestrator
spawna um sub-orchestrator + workers para:

### (a) Grep de agnosticidade/resíduo
Confirmar que nenhum template cita particulares do projeto-fonte como prescrição.
Tokens a rejeitar como fato (lista do `_STYLE.md`): paths/identificadores
específicos do repo original. Comando genérico:

```bash
# greps de resíduo (lista de tokens vem do _STYLE.md do pacote)
# deve retornar vazio nos corpos de runbook/command
```

### (b) Smoke de instalação num dir temporário
Instalar os templates num diretório temporário (ex.: `mktemp -d`) e rodar:
- `tools/spec-check.sh` (estrutura + links).
- Os greps de verificação das `rules/eng/*` contra uma amostra de arquivos.

### (c) Rodar `check-rules` contra amostra
Disparar o stage 00 sobre o próprio pacote gerado: Regra 1 (≤300 linhas por
arquivo), links íntegros, placeholders descritivos (formato `preencher: o quê`, nunca placeholder vazio).

Se qualquer cheque falhar → volta ao stage que gerou o artefato (fluxo normal de gates).

## Paradas obrigatórias (pedir humano)

- Item fora do escopo sem aprovação no `.spec/`.
- Ação destrutiva ou em produção.
- Gate reprovado **2×** no mesmo stage.
- Decisão estrutural (novo ADR) sem registro.
- Segredo/credencial exposto no diff.
