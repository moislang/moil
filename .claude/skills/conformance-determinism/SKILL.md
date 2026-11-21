---
name: conformance-determinism
description: Construir diferenciais e avaliar bootstrap, determinismo, ponto fixo, reprodutibilidade e DDC com alegações precisas.
---

# Conformance e determinismo

## Matriz de evidência

Registre como dimensões separadas:

1. conformance semântica com casos de referência;
2. build e execução do compilador sucessor;
3. compilação do próprio source pelo estágio recém-gerado;
4. igualdade de saídas entre estágios e definição do artefato comparado;
5. builds limpos repetidos com fontes, flags e toolchain fixados;
6. DDC com compilador diverso/root independente e hipóteses explicitadas.

## Procedimento

1. Fixe corpus e versão da referência.
2. Compare stdout, stderr, código de saída, diagnóstico/span e artefatos conforme o tipo de caso.
3. Torne diffs determinísticos e reproduzíveis; preserve os casos que revelaram diferenças.
4. Para fixed point, explique quais bytes são comparados e qual normalização ambiental é permitida.
5. Para DDC, identifique concretamente a origem confiável diversa; repetir compilação sob o mesmo compilador não basta.
6. Registre sucessos e falhas por alvo/fase, sem arredondar porcentagens sem denominador.

## Relato

Use “compila o próprio código” só após o estágio reportado fazê-lo. Use “reprodutível” só após builds limpos comparados. Use “DDC comprovado” somente com segunda raiz independente e condições do método documentadas.
