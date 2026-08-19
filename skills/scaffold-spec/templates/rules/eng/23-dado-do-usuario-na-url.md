# Regra 23 — Dado do usuário na URL que você monta

> **3 camadas:** Camada 1 (Princípio) é universal · Camada 2 traz o helper por stack ·
> Camada 3 traz o caso que originou a regra. Veja `_layer-guide.md`.

## Camada 1 — Princípio universal (agnóstico)

A Regra 13 cobre a borda de **entrada**. Esta cobre a de **saída**: a URL que o seu código
constrói para chamar o downstream. Todo valor de texto controlado pelo usuário que entra em
path ou query string passa por dois passos, **nesta ordem**:

1. **Normalizar** para a forma canônica que o downstream espera (só dígitos para documento,
   trim, caixa, formato de data). O usuário digita com máscara, com espaço e com pontuação.
2. **Escapar** com o codificador de componente de URL da plataforma.

Os dois são load-bearing e nenhum substitui o outro.

### Por que os dois

- **Sem normalizar**, um separador contido no valor (a barra de uma máscara de documento,
  por exemplo) **injeta segmentos** no path: a rota deixa de ter o formato que o servidor
  espera, o parâmetro seguinte cai na posição errada e o erro chega como 404 ou, pior, como
  consulta a outro recurso.
- **Sem escapar**, caractere fora do conjunto seguro — inclusive dígito Unicode não-ASCII, que
  passa por um filtro de "é dígito" — quebra a requisição ou é interpretado pelo servidor.

### Dado pessoal em URL

Path e query string **vazam inteiros** para log de acesso, proxy, APM e histórico de
navegador. Documento, e-mail, nome e identificador de pessoa só entram na URL quando o
contrato do downstream não oferece alternativa (corpo, header) — e, quando entram, a decisão
fica registrada no MR. Isso é a mesma invariante de PII da regra de segurança, aplicada à
outra ponta.

### Nunca componha a URL por concatenação solta
Um único ponto monta cada rota, e ele é quem aplica normalização e escape. URL montada em
dois lugares diverge — e é a Regra 17 que cobra a conferência contra a rota real do servidor.

### Motivação
É defeito que passa em todo teste unitário dos dois lados: o cliente asserta contra a própria
constante, o servidor asserta contra a rota certa, e o encontro só acontece com um valor
mascarado de produção.

### Exceções aceitas
- Valor tipado não textual (`int`, `long`, `DateTime`, `Guid`) formatado pelo próprio código —
  não é texto controlado pelo usuário.
- Contrato do downstream que exige a forma mascarada: aí a normalização é *para a máscara*, e
  o escape continua obrigatório.

## Camada 2 — Preset por stack

| Stack | Escape de componente | Evite |
|---|---|---|
| C# | `Uri.EscapeDataString`, `QueryHelpers.AddQueryString` | interpolar direto na string da rota |
| Node-TS | `encodeURIComponent`, `new URL()` + `searchParams.set` | template literal cru |
| Python | `urllib.parse.quote(..., safe='')`, `httpx` `params=` | f-string na URL |
| Go | `url.PathEscape`, `url.Values.Encode()` | `fmt.Sprintf` na rota |
| Rust | `percent_encoding`, `Url::query_pairs_mut` | `format!` na rota |

```bash
# Texto do usuário interpolado em rota — cada achado precisa de normalização + escape
rg -n '\$"[^"]*\{[a-zA-Z_.]*(Cpf|Cnpj|Documento|Email|Nome|Txt)[^"]*\}' <infra-root>
rg -n '`[^`]*\$\{[^}]+\}[^`]*`' <http-client-root>
```

**Teste que mata o mutante:** assertar a rota **inteira por igualdade** (um `Contains` deixa
passar o deslocamento de segmento) e incluir um caso com caractere que exige percent-encoding
— só com ASCII, o mutante que remove o escape é imortal.

## Camada 3 — Exemplo concreto

Encontrado em review no backend de atualização de apólice em lote: o documento do tomador,
vindo da planilha enviada pelo usuário, era interpolado cru no path da consulta ao serviço
financeiro.

```csharp
// Ruim — máscara com barra vira dois segmentos e desloca o resto da rota
$"api/Fatura/agrupada/.../tomador/{item.TxtTomadorCpfCnpj}/periodo-referencia/{...}"

// Bom — canoniza, depois escapa
$"api/Fatura/agrupada/.../tomador/{DocumentoNoCaminho(item.TxtTomadorCpfCnpj)}/..."
// DocumentoNoCaminho = Uri.EscapeDataString(SomenteDigitos(documento))
```

Dois defeitos num só ponto: a máscara injetava segmentos extras — o segmento seguinte deixava
de ser lido como período de referência — e o documento, dado pessoal, ia inteiro para o log de
acesso e para o APM.

## Como verificar
```bash
# 1. Rodar o grep da Camada 2 no diff: para cada valor textual do usuário na URL, mostrar
#    onde ele é normalizado e onde é escapado.
# 2. Para cada dado pessoal na URL: justificar no MR por que não vai no corpo/header.
# 3. Conferir que existe teste de igualdade da rota inteira + caso com percent-encoding.
```
