# Regra 27 — Escrita remota: marca de intenção antes, desfecho honesto depois

> **3 camadas:** Camada 1 (Princípio) é universal · Camada 2 traz o mecanismo por stack ·
> Camada 3 traz o caso que originou a regra. Veja `_layer-guide.md`.
>
> Vizinhas: Regra 19 (transação e ordem), Regra 15 (falha que não some), Regra 20 (flag sem
> consumidor), Regra 13 (o que o status significa).

## Camada 1 — Princípio universal (agnóstico)

Chamada externa que **produz efeito** tem três desfechos, não dois: aplicou, **pode ter
aplicado**, não aplicou. O terceiro é um estado próprio — não sinônimo de falha, não sinônimo de
sucesso — e some do sistema toda vez que alguém o colapsa num dos outros.

### 1. Marca de intenção antes da chamada
Efeito não idempotente exige um registro persistido **antes** do envio dizendo que a tentativa
começou, e ele commita antes da chamada. Sem isso, o processo que cai depois de aplicar o efeito
e antes de gravar o desfecho devolve o item ao estado inicial "virgem", e a próxima execução
reaplica.

### 2. Ambiguidade se resolve no destino, não no chamador
Tempo esgotado, erro de rede, resposta fora do contrato e `5xx` se resolvem com **consulta de
confirmação no destino**. Sem essa consulta, classificar como falha definitiva é chute — e é o
chute caro, porque manda o operador reprocessar o que já foi aplicado.

### 3. A classificação não colapsa desfechos
- Erro de rede ou `5xx` **não** é terminal antes da confirmação.
- Conflito devolvido por chave de idempotência prova que **uma requisição com aquela chave já
  foi recebida** — não que ela foi aplicada. Ele elimina o reenvio, não a confirmação. Tratar
  conflito como sucesso sem confirmar troca um falso negativo por um falso positivo, e o falso
  positivo é o que ninguém investiga.
- "Nada a fazer" (o registro não tem o campo alvo, o catálogo não prevê efeito, o destino já está
  no valor pedido) é um **quarto** resultado; colapsá-lo em "não aplicou" transforma sucesso em
  incidente.

### 4. Cada desfecho declara o estado persistido que produz — com diagnóstico
Antes de escrever a chamada, escreva a matriz: para tempo esgotado, erro de rede, `5xx`, `4xx`,
`200` com corpo fora do contrato e conflito de idempotência, **qual status fica gravado** e
**quem faz a confirmação**. E todo ramo que grava desfecho grava também **o que** aconteceu e
**quem disse**: status de falha sem código e sem mensagem, num desenho sem retentativa
automática, é item morto sem motivo — o operador vê "falhou" e reprocessa às cegas. Matriz que
não fecha é caminho sem tratamento.

### 5. A trilha do efeito é condicionada ao efeito, não ao desfecho final
Se o efeito externo aconteceu, ele é registrado — mesmo que o passo seguinte falhe, mesmo que o
item termine em erro. Amarrar a gravação da trilha ao status final de sucesso produz o pior
estado possível: efeito real aplicado, nenhum registro dele, nenhuma compensação.

Por isso a trilha do efeito remoto **não compartilha transação com o desfecho do item**: ela
commita assim que o efeito é confirmado, e o desfecho commita depois. Isso não afrouxa a
Regra 19 §2 — o que ela exige atômico é o conjunto de escritas **do seu banco** que descrevem o
mesmo fato. Efeito que já aconteceu fora do seu banco não é desfeito por rollback, então
registrá-lo dentro da transação do passo seguinte é escolher perder o registro. Pela mesma
razão, a marca de intenção do item 1 commita **antes** da chamada, fora da transação do desfecho.

### Motivação
Em base regulada o custo aparece dos dois lados: efeito aplicado e não registrado vira
divergência que ninguém explica na auditoria; efeito não aplicado e registrado como falha
definitiva vira retrabalho manual em cima de dado correto. Os dois nascem do mesmo lugar — o
desfecho ambíguo que não tem nome.

