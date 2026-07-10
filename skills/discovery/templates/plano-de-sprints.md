# Plano de Sprints NN — <tema> `[DISCOVERY · FAN-IN]`

> Consolidação (fan-in) da rodada de discovery: transforma os artefatos dos modos
> rodados (`.negocio.md` / `.dev.md` / `.refatoracao.md`) num backlog fatiado de
> sprints. **Gate de saída bloqueante:** só com este plano **aprovado pelo
> usuário** abre a 1ª Arquitetura (gate 10). Artefato canônico:
> `.spec/discovery/plano-de-sprints-NN.md`.
>
> No njord, cada linha vira uma **run** iniciada no entry_point `arquitetura`
> (reaproveitando os artefatos do discovery compartilhado) — zero mudança de
> domínio para "N sprints".

## Rodada de discovery (origem)
- **Modos rodados:** <negocio / dev / refatoracao — na ordem canônica>
- **Artefatos-fonte:** <lista dos `.spec/discovery/discovery-NN-<tema>.<modo>.md>`
- **scaffold-mode base:** <criar / refatorar / documentar>

## Backlog de sprints derivados

> Numeração: **NN fresco** por sprint derivado (não `NN.M`). A coluna
> `discoveries-fonte` rastreia a rodada de origem. `scaffold-mode` = como executar
> cada sprint (criar/refatorar/documentar). `ordem` fixa a sequência de execução.
> Sprint entregue **fora da esteira** (manual): marque `✅` na célula NN
> (`| NN ✅ |`) — a aba Planos deriva "Entregue", bloqueia re-disparo e
> destrava quem depende dele.

| NN | scaffold-mode | ACs do sprint | discoveries-fonte | depende-de | ordem |
|---|---|---|---|---|---|
| <NN> | <criar\|refatorar\|documentar> | <ACs verificáveis do incremento> | <negocio\|dev\|refat + arquivo> | <NN ou —> | <1> |
| <NN> | <...> | <...> | <...> | <...> | <2> |

## Notas de sequenciamento
- **Dependências:** <o que precisa entrar antes de quê e por quê>
- **Riscos de ordem:** <acoplamentos que forçam a sequência>

## DoD do Plano de Sprints (gate de saída da Discovery)
- [ ] Todo sprint tem **ACs verificáveis** + `scaffold-mode`
- [ ] Toda linha aponta seu `discoveries-fonte`
- [ ] Dependências e ordem coerentes (sem ciclo)
- [ ] **Aprovado pelo usuário** (gate bloqueante) → libera a 1ª Arquitetura
