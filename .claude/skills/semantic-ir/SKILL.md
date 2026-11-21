---
name: semantic-ir
description: Planejar semântica, resolução de nomes/tipos e IR intermediária com invariantes explícitas.
---

# Semântica e representação intermediária

## Semântica

Separe descoberta de símbolos, resolução, inferência/checking de tipos, validação de controle e lowering. Defina ordem e recuperação após erro. Tipos e diagnósticos devem ser tipados, estáveis e testáveis. Não imite um comportamento do compilador de referência sem fixture que o demonstre.

## IR

Antes de adicionar IR, registre quais problemas ela resolve frente a AST tipada direta. Se introduzida, defina:

- valores, blocos, terminadores, parâmetros e convenção de retorno;
- tipos suportados e representação de valores;
- invariantes verificáveis antes/depois de cada lowering;
- ownership/lifetime e origem dos spans;
- serialização determinística se a IR sair do processo.

## Fluxo

1. Escreva semântica observável e exemplos positivos/negativos.
2. Defina diagnóstico e localize fase responsável.
3. Escolha a menor representação que suporte o estágio atual.
4. Implemente validações de invariantes e casos de divergência.
5. Garanta que o predecessor compila todo o código novo.

Não introduza generics completos, closures, exceções, otimizações ou CFG SSA apenas por simetria com outro compilador. Justifique pelo próximo marco.
