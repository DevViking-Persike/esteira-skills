# Regra 25 — Desfecho de review é declarado, não implícito

> **3 camadas:** Camada 1 (Princípio) é universal · Camada 2 traz o preset por plataforma de
> review · Camada 3 traz o caso que originou a regra. Veja `_layer-guide.md`.
>
> Vizinhas: Regra 26 (a afirmação que abre a thread), Regra 06 (a correção é código novo),
> Regra 17 (não relate mais do que verificou).

## Camada 1 — Princípio universal (agnóstico)

Uma thread de review fecha de um de **quatro** jeitos, e todos são declarados:

1. **Corrigido** — a resposta nomeia o teste, o caso ou a asserção que **falharia sem** a
   correção.
2. **Corrigido com resíduo** — a correção entrou, sobrou risco nomeado, e o resíduo sai da
   thread: vira card, com dono e data.
3. **Recusado** — com a razão escrita, verificável por quem ler depois.
4. **Aberto** — depende de decisão de produto, de outro time ou de outro repositório, com dono
   nomeado.

`Corrigido em <sha>`, sozinho, não é nenhum dos quatro: afirma que houve um commit.

### O placar da suíte não é evidência
Colar `N testes, 0 falhas` prova que nada regrediu — e a suíte **já estava verde antes**, senão
o achado teria sido pego por ela. Por construção ela não alcança corrida, TOCTOU, invariante de
base de outro time, efeito remoto não confirmado nem símbolo sem consumidor. Placar ao lado de
um achado dessa classe é ruído com aparência de prova.

E o placar precisa ser **da árvore entregue**. Resposta que cita a suíte verde e, três
parágrafos abaixo, avisa que um arquivo precisa ser removido à mão ou que um teste de outro
grupo passa a falhar, está citando o resultado de uma árvore que não é a que vai para o merge.
Passo manual pendente é desfecho 4, não desfecho 1.

### Achado cujo arquivo se moveu é reancorado antes de classificado
A plataforma marca a thread como *outdated* sozinha quando o trecho sai do lugar, e a âncora se
perde sem ninguém decidir nada. "O arquivo apontado saiu ou foi movido neste push" responde ao
endereço, não ao achado: a pergunta continua sendo **onde a invariante passou a viver**.
Refatoração entre rodadas é o jeito mais barato de um achado sério desaparecer sem ser recusado.

### Correção que atravessa arquivos fecha em todos, ou vira plano
Quando o invariante exige mudança no contrato, no caso de uso e nos chamadores, aplicar só o que
cabe no arquivo comentado marca como resolvido um invariante ausente — e resolvido ninguém
reabre. A saída é o plano nomeado (arquivos, ordem, quais testes passam a falhar) com a thread
**aberta** até ele rodar.

### Premissa não fecha achado
"Os dados já estão consistentes", "esse caminho não é exercitado", "o volume nunca chega lá" são
premissas, e premissa morre no merge junto com a thread. Se ela é o que dispensa o achado, ela
vira **asserção, constraint ou consulta de monitoramento** no mesmo MR.

### Bifurcação de produto é pergunta registrada
"A lista é da squad ou do operador?", "o card pede este filtro e a tela não tem": as duas saídas
silenciosas erram — "corrigido" some com uma decisão aprovada, "não se aplica" some com o risco.
O caminho é a pergunta escrita com o nome de quem decide.

### Especificação que se contradiz bloqueia, não se interpreta
Duas rotas para o mesmo verbo, `200` num parágrafo e `202` em outro, cabeçalho descrito como
opcional e implementado como obrigatório: interpretar é escolher sozinho qual metade dos
consumidores quebra. Liste as contradições numeradas e devolva a decisão a quem é dono do
contrato.

### O veredito da rodada vem do inventário de achados abertos, não do delta revisado
Revisar só o que mudou desde a rodada anterior é economia legítima. Emitir **veredito de MR** a
partir dessa revisão parcial não é: "nada novo nesta rodada" e "nada aberto neste MR" são
afirmações diferentes, e trocar uma pela outra é a Regra 17 aplicada ao próprio review. O
veredito cita o inventário: quantas threads abertas, quais, e por que nenhuma bloqueia.

