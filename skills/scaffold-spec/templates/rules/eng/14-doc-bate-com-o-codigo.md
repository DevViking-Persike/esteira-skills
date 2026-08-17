# Regra 14 — Documentação de contrato bate com o código entregue

> **3 camadas:** Camada 1 (Princípio) é universal · Camada 2 lista o que verificar por stack · Camada 3 traz o exemplo que originou a regra. Veja `_layer-guide.md`.

## Camada 1 — Princípio universal (agnóstico)

**Documento que descreve contrato é código de integração de outra equipe.** Rota, verbo,
nome de DTO, porta, header obrigatório ou opcional, código de status: se está escrito e não
bate com o que foi entregue, alguém vai integrar contra o texto e quebrar em runtime.

O erro não avisa. O `README` não compila, não tem teste, e continua verde para sempre
descrevendo um sistema que nunca existiu.

### Regra prática
No mesmo commit em que a rota, o DTO ou a porta muda, **o documento que os cita muda junto**.
Se não der para atualizar agora, o trecho é marcado explicitamente como
**"contrato-alvo, ainda não implementado"** — nunca deixado como se fosse a realidade.

### O que sempre confere antes de abrir o MR
- rota e verbo de cada endpoint citado
- nome de controller, de serviço e de DTO citados
- porta de fallback de ambiente local
- header/parâmetro descrito como obrigatório: **é mesmo?**
- código de status prometido para cada caminho de erro

### Motivação
Doc de contrato desatualizada custa mais que doc ausente. Sem doc, o integrador lê o
código; com doc errada, ele confia e erra. Foi assim que uma tabela de endpoints apontou
o frontend para URLs inexistentes num MR que passou em todos os testes.

### Exceções aceitas
- Documento explicitamente histórico ou de decisão, datado (registra o que se decidiu à
  época, não o que existe hoje).
- Seção marcada como proposta/alvo, com o rótulo visível na própria seção.

## Camada 2 — O que verificar por stack

| Stack | Fonte da verdade a conferir contra o doc |
|---|---|
| C# / ASP.NET | atributos `[Route]`, `[HttpGet]`/`[HttpPost]`, nomes de `*Response`/`*Request`, fallbacks em `HttpClientExtensions` |
| Node-TS | definição de rotas do router, schemas de validação, `baseURL` dos clients |
| Angular/React | serviços de API, tokens de configuração, `environment*.ts` |
| Terraform | nomes de recurso e de variável de saída citados no README do módulo |

```bash
# Rotas citadas no doc que não existem no código (C#)
rg -o 'api/v[0-9]+/[A-Za-z/{}._-]+' README.md | sort -u > /tmp/doc-rotas
rg -oh 'Route\("([^"]+)"\)' -r '$1' <controllers-root> | sort -u > /tmp/cod-rotas
comm -23 /tmp/doc-rotas /tmp/cod-rotas   # saída esperada: vazia
```

## Camada 3 — Exemplo concreto

Encontrado em review no BFF de gestão financeira. O README descrevia:

| README dizia | Código entregava |
|---|---|
| `AtualizacaoLoteController`, base `api/v1/atualizacoes` | `ImportacaoController` (`api/v1/Importacao`) + `PlanilhasController` (`api/v1/Planilhas`) |
| `LoteStatusResponse`, `LotesPaginadosResponse` | `PlanilhaStatusResponse`, `PlanilhasPaginadosResponse` |
| fallback local `5103` / `5102` | `5182` / `5181` |
| headers **obrigatórios**, ausência = `400` | **opcionais**, servidor deriva o default |

Quatro divergências num único documento, todas capazes de fazer um integrador errar — e
nenhum teste falharia por causa delas.

## Como verificar
```bash
# Antes de abrir o MR: para cada rota, DTO, porta e header citados no doc tocado,
# confirmar a existência no código. O grep da Camada 2 automatiza a parte de rotas.
```
