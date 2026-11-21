# CI de documentação e governança

O workflow inicial valida a presença da estrutura de planejamento e referências locais nos Markdown. Ele não compila Snovalang e não prova a arquitetura. Quando o código começar, adicionar gates por fase sem transformar checks ainda não implementados em sucesso vazio.

## Gatilhos

- Pull requests e pushes para `main` que alterem documentação, regras, skills, workflows ou scripts de validação.
- Execução manual via `workflow_dispatch`.

## Política

- Não publicar artefatos nem fazer deploy.
- Não acessar nem alterar checkout vizinho.
- Não instalar dependências de rede para validar Markdown.
- Um check de compilador só entra após haver um caminho reproduzível e versionado para executá-lo.
