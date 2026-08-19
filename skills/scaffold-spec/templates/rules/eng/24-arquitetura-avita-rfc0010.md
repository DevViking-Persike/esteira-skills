# Regra 24 — Arquitetura Avita (RFC-0010) vence a genérica

> **3 camadas:** Camada 1 (Princípio) é universal · Camada 2 traz o preset .NET da Avita ·
> Camada 3 traz o caso que originou a regra. Veja `_layer-guide.md`.

## Camada 1 — Princípio universal (agnóstico)

Quando a organização publica um **padrão de arquitetura próprio**, ele é a convenção da casa
e **vence a regra genérica** naquilo que é escolha de arranjo: onde cada tipo de arquivo
mora, como se chama, qual projeto referencia qual.

A regra genérica continua valendo no que é **invariante de engenharia** — fluxo de
dependência apontando para dentro, domínio sem framework, ausência de ciclo. Padrão de casa
não autoriza domínio importando HTTP.

### Por que a precedência importa
Sem ela, cada review vira opinião contra opinião: o revisor cita a convenção interna, o
agente cita o princípio universal, e a discussão não fecha porque **os dois estão certos em
planos diferentes**. Declarar quem vence em qual plano encerra a disputa por escrito.

### Como decidir na hora
1. O ponto em disputa é **arranjo** (pasta, nome, sufixo, projeto)? → padrão da casa vence.
2. É **direção de dependência** ou **acoplamento a framework**? → invariante vence, sempre.
3. O padrão da casa **contradiz** um invariante? → não silencie: registre a divergência no MR
   e escale. Não escolha sozinho.

### Teste de arquitetura cita a fonte que ele trava

A Regra 22 manda transformar convenção corrigida em teste de arquitetura. Falta dizer o que o
teste carrega: **a fonte da decisão que ele reflete** — no nome do método ou na mensagem de falha,
apontando o documento ou o projeto de referência da casa.

Sem isso, o teste verde ganha cara de invariante organizacional quando é, no máximo, a opinião de
quem o escreveu — muitas vezes no mesmo trabalho, para travar exatamente o ponto em disputa. E aí
ele **inverte o ônus da prova contra a convenção da casa**: quem pede a convenção passa a ter que
derrubar um teste.

Corolário para a disputa: **quem invoca o padrão da casa é quem aponta o arquivo.** O pedido
certo, dos dois lados, é "me aponta o projeto de referência", não mais um argumento de princípio
(Regra 26). Um caso real fechou em uma mensagem, com o link do arquivo de composição de um serviço
de referência, depois de três mensagens longas discutindo direção de dependência: o padrão da casa
permitia a dependência exatamente para o registro de DI, e o teste que a proibia era mais novo que
a discussão.

**Exceção:** teste que trava um invariante de engenharia (domínio sem framework, ausência de
ciclo) — a fonte é a Regra 04, e citá-la basta.

### Exceções aceitas
- Padrão da casa desatualizado em relação à lib que ele mesmo manda usar (ex.: template ainda
  traz um controller que a lib de bootstrap passou a fornecer). Aí o pedido de review que
  remove a redundância é legítimo — cite a lib e a versão.

## Camada 2 — Preset .NET (Avita, RFC-0010)

Fonte canônica: skill `avt-api-dotnet`, `references/project-structure.md`.

**Onde cada coisa mora:**

| Tipo | Projeto/pasta |
|---|---|
| Mapeamento entre representações | `Application/Mappers/` |
| Serviço de aplicação | `Application/Services/` |
| DTO, validator | `Application/DTOs/`, `Application/Validators/` |
| Port de repositório e de serviço | `Domain/Interfaces/{Repositories,Services}/` |
| Implementação de repositório | `Infrastructure/Data/Repositories/` |
| Adapter de API externa | `Infrastructure/ExternalServices/` |
| Registro de DI do projeto | `Api/Extensions/ServiceExtension.cs` |
| HttpClients com resiliência | `Api/Extensions/HttpExtension.cs` |

**Grafo de dependências:**
```
Api --> Application --> Domain
                   --> Infrastructure --> Domain
Domain --> (nenhuma dependência de projeto)
Application --> Infrastructure  (apenas para registro de DI)
```

**Nomenclatura:** a classe declara o que é no sufixo. Serviço termina em `Service`.

> **Atenção — conflito conhecido com a Regra 4.** A Regra 4 sugere mapeamento em
> `infrastructure/` (perto da persistência). O RFC-0010 põe em `Application/Mappers/`.
> **Em projeto Avita, vale o RFC-0010.** A Regra 4 continua valendo para o resto: domínio
> sem framework, dependência apontando para dentro.

> **Atenção — conflito conhecido com a Regra 5.** A Regra 5 trata sufixo `Service`/`Manager`/
> `Helper` como sinal de SRP fraco. Em projeto Avita, `Service` é convenção obrigatória e
> **não** conta como violação. O sinal de SRP fraco continua sendo o *tamanho e a mistura de
> responsabilidades* da classe, não o sufixo.

```bash
# O que a lib já dá — não reimplementar (AvitaRun/AvitaApp):
# health check K8s, IExceptionHandler + ProblemDetails, API versioning, rate limiting,
# resiliência HTTP, Swagger por env, correlation id.
rg -n "AddHealthChecks|UseExceptionHandler|AddApiVersioning|AddRateLimiter" <api-root>
```

```bash
# Teste de arquitetura sem citação de fonte
find <tests-root> -name '*.cs' -print0 \
| xargs -0 grep -nA5 -E 'class Architecture|_Should_|Deve[A-Z]'
```

## Camada 3 — Exemplo concreto

Numa revisão de MR, o revisor pediu três coisas que o agente recusou citando as regras
genéricas do projeto: centralizar o registro de DI, dar sufixo `Service` às classes de
serviço, e mover mapeamento para `Application`.

O agente estava errado nas três — não porque as regras genéricas sejam ruins, mas porque
**o assunto era arranjo, e existe padrão publicado da casa**: o `project-structure.md` do
RFC-0010 traz `Application/Mappers/`, `Application/Services/` e
`Api/Extensions/ServiceExtension.cs` explicitamente.

O custo do erro foi uma rodada inteira de review gasta discutindo o que já estava escrito.

## Como verificar
```bash
# 1. A estrutura bate com o RFC-0010?
for d in Application/Mappers Application/Services Domain/Interfaces/Repositories \
         Infrastructure/Data/Repositories Api/Extensions; do
  test -d "src/<Nome>.${d%%/*}/${d#*/}" || echo "faltando: $d"
done

# 2. O grafo de dependências está respeitado? (teste arquitetural NetArchTest no repo)
dotnet test --filter "FullyQualifiedName~ArchitectureTests"
```
Divergência entre padrão da casa e invariante exige registro explícito no MR.