### Exceções aceitas
- Efeito naturalmente idempotente, com chave estável e custo de reenvio baixo: o reenvio
  substitui a consulta de confirmação, e isso fica escrito.
- Destino sem qualquer forma de leitura (envio sem retorno, declarado): o estado ambíguo é
  **persistido como ambíguo** e vira fila de conferência humana, nunca terminal silencioso.
- Cancelamento pedido pelo usuário: não é falha, mas grava o estado de cancelado.

## Camada 2 — Preset por stack

| Stack | Onde a ambiguidade nasce | Mecanismo |
|---|---|---|
| C# | `HttpRequestException`, `TaskCanceledException`, tempo esgotado e circuito aberto da política de resiliência | `HttpStatusCode?` nulo = sem resposta; consulta de confirmação em cliente próprio |
| Node-TS | `fetch` rejeitado, `AbortError`, `ECONNRESET` | `AbortController` + releitura no destino |
| Go | `context.DeadlineExceeded`, `net.Error.Timeout()` | releitura com a mesma chave de idempotência |
| Python | `httpx.TimeoutException`, `ReadError` | idem |

```bash
# Status intermediário declarado no enum e nunca escrito: a marca de intenção não existe
find <src-root> -name '*.cs' -not -path '*/obj/*' -print0 \
| xargs -0 grep -nE '<StatusIntermediario>' | grep -vE '(enum|[Tt]ests?/|_test)'

# Ausência de resposta indo direto para terminal
find <src-root> -name '*.cs' -print0 \
| xargs -0 grep -nE 'statusHttp is null|StatusCode == null|IsTimeout|TaskCanceled'

# Ramo terminal: localizar e inspecionar o bloco (não filtre por pipe — veja o bloco inteiro)
find <src-root> -name '*.cs' -print0 \
| xargs -0 grep -nE 'Status *= *[A-Za-z_.]*(Falha|Erro|Failed)'
sed -n '<linha>,+6p' <arquivo>     # tem CodErro e Mensagem?
```

## Camada 3 — Exemplo concreto

Num backend de atualização de apólice em lote, o classificador mandava
`houveErroRede || statusHttp is null` e `>= 500` direto para falha técnica **terminal**, sem
confirmação: o item encerrava, o sistema de destino nunca era atualizado e a trilha não era
gravada. Os resultados "campo alvo nulo", "catálogo sem efeito para o slug" e "nada a atribuir"
colapsavam todos em `Aplicado = false`, indistinguíveis de falha real. Quando o outro sistema não
aplicava e não devolvia código, o item ia para falha definitiva com código, tipo e mensagem
nulos.

O status intermediário existia no enum e **nenhuma das 12 escritas** o gravava: o item cuja
gravação de desfecho falhasse voltava ao estado inicial e o próximo disparo reaplicava o prêmio.
E a gravação da trilha estava condicionada a `novoStatus == Concluido`, enquanto o efeito
financeiro já tinha sido aplicado dezenas de linhas antes — falha no passo seguinte deixava
efeito real sem registro e sem compensação, com a suíte contendo testes que **fixavam** essa
ausência. O caso irmão, do parâmetro de confirmação fixo em `false` que transformava conflito de
idempotência em falha definitiva, está na Camada 3 da Regra 20.

## Como verificar
```bash
# 1. Para cada chamada com efeito: a matriz (tempo esgotado, rede, 5xx, 4xx, 200 fora do
#    contrato, conflito) → estado persistido + código + mensagem → quem confirma.
# 2. Grepar o enum de status por valores declarados e nunca escritos.
# 3. Mostrar onde a marca de intenção commita, e que é antes da chamada.
# 4. Mostrar onde a trilha do efeito commita, e que é independente do desfecho do passo seguinte.
# 5. Teste que redespacha o mesmo item duas vezes e prova efeito único.
# 6. Teste que simula queda entre o efeito remoto e a gravação do desfecho.
# 7. Grepar testes que assertam AUSÊNCIA de trilha — cada um exige justificativa escrita.
```
