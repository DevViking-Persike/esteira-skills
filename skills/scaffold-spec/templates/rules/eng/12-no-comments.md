# Regra 12 — Código sem comentários

> **3 camadas:** Camada 1 (Princípio) é universal · Camada 2 lista o que cada stack
> considera *diretiva* (e não comentário) · Camada 3 traz um exemplo. Veja `_layer-guide.md`.

## Camada 1 — Princípio universal (agnóstico)

**Código novo não leva comentário.** O que um comentário explicaria vira **nome**:
função extraída, variável intermediária, tipo nomeado, constante nomeada, teste.

- Comentário que descreve o **quê** é ruído — o código já diz.
- Comentário que descreve o **porquê** é sinal de **nome ruim** ou de **função
  fazendo coisa demais**: extraia até o porquê caber no nome.
- Comentário envelhece sem quebrar build: vira mentira silenciosa. Nome errado
  aparece no diff, no autocomplete e na chamada.
- Contexto histórico (por que a decisão foi tomada) mora no **commit**, no **ADR** ou
  no card — não no arquivo.

> Esta regra **substitui** o bullet de comentários da Regra 5 (Simplicidade), que
> tolerava comentário de *porquê*. O porquê agora sai do código.

### Como aplicar

| Em vez de… | Faça |
|---|---|
| bloco comentado explicando o passo | extraia uma função com o nome do passo |
| comentário sobre o valor mágico | constante nomeada |
| comentário sobre a condição | predicado nomeado (`EhDespachavel(item)`) |
| comentário sobre o workaround | função nomeada pelo efeito + teste que fixa o comportamento |
| comentário `TODO`/`FIXME` | task no board (o código não é backlog) |
| bloco de código comentado | **apagar** — o histórico está no git |

### Exceções aceitas (não são "comentário de código")

- **Doc comment exigido pelo toolchain**: XML docs quando o projeto liga
  `GenerateDocumentationFile` (inclui `/// <inheritdoc/>`), docstring de API pública
  publicada, JSDoc/TSDoc de biblioteca distribuída.
- **Diretiva que a linguagem escreve como comentário**: `// eslint-disable-next-line`,
  `# type: ignore`, `//go:generate`, `# noqa`, `#pragma`, shebang.
- **Cabeçalho legal/licença** exigido por política.
- **Bloco de uso de script executável** (o `# Uso: ...` que faz as vezes de `--help`).
- **Código gerado ou vendorizado** — não se edita, não se audita.

## Camada 2 — Preset por stack

O grep é o mesmo em toda stack; o que muda é **o que não conta como comentário**.

| Stack | Marca | Não conta (diretiva/doc) |
|---|---|---|
| C# | `//`, `/* */` | `///` (com `GenerateDocumentationFile`), `#pragma`, `#nullable` |
| Node-TS | `//`, `/* */` | `/** */` de lib publicada, `// eslint-disable*`, `// @ts-expect-error` |
| Angular/React/Svelte | idem Node-TS + `<!-- -->` no template | idem |
| Python | `#` | docstring `"""`, `# type: ignore`, `# noqa` |
| Go | `//` | doc comment de identificador exportado, `//go:` |
| Rust | `//` | `///`/`//!`, `#[...]` |
| Shell | `#` | shebang, bloco `# Uso:` do topo |

```bash
find <root> -name '<ext>' -not -path '*/node_modules/*' -not -path '*/obj/*' \
  -not -path '*/bin/*' -not -name '*.gen.*' -print0 \
| xargs -0 grep -n '^\s*//' | grep -v '///\|eslint-disable\|@ts-expect-error'
```
Esperado: vazio. (Trocar `//` pelo marcador da stack.)

> **Cuidado:** o wrapper `rtk` engole `grep --include` e devolve vazio sem erro.
> Varredura confiável só com `find … -print0 | xargs -0 grep`.

## Camada 3 — Exemplo concreto

**Ruim** — o comentário carrega o porquê que o código esconde:
```csharp
// O .env espelho traz a chave em branco quando o valor nao se aplica. Para o
// binder, "presente porem vazia" != "ausente": um int liga em "" e derruba o boot.
foreach (DictionaryEntry variavel in Environment.GetEnvironmentVariables())
{
    if (variavel.Value is string valor && valor.Length == 0)
    {
        Environment.SetEnvironmentVariable((string)variavel.Key, null);
    }
}
```

**Bom** — o nome carrega:
```csharp
TratarVariaveisDeAmbienteVaziasComoAusentes();
```

## Como verificar
```bash
# Rodar o grep da Camada 2 no diff do PR. Saída esperada: vazia.
git diff --unified=0 origin/main | grep '^+' | grep '^\+\s*//'
```
Comentário no diff exige justificativa explícita no commit/PR, encaixando numa das
exceções aceitas.
