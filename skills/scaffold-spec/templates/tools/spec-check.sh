#!/usr/bin/env bash
# spec-check.sh — valida a base operacional `.spec/` (entrega clara e funcionando).
# Checa: arquivos obrigatórios presentes, links .md internos não-quebrados, e
# avisa se o STATE.md parece desatualizado. Exit 1 se houver erro.
# Uso: ./spec-check.sh            (roda na raiz do projeto)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd || pwd)"
[ -d "$ROOT/.spec" ] || ROOT="$(pwd)"
cd "$ROOT"
err=0; warn=0
red(){ printf '\033[31m%s\033[0m\n' "$*"; }; grn(){ printf '\033[32m%s\033[0m\n' "$*"; }; yel(){ printf '\033[33m%s\033[0m\n' "$*"; }

# 1) arquivos obrigatórios
req=(.spec/MANIFEST.md .spec/STATE.md .spec/sprints/README.md .spec/sprints/RUNBOOK.md
     .spec/sprints/00-discovery/README.md .spec/sprints/10-arquitetura/README.md
     .spec/sprints/20-desenvolvimento/README.md .spec/sprints/30-qa/README.md
     .spec/sprints/40-seguranca/README.md)
for f in "${req[@]}"; do
  [ -f "$f" ] || { red "FALTA: $f"; err=1; }
done

# 2) links .md internos quebrados (dentro de .spec/)
while IFS= read -r src; do
  dir=$(dirname "$src")
  while IFS= read -r l; do
    case "$l" in http*|\#*|"") continue;; esac
    t="$dir/${l%%#*}"
    [ -e "$t" ] || { red "LINK QUEBRADO: ${src#./} -> $l"; err=1; }
  done < <(grep -oE '\]\(([^)]+\.md)\)' "$src" 2>/dev/null | sed -E 's/\]\(([^)]+)\)/\1/')
done < <(find .spec -name '*.md' 2>/dev/null)

# 3) STATE.md desatualizado? (heurística: ainda com placeholders e sem incremento)
if [ -f .spec/STATE.md ] && grep -q 'nenhum incremento ativo' .spec/STATE.md; then
  yel "AVISO: .spec/STATE.md sem incremento ativo (ok se o projeto está recém-scaffoldado)."; warn=1
fi

# 4) CLAUDE.md roteia pro .spec?
if [ -f CLAUDE.md ] && ! grep -q '.spec/MANIFEST.md' CLAUDE.md; then
  yel "AVISO: CLAUDE.md não aponta para .spec/MANIFEST.md (deveria ser o roteador)."; warn=1
fi

echo
[ "$err" = 0 ] && grn "spec-check: OK (estrutura íntegra, 0 link quebrado)${warn:+ — $warn aviso(s))}" \
              || red "spec-check: FALHOU — corrija os erros acima."
exit "$err"
