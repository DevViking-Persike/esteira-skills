# Regra 30 — Cobertura por convenção se prova por enumeração

> **3 camadas:** Camada 1 (Princípio) é universal · Camada 2 traz o mecanismo por stack ·
> Camada 3 traz o caso que originou a regra. Veja `_layer-guide.md`.
>
> Vizinhas: Regra 13 (o que a borda valida), Regra 20 (promessa sem mecanismo), Regra 28
> (vínculo por string).

## Camada 1 — Princípio universal (agnóstico)

Registro por varredura — validadores descobertos no pacote, handlers por convenção de nome,
mapeadores por perfil, jobs por atributo — dá **aparência** de cobertura universal. Ele cobre só
o que já existe: o tipo novo, sem par, não falha — passa direto.

Nada no build, no lint ou na suíte distingue "validou e aprovou" de "não tinha o que validar", e
é exatamente essa indistinção que faz o defeito sobreviver a várias revisões. O modo de falha é a
ausência de sinal: a requisição atravessa a borda inteira, ninguém reclama, e o único vestígio é
a conta de banco de dados.

### A prova é a enumeração, não a convenção
Se a cobertura importa, um teste **enumera** o conjunto (tipos de requisição do pacote, rotas do
roteador, membros do enum, entidades do contexto) e exige o par para cada elemento. O teste falha
sozinho quando o próximo membro nascer — que é a única forma de a convenção sobreviver a quem não
a conhece.

### O que a borda não declara, ela ignora em silêncio
O caso mais caro dessa família é o teto ausente. Limite herdado de valor padrão é limite
invisível: quem lê a chamada não vê teto nenhum, e um parâmetro absurdo atravessa a borda como
requisição barata que produz resposta cara. Serviço intermediário tem teto próprio mesmo quando o
destino tem o seu — e, quando o limite existe nos dois lados, o do intermediário registra **em
código** de onde vem o número, senão é constante duplicada (Regra 21).

### Motivação
Convenção é ótima para escrever e péssima para garantir: ela não tem lista, e sem lista não há o
que conferir. O custo aparece como buraco que ninguém consegue apontar, porque não existe linha
de código errada — existe linha que não foi escrita.

### Exceções aceitas
- Conjunto vazio por natureza (endpoint sem parâmetro de entrada, contexto sem entidade).
- Cobertura garantida pela plataforma em tempo de compilação (contrato gerado, tipo que já
  restringe faixa).
- Teto imposto por configuração de servidor ou gateway, **com** teste que o exercita e falha se
  ele for afrouxado.

## Camada 2 — Preset por stack

| Stack | Como fechar o opt-in | Onde o teto some |
|---|---|---|
| C# | teste que enumera os tipos de requisição do assembly e exige validador para cada | parâmetro com valor padrão no serviço; paginação chamada sem argumentos |
| Node-TS | schema obrigatório por rota; teste que varre o roteador | `limit = 20` no serviço |
| Python | modelo de entrada obrigatório por rota; teste sobre o roteador | `def listar(pagina=1, tamanho=20)` |
| Go | validação no construtor do request; teste sobre o mapa de handlers | idem |

```bash
# Tipos de requisição sem validador correspondente (nome de ARQUIVO, não conteúdo)
find <api-root> -name '*Request.cs' -not -path '*/obj/*' -print0 \
| xargs -0 -n1 basename | sed 's/\.cs$//' \
| while read -r base; do
    find <api-root> -name '*.cs' -print0 | xargs -0 grep -qlE "class ${base}Validator" \
      || echo "sem validador: $base"
  done

# Chamadas paginadas sem argumentos explícitos
find <src-root> -name '*.ts' -o -name '*.cs' -print0 \
| xargs -0 grep -nEi '\b(listar|buscar|carregar)[A-Za-z]*\( *[A-Za-z_]+ *\)'
```

## Camada 3 — Exemplo concreto

Num BFF, o registro de validadores varria o pacote a partir de um validador existente, dando
aparência de validação global. Dois tipos de requisição nasceram sem validador — o filtro de
planilhas e o de itens — e `?pagina=-1&tamanhoPagina=1000000` atravessou a borda inteira sem uma
linha de defesa, virando requisição barata que produzia resposta cara atravessando a rede duas
vezes. Nada no build, no lint ou na suíte distinguia isso de "validou e aprovou".

No frontend do mesmo fluxo, a chamada de listagem era feita sem argumentos de paginação e caía
nos valores padrão do serviço, tornando o teto de 20 itens invisível para quem lia a tela — e o
teste só matou o mutante quando passou a assertar os argumentos explicitamente.

## Como verificar
```bash
# 1. Teste que enumera os elementos do conjunto e exige o par para cada um.
# 2. Grepar chamadas paginadas sem argumentos de página/tamanho.
# 3. Todo teto replicado cita, em código, a origem do limite do destino.
# 4. Teste de borda com valor negativo e com valor absurdo, assertando 4xx.
```
