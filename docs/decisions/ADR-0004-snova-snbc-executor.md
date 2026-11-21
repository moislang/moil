# ADR-0004 — Executor SnBC iterativo em Snova e igualdade por valor

- **Status:** Aceito para o executor; **Proposto** para a primitiva string→bytes (seção "Fronteira provisória")
- **Data:** 2026-11-21

## Contexto

O compilador seed gera imagens SnBC que só o `snl run-snbc` executava. O
executor em Snova precisa rodar a imagem do próprio compilador e continuar
compilável pelo seed. As sondas registradas em `evidence.md` mostraram que:

- `snl run-snbc` v0.3.0 rejeita o opcode SET_INDEX (41), e o subset do seed não
  tem `a[i] = v`; a mutação disponível é SET_FIELD em structs;
- o `snl build` também gera SnBC e embute a VM C; o lowering dele rejeita
  `a[i].campo`, e cada chamada de função do host custa um quadro dessa VM;
- a VM C hospedeira limita a profundidade de chamadas (`error: call depth exceeded`);
- `==` de strings no `snl` v0.3.0 compara identidade, enquanto
  `snovac/runtime/value/value_equal.c` define igualdade estrutural.

## Decisão

1. Valores do convidado são pares `(tag, value)` guardados em células
   (`vmCell`), mutadas por parâmetros tipados. Arrays do convidado são structs
   `vmArray` com tags materializadas só quando surge um elemento não inteiro.
2. As instruções são pré-decodificadas na carga (`vmDecode.snl`): opcode,
   operandos e destinos de salto já resolvidos em índices de instrução.
3. O laço (`vmFrame.snl`) é iterativo: CALL salva o quadro em `vm.frames` e
   RETURN o restaura. O limite de 256 quadros segue `SN_VM_FRAMES_MAX` da
   referência e não depende da pilha do host.
4. `==`/`!=` comparam valores: strings por bytes e arrays/objetos campo a
   campo, com pares visitados para encerrar ciclos. Comparação de endereço
   (`&T == &E`) ainda não tem representação em SnBC e fica fora deste ADR.
5. O modo de execução é reconhecido pelo magic `SNBC` do primeiro argumento:
   `snova-bootstrap <imagem.snbc> run [args...]`. Os argumentos depois de `run`
   são os do programa. O seed ainda não compara a palavra `run`.

## Fronteira provisória (proposta pendente)

Strings vindas do host (`Runtime.environment`, `Runtime.argument`) não trazem
bytes, e o subset não converte string em bytes. Quando uma delas participa de
igualdade ou concatenação, `vmString.snl` grava o texto com `Runtime.writeText`
em `/tmp/snova-vm-string.bin` e relê os bytes com `read_bytes`. Riscos:
execuções simultâneas compartilham o arquivo, e a VM depende de `/tmp`
gravável. A execução da imagem do compilador não passa por esse caminho.

Proposta: substituir o arquivo por uma primitiva de runtime string→bytes,
registrada como fronteira de OS/ABI conforme ADR-0003, assim que o alvo de
runtime permitir. Até a decisão, o caminho continua isolado em `vmStringStart`.

## Consequências

- Divergências intencionais em relação ao `snl run-snbc` v0.3.0: igualdade de
  strings por conteúdo; argumentos repassados ao programa; mensagens de erro em
  stdout com prefixo `runtime error:`, já que o subset não escreve em stderr.
- Opcodes fora do uso do compilador (double, globais, variantes, defer/spawn)
  falham com `unsupported opcode`.
- O executor herda o custo da VM C hospedeira. A independência de desempenho e
  de runtime depende do backend nativo (ADR-0005).

## Reabrir quando

O runtime oferecer string→bytes ou stderr, o seed ganhar atribuição por índice
suportada pela referência, ou o backend nativo substituir a VM hospedeira.
