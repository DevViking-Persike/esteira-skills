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

### O outro lado: resposta do downstream fora do contrato

O mesmo princípio, invertido. Quando quem responde errado é o **serviço de quem você
depende**, o código de status precisa dizer isso: **`502`**, não `500`. Assumir `500` é
declarar culpa própria por falha alheia, e manda o time investigar o lugar errado.

E não troque o erro por um **fallback que mente**. Ao receber um valor que o contrato local
não conhece, é tentador assumir um neutro e seguir. Numa tela que existe para responder uma
pergunta operacional ("meu lote terminou?"), exibir um estado inventado engana o usuário
exatamente na decisão que ele veio tomar. Falhar barulhento, com o código certo e log que
nomeie o contrato, é melhor que acertar por sorte.

### Motivação
`5xx` é sinal operacional: dispara alerta, entra em SLO, acorda gente. Gastar esse sinal
com erro de cliente cega o monitoramento e esconde a falha real. E o cliente que recebe
500 tende a **repetir** a requisição, porque 500 parece transitório — o mesmo lixo volta.

### Exceções aceitas
- Falha genuína de dependência (banco fora, downstream 500) — aí `5xx`/`502`/`504` é o certo.
- Entrada vinda de sistema interno confiável com contrato garantido em compile-time.

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
```

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