### Motivação
O custo não é a rodada perdida: é o achado que chega à produção **com o status de tratado**.
Revisor não reabre o que está fechado, e o próximo leitor confia no histórico — inclusive para
concluir que o defeito é novo.

### Exceções aceitas
- Achado de forma (typo, nome, formatação) cuja correção é integralmente visível no diff — o
  diff **é** a evidência.
- Achado duplicado: fecha apontando a thread canônica, que carrega a evidência.
- Achado sobre código removido no mesmo lote: fecha citando o commit de remoção.
- Thread de dúvida, que não afirma defeito: fecha com a resposta.

## Camada 2 — Preset por stack

**Aplicável a qualquer stack — sem comando específico.** O princípio independe de
linguagem/framework: o mecanismo é o controle de versão e o template de MR. O que varia é a
plataforma de review.

| Plataforma | O que ela faz sozinha | O que sobra para você |
|---|---|---|
| GitLab | marca a discussão como *outdated* quando a linha se move e some da aba de diff | listar as não resolvidas **e** as *outdated*, e reancorar cada uma |
| GitHub | esconde o comentário como *outdated* e mantém a conversa | conferir "resolved" sem resposta e reancorar |
| Gerrit/Bitbucket | prende o comentário ao patchset | conferir se o patchset seguinte respondeu |

Item de template de MR (é o mecanismo; boa vontade não é):

```
Achado: <resumo>   Desfecho: corrigido | corrigido-com-resíduo | recusado | aberto
Evidência: <teste/caso que falharia sem isto> | <card do resíduo + dono> | <razão> | <quem decide>
```

```bash
# Refatoração entre rodadas órfã âncoras: liste movidos, renomeados e removidos
git log --oneline --name-status --diff-filter=RD <sha-da-rodada-anterior>..HEAD

# A correção mudou produção, ou só teste?
git show <sha> --stat | grep -vE '(_test|\.test\.|\.spec\.|[Tt]ests?/)'

# Antes de responder "corrigido": existe asserção nova?
git diff <sha-da-rodada-anterior>..HEAD -- <tests-root> | grep -E '^\+.*(Assert|expect|Should)'
```

## Camada 3 — Exemplo concreto

Numa revisão de backend de atualização de apólice em lote, 22 das 24 respostas fecharam com
`Corrigido em <sha>`, e dez delas anexaram `Suíte local: 208 testes, 0 falhas` — placar que já
estava verde antes das correções e que, por construção, não alcança nenhum dos achados que
fechou: corrida no status, exclusão lógica em base de outro sistema, confirmação de efeito
remoto ausente.

Os **dois achados mais sérios de consistência** saíram da mesa com "o arquivo apontado saiu ou
foi movido neste push": uma refatoração rodada entre as rodadas moveu o arquivo, a plataforma
marcou as threads como *outdated*, e ninguém reancorou — nenhum dos dois chegou a ser recusado.
Três respostas citaram a suíte verde e, no parágrafo seguinte, avisaram que um arquivo precisava
ser apagado à mão e que dois testes de outro grupo passariam a falhar. E doze threads deixadas
abertas à espera de decisão de time conviveram, na mesma rodada, com o veredito "aprovar — sem
bloqueio novo".

## Como verificar
```bash
# 1. Listar toda thread resolvida da rodada e classificar nos quatro desfechos.
# 2. Para cada "corrigido", exigir a linha "teste ou caso que falharia sem isto".
#    Evidência que é placar de suíte reabre a thread.
# 3. git log --diff-filter=RD entre as rodadas: todo arquivo movido exige reancoragem.
# 4. Para cada premissa usada como dispensa: apontar a asserção, constraint ou monitor.
# 5. O veredito da rodada cita o inventário de threads abertas, não o delta revisado.
```
