# Regra 13 — Contrato de borda: entrada do cliente nunca vira 5xx

> **3 camadas:** Camada 1 (Princípio) é universal · Camada 2 lista o mecanismo de cada stack · Camada 3 traz o exemplo que originou a regra. Veja `_layer-guide.md`.

## Camada 1 — Princípio universal (agnóstico)

**Todo valor que o cliente controla precisa ser validado antes de ser usado.** Se o valor é
inválido, a resposta é **4xx com mensagem acionável**. `5xx` significa "o servidor falhou",
e um cliente mandando lixo não é falha do servidor.

O sintoma clássico: um parser que **lança** ao receber entrada malformada, dentro de um
bloco cujo `catch` genérico devolve 500. O cliente não descobre o que errou, o erro polui
o alerta de disponibilidade, e o time caça um bug de servidor que não existe.

### Onde mora o risco
Todo ponto onde entrada externa vira objeto tipado: cabeçalho HTTP, `Content-Type`,
query string, path param, corpo JSON, nome de arquivo, data, número, enum, culture,
URL, regex vinda de config.

### Como aplicar
- Prefira a variante **`TryParse`** à que lança. Se só existe a que lança, envolva e traduza.
- A tradução acontece **na borda**, junto da validação — não num `catch` distante.
- `4xx` diz **qual campo** e **o que se esperava**. Nunca ecoe o valor recebido em log
  (ver Regra 12 de segurança sobre PII).
- Teste o caminho: existe um caso que passa entrada malformada e asserta o status.

### Cultura e formato: converter não é só parsear

Número e data **digitados por humano** chegam na convenção local de quem digitou — planilha,
formulário, CSV, integração com sistema regional. Duas armadilhas, nesta ordem:

1. `TryParse` com **uma única cultura** descarta valor legítimo. `10,5` lido com cultura
   invariante vira `null`, e o `null` costuma seguir adiante sem erro: prêmio, comissão ou
   valor monetário some em silêncio (Regra 15).
2. **Trocar a cultura sem normalizar troca o `null` por um valor errado**, que é pior. Os
   parsers não validam tamanho de grupo de milhar: com a cultura "errada", `2500,50` pode
   virar `250050` e `1500.00` pode virar `150000`. O defeito passa a ter aparência de sucesso.

O remédio é **normalizar o texto e depois converter**: decidir qual separador é decimal a
partir da forma do próprio valor (o último separador presente é o decimal; separador repetido
é agrupamento), e só então `TryParse` com cultura invariante. O teste cobre os dois formatos e
mantém explicitamente o que **deve** continuar sendo rejeitado.

Se um campo do mesmo formulário já aceita o formato local (data `dd/MM/yyyy`), então a entrada
**é** local — o campo numérico ao lado não pode assumir o contrário.

**Whitelist com escape permissivo ao lado não é whitelist.** Declarar N formatos exatos e, ao
final, cair num parse genérico é a mesma classe de erro do parse com a cultura errada — com
aparência de rigor. E o pior caso não é falhar: é acertar errado. Dois componentes numéricos
separados por barra são lidos na ordem que a cultura mandar, então um campo declarado como
mês/ano recebe uma data plausível em vez de um `4xx`, e um valor de competência regulatória entra
no banco sem que nada tenha estourado. O mesmo escape aceita mês-primeiro num contrato
dia-primeiro.

Cada coluna do contrato declara os formatos que aceita, e o que não casa é erro do cliente, com o
nome da coluna e a lista do que se esperava. O nome do conjunto diz que ele é o contrato inteiro
(`FormatosAceitos`), não uma amostra (Regra 12). **Teste de remoção:** apague o parse genérico e
rode a suíte — se nada quebra, ele só existia para o que a lista exata já cobria; e o teste
tabelado inclui explicitamente o que **deve** continuar sendo rejeitado.

### O outro lado: resposta do downstream fora do contrato

O mesmo princípio, invertido. Quando quem responde errado é o **serviço de quem você
depende**, o código de status precisa dizer isso: **`502`**, não `500`. Assumir `500` é
declarar culpa própria por falha alheia, e manda o time investigar o lugar errado.

E não troque o erro por um **fallback que mente**. Ao receber um valor que o contrato local
não conhece, é tentador assumir um neutro e seguir. Numa tela que existe para responder uma
pergunta operacional ("meu lote terminou?"), exibir um estado inventado engana o usuário
exatamente na decisão que ele veio tomar. Falhar barulhento, com o código certo e log que
nomeie o contrato, é melhor que acertar por sorte.

### O status carrega origem

Um número de status tem dono. O `404` que **você** decidiu e o `404` que **chegou** do serviço de
quem você depende têm o mesmo dígito e significados opostos: o primeiro é resposta de negócio; o
segundo, quase sempre, é rota errada no seu cliente — defeito seu. Propagar o segundo verbatim
faz um erro de integração sair classificado como informação de rotina, e ninguém investiga.

- **O tipo que atravessa o sistema carrega a origem** (resposta de outro serviço × decisão
  local); severidade, nível de log e resposta ao chamador derivam dela, nunca do dígito.
- **`401`, `403` e `429` do downstream são sobre a sua credencial e a sua quota.** Repassados ao
  navegador, deslogam um usuário que autenticou corretamente. Viram `502`, com o status cru só no
  log — e o log carrega o par (original, enviado).
- **Dentro do `4xx` o tipo não se perde.** Mapear todo erro de aplicação para `400` apaga a
  diferença entre "não existe" (`404`), "conflito" (`409`) e "corrija e reenvie" (`400`), e a
  decisão mais cara — reenviar ou não — vira chute.
