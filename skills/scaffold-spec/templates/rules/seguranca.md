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
- **[INEGOCIÁVEL]** Autorização mora no **serviço dono do dado**. Propagar identidade sem que o
  dono filtre por ela é controle aparente — e meia-medida é pior que nenhuma, porque parece feita.
- **[INEGOCIÁVEL]** Escopo de posse é invariante do tipo, não filtro. Se um campo decide **o que o
  usuário pode ver**, ele é: (a) **obrigatório no tipo**, não anulável e sem valor padrão; (b)
  **derivado da identidade autenticada**, nunca da query string, do corpo ou de cabeçalho que o
  cliente controla; (c) aplicado **sem ramo condicional** — `se preenchido, adiciona a cláusula` é
  o mesmo que não ter escopo, com o modo inseguro protegido só por convenção; (d) com **uma**
  semântica de comparação escrita em código — comparar identidade no motor e na linguagem com
  regras diferentes é ter duas respostas para "é o dono?". O modo de falha não tem erro, não tem
  log e não tem sintoma: a consulta responde `200` com dados de outra pessoa.
- **Especificação que lista o dono ao lado de situação e período, "como se fosse mais um filtro",
  não converte controle de acesso em parâmetro de busca.** Quando o card disser isso, a resposta é
  a divergência registrada, não a implementação. Papel administrativo com visão ampliada é **outro
  escopo**, explícito no tipo ou em outra consulta — nunca o mesmo campo tornado opcional.
- **Fechar autorização é inventariar todas as portas do recurso — e a mutação vem antes da
  leitura.** Endurecer os `GET` e deixar de fora o `POST` que aplica efeito regulado entrega a
  operação mais cara do fluxo sem checagem de posse. Liste, por recurso, cada endpoint que o toca
  e marque quem valida posse.
- **Proteção delegada a montante é decisão registrada, verificada e com falha fechada.** "Roda só
  internamente" não é controle: ou está escrito, com o ponto do gateway citado, e o serviço
  **recusa subir** fora dessa borda, ou o serviço valida por conta própria.
- **Modo de autenticação relaxado desliga tudo que deriva da identidade.** Quando o solicitante
  chega nulo, caem juntos o tempero da chave de idempotência, a atribuição de dono na escrita e o
  autor da auditoria — três invariantes a partir de **uma** chave de configuração. Para cada modo
  relaxado, listar por escrito o que degrada junto, e garantir que ele não é caminho de produção.
- **[INEGOCIÁVEL]** Valor sentinela de identidade ausente (`"nao informado"`, `"anonimo"`, string
  vazia) **nunca** pode ser um valor que a checagem de posse aceita. Ausência falha fechado;
  sentinela falha **aberto** e passa no teste de posse — todos os envios anônimos viram um único
  dono real, mutuamente legíveis e mutuamente processáveis. Quando a especificação propõe o
  fallback, ele é recusado por escrito.
- Promessa de isolamento escrita na documentação de um método vale só enquanto a identidade
  existe: ou o caso de identidade ausente está tratado, ou a ressalva está escrita no mesmo lugar
  da promessa (Regra 14).

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
- **[INEGOCIÁVEL]** Corpo de erro de integração **não entra na resposta ao cliente**, do mesmo
  jeito que não entra no log. Repassar o texto do downstream no campo de detalhe da resposta o põe
  num lugar **mais exposto** que o sink de log: ele atravessa o navegador, o histórico e o
  relatório de erro do usuário, carregando mensagem de autenticação, identificador de apólice e
  documento de terceiro. A resposta carrega só o lado local (código, mensagem própria,
  identificador de correlação); o texto alheio fica no log, com o par (original, enviado).
- **Dado pessoal não entra em path nem query string sem decisão registrada.** Path e query
  vazam inteiros para log de acesso, proxy, APM e histórico — é o mesmo vetor de "corpo no
  log", pela outra ponta. Quando o contrato do downstream não oferece alternativa (corpo ou
  header), normalize para a forma canônica, escape, e registre a decisão no MR (ver Regra 23).
- **Chave de idempotência derivada precisa ser escopada pela identidade do solicitante.**
  Chave determinística global (ex.: hash só do conteúdo) faz dois usuários que enviam o
  mesmo arquivo colidirem na mesma chave — o segundo pode receber o recurso criado pelo
  primeiro. Sale o hash com o usuário autenticado, ou confirme por escrito que o
  downstream escopa a idempotência por usuário.
- **[INEGOCIÁVEL]** Nenhuma conversão **com perda** entra na cadeia de derivação de identidade
  (hash, deduplicação, idempotência): entrada distinta continua distinta até o resumo. Codificação
  que substitui caractere fora da faixa, truncamento, normalização de caixa e corte de espaço
  colapsam entradas legítimas na mesma chave — e o sintoma em produção é "não aconteceu nada",
  porque a operação nova é descartada como duplicata. O teste que só usa caracteres da faixa
  restrita nunca mata esse mutante: inclua acento, caixa e comprimento no vetor.
- **[INEGOCIÁVEL]** Consulta pelo caminho de reprodução (replay) de chave de idempotência leva a
  identidade do solicitante no filtro. Busca global por chave que o cliente controla faz um
  solicitante receber o recurso criado por outro — com identificadores e contadores alheios — e a
  requisição legítima do segundo **desaparece com resposta de sucesso**. Teste obrigatório: duas
  identidades enviando o mesmo conteúdo e a mesma chave.
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
- Corpo de erro de integração ecoado na resposta ao cliente.
- Dado pessoal em path/query string sem decisão registrada no MR.
- Trilha de auditoria que grava o "antes" de um registro e o generaliza para o lote.
- Chave de idempotência derivada sem identidade do solicitante.
- Conversão com perda (codificação restrita, truncamento, caixa) na cadeia até o hash de identidade.
- Consulta por chave de idempotência sem a identidade do solicitante no filtro.
- Dado pessoal real em seed, mock ou fixture.
- Exportação sem neutralizar início de fórmula.
- Audit log com UPDATE/DELETE.
- Escopo de posse vindo do cliente (query, corpo, cabeçalho) ou dentro de condicional de "preenchido".
- Endpoint de mutação sem checagem de posse quando a leitura do recurso já tem.
- Valor sentinela de identidade ausente aceito pela checagem de posse.
- Bypass de auth ou validação afrouxada em produção.
- Modo de autenticação relaxado sem a lista escrita do que degrada junto.
