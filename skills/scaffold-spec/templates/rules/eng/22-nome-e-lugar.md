# Regra 22 — Nome e lugar dizem a camada e o papel

> **3 camadas:** Camada 1 (Princípio) é universal · Camada 2 traz a convenção por stack ·
> Camada 3 traz o caso que originou a regra. Veja `_layer-guide.md`.

## Camada 1 — Princípio universal (agnóstico)

Num projeto em camadas, **onde o arquivo mora** e **como o tipo se chama** são documentação
executável: dizem em que camada a peça vive e que papel ela cumpre. Quando um dos dois
mente, o leitor procura a regra de negócio no lugar errado — e o próximo arquivo novo copia
o desvio.

### Nome diz o papel

- O sufixo nomeia a função na arquitetura: caso de uso, serviço de domínio, repositório,
  entidade, DTO, value object, agregado, validador. **Escolha o vocabulário uma vez e use
  sempre o mesmo.**
- **Substantivo de agente não é papel.** `Despachador`, `Orquestrador`, `Gerenciador`,
  `Helper`, `Util` dizem que a classe faz algo — não dizem em que camada ela está nem como
  ela é composta. Se o repo já nomeia três casos de uso com o mesmo sufixo, o quarto não
  inventa.
- O nome também não promete mecanismo inexistente (Regra 20) nem esconde o porquê num
  comentário (Regra 12).

### Lugar diz a camada

- Contrato com arquivo próprio mora na pasta de contratos **da sua camada** — não solto numa
  pasta de feature, e não no mesmo arquivo de um record de payload.
- Onde a porta mora é decidido por **quem a implementa**, não por quem a chama (Regra 4).
- Validação de contrato de entrada não mora dentro do caso de uso: vai para uma classe
  dedicada, na pasta de validadores da camada — o caso de uso chama uma vez e mapeia as
  falhas.

### Renomear é uma operação inteira

Trocar o nome de um tipo leva junto, no mesmo commit: o **arquivo**, os dublês de teste, as
variáveis e propriedades que carregavam o nome antigo, os arquivos de teste correspondentes e
as citações na documentação. O nome antigo sobrevivendo em qualquer um desses lugares
continua mentindo — e é justamente onde ninguém olha.

### O que o rename não pode levar junto

A operação inteira tem um limite: **contrato externo não acompanha o rename**. Variável de
ambiente, seção de configuração, nome de fila ou tópico, coluna, rota, cabeçalho e chave de cache
pertencem a quem está do outro lado — deploy, banco, mensageria, cliente — e só mudam por migração
coordenada, com o MR par citado (Regra 20).

O sinal de que o rename vazou é específico e fácil de ver no diff: **um teste ajustado sem que o
código de produção tenha mudado**. A suíte fica verde tendo deixado de proteger a chave real, e a
quebra aparece no ambiente como configuração que não liga e cai no valor padrão — sem exceção, sem
log, com o serviço subindo.

A armadilha irmã é o contrato público **derivado** de nome interno: rota montada a partir do nome
da classe, tópico montado a partir do nome do tipo, tabela derivada do nome da entidade. Aí o
rename muda um contrato que outro repositório consome sem que nenhum literal mude — não há o que
grepar. Quando o padrão da casa oferece a forma literal (rota escrita, tópico escrito), use a
forma literal justamente por isso.

**Exceção:** chave interna consumida só por este serviço e migrada no mesmo commit com leitura
dupla por um ciclo, e a data de remoção registrada.

### A convenção que já foi violada vira teste

Depois da primeira correção, a fronteira sai do olho do revisor e entra no CI: um teste de
arquitetura varre o assembly/diretório e falha quando o desvio reaparece. Convenção sem teste
volta no próximo arquivo novo.

### Motivação
Inconsistência de nome e de lugar não é gosto: é o revisor gastando rodada para descobrir o
que a peça é, e o próximo dev replicando o desvio por imitação. O custo aparece como atrito
permanente em review, não como bug.

### Exceções aceitas
- Interface de caso de uso declarada no arquivo da própria implementação, **se o padrão for
  consistente em todas as ocorrências** e estiver escrito na doc de convenções.
