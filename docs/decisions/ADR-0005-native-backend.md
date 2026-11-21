# ADR-0005 — Backend nativo aarch64-apple-darwin em Snova

- **Status:** Proposto; etapa N1 implementada (ver "Estado")
- **Data:** 2026-11-21

## Contexto

O executável gerado por `snl build` não é código de máquina do programa.
Observação de 2026-11-21: o `snl build` gera SnBC e empacota a VM C do `snl`
(`run_function` domina o perfil). A mensagem do próprio build diz "bundled
binary dependencies", e o lowering para SnBC rejeita construções que o
checker aceita. Por isso o executor SnBC em Snova roda sobre outra VM: há duas
camadas de interpretação, e a auto-compilação pela VM Snova leva minutos.

O requisito do projeto é que a compilação de Snovalang seja nativa: o
compilador em Snova deve emitir código de máquina do host para os programas e
para si mesmo, sem VM C embutida e sem `snovac`.

Sonda registrada em `evidence.md`: no host `arm64`, um `main` em assembly
montado com `as` e ligado com `ld -lSystem` executa e retorna 48. O `ld`
aplica assinatura ad-hoc (`flags=adhoc,linker-signed`), exigida pelo kernel
para executáveis arm64.

## Proposta

Alvo único inicial: `aarch64-apple-darwin`, Mach-O, AAPCS64, ligação com
`libSystem`. Cortes verticais, cada um com gate próprio:

1. **N1 — numérico.** Backend em Snova que traduz o lowering atual (funções,
   locais, aritmética, comparações, saltos, chamadas, retorno) para assembly
   textual. Gate: `numericVm`, `numericFlow` e `nativeCalls` (chamadas,
   recursão, divisão/resto por zero, deslocamentos, negação) com o mesmo código
   de saída do executor Snova e do `run-snbc`. `vmCalls` imprime e fica para N2. Neste corte, `as`/`ld` do sistema
   são ferramentas de montagem e ligação, não implementação do compilador.
2. **N2 — runtime em Snova.** Alocação, arrays, structs, strings, impressão,
   arquivos, argumentos e ambiente, escritos em Snova e compilados pelo próprio
   backend. Assembly só nas chamadas de `libSystem` (por exemplo `write`,
   `read`, `open`, `mmap`, `exit`), cada uma com contrato de ABI, registradores
   e teste (ADR-0003). Esta fronteira também resolve a conversão string→bytes
   pendente no ADR-0004.
3. **N3 — compilador nativo.** O compilador compila as próprias fontes para
   executável nativo; o executável resultante repete a compilação. Ponto fixo
   sobre o assembly emitido; o Mach-O carrega UUID/assinatura e precisa de
   política de normalização (ADR-0002).
4. **N4 — sem toolchain externa (opcional, ADR separado).** Escritor Mach-O e
   assinatura ad-hoc em Snova, eliminando `as`/`ld`.

## Estado

N1 está implementado em `bootstrap/src/native*.snl`. A entrada é
`snova-bootstrap <entrada.snl> <saida.s> native`: o compilador gera a imagem
SnBC em memória, valida e traduz para assembly. O gate é `make bootstrap-native`.
Opcodes fora do subset numérico (o primeiro encontrado, por exemplo 3 =
CONST_STRING) fazem o backend falhar com `unsupported opcode for native
backend: N`. `_exit` da `libSystem` é a única chamada externa (HALT/TRAP).
A pilha de operandos usa slots de 16 bytes, uma escolha simples ainda sem
alocação de registradores. A terceira palavra da linha de comando não é
comparada, porque o subset não compara strings do host.

## Consequências

- Até N3, `snl build` continua sendo a raiz transitória, e os documentos
  chamam seus binários de "executável empacotado com VM C", não de "nativo".
- O executor SnBC em Snova (ADR-0004) passa a ser oráculo diferencial do
  backend, sem ser o caminho de distribuição.
- O subset do seed não executa processos. Enquanto não houver essa primitiva,
  a montagem e a ligação em N1–N3 são passos do build (Makefile).

## Reabrir quando

Surgir requisito de outro alvo, o runtime ganhar execução de processos, ou N4
for priorizado.
