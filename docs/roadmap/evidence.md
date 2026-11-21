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
