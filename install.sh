#!/usr/bin/env bash
# Instalador da esteira: skills no usuário e, com --projeto, materializa a esteira
# COMPLETA no projeto já na instalação (rules, commands, esteira, stacks, tools,
# esteira-state, sprints) — nada fica para trás; o /scaffold-spec depois só ADAPTA
# (preenche placeholders, gera .spec/), nunca precisa criar estrutura.
#
# Uso:
#   ./install.sh                                  # skills no usuário (~/.claude/skills, via symlink)
#   ./install.sh --projeto <dir>                  # + esteira completa em <dir>/.opennjord + espelhos
#   ./install.sh --projeto <dir> --com-agents     # inclui agents/ (opt-in por design)
#   ./install.sh --projeto <dir> --com-hooks      # inclui hooks/ (opt-in por design)
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$RAIZ/skills"
TEMPLATES="$SKILLS_SRC/scaffold-spec/templates"

PROJETO=""
COM_AGENTS=0
COM_HOOKS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --projeto) PROJETO="${2:?--projeto exige um diretório}"; shift 2 ;;
    --com-agents) COM_AGENTS=1; shift ;;
    --com-hooks) COM_HOOKS=1; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "argumento desconhecido: $1 (use --help)"; exit 1 ;;
  esac
done

log() { printf '\033[1;34m[esteira]\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
falha() { printf '\033[1;31m[FALHA]\033[0m %s\n' "$*"; exit 1; }

# ---------- 1) skills no usuário (symlink: git pull atualiza sozinho) ----------
mkdir -p "$HOME/.claude/skills"
instaladas=0; puladas=0
for skill in "$SKILLS_SRC"/*/; do
  nome="$(basename "$skill")"
  destino="$HOME/.claude/skills/$nome"
  if [ -e "$destino" ] && [ ! -L "$destino" ]; then
    log "pulando $nome (já existe em ~/.claude/skills e não é symlink deste repo)"
    puladas=$((puladas+1))
    continue
  fi
  ln -sfn "${skill%/}" "$destino"
  instaladas=$((instaladas+1))
done
ok "skills no usuário: $instaladas instaladas/atualizadas, $puladas puladas"

[ -z "$PROJETO" ] && { log "sem --projeto: instalação de usuário concluída"; exit 0; }

# ---------- 2) esteira completa no projeto (a instalação JÁ materializa) ----------
[ -d "$PROJETO" ] || falha "diretório do projeto não existe: $PROJETO"
ON="$PROJETO/.opennjord"
mkdir -p "$ON"

rsync -a "$SKILLS_SRC/" "$ON/skills/"

for pasta in rules commands esteira stacks tools; do
  [ -d "$TEMPLATES/$pasta" ] || falha "template ausente no repo: $pasta"
  rsync -a "$TEMPLATES/$pasta/" "$ON/$pasta/"
done
[ -f "$TEMPLATES/esteira-state.yaml" ] && cp "$TEMPLATES/esteira-state.yaml" "$ON/esteira-state.yaml"
[ -d "$TEMPLATES/sprints" ] && rsync -a "$TEMPLATES/sprints/" "$ON/sprints/"

[ "$COM_AGENTS" = 1 ] && [ -d "$TEMPLATES/agents" ] && rsync -a "$TEMPLATES/agents/" "$ON/agents/" && ok "agents/ incluído (--com-agents)"
[ "$COM_HOOKS" = 1 ] && [ -d "$TEMPLATES/hooks" ] && rsync -a "$TEMPLATES/hooks/" "$ON/hooks/" && ok "hooks/ incluído (--com-hooks)"

chmod +x "$ON"/tools/*.sh 2>/dev/null || true

# ---------- 3) espelhos multi-CLI (convenção router: .opennjord é a fonte) ----------
mkdir -p "$PROJETO/.claude" "$PROJETO/.agents"
for p in rules skills commands agents; do
  [ -d "$ON/$p" ] && ln -sfn "../.opennjord/$p" "$PROJETO/.claude/$p"
done
ln -sfn "../.opennjord/skills" "$PROJETO/.agents/skills"
if [ -d "$TEMPLATES/router" ]; then
  mkdir -p "$PROJETO/.codex"
  [ -f "$TEMPLATES/router/codex-README.md" ] && cp -n "$TEMPLATES/router/codex-README.md" "$PROJETO/.codex/README.md" 2>/dev/null || true
fi

# ---------- 4) verificação: nada pode ter ficado de fora ----------
erros=0
for pasta in skills rules commands esteira stacks tools; do
  [ -d "$ON/$pasta" ] && [ -n "$(ls -A "$ON/$pasta")" ] || { printf '\033[1;31m[FALHA]\033[0m %s\n' "pasta ausente/vazia: .opennjord/$pasta"; erros=$((erros+1)); }
done
for n in 01 02 03 04 05 06 07 08 09 10 11; do
  ls "$ON/rules/eng/$n"-*.md >/dev/null 2>&1 || { printf '\033[1;31m[FALHA]\033[0m %s\n' "regra eng $n ausente"; erros=$((erros+1)); }
done
[ "$erros" -gt 0 ] && falha "$erros problema(s) na materialização — instalação incompleta"

ok "esteira completa materializada em $ON (rules 01–11, commands, esteira, stacks, tools, sprints, esteira-state)"
log "próximo passo: no projeto, rode /scaffold-spec [criar|refatorar|documentar] — ele ADAPTA a estrutura"
log "(preenche placeholders, escolhe preset de stack, gera .spec/) sem criar nem podar nada."
log "poda de presets de stacks exige registro no MANIFEST.md e nunca remove stacks/README.md nem o preset ativo."
