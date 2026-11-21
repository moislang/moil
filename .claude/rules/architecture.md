# Regras de arquitetura do compilador

- Este checkout é o limite de escrita. Trate `../snovac` como referência somente leitura.
- A meta é implementar compilador e runtime em Snovalang. Não migre para C por conveniência.
- Assembly é permitido apenas no seed mínimo/ABI/OS quando a sonda provar que não há alternativa Snovalang. Documente cada fronteira.
- O predecessor deve compilar o código do estágio seguinte. Nunca introduza recurso de linguagem no compilador sem atualizar a matriz do subset e fixtures.
- Confirme a versão e as capacidades do `snl` instalado com probes; não confie em notas históricas ou no plano como evidência atual.
- Separe lexer, parser, semântica, IR, backend, runtime e driver por contratos explícitos; evite regras de linguagem escondidas no driver.
- Use estruturas e retornos tipados; diagnósticos são dados com código e span. Preserve determinismo em símbolos, erros e artefatos.
- Nomeie funções, classes, structs, interfaces e arquivos-fonte em `camelCase` por padrão.
- Não declare self-hosting, ponto fixo, reprodutibilidade ou DDC sem evidência correspondente registrada.
- Uma feature exige especificação, caso válido, caso inválido e gate de construção pelo predecessor.
- Não adicione dependência, alvo, exceção, concorrência ou GC avançado ao primeiro corte vertical sem ADR/roadmap atualizado.
