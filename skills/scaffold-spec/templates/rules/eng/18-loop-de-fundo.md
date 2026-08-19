# Regra 18 — Loop de fundo é feature, não detalhe

> **Camada predominante: frontend** (polling de tela, auto-refresh), mas vale para qualquer
> laço periódico — worker, job, retry de client. Veja `_layer-guide.md`.

## Camada 1 — Princípio universal (agnóstico)

Adicionar polling, auto-refresh ou retry periódico parece três linhas e é uma feature
inteira. Antes de escrever a primeira, responda **as doze**:

**0. Quem dispara?** O laço nasce do **estado observado**, não da ação que originou o estado.
Acompanhamento que só começa depois da ação do usuário deixa congelada toda linha não-terminal
que já estava lá quando a tela abriu, inclusive a criada por outra pessoa — que, numa tela cuja
função é acompanhar processamento, é o caso principal, não a exceção.

1. **Condição de parada.** O que faz o laço terminar? Se a resposta é "quando o estado
   mudar", o que acontece se ele nunca mudar?
2. **Teto.** Quantos ciclos, ou por quanto tempo, no máximo? Sem teto, um item preso
   martela o servidor para sempre.
3. **Backoff.** O intervalo cresce? Até quanto?
4. **Aba/processo em segundo plano.** Pausa? E ao voltar, retoma ou já morreu?
5. **Ação do usuário no meio.** Um clique manual concorre, é engolido, ou reinicia o laço?
6. **Concorrência.** Existe outro laço acompanhando a mesma coisa? Quem é a fonte de
   verdade?
7. **Efeitos colaterais do que você reaproveitou.** O método reusado dispara overlay,
   reseta estado, notifica, reordena?
8. **Caminho de erro.** Ele recebeu o mesmo tratamento do caminho de sucesso? Falha
   transitória durante o laço não pode apagar o que está na tela, nem alertar o usuário
   sobre algo que ele não pediu, nem fazer o laço desistir.
9. **Fan-out.** Acompanhar N itens é **um** laço sobre a coleção, não N laços por item. A versão
   por item multiplica as requisições por ciclo e ainda perde a linha que apareceu no intervalo.
10. **Precedência.** Guarda de reentrância compartilhada entre o laço de fundo e a ação do usuário
    cede **sempre** à ação do usuário. Um retorno antecipado por "já estou carregando" engole o
    clique manual sem erro, sem indicador e sem log — o usuário clica de novo, e nada acontece de
    novo.
11. **Isolamento por iteração.** Laço sobre N recursos independentes isola o erro de cada um, e o
    isolamento vale **no caminho de exceção**: se o processamento cria escopo, conexão ou sessão
    por item para não compartilhar estado, o tratamento de falha não pode gravar pela dependência
    resolvida no escopo de fora — sessão com estado mutável compartilhada entre duas falhas
    simultâneas produz corrupção, erro de recurso em uso, ou item sem marcação nenhuma, com
    sintoma diferente a cada execução. E trocar o paralelo por um laço serial depois da junção só
    muda o modo de falha: uma falha transitória no item k deixa k+1..N sem marcação, sem código de
    erro e invisíveis para a consulta operacional que existe para achá-los. Cada iteração trata o
    próprio erro; cancelamento continua propagando, falha de item não.

O item que fica sem marcação é o pior desfecho: não está pendente, não está concluído e não
aparece na consulta de falhas — só reaparece quando alguém confere o total, normalmente o cliente.

### Silenciar pela metade
Se o laço tem "modo silencioso", ele vale para **todos** os desfechos. Silenciar só o
sucesso deixa o erro barulhento e destrutivo justamente onde ninguém está olhando — e o
efeito composto costuma ser pior que a soma: lista apagada + estado vazio exibido +
nenhuma linha "em andamento" para reagendar = laço morto sem aviso.

