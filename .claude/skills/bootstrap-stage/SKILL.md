---
name: bootstrap-stage
description: Especificar e executar um estágio incremental do bootstrap, garantindo que o predecessor compile o sucessor.
---

# Planejamento de estágio de bootstrap

Leia `.claude/skills/bootstrap-incremental/SKILL.md`, `docs/roadmap/stages.md` e a bibliografia antes de começar.

## Passos

1. Identifique seed e compiler predecessor exatos, revisão, host e subset aceito.
2. Faça probes pequenos dos recursos exigidos; registre a saída sem depender de documentação não verificada.
3. Descreva subset anterior e extensão nova, com exemplos aceitos/rejeitados.
4. Defina entradas/saídas, contrato do artefato, diagnósticos, erros de build e comandos reprodutíveis.
5. Proponha o menor corte vertical que o predecessor consiga construir.
6. Planeje bootstrap sequencial, limpeza de diretórios, origem das ferramentas e comparação de artefatos.
7. Declare gates e limitações; DDC só é plano elegível quando existe raiz independente identificada.
8. Atualize roadmap/evidence/ADR conforme o estágio, sem apresentar plano como conclusão.

## Saída

Entregue objetivo, subset, arquivos, probes, cadeia de comandos, gates, dependências, riscos, fallback e evidência esperada. Não amplie o escopo com alvos ou runtime avançados sem dependência demonstrada.
