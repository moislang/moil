# Subset do compilador

Esta matriz separa capacidade implementada de compatibilidade com `snovac`.
Uma linha só avança depois de fonte Snova do compilador usar o recurso e de um
estágio anterior conseguir compilá-la.

| Área | Seed atual | Próximo gate |
|---|---|---|
| Fontes do compilador | Módulos `.snl` camelCase; build de projeto; montagem interna das próprias fontes | Resolver imports e compilar projetos gerais diretamente no compilador Snova |
| Frontend | Lexer/parser do subset com diagnóstico de fase e linha | Diagnósticos estáveis com span e diferencial versionado com referência |
| Semântica | Resolução local necessária ao subset; tipos estáticos de literais, locais, parâmetros e campos; warning `SNW0001` para `==`/`!=` entre tipos conhecidos e diferentes (não interrompe a compilação) | Tipos e diagnósticos compatíveis por marcos; spans completos; comparação de endereço `&T == &E` quando referências entrarem no subset |
| IR e backend | Lowering para SnBC; o binário de `snl build` é SnBC + VM C empacotada; backend nativo N1 em Snova: SnBC numérico → assembly aarch64 (`native`), montado por `as`/`ld` | N2: runtime em Snova (strings, arrays, structs, I/O) no backend nativo; N3: compilador nativo (ADR-0005) |
| Runtime | Fachada Snova para argumentos, ambiente e I/O; `Runtime.writeText`, `fileExists` e `readText` aceitos pelo seed; validador SnBC; executor SnBC iterativo em Snova (valores tipados, chamadas, arrays, objetos, strings por bytes, I/O e runtime API) que roda a imagem do compilador; operações de OS ainda fornecidas pelo runtime anterior | Primitiva string→bytes e stderr como fronteira (ADR-0004); runtime nativo (ADR-0005) |
| CLI | Caminhos de entrada e saída por argumentos; modo interno de bootstrap por `SNL_OUTPUT` | Flags, diagnósticos e projeto compatíveis com `snovac` |
| Self-compilation | Seed Snova compila seu source para SnBC; imagem seguinte coincide | Repetir o ciclo após cada extensão e registrar os hashes |
| Compatibilidade total | Não demonstrada | Corpus `snovac` com resultados diferenciais e lacunas explicitadas |

## Regra de implementação

Todo novo código do compilador, runtime e ferramentas de desenvolvimento deve
ser escrito em Snova. C/C++ não é uma implementação alternativa. O seed
instalado `snl` é apenas a raiz transitória para obter o primeiro artefato; a
cadeia avança quando o compilador Snova gerado puder compilar sua própria
revisão e produzir o mesmo artefato. Chamadas indispensáveis ao sistema ficam
atrás de contratos pequenos de ABI, sem lógica do compilador fora de Snova.

O compilador é a única peça de produto/publicação deste projeto. Scripts de
build e documentação são suporte de desenvolvimento e não componentes públicos
da toolchain.
