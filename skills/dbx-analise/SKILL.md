---
name: dbx-analise
description: Análise de banco de dados local (MySQL gap-stack e Mongo) via MCP do DBX — inventário de schema, dumps de domínio, contagens, redundâncias entre schemas. Use quando o usuário pedir "analisar o banco", "inventário de schema", "consultar o banco local", "/dbx-analise", ou quando qualquer disciplina da esteira (discovery, arquitetura, desenvolvimento, QA) precisar de dados reais do banco local.
---

# Skill: dbx-analise

Análise **read-only** dos bancos locais de desenvolvimento via **DBX MCP**
(`@dbx-app/mcp-server`), com fallback para o cliente `mysql` CLI.

## Pré-condições

1. **App DBX aberto** (o bridge MCP vive no app — portas 4224/aleatória local).
   Verificar: `pgrep -af dbx` e `ss -ltn | grep 4224`.
2. Pacote npm global instalado: `npm ls -g @dbx-app/mcp-server`
   (instalar/atualizar: `npm install -g @dbx-app/mcp-server@latest`).
3. Servidor registrado no projeto em `.mcp.json` (raiz do bill-1940):
   `{"mcpServers": {"dbx": {"command": "dbx-mcp-server"}}}`.
   Numa sessão nova do Claude Code as tools aparecem como `mcp__dbx__*`
   (carregar schema via ToolSearch se estiverem deferred).

## Conexões conhecidas (verificado em 2026-07-16)

| Nome | Tipo | Endereço | Conteúdo |
|---|---|---|---|
| `local-mysql-gap` | mysql | 127.0.0.1:3306 | gap-stack: `sga`, `sgi_pre_apolice`, `sgi_atualizacao_apolice`, `sgi_controle_upload_arquivo`, `sgi_alfandega`, `db_financeiro`… |
| `local-mongo-cancelamento` | mongodb | 127.0.0.1:27017 | só admin/config/local (sem os raws de importação) |

## Tools do MCP (nesta ordem de uso)

1. `dbx_list_connections` — confirmar conexões disponíveis.
2. `dbx_get_schema_context` — contexto de schema de uma conexão/database (visão geral primeiro, sempre).
3. `dbx_list_tables` / `dbx_describe_table` — detalhar tabelas específicas.
4. `dbx_execute_query` — consultas ad-hoc (SELECT/SHOW apenas).

### Regras

- **Read-only sempre.** Nunca definir `DBX_MCP_ALLOW_WRITES` sem pedido explícito
  do usuário no turno. Nada de UPDATE/DELETE/DDL via MCP.
- **Escopo estreito quando possível:** env `DBX_MCP_SCOPE_CONNECTION_NAME=local-mysql-gap`
  e `DBX_MCP_SCOPE_DATABASE=<schema>` restringem o servidor a um banco.
- Ambiente local de dev — **não é produção**; volumetria/transacionais locais
  não representam prod (marcar como lacuna nos relatórios de discovery).
- Ignorar tabelas de infra: `__liquibase%`, `databasechangelog%`.

## Fallback sem MCP (sessão atual sem `mcp__dbx__*`)

- MySQL direto: `mysql -h127.0.0.1 -P3306 -uroot -proot -e "<SQL>"`.
- Ou sondar o servidor MCP via stdio (JSON-RPC newline-delimited):
  `initialize` → `notifications/initialized` → `tools/call`
  (binário: `dbx-mcp-server`).

## Receitas de análise (padrão da esteira)

- **Inventário de schema:** para cada tabela do schema alvo,
  `SHOW CREATE TABLE` + `SELECT COUNT(*)`; resumir colunas/PK/FK/índices.
- **Dump de domínio:** `SELECT *` das tabelas pequenas de domínio
  (`status`, `fonte_importacao`, `upload_template_pasta`, `status_raw`).
- **Redundância entre schemas:** comparar tabelas homônimas/sobrepostas
  entre `sgi_pre_apolice`, `sgi_controle_upload_arquivo` e
  `sgi_atualizacao_apolice` (ex.: 3 tabelas `status` distintas) — insumo
  da consolidação BILL-1940.
- **Relatório:** markdown com evidências (schema.tabela.coluna), fatos
  separados de hipóteses, seção de lacunas.
