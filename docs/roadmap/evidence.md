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

## 2026-11-21 — sondas do runtime SnBC v0.3.0 e do `snl build`

- Ambiente: `snl v0.3.0`, `aarch64-apple-darwin`. Imagens SnBC montadas à mão (ferramenta de sonda fora do repositório) e programas compilados pelo seed.
- Observado: `snl run-snbc` recusa imagem com SET_INDEX (41) ("cannot read SnBC image"); SET_FIELD (38) espera alvo no topo e valor abaixo, devolvendo o valor; `"ab" + "c" == "abc"` dá `false` e constantes de mesmo conteúdo dão `true` (igualdade de strings por identidade, também no executável de `snl build`); `int + string` produz número espúrio; `bool == int` dá `false`; PRINT de unit imprime linha vazia; runtime calls 2/3/4 são `fileExists`, `readText` e `writeText`; o programa não recebe argumentos (`argumentCount` = 0); estouro de profundidade imprime `error: call depth exceeded` com saída 70.
- Observado: `snl build` gera SnBC e empacota a VM C ("bundled binary dependencies"; perfil dominado por `run_function`); o lowering recusa `a[i].campo` ("cannot lower field to SnBC"). Os executáveis citados em entradas anteriores como "build nativo" são, portanto, SnBC + VM C, não código de máquina do programa.
- Observado: `as -arch arm64` + `ld -lSystem` montam e ligam um `main` em assembly que retorna 48; o `ld` aplica assinatura ad-hoc (`adhoc,linker-signed`).
- Limitações: sondas pontuais; não cobrem todos os opcodes nem a semântica completa da referência.

## 2026-11-21 — executor SnBC em Snova roda a imagem do compilador

- Ambiente: `snl v0.3.0`, `aarch64-apple-darwin`; executável do compilador produzido por `snl build` (SnBC + VM C empacotada).
- Comandos: `make bootstrap-vm bootstrap-diagnostics bootstrap-fixed-point bootstrap-image-check bootstrap-smoke`, `make bootstrap-vm-self`, `git diff --check`.
- Resultado observado: o diferencial de stdout e código de saída entre o executor Snova (`<imagem> run`) e `snl run-snbc` passou para `numericVm` (48), `numericFlow` (48), `hello` (0), `vmCalls` (16, recursão) e `vmComposite` (14, structs/arrays/strings). `vmEquality` e `vmHostText` deram a saída esperada fixa (igualdade por valor; argumentos repassados), divergindo de propósito do `run-snbc`. `vmStackOverflow` falhou com `runtime error: Stack overflow` e saída 70. `invalidRuntimeArity` foi rejeitado pelo seed.
- Resultado observado: em `bootstrap-vm-self`, o executor Snova executou `stage1.snbc`; o compilador convidado leu as próprias fontes, gravou `vm-stage.snbc` via `SNL_OUTPUT` e terminou com 0. `stage1.snbc`, `stage2.snbc` (via `run-snbc`) e `vm-stage.snbc` coincidiram byte a byte. SHA-256: `772cd2e01c2a2e7bc97ebc312d4c13679fb7e22b055d056817d6ac45d9ce563c`. Tempo: 3 min 08 s (185,6 s de CPU), contra cerca de 1 s do compilador no executável de `snl build`.
- Limitações: o executor Snova roda sobre a VM C embutida pelo `snl build`, de modo que a execução continua dependendo do runtime anterior e não é nativa (ADR-0005, proposto). Opcodes que o compilador não usa (double, globais, variantes, defer/spawn) não são executados. Erros vão para stdout. Strings vindas do host usam um arquivo de rascunho em `/tmp` quando comparadas (fronteira provisória, ADR-0004). Isto não constitui DDC, reprodutibilidade em build limpo nem substituição integral do `snovac`.

## 2026-11-21 — warning SNW0001 e repetição do gate do executor

- Ambiente: `snl v0.3.0`, `aarch64-apple-darwin`.
- Comandos: `make bootstrap-diagnostics bootstrap-vm bootstrap-fixed-point bootstrap-image-check bootstrap-smoke`, `make bootstrap-vm-self`, `git diff --check`.
- Resultado observado: `warnMismatch.snl` compilou com saída 0 e dois diagnósticos `warning[SNW0001]`, nas linhas 10 (`"seven" == 7`) e 13 (struct `!=` int); `warnCompare.snl` compilou sem diagnóstico e retornou 7 no executor Snova. A compilação das próprias fontes do compilador não emitiu warnings. Todos os gates rápidos passaram.
- Resultado observado: o executor Snova executou de novo a imagem do compilador com as fontes atuais; `stage1.snbc`, `stage2.snbc` e `vm-stage.snbc` coincidiram byte a byte. SHA-256: `e5aa78db2ad50a0898e2eaaea287b6ac6a66a39063a6f3fbc8c259ab4ddef2dc`. Tempo: 3 min 09 s (187,5 s de CPU). Este hash substitui o da entrada anterior como estado atual.
- Observado no `snl run-snbc` v0.3.0: em `warnCompare`, `true == (1 < 2)` dá falso (saída 3), enquanto o executor Snova dá verdadeiro (saída 7). Por isso o gate verifica essa fixture apenas pelo executor Snova.
- Limitações: o warning só cobre tipos estáticos conhecidos (literais, locais tipados, parâmetros, campos); chamadas e indexação têm tipo desconhecido e não geram aviso. O span é só a linha. Comparação de endereço (`&T`) ainda não existe no subset.

## 2026-11-21 — backend nativo N1 (ADR-0005)

- Ambiente: `snl v0.3.0`, `aarch64-apple-darwin`; `as`/`ld` do Command Line Tools (`-platform_version macos` = versão do SDK, `-lSystem`).
- Comandos: `make bootstrap-native bootstrap-fixed-point bootstrap-vm bootstrap-diagnostics bootstrap-image-check bootstrap-smoke`, `make bootstrap-vm-self`, `git diff --check`.
- Resultado observado: o compilador Snova emitiu assembly aarch64 para `numericVm`, `numericFlow` e `nativeCalls`; os executáveis Mach-O arm64 montados e ligados retornaram 48, 48 e 126, iguais ao executor Snova e ao `snl run-snbc`. `hello.snl` foi recusado com `unsupported opcode for native backend: 3`. Duas emissões do mesmo fonte deram `.s` idênticos (SHA-256 de `nativeCalls.s`: `62345b3011b88abbfc36cb0ac6524a5cd76a00b2c05876f6569f63518f67fe4c`).
- Resultado observado: com os módulos nativos nas fontes, o ponto fixo e o gate do executor continuaram passando; `stage1.snbc`, `stage2.snbc` e `vm-stage.snbc` coincidiram. SHA-256: `47469d977b858b6b463acec9bce71475a3d87a7d23115e547fe5a2c939959951`.
- Limitações: N1 cobre só o subset numérico (sem strings, arrays, structs, impressão nem I/O); o compilador em si ainda roda no executável de `snl build` (SnBC + VM C); a montagem e a ligação usam `as`/`ld` do sistema; o código gerado não tem alocação de registradores. Não há ponto fixo nativo nem compilador nativo (N3).
