#!/usr/bin/env bash
# contract-lint.sh — trava a deriva entre as skills da esteira e o contrato.
#
# Valida os 9 SKILL.md + templates (deploy, rules/seguranca, fluxo-desenvolvimento)
# contra `contract/pipeline-contract.yaml`. FALHA em:
#   (a) referencia a `sprints/{10,20,25,30,40}-*` (path por disciplina que o
#       blueprint flat NUNCA cria);
#   (b) gate declarado ANTES do seu executor (ex.: DoR da 25 exigindo o 10b) e
#       arrows executor→gate invertidos nos diagramas;
#   (c) home de artefato citado numa skill fora do contrato (ex.: docs/relatorios)
#       ou skill-produtora sem citar seu home canonico;
#   (d) ciclo de DoR entre duas skills (25 <-> 10b).
#   golden: o DAG do yaml bate com a ordem canonica hardcoded aqui.
#
# Uso: bash contract/contract-lint.sh   (exit 0 = verde; 1 = violacao; 2 = erro)
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CONTRACT_LINT_DIR="$SCRIPT_DIR"

python3 - <<'PYEOF'
import os, re, sys

DIR   = os.environ["CONTRACT_LINT_DIR"]
ROOT  = os.path.dirname(DIR)                 # raiz do repo esteira-skills
YAML  = os.path.join(DIR, "pipeline-contract.yaml")

# ---- ordem canonica hardcoded (golden) -----------------------------------
CANON = ["00-discovery","plano","00s","10a","20","25","10b",
         "30-qa-rpa","30-qa","40-redteam","40-seguranca","deploy"]

# ---- conjunto de arquivos escaneados (9 SKILL.md + templates) -------------
SKILLS = [
    "skills/discovery/SKILL.md",
    "skills/arquitetura/SKILL.md",
    "skills/desenvolvimento/SKILL.md",
    "skills/review-codigo-subagents/SKILL.md",
    "skills/qa/SKILL.md",
    "skills/qa-rpa/SKILL.md",
    "skills/seguranca/SKILL.md",
    "skills/redteam/SKILL.md",
    "skills/scaffold-spec/SKILL.md",
    "skills/scaffold-spec/templates/skills/deploy/SKILL.md",
    "skills/scaffold-spec/templates/rules/seguranca.md",
    "skills/scaffold-spec/templates/rules/fluxo-desenvolvimento.md",
]

def read(rel):
    p = os.path.join(ROOT, rel)
    try:
        with open(p, encoding="utf-8") as f:
            return f.read()
    except OSError:
        return None

def lines(rel):
    txt = read(rel)
    return txt.splitlines() if txt is not None else []

fails = []
def fail(tag, msg):
    fails.append((tag, msg))

# =========================================================================
# GOLDEN — DAG do yaml == CANON
# =========================================================================
def golden():
    txt = read(os.path.relpath(YAML, ROOT))
    if txt is None:
        fail("golden", f"pipeline-contract.yaml nao encontrado em {YAML}")
        return
    ids, in_dag = [], False
    for ln in txt.splitlines():
        if re.match(r"^dag:\s*$", ln):
            in_dag = True; continue
        if in_dag and re.match(r"^[A-Za-z_]", ln):   # proxima chave top-level fecha o dag
            break
        if in_dag:
            m = re.match(r"^\s*-\s*id:\s*(\S+)", ln)
            if m:
                ids.append(m.group(1))
    if ids == CANON:
        print(f"golden: OK — DAG bate com a ordem canonica ({len(ids)} etapas)")
    else:
        fail("golden", f"DAG do yaml != ordem canonica.\n  yaml : {ids}\n  canon: {CANON}")

# =========================================================================
# (a) paths stale por disciplina  ->  sprints/NN-
# =========================================================================
def check_a():
    hits = []
    pat = re.compile(r"sprints/[0-9]+-")
    for rel in SKILLS:
        for i, ln in enumerate(lines(rel), 1):
            if pat.search(ln):
                hits.append(f"{rel}:{i}: {ln.strip()}")
    if hits:
        fail("(a) C10", "path por disciplina que o blueprint flat NAO cria:\n    " +
             "\n    ".join(hits))
    else:
        print("(a) C10: OK — 0 referencia a sprints/NN-<disciplina>")

