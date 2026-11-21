# Leituras sobre bootstrap e arquitetura de compiladores

Esta bibliografia reúne fontes primárias para orientar o projeto. Use a sequência sugerida por tema; não copie uma arquitetura sem verificar se ela cabe nas capacidades confirmadas do `snl` e nos requisitos de Snovalang.

## Bootstrap e compiladores self-hosted

1. **Huberdeau, Hamel, Monnier e Feeley, “The Design of a Self-Compiling C Transpiler Targeting POSIX Shell” (SLE 2024).** [Artigo (PDF)](https://www-labs.iro.umontreal.ca/~feeley/papers/HuberdeauHamelMonnierFeeleySLE24.pdf), [DOI](https://doi.org/10.1145/3687997.3695639). Estuda um seed limitado, a fronteira do subconjunto necessário, compilação do próprio transpiler e cadeia de ferramentas reproduzível. Aplicação local: usar o princípio do seed mínimo e da cadeia explícita; não pressupor que o backend POSIX shell seja apropriado aqui.
2. **Wheeler, “Countering Trusting Trust through Diverse Double-Compiling” (ACSAC 2005).** [Artigo (PDF)](https://profsandhu.com/cs5323_s17/wheeler-2005.pdf), [versão arXiv](https://arxiv.org/abs/1004.5548). Explica DDC e suas condições. Aplicação local: manter DDC separado de self-hosting comum e registrar a segunda raiz confiável e as comparações requeridas.
3. **Myreen, “A Minimalistic Verified Bootstrapped Compiler” (CPP 2021).** [Artigo (PDF)](https://www.cse.chalmers.se/~myreen/cpp2021-bootstrap-myreen.pdf). Estuda um compilador bootstrapped formalmente verificado. Aplicação local: referência para separar confiança no bootstrap de correção/semântica verificada; verificação formal não está no primeiro escopo.
4. **GCC Internals — Makefile / bootstrap.** [Documentação oficial](https://gcc.gnu.org/onlinedocs/gccint/Makefile.html). Descreve builds por estágios, comparação de saídas e rebuild “bubble”. Aplicação local: inspiração para gates explícitos e comparação por estágio, não para replicar o complexo build system do GCC.

## Arquitetura e fases do compilador

5. **LLVM, “My First Language Frontend with LLVM” (Kaleidoscope).** [Tutorial oficial](https://llvm.org/docs/tutorial/MyFirstLanguageFrontend/). Constrói incrementalmente lexer, parser/AST, IR/code generation, objetos e debug info. Aplicação local: sequência pedagógica de cortes verticais; o tutorial não é norma de arquitetura e avisa que simplifica práticas de engenharia.
6. **Appel, “Modern Compiler Implementation”.** [Visão geral do autor](https://www.cs.princeton.edu/~appel/modern/), [descrição de tópicos](https://www.cs.princeton.edu/~appel/modern/description.html), [Cambridge University Press](https://www.cambridge.org/core/books/modern-compiler-implementation-in-ml/C2A59C37468AA8AAD0ADDCE080E3CB5D). Cobertura de frontend, IR, seleção de instruções, análise de fluxo de dados, alocação de registradores e runtime. Aplicação local: mapa de tópicos para planejar a evolução do compilador, evitando introduzir otimizações antes de haver necessidade medida.
7. **Wirth, “Compiler Construction”.** [Página do autor](https://people.inf.ethz.ch/wirth/), que disponibiliza material de construção de compiladores. Aplicação local: referência compacta para gramática, parsing, estruturas de dados e geração de código.

## Síntese para este repositório

- **Escalonar por capacidade:** um estágio só deve usar recursos que o predecessor compila; o subset é uma interface versionada, não uma expectativa implícita.
- **Manter fases testáveis:** lexer → parser/AST → semântica → IR → backend/runtime → driver, com fixtures específicas por fase.
- **Comparar estágios com cuidado:** a comparação de saídas GCC serve de modelo para estabilidade interna; DDC exige ainda uma compilação com raiz diversa sob hipóteses registradas.
- **Priorizar legibilidade do seed:** o seed é parte da cadeia de confiança e deve ser pequeno, determinístico e revisável.
- **Registrar limites:** artefato igual não prova sozinho corretude semântica, segurança do assembler/linker, independência da raiz ou ausência de diferenças ambientais.

## Regras de uso da bibliografia

Quando uma skill ou ADR aplicar uma ideia destas fontes, identifique a fonte e a adaptação. Marque claramente qualquer conclusão própria como inferência. Prefira DOI, autores/instituições e documentação oficial. Reavalie URLs antes de depender delas em automação; links de leitura são apenas referência e não devem ser baixados/buildados sem necessidade.
