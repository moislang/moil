---
name: bootstrap-incremental
description: Planejar ou implementar um estágio do compilador self-hosted sem criar desnível entre o seed e a linguagem usada pelo próximo estágio.
---

# Bootstrap incremental Snovalang

## Quando usar

Use ao planejar probes do `snl`, escolher subset, desenhar seed, implementar uma feature do compilador, adicionar uma etapa de bootstrap ou avaliar evidência de self-hosting.

Use também as skills especializadas conforme a fase: `bootstrap-stage`, `compiler-frontend`, `semantic-ir`, `backend-runtime`, `conformance-determinism` e `self-hosting-research`.

## Restrições

- Trabalhe apenas no checkout atual; `../snovac` é referência somente leitura.
- Priorize `.snl`/`.sns`. Use assembly apenas em fronteiras justificadas e nunca C como implementação paralela sem decisão explícita.
- Não presuma que a versão, sintaxe ou runtime instalado correspondem à documentação histórica. Registre a versão antes das sondas.
- Não chame um build de DDC se a segunda raiz não for independente.

## Procedimento

1. **Identifique o estágio.** Leia `docs/roadmap/stages.md`, `docs/roadmap/evidence.md`, ADRs e matriz atual do subset.
2. **Meça a capacidade necessária.** Faça probe mínimo e isolado para cada recurso do `snl` do qual o próximo estágio depende. Registre comando, versão e saída.
3. **Defina o subconjunto.** Liste construções aceitas/rejeitadas, semântica, limites e fixtures. Garanta que fontes do estágio N+1 só usem recursos compiláveis por N.
4. **Escolha o menor caminho vertical.** Seed → artefato executável → teste funcional. Adie recursos sem dependência direta.
5. **Defina contratos.** Tipos, ownership, erros/diagnósticos, spans, formatos de IR/artefato, ABI e determinismo.
6. **Organize os módulos.** Use arquivos `.snl` em `camelCase`, pacotes/imports explícitos entre módulos, APIs públicas pequenas e arquivos abaixo de 400 linhas quando possível.
7. **Implemente por cortes.** Cada corte inclui comportamento positivo e negativo e pode ser compilado pelo predecessor existente.
8. **Compare com referência.** Quando aplicável, rode corpus diferencial e agrupe divergências por fase; não aceite só “compila”.
9. **Registre evidência.** Atualize `evidence.md` com ambiente, comandos, resultados, hashes e limitações.
10. **Avalie a afirmação correta.** Diga separadamente se bootstrap, self-compilation, fixed point, reprodutibilidade ou DDC foram demonstrados.

## Checklist de revisão

- [ ] O estágio anterior constrói integralmente o próximo?
- [ ] Todas as capacidades do host têm probes atuais?
- [ ] Há casos aceitos, rejeitados e diagnósticos com posição?
- [ ] O assembly introduzido tem contrato e não duplica lógica de alto nível?
- [ ] Arquivos e APIs mantêm o limite de tamanho e o padrão `camelCase`?
- [ ] Saída e ordenação são determinísticas?
- [ ] A evidência distingue execução, cross-compile, fixed point e DDC?
- [ ] `../snovac` permaneceu intocado?

## Saída esperada ao planejar

Entregue: estágio e objetivo; subset predecessor/sucessor; probes; arquivos previstos; contratos; critérios de aceite; riscos e dependências; evidência necessária. Não transforme itens futuros em funcionalidades já disponíveis.