- Camadas onde não existe pasta de contratos (adapters de infraestrutura com a interface
  colada no adapter) — desde que seja o padrão único da camada.
- Código gerado/vendorizado.

## Camada 2 — Preset por stack

| Stack | Convenção típica | Trava |
|---|---|---|
| C# | sufixo por papel (`*Application`/`*UseCase`, `*Service`, `*Repository`, `*Validator`, `*Dto`); contratos em `Interfaces/`; validação com FluentValidation em `Validators/` | NetArchTest / ArchUnitNET |
| Node-TS | `*.use-case.ts`, `*.repository.ts`, `*.validator.ts`; ports em `application/ports/` | `eslint-plugin-boundaries`, `dependency-cruiser` |
| Python | módulos `use_cases/`, `repositories/`, `schemas/` (pydantic) | `import-linter` |
| Go | `internal/usecase`, `internal/adapter`; interface no consumidor | `go-arch-lint` |
| Java/Kotlin | ArchUnit | ArchUnit |

```bash
# Arquivo de interface fora da pasta de contratos da camada
find <application-root> -name 'I[A-Z]*.<ext>' -not -path '*/Interfaces/*'

# Classe de caso de uso sem o sufixo do papel
rg -n 'public (sealed )?class \w+(?<!Application)(?<!Service)(?<!Repository)\b' <application-root>

# Nome antigo sobrevivendo depois de um rename
rg -n '<NomeAntigo>' <repo-root>   # inclui tests/, README e nomes de arquivo

# O nome antigo DEVE sobreviver onde é contrato externo (parênteses obrigatórios no find)
find . \( -name '*.env*' -o -name '*.yml' -o -name '*.yaml' \
       -o -path '*/migrations/*' -o -path '*/helm/*' -o -path '*/docs/*' \) -print0 \
| xargs -0 grep -n '<NomeAntigo>\|<NOME_ANTIGO>'

# Contrato público derivado de nome interno
find <src-root> -name '*.cs' -print0 \
| xargs -0 grep -nE '\[controller\]|nameof\(|typeof\([A-Za-z]+\)\.Name'

# Teste alterado sem o código de produção correspondente
git diff --stat <sha-do-rename>^..<sha-do-rename> -- <tests-root> <src-root>
```

`find` sem os parênteses liga `-print0` apenas ao último `-o` e varre **um** dos padrões, calado —
foi assim que a chave viva num `.env` passou por "limpo".

> Ao adotar validação declarativa, **confira antes se a borda já liga auto-validation**:
> registrar o validador no container pode trocar o corpo de erro que os consumidores já usam
> (Regra 14 e Regra 17). Validador instanciado no caso de uso preserva o contrato.

## Camada 3 — Exemplo concreto

Num MR de backend de atualização de apólice em lote, a inconsistência era **interna ao próprio
repositório**:

| O que estava | O que o repo já fazia |
|---|---|
| `DespachadorPlanilha`, `OrquestradorDespachoItem` | `RegistrarPlanilhaApplication`, `ConsultarPlanilhasApplication`, `DespacharPlanilhaApplication` |
| `IFila` solto em `Application/Despacho/`, no mesmo arquivo de um record de payload | todas as outras interfaces em `Application/Interfaces/` — e a doc já dizia esse caminho |
| três validações de contrato como `if` dentro do caso de uso | o projeto já referenciava a lib de validação e a registrava no boot, sem um único validador |

O rename cascateou como previsto: arquivo, dublês (`OrquestradorFake` → `ProcessadorFake`),
propriedade `Orquestrador` → `Processador`, quatro arquivos de teste e três citações no
README. Nas duas correções de lugar, a fronteira virou teste de arquitetura — um que exige o
namespace dos contratos, outro que varre o diretório e reprova qualquer arquivo de interface
fora da pasta de contratos.

## Como verificar
```bash
# 1. Listar os tipos novos do diff: cada um tem o sufixo do papel usado pelo repo?
# 2. Todo arquivo de contrato está na pasta de contratos da sua camada?
# 3. Se houve rename: grepar o nome antigo em src/, tests/, doc/ e nos nomes de arquivo.
# 4. A convenção corrigida ganhou teste de arquitetura?
```
