# Regra 15 — Nenhuma falha desaparece em silêncio

> **3 camadas:** Camada 1 (Princípio) é universal · Camada 2 traz o mecanismo por stack · Camada 3 traz o exemplo que originou a regra. Veja `_layer-guide.md`.

## Camada 1 — Princípio universal (agnóstico)

**Erro engolido é pior que erro que estoura.** Quando uma falha some sem sinal, a interface
continua exibindo o último estado bom e o usuário decide em cima de informação velha —
achando que decide em cima da atual.

As formas em que isso costuma aparecer:

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

### 6. Ausência indistinguível do valor esperado

Ausência de dado é informação. Quando ela vira um valor plausível, some — e some justamente no
ponto que decide algo.

- **Antes de escolher o padrão, descubra o que produz a ausência.** Campo nulo raramente é
  "opcional": costuma ser sintoma — divergência entre a semente do banco e o enum do código,
  origem que não expõe o dado. Nenhum padrão corrige isso, nem o permissivo nem o barulhento.
- **O padrão nunca é o valor que desliga a verificação que depende dele.** Derivar "é terminal"
  de um campo ausente como falso faz um registro já concluído se reportar como não concluído e
  mata o acompanhamento; preencher um total ausente com a quantidade já carregada torna "a lista
  está truncada" vacuamente falso. Escolha o padrão que degrada para o lado **barulhento**, e
  prove com o caso que inverte o valor.
- **Existe uma família de leitura-por-nome em que ausência devolve o valor certo.** Busca que
  nunca lança — mapa com criação implícita, leitura de configuração nomeada, obtenção com padrão
  — devolve para o nome correto, para o nome com erro de digitação e para um nome inventado
  exatamente a mesma coisa, que costuma ser o que o teste asserta. Se o vínculo é por nome, o
  teste prova que o nome **errado** falha (Regra 28).
- **O valor zero de um enum de classificação cai no ramo conservador**, porque é ele que todo
  caminho novo herda por esquecimento.
- **Degradação bem-sucedida sem registro é degradação permanente.** Calcular localmente o que
  deveria vir da origem conserta a tela e esconde para sempre o dado faltando na origem. O aviso
  que nomeia o identificador e o valor faltante é o que torna a origem consertável.

**Exceção:** campo declaradamente opcional cujo padrão é regra de negócio escrita — e aí o padrão
tem nome (`SemPrazoConfigurado`), não é literal solto no ponto de leitura. Coleção vazia como
padrão de leitura, quando vazio e ausente são indistinguíveis para o consumidor.

### 7. O tratamento tem alcance e alvo

As formas acima assumem que o erro **chega** ao handler. Cinco maneiras de ele não chegar — ou de
chegar ao handler errado:

- **Escopo.** O bloco protegido vai do envio até o **consumo do corpo**. Cobrir só a chamada de
  rede e deixar a desserialização de fora faz um `200` com conteúdo de erro de gateway escapar do
  tratamento inteiro. Quando um irmão no mesmo repositório já faz certo, a divergência é a
  evidência (Regra 21).
- **Tipo.** Capturar a exceção da camada de driver não cobre a que a materialização lança;
  capturar a de rede não cobre as que uma política de resiliência **interposta** passa a lançar.
  Ligar resiliência é uma linha no arquivo de composição que troca o conjunto de tipos que chegam
  ao `catch` — e desliga em silêncio o tratamento que o mesmo lote acabou de criar, com a suíte
  verde porque os dublês continuam lançando os tipos antigos. No mesmo commit em que se interpõe
  a camada, todo `catch` a jusante é reconferido; quando a camada interna não pode enxergar os
  tipos da biblioteca interposta, a tradução vira um componente do pipeline (Regra 28).
- **Alvo.** Capturar o tipo errado troca desfecho de negócio por acidente: exceção não prevista
  que converte "conflito de estado" em "resultado desconhecido" muda a decisão do operador sem
  deixar rastro.