# =========================================================================
# (b)+(d) gate antes do executor / ciclo 25<->10b
# =========================================================================
def check_b():
    hits = []
    rc = read("skills/review-codigo-subagents/SKILL.md") or ""
    # B1 — a 25 (executor) NAO pode declarar rodar depois / exigir o 10b (gate)
    if re.search(r"e do gate\s+`?/arquitetura review", rc):
        hits.append("review-codigo-subagents: intro diz rodar 'depois do gate /arquitetura review' (10b apos 25)")
    if re.search(r"aprovado no gate\s+`?/arquitetura review", rc):
        hits.append("review-codigo-subagents: DoR exige 'aprovado no gate /arquitetura review' (ciclo 25<->10b)")
    # B2 — arrows invertidos nos diagramas
    scaffold = read("skills/scaffold-spec/SKILL.md") or ""
    fluxo    = read("skills/scaffold-spec/templates/rules/fluxo-desenvolvimento.md") or ""
    inv = [
        (fluxo,    r"ARQ\(review\)\s*→\s*25",                 "fluxo-desenvolvimento: '10 ARQ(review) → 25' (10b antes da 25)"),
        (scaffold, r"(?m)^10\s+/arquitetura review.*\n25\s+/review-codigo",
                                                              "scaffold flow: '/arquitetura review' listado antes de '/review-codigo-subagents'"),
        (scaffold, r"10-review\s*→\s*25",                     "scaffold: '10-review → 25-review-codigo' (10b antes da 25)"),
        (scaffold, r"arquitetura review`?\s*→\s*`?/review-codigo",
                                                              "scaffold RUNBOOK: '/arquitetura review → /review-codigo' (10b antes da 25)"),
        (scaffold, r"/qa\s+→\s+/qa-rpa",                      "scaffold flow: '/qa → /qa-rpa' (gate antes do executor)"),
        (scaffold, r"/seguranca\s+→\s+/redteam",              "scaffold flow: '/seguranca → /redteam' (gate antes do executor)"),
        (scaffold, r"`/qa`\+`/qa-rpa`",                       "scaffold RUNBOOK: '/qa + /qa-rpa' (gate antes do executor)"),
        (scaffold, r"`/seguranca`\+`/redteam`",              "scaffold RUNBOOK: '/seguranca + /redteam' (gate antes do executor)"),
    ]
    for txt, pat, desc in inv:
        if re.search(pat, txt):
            hits.append(desc)
    if hits:
        fail("(b)(d) C9", "ordem executor→gate violada / ciclo de DoR:\n    " +
             "\n    ".join(hits))
    else:
        print("(b)(d) C9: OK — ordem 20→25→10b→30→40 e nenhum ciclo 25<->10b")

# =========================================================================
# (c) home de artefato sem contrato
# =========================================================================
def check_c():
    hits = []
    # C1 — denylist de homes nao-canonicos
    deny = re.compile(r"docs/relatorios")
    for rel in SKILLS:
        for i, ln in enumerate(lines(rel), 1):
            if deny.search(ln):
                hits.append(f"{rel}:{i}: home 'docs/relatorios' fora do contrato (use .spec/qa/sprint-NN-<tema>/)")
    # C2 — skill-produtora tem que citar seu home canonico
    positives = [
        ("skills/review-codigo-subagents/SKILL.md", r"sprint-NN-<tema>/review-codigo\.md",
         "relatorio da 25 sem home canonico (.spec/sprints/sprint-NN-<tema>/review-codigo.md)"),
        ("skills/seguranca/SKILL.md",               r"sprint-NN-<tema>/seguranca\.md",
         "relatorio do 40 sem home canonico (.spec/sprints/sprint-NN-<tema>/seguranca.md)"),
        ("skills/qa-rpa/SKILL.md",                  r"\.spec/qa/sprint-NN-<tema>/",
         "evidencia de QA sem home canonico (.spec/qa/sprint-NN-<tema>/)"),
    ]
    for rel, pat, desc in positives:
        txt = read(rel) or ""
        if not re.search(pat, txt):
            hits.append(f"{rel}: {desc}")
    if hits:
        fail("(c) C11", "home de artefato fora do contrato:\n    " + "\n    ".join(hits))
    else:
        print("(c) C11: OK — todo home de artefato tem contrato")

# =========================================================================
golden()
check_a()
check_b()
check_c()

print()
if fails:
    print("contract-lint: FALHOU\n")
    for tag, msg in fails:
        print(f"[FAIL {tag}] {msg}\n")
    sys.exit(1)
print("contract-lint: OK — skills coerentes com o contrato")
sys.exit(0)
PYEOF
