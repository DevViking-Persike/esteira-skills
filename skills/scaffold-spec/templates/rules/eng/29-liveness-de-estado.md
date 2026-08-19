# Regra 29 — Máquina de estados persistida prova liveness

> **3 camadas:** Camada 1 (Princípio) é universal · Camada 2 traz o mecanismo por stack ·
> Camada 3 traz o caso que originou a regra. Veja `_layer-guide.md`.
>
> Vizinhas: Regra 19 (gravação condicional do agregado), Regra 21 (o ciclo de vida deriva da
> tabela de transições), Regra 15 (o `catch` que esquece).

## Camada 1 — Princípio universal (agnóstico)

Toda máquina de estados persistida prova duas coisas, e nenhuma é provada por teste de transição
isolada:

1. **De todo estado alcançável existe caminho para um estado terminal.** Estado sem saída não dá
   erro: ele fica, e o registro some do fluxo operacional para sempre.
2. **Todo caminho de saída do processamento reconcilia o agregado** — inclusive o de exceção, o
   de cancelamento e o de retorno antecipado. O caminho feliz sempre reconcilia; é o `catch` que
   esquece.

### Estado inicial também precisa de saída
Registro que nasce num estado cujo gatilho de avanço tem uma guarda que ele nunca satisfaz é o
caso mais silencioso de todos: entra no sistema e nunca é processado, sem uma linha de log. Ao
criar um estado inicial, prove que **existe** entrada válida para o gatilho.

### O estado agregado tem um dono só
Estado derivado de outros registros é gravado por **um** ponto. Quando a gravação aparece em dois
lugares "por segurança", ela custa leitura em ordem quadrática e disputa de concorrência — e a
redundância normalmente existe porque o ponto correto está dentro de um bloco que engole o erro.
Conserte o silêncio primeiro (Regra 15); a duplicata cai sozinha depois.

### Motivação
Num desenho sem retentativa automática, estado sem saída é definitivo. O registro fica pendurado,
o lote nunca fecha, o painel mostra "processando" indefinidamente e a única recuperação é
intervenção manual em banco — exatamente o que ninguém quer autorizar em base regulada.

### Exceções aceitas
- Estado de repouso deliberado, à espera de evento externo, com o gatilho nomeado e um monitor de
  tempo de permanência.
- Estado terminal de erro que exige ação humana, desde que exposto numa consulta operacional
  nomeada no MR e com dono nomeado.

## Camada 2 — Preset por stack

| Stack | Prova de liveness | Prova de reconciliação |
|---|---|---|
| C# | `[Theory]` sobre `Enum.GetValues` percorrendo a tabela de transições até terminal | teste que força exceção no meio e asserta o estado do agregado |
| Node-TS | `it.each(Object.values(Status))` | dublê que lança e asserta o agregado |
| Python | `@pytest.mark.parametrize` sobre o enum | idem |
| Go | tabela de casos sobre as constantes do tipo | idem |

```bash
# Pontos de saída do processamento
find <application-root> -name '*.cs' -print0 \
| xargs -0 grep -nE 'return |throw |catch |OperationCanceled'

# Gravação do estado agregado em mais de um lugar
find <src-root> -name '*.cs' -print0 \
| xargs -0 grep -nE 'Reconciliar|RecalcularStatus|AtualizarStatus[A-Za-z]*Agregad'
```

## Camada 3 — Exemplo concreto

Num processamento de planilha em lote, o caminho de sucesso reconciliava o status do lote e o de
exceção não: o método que marcava o item como "resultado desconhecido" gravava o item e devolvia.
Como esse estado **não é terminal** e o agregador devolve "processando" enquanto houver item não
terminal, uma exceção técnica travava o lote para sempre num desenho sem retentativa.

No mesmo fluxo, planilha com zero linhas válidas e sem erro de layout nascia no estado de fila, e
a guarda do enfileiramento exigia justamente linhas válidas maiores que zero: estado inicial sem
saída, criado no ato do registro. E a reconciliação rodava por item **e** ao fim do lote —
redundância cara que ninguém podia remover, porque a chamada final estava dentro de um bloco que
só registrava o erro.

## Como verificar
```bash
# 1. Teste que, para cada valor do enum de status, prova existir caminho até terminal.
# 2. Listar os pontos de saída (retorno, catch, cancelamento) e conferir que todos reconciliam.
# 3. Um único ponto grava o estado agregado; se houver dois, procurar o handler silencioso.
# 4. Todo estado inicial tem entrada válida comprovada para o gatilho de avanço.
```
