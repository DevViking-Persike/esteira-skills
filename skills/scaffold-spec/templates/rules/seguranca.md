# Regras de Segurança

> Baseline de segurança do projeto. Preencha os `<...>` com a realidade local.
> Invariantes marcados **[INEGOCIÁVEL]** não mudam sem aprovação escrita.

## Segredos

- **[INEGOCIÁVEL]** Nunca abrir, colar, resumir ou logar valores de segredo
  (`<diretório de secrets>`, `.env` reais, chaves, tokens). Só `*.example` e
  `*.enc` (cifrados) entram no git.
- Cifrar segredos em repouso (ex.: SOPS/age) e versionar **só** o cifrado; a chave
  privada nunca vai pro git.
- Rotação simples e documentada; comprometeu uma chave → rotaciona chave **e**
  segredos.
- No cluster, segredo vira Secret/sealed-secrets — nunca Secret YAML plano no git.

## Autenticação & Autorização

- **[INEGOCIÁVEL]** Bypass de auth **não** pode ser caminho de produção.
- Token/credencial nunca chega ao browser/cliente (fica server-side: cookie
  httpOnly cifrado ou equivalente; **nunca** em PageData/localStorage/bundle).
- AuthZ por papel/permissão checada **no servidor** (deny-by-default); rota não
  mapeada não fica liberada por omissão.
- Validar o token na borda confiável (JWKS/introspecção), não confiar em claims
  não verificados.

## Dados & Integridade

- **[INEGOCIÁVEL]** Audit log **append-only** — não deletar/alterar
  retroativamente (proteger no banco, ex.: trigger).
- Actor de auditoria vem do **usuário autenticado**, nunca do body da requisição.
- **Trilha de auditoria registra o estado "antes" de cada registro alterado.** Quando uma
  operação altera N registros, ler o "antes" de um só — ou omiti-lo — e generalizar para o
  lote produz auditoria que **não reconstitui** o que mudou. Leia o conjunto afetado antes da
  escrita, atualize exatamente esse conjunto e emita um registro de trilha por linha, para
  que trilha e efeito nunca divirjam (ver Regra 19).
- Validar/normalizar toda entrada externa (rejeitar inválido com 4xx); nunca
  montar SQL/comando por concatenação de input.
- **[INEGOCIÁVEL]** Nunca logar corpo de resposta ou de requisição de integração — logar
  apenas **tamanho** e status (`TamanhoDoCorpo={body?.Length ?? 0}`). Corpo de erro de
  downstream carrega PII (CPF/CNPJ, apólice, solicitante) e sink de log não é lugar de
  dado de cliente. Vale para log de sucesso e de erro.
- **Dado pessoal não entra em path nem query string sem decisão registrada.** Path e query
  vazam inteiros para log de acesso, proxy, APM e histórico — é o mesmo vetor de "corpo no
  log", pela outra ponta. Quando o contrato do downstream não oferece alternativa (corpo ou
  header), normalize para a forma canônica, escape, e registre a decisão no MR (ver Regra 23).
- **Chave de idempotência derivada precisa ser escopada pela identidade do solicitante.**
  Chave determinística global (ex.: hash só do conteúdo) faz dois usuários que enviam o
  mesmo arquivo colidirem na mesma chave — o segundo pode receber o recurso criado pelo
  primeiro. Sale o hash com o usuário autenticado, ou confirme por escrito que o
  downstream escopa a idempotência por usuário.
- **Dado pessoal real nunca entra em seed, mock ou fixture.** Use domínio de exemplo
  (`example.com`). O vetor não é o mock: é ele ser alcançável a partir de código de
  produção — um seed importado por service singleton viaja no pacote publicado.
- **Exportação de dados neutraliza início de fórmula.** Célula que começa com `=`, `+`,
  `-`, `@`, TAB ou CR recebe prefixo de aspa simples antes do escape normal. Vale para
  CSV, TSV e XLSX: o conteúdo veio do usuário, atravessa o sistema e arma na planilha de
  quem abre.
- **Identidade autenticada atravessa a cadeia inteira.** Quem captura o usuário na borda
  propaga até quem persiste. Amarrar dono só na leitura não adianta se a escrita não
  registrou quem foi. Antes de assumir que o downstream não aceita, conferir o contrato.
- Criptografia em repouso para dados sensíveis quando aplicável; TLS em trânsito.
- LGPD/privacidade e **mínimo privilégio** para usuários, operadores e automações.

## Aplicação (web)

- CSP restritiva (nonce, sem `unsafe-inline`); sanitizar saída para evitar XSS.
- Sem open-redirect: validar `returnTo`/deep-links contra allowlist.
- Sem SSRF: o backend não busca URL arbitrária vinda do cliente.
- Sem mass-assignment: aceitar só os campos esperados.

## Supply chain & Operação

- Dependências fixadas (sem `latest`); revisar antes de subir versão.
- Imagens de container mínimas (distroless/non-root) e de registry confiável.
- **[INEGOCIÁVEL]** Nunca afrouxar validação de segurança em produção (ex.: flags
  `*_LENIENT`, `*_BYPASS`) — só em `NODE_ENV=development`/dev local.
- Backup antes de operação destrutiva (`DROP`, migration irreversível, delete em
  massa).

## Verificação

- **Estático:** revisão de diff focada em segurança (`/security-review` ou
  equivalente) antes do merge.
- **Dinâmico:** a disciplina **40-segurança** da esteira (`.spec/sprints/`) tenta
  **invadir pelo navegador** o ambiente vivo (token vazando, authz, audit,
  CSP, redirect) — ver `.spec/sprints/README.md`.

## Proibido

- Segredo em claro no git / em chat / em issue / em PR.
- Token/JWT/dado sensível em PageData, localStorage ou cookie não-httpOnly.
- Corpo de resposta de integração no log (só tamanho e status).
- Dado pessoal em path/query string sem decisão registrada no MR.
- Trilha de auditoria que grava o "antes" de um registro e o generaliza para o lote.
- Chave de idempotência derivada sem identidade do solicitante.
- Dado pessoal real em seed, mock ou fixture.
- Exportação sem neutralizar início de fórmula.
- Audit log com UPDATE/DELETE.
- Bypass de auth ou validação afrouxada em produção.
