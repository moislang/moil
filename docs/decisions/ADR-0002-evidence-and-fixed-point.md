# ADR-0002 — Evidência de self-hosting e ponto fixo

- **Status:** Aceito
- **Data:** 2026-11-21

## Contexto

“Compila a si mesmo”, igualdade binária, builds reproduzíveis e Diverse Double-Compiling (DDC) são propriedades diferentes. Um bootstrap pode funcionar e ainda não produzir bytes estáveis; repetir builds pela mesma raiz não prova independência.

## Decisão

Registrar separadamente: (1) bootstrap funcional com cadeia de versões; (2) determinismo de artefatos; (3) reprodutibilidade em builds limpos; (4) ponto fixo segundo comparação explícita; e (5) DDC com segunda raiz independente. Documentar toolchain, flags, alvo, normalização permitida e hash de cada artefato.

## Consequências

- Não haverá uma declaração genérica “self-hosted” sem descrever qual gate foi alcançado.
- Comparação de assembly pode ser necessária quando o formato executável carrega UUID, timestamps ou outras diferenças ambientais.
- Se não existir segunda raiz independente, DDC fica não comprovado, mesmo que os outros gates passem.

## Reabrir quando

O formato de saída ou a cadeia de confiança mudar, ou quando as comparações observadas mostrarem que outra definição de ponto fixo é mais apropriada.

## Evidência inicial

Foi comparada igualdade byte a byte de duas imagens SnBC do seed atual. Isso
registra um ponto fixo restrito ao subset e à raiz usada; não demonstra
reprodutibilidade independente nem DDC. Consulte o registro de evidências.
