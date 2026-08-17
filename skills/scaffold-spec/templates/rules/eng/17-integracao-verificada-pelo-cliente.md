# Regra 17 — Integração se verifica pelo caminho do cliente

> **3 camadas:** Camada 1 (Princípio) é universal · Camada 2 separa o que cabe ao frontend e ao backend · Camada 3 traz o exemplo que originou a regra. Veja `_layer-guide.md`.

## Camada 1 — Princípio universal (agnóstico)

**Testar o servidor não prova que o cliente funciona.** `curl` numa rota que responde 200
demonstra que *aquela rota* existe — não que o cliente chama *aquela* URL, com aqueles
parâmetros, esperando aquele formato.

Entre os dois há espaço para: caminho base diferente, segmento a mais, maiúscula que
importa, header ausente, campo com outro nome. Todo defeito desse tipo passa por qualquer
suíte de teste unitário dos dois lados, porque cada um está certo isoladamente.

### A verificação que vale
Exercite **o caminho que o usuário percorre**: a tela chamando a API de verdade, ou ao
menos um teste que monte a URL pelo mesmo código que produção usa. Se não der para abrir a
tela, compare explicitamente a URL que o cliente **constrói** com a que o servidor
**expõe** — e diga que foi isso que você verificou, não outra coisa.

### Nunca relate mais do que verificou
"Validado ponta a ponta" e "as rotas respondem 200" são afirmações diferentes. Relatar a
segunda como se fosse a primeira transfere para quem lê uma confiança que ninguém produziu.

### Ligar a integração real revela o que o mock escondia
Seed é sempre pequeno e bem-comportado: costuma caber numa página, não tem acento estranho,
não tem 300 linhas. No dia em que o backend real entra, aparecem os limites que o mock nunca
exercitou. Ao trocar mock por real, **reconfira**: paginação e truncamento, contadores
totais versus contagem da página, volume, caracteres, tempo de resposta.

### Derivado de estado parcial não afirma completude
Se a tela carregou parte dos dados, tudo que deriva disso — contador, exportação, resumo —
precisa dizer que é parcial. Um CSV incompleto com mensagem de sucesso é pior que um erro:
ele vira evidência e ninguém confere de novo.

### Motivação
É o defeito mais caro de encontrar tarde: os dois lados têm teste verde, o build passa, o
review aprova, e a tela nasce quebrada no primeiro clique de quem for usar.

### Exceções aceitas
- Contrato gerado (OpenAPI/gRPC) com cliente compilado a partir do schema: a compilação já
  é a verificação.

## Camada 2 — Preset por camada

### Frontend
```bash
# A URL que o cliente monta bate com a que o servidor expõe?
rg -n "apiBase|baseUrl|concat\('/v" <services-root>     # como o cliente monta
curl -s -o /dev/null -w '%{http_code}\n' "<url-exata-que-o-cliente-monta>"
```
- Teste de service com `HttpTestingController` assertando a **URL literal**, não um prefixo.
- Ao ligar `usarApiReal`/flag equivalente, abrir a tela e percorrer o fluxo principal.

### Backend
- Expor a lista de rotas no boot (log ou endpoint) facilita a conferência do outro lado.
- Mudou rota, verbo ou nome de campo: avise quem consome **no mesmo MR** e cite o MR par.
- Teste de contrato (o cliente real do consumidor, ou um teste de integração que suba os dois)
  vale mais que dois testes unitários verdes.

## Camada 3 — Exemplo concreto

Encontrado em review, depois de o MR já ter passado por várias rodadas:

```
Cliente montava:  apiFinanceiro + '/v1/atualizacoes' + '/planilhas'
Servidor expunha: api/v1/Planilhas

/api/v1/atualizacoes/planilhas  ->  404
/api/v1/Planilhas               ->  200
```

Os testes unitários dos dois lados estavam verdes: o do cliente assertava contra a própria
constante errada, o do servidor contra a rota certa. E o relatório dizia "validado ponta a
ponta com as quatro rotas respondendo 200" — as rotas **do servidor**, verificadas por
`curl`. A tela nunca tinha sido aberta.

## Como verificar
```bash
# 1. Liste as URLs que o cliente constrói e chame cada uma contra o servidor no ar.
# 2. Abra a tela e percorra o fluxo principal com a integração real ligada.
# 3. No relato do MR, escreva exatamente o que foi exercitado.
```