### O erro que mais custa: reaproveitar sem inventariar
Reusar a função de carregamento inicial no laço traz junto **tudo** que ela faz. Bloqueio
de tela vira flash a cada ciclo; substituir a lista descarta a ordenação que o usuário
escolheu; resetar filtro apaga o que ele digitou. Antes de reusar, leia a função inteira e
liste os efeitos — não só o que você quer dela.

### Pausa que não pausa
Se o laço "pula" o ciclo em segundo plano mas ainda assim consome orçamento e avança o
backoff, ele não pausou: penalizou justamente a sessão ativa, que volta e encontra o
acompanhamento morto ou lento. Ciclo que não buscou não conta.

### Motivação
Nenhum desses defeitos aparece em teste unitário nem em revisão rápida: o laço "funciona".
Aparece em produção como martelada no backend, tela piscando, ordenação que volta sozinha e
lista que congelou sem ninguém saber por quê.

### Exceções aceitas
- Laço de infraestrutura com supervisão própria (consumer de fila, scheduler), onde o teto
  e o backoff vivem na plataforma.
- Laço de passo único dispensa as perguntas 9 e 11; laço sem interface associada dispensa a 10.
- Falha que invalida o lote inteiro por regra de negócio encerra explicitamente, com **todos**
  os itens recebendo o mesmo desfecho registrado.

## Camada 2 — Preset por camada

### Frontend
```bash
# Laços sem teto aparente; e quem dispara: o gatilho cobre todo estado não-terminal visível,
# ou só o desta sessão?
find <src-root> -name '*.ts' -print0 \
| xargs -0 grep -nE 'setInterval\(|setTimeout\(|interval\(|timer\('

# Fan-out por elemento (um laço por item, em vez de um laço sobre a coleção)
find <src-root> -name '*.ts' -print0 \
| xargs -0 grep -nA3 -E 'forEach\(|for \(const [A-Za-z]+ of'

# Guarda compartilhada engolindo a ação do usuário
find <src-root> -name '*.ts' -print0 \
| xargs -0 grep -nE 'if \((this\.)?(estaCarregando|isLoading|carregando|_processando)'
```
- Amarre ao ciclo de vida (`takeUntilDestroyed`, `AbortController`, `clearInterval` no unmount).
- Respeite `document.hidden` **sem** consumir o orçamento do laço.
- Reaplique estado do usuário (ordenação, seleção, filtro) depois de recarregar.
- Refresh automático não dispara indicador de carregamento bloqueante.

### Backend
- Retry com teto e backoff exponencial; jitter quando há muitas instâncias.
- Idempotência antes de repetir.
- Distinga erro transitório (repete) de definitivo (não repete).
- Laço sobre N recursos independentes trata o erro **dentro** de cada iteração, com escopo e
  sessão próprios; o tratamento de fora não grava pela dependência resolvida no escopo externo.

```bash
# Tratamento de erro dentro de laço concorrente usando dependência resolvida fora da iteração
find <backend-root> -name '*.<ext>' -print0 \
| xargs -0 grep -nB10 -E 'Parallel\.|WhenAll|allSettled|gather'
```

## Camada 3 — Exemplo concreto

Um auto-refresh de lista precisou de **quatro rodadas de review** — cada correção expondo a
próxima:

| Rodada | Defeito |
|---|---|
| 1 | reusou o carregamento inicial: overlay de tela cheia piscando a cada 2,5 s |
| 2 | resubstituía a lista: a ordenação escolhida pelo usuário voltava sozinha |
| 3 | sem condição de parada: com uma linha presa, pedia a lista para sempre |
| 4 | a "pausa" em aba oculta consumia o teto e acelerava o backoff |
| 5 | o modo silencioso valia só no sucesso: um blip de rede apagava a lista, alertava sem ser pedido e matava o laço |

Nenhuma foi pega por teste unitário: em todas as cinco a suíte estava verde.

## Como verificar
```bash
# Para cada laço novo, responder por escrito as doze perguntas da Camada 1 no MR.
```
O teste que pega o defeito de isolamento **mede escritas em voo** (máximo simultâneo por sessão
obrigatório = 1); assert de estado final não o enxerga.
