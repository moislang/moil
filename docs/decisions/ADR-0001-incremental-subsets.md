# ADR-0001 — Bootstrap por subconjuntos cumulativos

- **Status:** Aceito; bootstrap inicial em andamento
- **Data:** 2026-11-21

## Contexto

Um seed limitado que tenta gerar diretamente um compilador escrito em um subconjunto muito mais amplo cria um desnível de capacidades: o seed precisa implementar um compilador complexo antes de conseguir compilar sua linguagem de implementação. A capacidade efetiva do `snl build` também depende da versão instalada e precisa ser medida.

## Decisão

Usar uma sequência de subconjuntos cumulativos. O seed compila o menor subset medido; cada estágio gera o seguinte e só usa recursos que seu predecessor suporta. Não adotar uma linguagem S separada por suposição.

## Consequências

- O primeiro seed permanece pequeno e fácil de auditar.
- Recursos entram em passos verificáveis e o compilador inicial permanece útil durante a expansão.
- A sequência de subsets, probes e fixtures torna-se parte da documentação e do CI.
- Mais estágios podem ser necessários; otimizações e recursos avançados ficam para depois do caminho vertical.

## Reabrir quando

Uma alternativa concreta (por exemplo, compilador existente compatível ou gerador externo confiável) reduzir comprovadamente a cadeia sem violar o requisito de implementação em Snovalang.

## Evidência inicial

O seed em `bootstrap/src/` é um subset Snova e compilou seu próprio source para
SnBC; a imagem seguinte coincidiu byte a byte. A matriz e as limitações estão
em [`docs/roadmap/subset.md`](../roadmap/subset.md) e
[`docs/roadmap/evidence.md`](../roadmap/evidence.md).
