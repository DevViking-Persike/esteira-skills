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
- nome de controller, de serviço, de DTO e de tipo citados — rename que o doc não acompanha
  manda o integrador procurar um tipo que não existe, e tipo inexistente não dá `404`: dá
  compilação quebrada do outro lado
- porta de fallback de ambiente local
- header/parâmetro descrito como obrigatório: **é mesmo?**
- código de status prometido para cada caminho de erro
- gerenciador de pacotes, comandos e versão de runtime citados
- **todas** as seções em que o mesmo contrato aparece, não só a linha apontada na thread

### Doc que nasce nesta MR envelhece dentro dela

Documento adicionado no mesmo lote é o que mais diverge: descreve o desenho da primeira rodada
e sobrevive às quatro seguintes. A releitura acontece **depois do último commit de correção**,
contra o código final e não contra a intenção do início. Sinal mais barato de detecção:
documento que **se contradiz internamente** — a tabela dizendo uma coisa e o parágrafo dois
abaixo dizendo o contrário; um dos dois já não bate com o código, e isso se acha sem abrir o
código.

E contrato citado em N seções corrige nas N: consertar a tabela de endpoints e deixar a
introdução três seções acima anunciando a rota antiga produz documento certo e errado ao mesmo
tempo — e o integrador lê a introdução.

**Reincidência é falta de mecanismo, não de disciplina.** Quando o mesmo documento fica para
trás três vezes na mesma revisão — inclusive pelo autor da própria convenção — a correção não é
prestar mais atenção: é item do template de MR ou gate de CI.

### Garantia escrita nomeia a condição em que não vale

Frase de contrato que promete unicidade, isolamento ou não-colisão diz o que acontece quando o
insumo dela falta. Uma chave que promete "não colide com a de outro solicitante" e é derivada de
uma identidade que pode chegar vazia promete exatamente o contrário no ambiente em que a
identidade não chega.

### Toolchain declarada é executável

Se a documentação fixa o gerenciador de pacotes, os scripts do próprio manifesto usam **esse**
gerenciador, e o lockfile versionado manda nos dois. Um README que crava um gerenciador ao lado
de um script que invoca outro é contradição que só aparece no runner: na máquina do autor os
dois binários existem. O custo maior não é o build vermelho — é o verde errado: quem seguir a
doc com o gerenciador errado gera lockfile paralelo e resolve versões diferentes das do CI, e a
divergência se manifesta como bug que não reproduz.

### Motivação
Doc de contrato desatualizada custa mais que doc ausente. Sem doc, o integrador lê o
código; com doc errada, ele confia e erra. Foi assim que uma tabela de endpoints apontou
o frontend para URLs inexistentes num MR que passou em todos os testes.

### Exceções aceitas
- Documento explicitamente histórico ou de decisão, datado (registra o que se decidiu à
  época, não o que existe hoje).
- Seção marcada como proposta/alvo, com o rótulo visível **na própria seção** — não no topo do
  arquivo nem no histórico da discussão.

## Camada 2 — O que verificar por stack

| Stack | Fonte da verdade a conferir contra o doc |
|---|---|
| C# / ASP.NET | atributos `[Route]`, `[HttpGet]`/`[HttpPost]`, nomes de `*Response`/`*Request`, fallbacks em `HttpClientExtensions` |
| Node-TS | definição de rotas do router, schemas de validação, `baseURL` dos clients |
| Angular/React | serviços de API, tokens de configuração, `environment*.ts` |
| Terraform | nomes de recurso e de variável de saída citados no README do módulo |

```bash
# Rotas citadas no doc que não existem no código (C#)
grep -oE 'api/v[0-9]+/[A-Za-z/{}._-]+' README.md | sort -u > /tmp/doc-rotas
find <controllers-root> -name '*.cs' -print0 | xargs -0 grep -hoE 'Route\("[^"]+"\)' \
| sed 's/^Route("//; s/")$//' | sort -u > /tmp/cod-rotas
comm -23 /tmp/doc-rotas /tmp/cod-rotas   # saída esperada: vazia

# DTO/tipo citado no doc que não existe no código (sem rg -r: grep -oE + sed)
grep -hoE '\b[A-Z][A-Za-z]+(Request|Response|Dto|Controller|Service)\b' README.md \
| sort -u > /tmp/doc-tipos
find <src-root> -name '*.cs' -print0 | xargs -0 grep -hoE 'class [A-Za-z]+' \
| sed 's/^class //' | sort -u > /tmp/cod-tipos
comm -23 /tmp/doc-tipos /tmp/cod-tipos          # saída esperada: vazia

# Termo corrigido numa seção e sobrevivente em outra
find <doc-root> -name '*.md' -print0 | xargs -0 grep -n '<termo-antigo>'

# Toolchain: script do manifesto x lockfile versionado x doc
grep -nE '"(npm|npx|pnpm|yarn) ' package.json
ls -1 package-lock.json yarn.lock pnpm-lock.yaml 2>/dev/null
find . -maxdepth 2 -name 'README.md' -print0 | xargs -0 grep -nE '\b(npm|yarn|pnpm|uv|pip|make)\b'

# Doc criada/alterada no mesmo MR que src/: relê depois do último commit de correção
git diff --stat origin/main...HEAD -- '*.md' <src-root>
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
