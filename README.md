# snl

Este repositório desenvolve um compilador Snovalang escrito em Snova. O compilador é a única peça pública do projeto; o código-fonte do compilador e de seu runtime permanece em `.snl` e evolui por estágios de bootstrap.

## Comece por aqui

1. [Visão de arquitetura](docs/architecture/overview.md)
2. [Roadmap incremental](docs/roadmap/stages.md)
3. [Decisões arquiteturais](docs/decisions/README.md)
4. [Regras para contribuição](.claude/rules/architecture.md)
5. Skill [bootstrap-incremental](.claude/skills/bootstrap-incremental/SKILL.md)
6. [Fluxo de trabalho](docs/workflows/development.md)
7. [Bibliografia de compiladores](docs/research/compiler-literature.md)
8. Subagents Claude Code em `.claude/agents/`
9. [Subset atual do compilador](docs/roadmap/subset.md)

## Princípios

- Cada compilador compila a próxima revisão: não se exige que o primeiro seed entenda toda a linguagem.
- O compilador é escrito em Snovalang; assembly fica restrito a interfaces inevitáveis com o sistema e ao seed inicial onde a linguagem hospedeira não basta.
- Capacidades do `snl` instalado são premissas a medir em sondas reproduzíveis, nunca fatos presumidos pelo plano.
- `../snovac` é referência somente leitura para comparação e proveniência.
- C/C++ não é usado para implementar o compilador neste repositório. O `snl` instalado é somente a raiz transitória do bootstrap inicial.
- Self-hosting, ponto fixo, reprodutibilidade e DDC são afirmações distintas, cada uma com evidência própria.

## Estado

## Bootstrap atual

O diretório `bootstrap/src/` contém módulos Snova no pacote `snova.compiler`. A API pública em `api.snl` é importada e verificada por `apiConsumer.snl`; os arquivos usam `camelCase` e permanecem abaixo de 400 linhas. `make bootstrap-check` verifica o projeto multi-arquivo e o seed; `make bootstrap-smoke`, `make bootstrap-diagnostics` e `make bootstrap-fixed-point` cobrem execução e auto compilação do subset. O seed ainda usa o runtime do `snl` e um joiner temporário porque não compila projetos multi-arquivo por conta própria. Isso não equivale à reescrita completa nem à compatibilidade com `snovac`. Consulte o [registro de evidências](docs/roadmap/evidence.md) e a [matriz de subset](docs/roadmap/subset.md).
