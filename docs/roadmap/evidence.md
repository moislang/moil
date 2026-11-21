# Registro de evidências

Este arquivo começa vazio de resultados técnicos. As entradas devem registrar fatos observados, não metas.

## Modelo de entrada

```text
### YYYY-MM-DD — fase/marco
- Revisão do repositório:
- Host e SO:
- snl/snovac de referência (versão e caminho):
- Comando(s):
- Resultado observado:
- Artefatos/hash:
- Limitações e itens não verificados:
```

## 2026-11-21 — seed Snova e fixed point restrito

- Revisão do repositório de referência: `snovac` `2b5048aaf221527e22ea844f858b5d0f33f149c9` (checkout local; somente leitura).
- Host e SO: Apple Silicon, macOS; triple observado `aarch64-apple-darwin`.
- `snl`: `snl v0.3.0` (`/Users/yurimoinhos/.snova/bin/snl`).
- Comandos observados: `make bootstrap-fixed-point` (targets encadeados de join, check, build, self-host e compare).
- Resultado observado: check e build nativo passaram; o seed compilou seu próprio source para SnBC; a segunda imagem comparou byte a byte igual à primeira.
- SHA-256 das duas imagens comparadas: `2bff50e2757bd6fbd252f375832c445aa1b20a48aa9876bbe126f0da9e4482d1`.
- Limitações: resultado do subset implementado no seed, usando runtime do `snl`; não comprova CLI completa, compilação do source de `snovac`, standalone sem runtime C, build reproduzível independente, DDC ou equivalência geral. A proveniência do source importado está em `bootstrap/README.md`.

## 2026-11-21 — smoke e diagnósticos do seed

- Revisão e host: mesmos do registro anterior; `snl v0.3.0`, `aarch64-apple-darwin`.
- Comandos: `make bootstrap-smoke`, `make bootstrap-diagnostics`, `make bootstrap-fixed-point`.
- Resultado observado: programa de fixture compilado pelo seed e executado pelo runtime SnBC imprimiu `snova bootstrap ok`; entradas léxica e sintaticamente inválidas falharam com fase e linha esperadas; a compilação do próprio source pelo SnBC gerado produziu imagem igual à anterior.
- SHA-256 de ambas as imagens do fixed point restrito: `632aab95921a0ac749b8dca5ab575498f8a1ab004ad6636af148740f97ae1ef7`.
- Limitações: diagnósticos de lowering ainda são gerais e não têm span; fixtures não constituem diferencial com o `snovac`; runtime, CLI de argumentos e backend standalone permanecem pendentes.

## 2026-11-21 — módulos importáveis e nomes camelCase

- Ambiente: `snl v0.3.0`, `aarch64-apple-darwin`.
- Organização: módulos do compilador em `bootstrap/src/`, funções e tipos em `camelCase`, arquivos abaixo de 400 linhas. `api.snl` importa `snova.compiler`; `apiConsumer.snl` importa `snova.compiler.api`.
- Comandos: `snl check --project bootstrap/src`, `make bootstrap-smoke`, `make bootstrap-diagnostics`, `make bootstrap-fixed-point`.
- Resultado observado: imports entre pacotes e projeto multi-arquivo passaram no check; smoke e diagnósticos passaram; o joiner em Snova gerou a unidade seed, que compilou as fontes e atingiu igualdade byte a byte.
- SHA-256 das imagens SnBC stage 1 e 2: `6dab7126700e6416ade1ba2df110ea8486dc6cae989954d484330a0919c42740`.
- Limitações: o seed ainda não carrega módulos/imports por conta própria; o joiner temporário remove cabeçalhos para auto-compilar. O runtime de execução continua sendo o do `snl`; compatibilidade ampla e backend standalone não foram demonstrados.

## 2026-11-21 — I/O por caminhos e montagem interna do bootstrap

