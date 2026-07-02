#!/usr/bin/env bash
# esteira-check.sh — valida a eng-esteira (templates de engenharia do scaffold-spec).
#
# 4 frentes:
#   1. Agnosticidade LLM  — sem $ARGUMENTS / !`cmd` / allowed-tools no CORPO dos runbooks.
#   2. Resíduo njord       — src-tauri/dbx/surreal/$modules só como exemplo rotulado (ex.:).
#   3. Estrutura           — todo template ≤ 300 linhas; artefatos obrigatórios presentes.
#   4. Smoke install       — cp dos templates p/ tmpdir; arquivos esperados presentes.
#
# Uso:  bash esteira-check.sh [templates-dir]
#   Sem arg: valida os templates ao lado do script (manutenção do repo esteira-skills).
#   Com arg: valida o dir informado (ex.: .claude/skills/scaffold-spec/templates de um consumer).
# Requer: rg (ripgrep), find, wc, mktemp.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="${1:-}"
if [ -z "$TEMPLATES" ]; then
  # Procura candidatos: repo-fonte (tools/ dentro de templates/) ou install consumer.
  for cand in "$SCRIPT_DIR/.." "$SCRIPT_DIR/../skills/scaffold-spec/templates" "$SCRIPT_DIR/../templates"; do
    if [ -f "$cand/_STYLE.md" ]; then TEMPLATES="$cand"; break; fi
  done
fi

[ -n "$TEMPLATES" ] && [ -d "$TEMPLATES" ] || {
  echo "FAIL: templates dir não encontrado (use: bash esteira-check.sh <templates-dir>)"; exit 2; }

FAIL=0
section() { printf '\n=== %s ===\n' "$1"; }
ok()      { printf 'OK:   %s\n' "$1"; }
fail()    { printf 'FAIL: %s\n' "$1"; FAIL=1; }

ENG_RULES="$TEMPLATES/rules/eng"
STACKS="$TEMPLATES/stacks"
ESTEIRA="$TEMPLATES/esteira"
AGENTS="$TEMPLATES/agents"
CMD="$TEMPLATES/commands/eng"

# ---------- Frente 1 — Agnosticidade LLM ----------
section "Frente 1 — Agnosticidade LLM (corpo dos 4 runbooks)"
for f in check-rules refactor responsive-pass dead-code-cleansing; do
  file="$CMD/$f.md"
  [ -f "$file" ] || { fail "$f.md ausente"; continue; }
  # $ARGUMENTS e !`cmd` (dynamic context) são proibidos no corpo (sintaxe Claude-only).
  needle='$ARGUMENTS'; dynctx='!`'
  hits=$(grep -nF -e "$needle" -e "$dynctx" "$file" 2>/dev/null || true)
  [ -z "$hits" ] && ok "$f.md: corpo LLM-agnostic" || fail "$f.md tem tokens Claude no corpo:\n$hits"
done

# ---------- Frente 2 — Resíduo njord ----------
section "Frente 2 — Resíduo njord (só permitido em linha com 'ex.')"
# Linhas com src-tauri/dbx/surreal/$modules/$studio/tauri:: SEM 'ex.' são resíduo.
res=$(grep -rnE 'src-tauri|dbx|surreal|notebook_njord|\$modules|\$studio' \
  "$ENG_RULES" "$STACKS" "$ESTEIRA" "$AGENTS" "$CMD" 2>/dev/null \
  | grep -vE 'ex\.|exemplo|rotulad|ilustra|prescri' || true)
[ -z "$res" ] && ok "0 resíduo njord (fora de 'ex.')" || fail "resíduo njord encontrado:\n$res"

# ---------- Frente 3 — Estrutura ----------
section "Frente 3 — Estrutura (≤300 linhas + artefatos obrigatórios)"
over=""
for d in "$ENG_RULES" "$STACKS" "$ESTEIRA" "$AGENTS" "$CMD"; do
  [ -d "$d" ] || { fail "dir ausente: $d"; continue; }
  while IFS= read -r f; do
    lines=$(wc -l < "$f")
    [ "$lines" -gt 300 ] && over="$over\n$f: $lines linhas"
  done < <(find "$d" -type f \( -name '*.md' -o -name '*.tpl' \))
done
[ -z "$over" ] && ok "todos os templates ≤ 300 linhas" || fail "arquivos >300:$over"

[ -f "$TEMPLATES/_STYLE.md" ] && ok "_STYLE.md presente" || fail "_STYLE.md ausente"
for r in 01-file-size 02-unit-tests 03-solid 04-clean-architecture 05-simplicity \
         06-continuous-refactoring 07-build-and-run 08-delegate-execution \
         09-responsive-ui 10-frontend-architecture 11-external-parity-source; do
  [ -f "$ENG_RULES/$r.md" ] || fail "rules/eng/$r.md ausente"
done
{ [ -f "$ENG_RULES/README.md" ] && [ -f "$ENG_RULES/_layer-guide.md" ]; } \
  && ok "rules/eng: índice + _layer-guide presentes" || fail "rules/eng: README/_layer-guide ausentes"
[ -f "$ESTEIRA/RUNBOOK.md" ] && ok "esteira/RUNBOOK presente" || fail "esteira/RUNBOOK ausente"
[ -f "$AGENTS/README.md" ] && ok "agents/README presente" || fail "agents/README ausente"

# ---------- Frente 4 — Smoke install ----------
section "Frente 4 — Smoke install (cp p/ tmpdir)"
TMP="$(mktemp -d)"
mkdir -p "$TMP/.claude"/{rules,commands,stacks,esteira}
cp -R "$ENG_RULES/." "$TMP/.claude/rules/" 2>/dev/null || true
cp -R "$CMD/."       "$TMP/.claude/commands/" 2>/dev/null || true
cp -R "$STACKS/."    "$TMP/.claude/stacks/" 2>/dev/null || true
cp -R "$ESTEIRA/."   "$TMP/.claude/esteira/" 2>/dev/null || true
n_rules=$(find "$TMP/.claude/rules" -name '[0-9]*-*.md' | wc -l)
{ [ "$n_rules" -ge 11 ] && [ -f "$TMP/.claude/esteira/RUNBOOK.md" ] && [ -d "$TMP/.claude/stacks/backend" ]; } \
  && ok "smoke: $n_rules rules + esteira + stacks instalados em tmp" \
  || fail "smoke: instalação incompleta (rules=$n_rules)"
rm -rf "$TMP"

printf '\n'
if [ "$FAIL" -eq 0 ]; then echo "✅ esteira-check PASSOU (4 frentes)"; else echo "❌ esteira-check FALHOU"; fi
exit "$FAIL"
