# Regra 28 — Wiring é comportamento: registrar não é fiar

> **3 camadas:** Camada 1 (Princípio) é universal · Camada 2 traz o teste que vale por stack ·
> Camada 3 traz o caso que originou a regra. Veja `_layer-guide.md`.
>
> Vizinhas: Regra 04 (o composition root só compõe), Regra 21 (não presuma o que a lib dá),
> Regra 20 (nome amarrado por string é promessa), Regra 26 (verifique no artefato).

## Camada 1 — Princípio universal (agnóstico)

O arquivo de composição não é configuração: é código que decide comportamento. Cinco
invariantes, todas invisíveis para teste de unidade da peça.

### 1. Registrar no container não liga a capacidade
Capacidade que só age através de um pipeline — tratamento de exceção, autenticação, limitação de
taxa, correlação, serialização — depende de três coisas além do registro: o pipeline estar
montado, a peça estar na **posição** certa dele, e a ordem entre peças do mesmo tipo. Um teste
que chama o método do manipulador diretamente prova que o método funciona; não prova que alguém
o chama.

### 2. Ordem e posição são comportamento, não estilo
Peças do mesmo tipo são consultadas na **ordem de registro**: registrar a sua depois da genérica
faz a genérica responder primeiro e a sua nunca decidir nada. Middleware de tratamento de erro
registrado **depois** de autenticação, autorização ou limitação de taxa não cobre as exceções
dessas etapas — que escapam sem resposta. O ambiente de desenvolvimento esconde isso, porque a
página de diagnóstico cobre o buraco que produção deixa aberto.

### 3. Peça que declina devolve o contexto como encontrou
Manipulador que decide não tratar não pode ter mexido no estado compartilhado no caminho:
cabeçalho, tipo de conteúdo, código de status e corpo continuam como estavam. Meio-tratamento é
pior que nenhum — o próximo elo recebe um contexto sujo.

### 4. Endereço de dependência externa não tem valor padrão de conveniência
Sem o valor configurado, o processo **não sobe**. Cair em `localhost` numa porta fixa, em
`http://` sem TLS, transforma erro de implantação em serviço saudável que conversa com ninguém:
health check verde, requisições falhando uma a uma, e o time procurando o defeito no código. O
mesmo vale para vínculo por string — política, cliente nomeado, seção de configuração, nome de
fila: o compilador não olha, então o MR mostra onde o registro do outro lado acontece, e existe
teste que resolve pelo nome.

### 5. Dois prazos no mesmo caminho têm um dono
Quando duas camadas impõem tempo limite (o cliente e a política de resiliência, por exemplo),
declare qual é o dono e **derive** o outro dele, lendo do próprio ponto de configuração. Dois
prazos iguais por coincidência produzem o pior resultado possível: o externo corta exatamente as
retentativas que o interno existia para permitir. Copiar o número para uma constante local
congela um valor que a dependência muda no próximo bump de versão (Regra 21).

### Motivação
É a classe de defeito com a pior relação entre esforço de detecção e impacto: uma linha no
arquivo de composição decide se a exceção de domínio vira o status certo ou `500` genérico, se o
serviço fala com o gateway ou com ninguém — e nenhum teste de unidade da suíte inteira reprova a
linha errada.

### Exceções aceitas
- Registro de dependência sem comportamento no pipeline (repositório, mapeador, serviço de
  aplicação): o teste de unidade basta.
- Peça cuja posição a plataforma impõe em tempo de compilação ou no boot (a subida falha se ela
  estiver fora de lugar).
- Emulador ou dependência local declarados **apenas** no perfil de desenvolvimento, com o perfil
  de produção falhando fechado na ausência do valor.
- Valor com padrão seguro por natureza (nível de log, tamanho de página), que não decide destino,
  credencial nem prazo.

## Camada 2 — Preset por stack

| Stack | Teste que vale | Armadilha típica |
|---|---|---|
| C# / ASP.NET | `WebApplicationFactory` batendo num endpoint que aciona a capacidade | ordem entre manipuladores de exceção; bootstrap depois de autenticação/autorização/limite de taxa; escrita de resposta sobrescrevendo o tipo de conteúdo |
| Node-TS (express/fastify) | `supertest` contra o app montado | middleware de erro registrado antes das rotas |
| Python (FastAPI) | `TestClient` | ordem de middleware invertida em relação à declaração |
| Go | `httptest.NewServer` com o roteador real | encadeamento manual fora de ordem |

```bash
# Ordem das peças no arquivo de composição
find <api-root> -name 'Program.cs' -o -name 'Startup.cs' -print0 \
| xargs -0 grep -nE 'Use[A-Z][A-Za-z]+\(|Add[A-Z][A-Za-z]+\('

# Valor padrão de conveniência em leitura de endereço (inclui .env, que é gitignored)
find <src-root> -name '*.cs' -o -name '*.ts' -print0 \
| xargs -0 grep -nE '\?\? *"http|localhost|127\.0\.0\.1'
find . -name '*.env*' -not -path '*/node_modules/*' -print0 \
| xargs -0 grep -nE 'localhost|127\.0\.0\.1|http://'

# Vínculo por string sem prova de registro
find <src-root> -name '*.cs' -print0 \
| xargs -0 grep -nE 'EnableRateLimiting\("|AddHttpClient\("|GetSection\("'

# Capacidade registrada sem teste que suba o host
find <tests-root> -type f -print0 \
| xargs -0 grep -lE 'WebApplicationFactory|TestClient|httptest|supertest'
```

## Camada 3 — Exemplo concreto

Num BFF financeiro, seis defeitos saíram do mesmo arquivo de composição:

| Ponto | O que acontecia |
|---|---|
| manipulador de exceção de domínio | o registro no container só o **adiciona**; o método só roda pelo middleware correspondente, e o container resolvia dois manipuladores na ordem de registro — registrar depois do bootstrap da casa fazia a exceção de `502` sair como `500` |
| posição do bootstrap | ficava depois de limite de taxa, autenticação e autorização, então exceção nessas etapas escapava **em produção sem resposta HTTP**, mascarado em desenvolvimento pela página de diagnóstico |
| caminho declinado | o manipulador que devolvia "não tratei" deixava o tipo de conteúdo já alterado |
| endereço do gateway | sem a variável de ambiente, caía em `http://localhost:5000` — sem TLS, num cliente que trafega apólice e documento do tomador — e a aplicação subia com o health check verde |
| política por string | o atributo amarrava uma política registrada em outro lugar; a falha só apareceria na primeira requisição do ambiente |
| prazo do cliente | `Timeout = 30s` convivia com a política de resiliência cujo prazo total também era 30s: o externo cortava exatamente as retentativas que o commit queria ligar |

A primeira tentativa de correção do prazo espelhou o padrão da biblioteca numa constante local —
que desalinha no próximo bump. A correção final lê o valor do próprio ponto de configuração.

## Como verificar
```bash
# 1. Para cada capacidade registrada, existe teste que sobe o host real e bate num endpoint
#    que a aciona.
# 2. Conferir a posição do middleware de erro em relação a autenticação, autorização e limite
#    de taxa — e a ordem entre peças do mesmo tipo.
# 3. Testar o caminho declinado: o contexto sai como entrou.
# 4. Para cada string de wiring, o MR mostra onde o registro acontece + teste que resolve pelo nome.
# 5. Quando dois prazos coexistem no mesmo caminho, declarar o dono e derivar o outro.
```