- **Expressão que lança fora do bloco.** Valor padrão de parâmetro, inicializador de campo e
  argumento montado antes da chamada são avaliados **fora** do tratamento — nenhum handler os
  alcança. Pior quando dependem de capacidade do ambiente (contexto seguro, permissão,
  armazenamento local): rodam inclusive no modo de dados simulados, porque o que é avaliado antes
  da bifurcação não é isolado por nenhuma flag.
- **A liberação acontece mesmo sem handler.** Bloqueio de tela, conexão e recurso são liberados no
  caminho final, não no ramo de sucesso nem no par de handlers — o terceiro caminho não tem
  handler.

**Exceção:** bloco estreito de propósito, com o tipo capturado dito pelo nome do método que o
traduz e os demais tratados uma camada acima — desde que essa camada exista e esteja apontada no
MR. Código que roda antes do pipeline por exigência da plataforma (bootstrap): aí o tratamento é
falha rápida na subida, com mensagem que nomeia a configuração.

### 8. O inverso: log de incidente é contrato

Esta regra cobre a falha que some. A falha **duplicada e desinformativa** custa igual, do outro
lado: alerta que dispara em dobro deixa de ser lido.

- **Uma falha, uma entrada de nível de incidente.** Centralizar o tratamento num manipulador
  global sem remover o registro do ponto anterior produz duas entradas com rastro de pilha por
  falha, inclusive para `400` e `404`, que são erro de cliente e nem incidente são — e dobra a
  taxa de erro do serviço no painel.
- **Quem registra em nível de incidente é quem sabe o desfecho final.** A correção reposiciona,
  não apaga: a camada de fora registra em nível informativo o escopo que só ela conhece (qual
  endpoint, qual operação), sem passar a exceção; a entrada de incidente fica com quem sabe
  status resolvido, identificador de rastreio e caminho.
- **Toda tradução de valor na borda registra o par (original, enviado).** Ao traduzir um status,
  registrar só o traduzido cega a investigação exatamente no caso classificado como incidente
  próprio, que é o único em que alguém vai olhar.
- **Corpo de resposta de integração fica no log — e não vai para a resposta.** O invariante de PII
  em `seguranca.md` fecha o log; a outra ponta é o corpo do erro que você devolve ao cliente.

Nível e contagem travam por teste: o teste asserta **quantas** entradas e **em que nível** — não o
texto.

**Exceção:** registro repetido em níveis baixos (informativo, depuração) com finalidade de
escopo; e nova entrada emitida por uma camada de retentativa que acrescenta o desfecho da série
(número de tentativas, decisão final).

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

# Padrão silencioso sobre valor que alimenta decisão
find <src-root> -type f \( -name '*.cs' -o -name '*.ts' \) -print0 \
| xargs -0 grep -nE '\?\? *(false|true|0|\[\]|new )|GetValueOrDefault\(|TryGetValue|getOrDefault'

# Qual membro do enum é o zero (o que todo caminho novo herda)
find <src-root> -name '*.cs' -print0 | xargs -0 grep -nA3 'enum [A-Za-z]+'

# Expressão executável em valor padrão de parâmetro / inicializador
find <src-root> -type f \( -name '*.cs' -o -name '*.ts' \) -print0 \
| xargs -0 grep -nE '[A-Za-z_]+ *= *[A-Za-z_.]+\(\) *[,)]|crypto\.|localStorage|navigator\.|new URL\('

# Bloqueio de UI sem liberação no caminho final
find <src-root> -name '*.ts' -print0 \
| xargs -0 grep -nE 'setLoading\(true\)|\.set\(true\)|block\(\)|start\(\)'
find <src-root> -name '*.ts' -print0 | xargs -0 grep -nE 'finally|finalize\('

# Tipos que passam a chegar depois de interpor resiliência/interceptador
find <src-root> -type f -print0 \
| xargs -0 grep -nE 'AddResilience|AddPolicyHandler|DelegatingHandler|addInterceptor'

# Mesma falha registrada em mais de uma camada
find <src-root> -type f -print0 \
| xargs -0 grep -nE 'LogError|LogCritical|logger\.error|logger\.exception|log\.Error'
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
