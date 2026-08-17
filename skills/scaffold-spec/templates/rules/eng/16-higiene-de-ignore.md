# Regra 16 — Higiene de ignore: nada some sem aviso

> **3 camadas:** Camada 1 (Princípio) é universal · Camada 2 traz o formato por ferramenta · Camada 3 traz o exemplo que originou a regra. Veja `_layer-guide.md`.

## Camada 1 — Princípio universal (agnóstico)

**Regra de ignore nunca casa extensão na raiz do repositório.** Sempre restrinja ao
diretório onde o artefato nasce.

O que torna esse erro caro é a assimetria do feedback: o git **não avisa** sobre arquivo
não rastreado que está ignorado. Ele não aparece no `status`, não aparece no diff, não
falha o build. Some, e a descoberta acontece semanas depois, no clone de outra pessoa.

### O que costuma dar errado
- `*.yml` na raiz → o `.gitlab-ci.yml` novo deixa de subir e o MR passa a rodar um pipeline
  genérico, ou nenhum.
- `*.md` na raiz → um ADR, o README de um componente ou o próprio doc que outro arquivo
  referencia deixam de existir para quem clona.
- `*.xlsx`, `*.json`, `*.csv` na raiz → fixture de teste e template servido pela aplicação
  desaparecem.
- **`.gitkeep` ignorado** → é autodestrutivo: o propósito inteiro do arquivo é ser
  versionado para o git manter um diretório vazio.

### Quando o glob amplo é a escolha certa
Existe caso legítimo (planilha solta costuma ser artefato de trabalho). Aí a regra não é
remover o glob, é **escrever ao lado dele a convenção que o torna seguro**: onde o arquivo
legítimo mora, e que sair de lá exige exceção no mesmo commit.

### Teste seco
Antes de adicionar uma linha ao ignore, pergunte: *"se amanhã alguém criar um arquivo
legítimo com essa extensão, ele percebe que sumiu?"* Se a resposta é não, restrinja o
escopo ou escreva a convenção.

### Exceções aceitas
- Diretórios de build e dependência (`node_modules/`, `target/`, `bin/`, `obj/`, `dist/`) —
  já são caminhos, não extensões.
- Ignore **local** de máquina: use `.git/info/exclude`, que não é versionado, em vez de
  poluir o `.gitignore` do time.

## Camada 2 — Preset por ferramenta

| Ferramenta | Arquivo | Observação |
|---|---|---|
| git | `.gitignore` | versionado, vale para o time |
| git (local) | `.git/info/exclude` | não versionado, para escolha individual |
| docker | `.dockerignore` | mesmo princípio; excesso quebra build por falta de arquivo |
| npm | `.npmignore` / `files` no package.json | prefira `files`: allowlist erra menos que denylist |

```bash
# Globs por extensão na raiz — cada um exige convenção escrita ao lado
rg -n '^\*\.[a-z0-9]+$' .gitignore

# O que está ignorado e não deveria: confira antes de confiar
git status --porcelain --ignored | grep -v node_modules
git check-ignore -v <caminho-que-voce-espera-versionar>
```

## Camada 3 — Exemplo concreto

Um único repositório, quatro ocorrências da mesma armadilha numa só revisão:

| Linha | O que escondeu |
|---|---|
| `*.yml` | qualquer configuração de CI nova |
| `*.md` | o doc que o próprio README referenciava |
| `*.xlsx` | templates servidos pela aplicação, se saírem de `assets/` |
| `.gitkeep` | o arquivo cuja única função é ser versionado |

Num repositório irmão, o `*.md` fez `CLAUDE.md` e um template de ADR aparecerem como
deleção no índice — sem ninguém ter apagado nada.

## Como verificar
```bash
# 1. Rodar o rg da Camada 2: cada glob de extensão na raiz precisa de convenção escrita.
# 2. Para todo arquivo que o doc referencia, rodar git check-ignore -v.
```
