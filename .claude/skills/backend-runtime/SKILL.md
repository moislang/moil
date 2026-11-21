---
name: backend-runtime
description: Projetar backend, ABI e runtime mantendo a lógica em Snovalang e delimitando assembly às fronteiras do host.
---

# Backend e runtime

## Fronteiras

Comece com um único alvo host. Descreva target triple, formato de objeto, ABI, calling convention, alinhamento, stack frame, símbolos, relocations, linker e runtime necessário. Assembly é permitido para chamadas ABI/OS demonstravelmente ausentes da linguagem. Não use C como caminho paralelo.

## Procedimento

1. Escolha um programa vertical mínimo e desenhe o fluxo IR → assembly/objeto → link → execução.
2. Especifique calling convention e ownership de registradores/stack antes de emitir chamadas.
3. Implemente operações básicas e compare saída/desempenho apenas se isso for requisito.
4. Adicione chamadas externas e runtime por interfaces pequenas, tipadas e testáveis.
5. Verifique overflow, alinhamento, preservação de registradores, símbolos e comportamento de saída/erro.
6. Registre diferenças entre gerar assembly, montar, linkar e executar; não os chame genericamente de cross-compile validado.
7. Só adicione outra arquitetura após o host ter casos verticais estáveis.

Cada rotina assembly requer comentário de contrato, plataforma/ABI, registradores consumidos/preservados e chamada de teste correspondente.