- Ambiente: `snl v0.3.0`, `aarch64-apple-darwin`.
- Comandos: `make bootstrap-fixed-point`, `make bootstrap-smoke`, `make bootstrap-diagnostics`.
- Resultado observado: o binário do projeto multi-arquivo aceitou caminhos de entrada/saída por argumentos; sem argumentos, compilou suas próprias fontes a partir de `sourceJoin.snl` e usou `SNL_OUTPUT`. O SnBC gerado repetiu a compilação sem o joiner externo e as duas imagens coincidiram byte a byte. Smoke e diagnósticos passaram com a nova CLI.
- SHA-256 das duas imagens SnBC: `4d00222c46e427a3308bf1f7ede3935d8a6744222f7d074a2f7ac115b2482716`.
- Limitações: `runtime.snl` encapsula as chamadas de argumentos, ambiente e bytes, mas essas primitivas e a execução de SnBC ainda vêm do runtime de referência. A montagem interna lista os módulos do próprio compilador; imports gerais, semântica completa, backend nativo em Snova e compatibilidade integral com `snovac` permanecem pendentes.

## 2026-11-21 — leitor estrutural SnBC em Snova

- Ambiente: `snl v0.3.0`, `aarch64-apple-darwin`.
- Comandos: `make bootstrap-image-check`, `make bootstrap-fixed-point`.
- Resultado observado: `imageReader.snl` aceitou a imagem produzida pelo compilador, rejeitou uma imagem truncada e foi compilado como parte do próprio compilador na geração seguinte. As imagens de estágio 1 e 2 coincidiram byte a byte.
- SHA-256 de ambas as imagens: `8ecf10657461d96e7033ed391ba1fdfd60400579e503e36ff7d5dd5cec4952cd`.
- Limitações: a validação cobre estrutura, tamanhos e índices principais; ainda não valida instruções/opcodes, não executa SnBC em Snova e não substitui o runtime ou backend de referência.

## 2026-11-21 — validação de instruções SnBC em Snova

- Ambiente: `snl v0.3.0`, `aarch64-apple-darwin`.
- Comandos: `make bootstrap-fixed-point`, `make bootstrap-image-check`, `make bootstrap-smoke`; imagens derivadas de `stage1.snbc` com opcode inválido e salto fora da imagem foram rejeitadas pelo compilador Snova.
- Resultado observado: `imageCode.snl` verificou limites das instruções, último opcode, índices de strings/locais/funções, aridade, chamadas de runtime, saltos e opcodes ainda sem implementação; as imagens de estágio 1 e 2 coincidiram byte a byte.
- SHA-256 de ambas as imagens: `d85c9e395f93e2b16d8156dc47589f619b8d6693f6d935b79ddbc00b8100d3ee`.
- Limitações: este validador não executa bytecode, não prova paridade para todo corpus e ainda usa o runtime anterior para construir/executar as imagens de estágio.

## 2026-11-21 — executor numérico SnBC em Snova

- Ambiente: `snl v0.3.0`, `aarch64-apple-darwin`.
- Comandos: `make bootstrap-vm-numeric bootstrap-fixed-point bootstrap-image-check bootstrap-smoke` e `git diff --check`.
- Resultado observado: `vmStack.snl` e `vmNumeric.snl` executaram duas imagens geradas pelo seed. Ambas retornaram `48`, igual ao código de saída de `snl run-snbc` para as mesmas imagens. Os casos cobrem locais, aritmética, comparação, desvio condicional e laço. O fixed point restrito continuou byte a byte igual; SHA-256 das duas imagens: `ce8b1d0daf76aad72e1ffb43622d7963a6ad219e2a46e69eec0c3e0af645e724`.
- Limitações: o executor aceita apenas uma função e valores numéricos/booleanos; não executa strings, chamadas, objetos, arrays, I/O ou a imagem do próprio compilador. A geração nativa e as primitivas de I/O ainda dependem do runtime anterior. Este resultado não constitui substituição integral do `snovac`.
