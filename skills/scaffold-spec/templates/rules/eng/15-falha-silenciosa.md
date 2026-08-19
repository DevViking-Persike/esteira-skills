# Regra 15 — Nenhuma falha desaparece em silêncio

> **3 camadas:** Camada 1 (Princípio) é universal · Camada 2 traz o mecanismo por stack · Camada 3 traz o exemplo que originou a regra. Veja `_layer-guide.md`.

## Camada 1 — Princípio universal (agnóstico)

**Erro engolido é pior que erro que estoura.** Quando uma falha some sem sinal, a interface
continua exibindo o último estado bom e o usuário decide em cima de informação velha —
achando que decide em cima da atual.

Os três formatos em que isso costuma aparecer:

### 1. Handler de erro vazio
`catch {}`, `error: () => {}`, `.catch(() => null)`. Se não há o que fazer com o erro, ainda
há o que fazer com o **estado**: recarregar do servidor, marcar como desconhecido, liberar o
bloqueio de tela. O que não pode é seguir como se nada tivesse acontecido.

### 2. Confirmação antes da confirmação
Avisar sucesso sem esperar a operação assíncrona resolver. O toast dispara, a operação
falha, e a interface mente. Prometa depois que a `Promise`/`Task` resolveu — e trate o
caminho de rejeição.

### 3. Capacidade ausente tratada como sucesso
Optional chaining sobre API que pode não existir (`navigator?.clipboard?.write?.()`) vira
no-op silencioso: o código segue como se tivesse funcionado. Se a capacidade não existe,
**degrade explicitamente** e diga ao usuário.

### 4. Handler que só loga

`catch` que registra o erro e **retorna como se tivesse dado certo** é falha silenciosa com
comprovante: existe log, e ainda assim o chamador reporta sucesso. Logar não é tratar. Em
qualquer caminho cujo retorno outro componente lê como sucesso — publicar na fila, enfileirar,
enviar, confirmar — ou **repropaga**, ou **grava estado de falha** no recurso afetado. Nunca
deixa o registro pendente sem sinal, esperando um operador que não foi avisado.

Cancelamento pedido pelo usuário não é falha: repropague-o como cancelamento, sem marcar erro.

### 5. Falha que aparece ilegível

Meio-silêncio conta: a exceção sobe, mas a mensagem sai invertida ou truncada exatamente no
cenário em que alguém precisa lê-la. O caso clássico é usar o construtor de um argumento de
uma exceção cujo primeiro parâmetro é o **nome do parâmetro**, e não a mensagem — a saída vira
`Value cannot be null. (Parameter '<a sua mensagem>')`. Para configuração ausente ou estado
inválido, use a exceção de estado inválido com a mensagem inteira; e **asserte a mensagem no
teste**, não só o tipo, senão o mutante que reintroduz o construtor errado sobrevive.

### Em polling e retry
Um ciclo que falha não deve notificar a cada tick — vira spam pior que o problema. Mas
também não pode congelar: no erro, **reconcilie** buscando o estado real do servidor. Isso
recupera inclusive o caso em que a operação terminou enquanto o polling estava cego.

### Motivação
Falha visível custa um alerta. Falha silenciosa custa uma decisão errada, tomada por alguém
que confiou na tela — e ninguém descobre pelo log, porque não houve log.

### Exceções aceitas
- Telemetria e métrica best-effort: não derrube fluxo de negócio por falha de envio de
  métrica (mas registre em nível baixo).
- Cancelamento esperado (usuário saiu da tela, token cancelado) — não é falha.

## Camada 2 — Preset por stack

| Stack | Onde procurar |
|---|---|
| C# | `catch { }` e `catch (Exception) { }` sem log nem rethrow; `async void`; `Task` sem `await` |
| Node-TS | `.catch(() => {})`, `catch {}`, promise sem `await` nem `.catch` |
| Angular/RxJS | `error: () => {}` no `subscribe`; `catchError(() => of(null))` sem tratar estado |
| React | `useEffect` com promise sem `.catch`; estado de erro nunca renderizado |
| Go | `_ = err`, `if err != nil {}` vazio |
| qualquer | `catch` que só loga num caminho cujo retorno é lido como sucesso |
| qualquer | exceção de argumento recebendo mensagem no slot de `paramName` |

```bash
# Handlers vazios — cada achado exige justificativa
rg -n 'catch\s*\{\s*\}|catch\s*\([^)]*\)\s*\{\s*\}|error:\s*\(\)\s*=>\s*\{\s*\}' <root>
```

## Camada 3 — Exemplo concreto

Encontrado em review, dois no mesmo componente:

```typescript
// Ruim — polling que falha congela a linha em PROCESSANDO para sempre
.subscribe({ next: (s) => this.aplicar(s), error: () => {} });

// Bom — no erro, reconcilia com o servidor
.subscribe({ next: (s) => this.aplicar(s), error: () => this.carregarPlanilhas() });
```

```typescript
// Ruim — avisa sucesso sem esperar, e vira no-op silencioso sem clipboard
navigator?.clipboard?.writeText?.(hash);
this.alerta.info('Hash copiado.');

// Bom — promete depois de resolver, e degrada quando a capacidade não existe
const escrita = navigator?.clipboard?.writeText?.(hash);
if (!escrita) return this.alerta.warning('Área de transferência indisponível.');
escrita.then(() => this.alerta.info('Hash copiado.'))
       .catch(() => this.alerta.warning('Não foi possível copiar.'));
```

## Como verificar
```bash
# Rodar o grep da Camada 2 no diff do PR. Saída esperada: vazia.
```
