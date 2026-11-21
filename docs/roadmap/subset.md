# Subset do compilador

Esta matriz separa capacidade implementada de compatibilidade com `snovac`.
Uma linha só avança depois de fonte Snova do compilador usar o recurso e de um
estágio anterior conseguir compilá-la.

| Área | Seed atual | Próximo gate |
|---|---|---|
| Fontes do compilador | Módulos `.snl` camelCase; check do projeto multi-arquivo e imports públicos entre pacotes | Ensinar o seed a carregar/importar arquivos sem o joiner temporário |
| Frontend | Lexer/parser do subset com diagnóstico de fase e linha | Diagnósticos estáveis com span e diferencial versionado com referência |
| Semântica | Resolução local necessária ao subset | Tipos e diagnósticos compatíveis por marcos |
| IR e backend | Lowering para SnBC | Backend nativo implementado em Snova e artefato executável standalone |
| Runtime | Usa funções do runtime já existente | Reimplementar em Snova; manter apenas fronteiras ABI/OS mínimas |
| CLI | Entrada/saída fixas `in.snl` e `out.snbc` | Argumentos, flags, diagnósticos e projeto compatíveis gradualmente |
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