- **Remapear status é mexer em contrato consumido.** Antes de mudar, grepe quem ramifica naquele
  status nos repositórios consumidores; o que já é usado como bifurcação de tela fica cru, de
  propósito, e isso é escrito no MR (Regra 20).

### A segunda borda: o seu banco e o vocabulário alheio

A borda de entrada não é só o cliente. O dado que você lê do **seu** banco foi escrito por uma
versão anterior do seu código, e o vocabulário de que **outro serviço** é dono evolui sem avisar.
Nos dois casos o código local é o mais novo e o dado é o mais velho.

- **Conversão estrita na materialização derruba a consulta inteira.** Indexação direta de mapa ou
  conversão que lança sobre um código legado numa única linha transforma "uma linha esquisita" em
  "a listagem responde `5xx`", e a tela de acompanhamento fica cega por causa de um registro. Todo
  conversor de valor persistido tem o par: a forma estrita, para quem escreve; a tolerante, para
  quem lê.
- **Valor desconhecido vindo do dono do modelo é `502`, não `500`** — quem quebrou o contrato não
  foi você.
- **O desconhecido nunca vira o neutro**: vira desconhecido explícito e registrado (Regra 15). O
  que só transita mantém a forma crua.
- **A mensagem nomeia parâmetro, valor recebido e conjunto conhecido**, sem ecoar dado pessoal.

Assimetria interna é o sinal mais barato: se um conversor irmão já tem o par estrito/tolerante e o
outro não, o segundo é o defeito — e a correção vale para a família (Regra 21).

### Motivação
`5xx` é sinal operacional: dispara alerta, entra em SLO, acorda gente. Gastar esse sinal
com erro de cliente cega o monitoramento e esconde a falha real. E o cliente que recebe
500 tende a **repetir** a requisição, porque 500 parece transitório — o mesmo lixo volta.

### Exceções aceitas
- Falha genuína de dependência (banco fora, downstream 500) — aí `5xx`/`502`/`504` é o certo.
- Entrada vinda de sistema interno confiável com contrato garantido em compile-time.
- Whitelist de formato: campo de texto livre que só transita e nunca vira decisão — não há
  whitelist a declarar, e o valor viaja cru.
- Status repassado verbatim: gateway declaradamente transparente, cujo contrato publicado é
  "repasso o status do upstream".
- Conversão estrita na leitura: coluna cuja faixa é garantida por constraint no próprio banco e
  escrita apenas por este serviço — aí o estrito é o certo, e a constraint é a prova.

## Camada 2 — Preset por stack

| Stack | Prefira | No lugar de |
|---|---|---|
| C# | `MediaTypeHeaderValue.TryParse`, `DateTime.TryParse`, `int.TryParse`, `Enum.TryParse`, `Uri.TryCreate` | construtor/`Parse` que lança |
| Node-TS | `zod`/`valibot` `safeParse`, `Number.isFinite` | `JSON.parse` cru, `new URL()` sem try |
| Python | `pydantic` com `ValidationError` → 422/400 | `int()`/`datetime.fromisoformat` cru |
| Go | `strconv.Atoi` com checagem de `err` | ignorar `err` |
| Rust | `parse::<T>()` com `?` mapeado para 400 | `unwrap()` |

**Número/data digitado por humano:** normalize o texto antes do `TryParse` e converta com
cultura invariante. Nunca resolva trocando só o `NumberStyles`/a cultura.

```bash
# C#: construtores/Parse que lançam sobre dado de borda — cada achado exige justificativa
rg -n 'new MediaTypeHeaderValue\(|DateTime\.Parse\(|Enum\.Parse\(|int\.Parse\(' <api-root>

# Status copiado verbatim do downstream / erro de aplicação achatado em 400
find <src-root> -name '*.cs' -not -path '*/obj/*' -print0 \
| xargs -0 grep -nE '\(HttpStatusCode\)[A-Za-z_.]*StatusCode|BadRequest\('

# Onde o consumidor ramifica por status (antes de remapear)
find <frontend-root> -name '*.ts' -not -path '*/node_modules/*' -print0 \
| xargs -0 grep -nE 'status *===? *(400|401|403|404|409|429|502)'

# Conversão estrita sobre valor vindo do banco ou de JSON alheio
find <infra-root> -name '*.cs' -not -path '*/obj/*' -print0 \
| xargs -0 grep -nE 'Enum\.Parse|Mapa[A-Za-z]*\[|\[chave\]'

# Parse genérico logo depois de um parse exato
find <mapper-root> -name '*.cs' -not -path '*/obj/*' -print0 \
| xargs -0 grep -nE 'TryParseExact|TryParse\('
```

O teste asserta o status **por tipo de erro** — um teste por tipo, não um por endpoint.

## Camada 3 — Exemplo concreto

Encontrado em review no BFF de gestão financeira: o `Content-Type` do upload, **controlado
pelo cliente**, ia direto para o construtor.

```csharp
// Ruim — Content-Type malformado lança FormatException, cai no catch genérico e vira 500
arquivoContent.Headers.ContentType = new MediaTypeHeaderValue(request.ContentType);

// Bom — entrada inválida do cliente é 400, com mensagem
if (!MediaTypeHeaderValue.TryParse(request.ContentType, out var tipoConteudo))
    throw new ServiceException("O Content-Type do arquivo e invalido", HttpStatusCode.BadRequest);

arquivoContent.Headers.ContentType = tipoConteudo;
```

## Como verificar
```bash
# Rodar o grep da Camada 2 no diff do PR. Cada ocorrência sobre dado de borda precisa
# de TryParse ou de justificativa explícita.
```
