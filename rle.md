# text-compressor-in-assembly
# Compactador de Texto RLE em Assembly x86-64

> Projeto Final de **Organização e Arquitetura de Computadores** — UFAL, Instituto de Computação (Prof. Lucas Amorim).
> **Opção 03:** Compactador de Texto (Run-Length Encoding).

Programa escrito em **assembly x86-64 (NASM) para Linux**, **sem nenhuma biblioteca** (nem a libc): toda entrada e saída é feita
diretamente com chamadas de sistema (`syscall`). Ele comprime e descomprime arquivos de texto usando RLE, por exemplo
`AAAAABBBCC` → `5A3B2C` e de volta.

```text
.
├── rle.asm      # o programa (único arquivo de código)
└── README.md    # este arquivo
```

**Como ler este README:** as seções 1 a 5 mostram o que o programa faz e como usá-lo; a seção 6 revisa os conceitos de assembly;
a seção 7 explica **cada parte do código**, na mesma ordem em que ele aparece em `rle.asm`; as demais trazem rastreios, testes e dicas.

## Sumário

- [1. O que é RLE](#1-o-que-é-rle)
- [2. Como montar e executar](#2-como-montar-e-executar)
- [3. Como usar o programa](#3-como-usar-o-programa)
- [4. Formato e limitações](#4-formato-e-limitações)
- [5. Visão geral do código](#5-visão-geral-do-código)
- [6. Conceitos de assembly usados](#6-conceitos-de-assembly-usados)
- [7. O código, parte a parte](#7-o-código-parte-a-parte)
- [8. Execução de ponta a ponta](#8-execução-de-ponta-a-ponta)
- [9. Testes](#9-testes)
- [10. Problemas comuns](#10-problemas-comuns)
- [11. Limitações e ideias de melhoria](#11-limitações-e-ideias-de-melhoria)

## 1. O que é RLE

**Run-Length Encoding** (codificação por comprimento de sequência) troca cada sequência de caracteres iguais (uma "corrida") por
**quantos são** seguido de **qual é** o caractere.

```text
Original   : A A A A A B B B C C        (10 bytes)
Sequências : 5×A   3×B   2×C
Comprimido : 5 A 3 B 2 C                (6 bytes)
```

O programa é uma tradução direta destes dois algoritmos:

```text
COMPRESSÃO                                    DESCOMPRESSÃO
i = 0                                         n = 0 ; viu_digito = falso
enquanto i < tamanho:                         para cada byte b do arquivo comprimido:
    c = texto[i]                                  se b é dígito ('0'..'9'):
    n = 0                                             n = n * 10 + (b - '0')
    enquanto i < tamanho e texto[i] == c:             viu_digito = verdadeiro
        n = n + 1                                 senão:
        i = i + 1                                     se não viu_digito: ERRO
    escreva n em decimal                              escreva b repetido n vezes
    escreva c                                         n = 0 ; viu_digito = falso
                                              se viu_digito ao final: ERRO
```

## 2. Como montar e executar

O programa usa **syscalls do Linux**, então precisa de Linux (ou do WSL no Windows). São três etapas:

| Etapa | Comando | O que faz |
|---|---|---|
| 1. Montar | `nasm -f elf64 rle.asm -o rle.o` | O assembler (NASM) traduz o texto assembly em código de máquina (arquivo objeto). `-f elf64` = formato de objeto do Linux 64 bits. |
| 2. Ligar | `ld rle.o -o rle` | O linker junta o objeto em um executável e define `_start` como ponto de entrada. Usa-se `ld` direto (e não `gcc`) justamente para **não** incluir a libc. |
| 3. Executar | `./rle` | Roda o programa. O `./` é necessário porque a pasta atual não está no PATH. |

### Linux (Mint, Ubuntu, Debian...)

```bash
sudo apt update
sudo apt install nasm binutils      # nasm = assembler ; binutils = ld (linker)

nasm -f elf64 rle.asm -o rle.o
ld rle.o -o rle
./rle
```

### Windows 10 (via WSL)

O programa **não roda direto no Windows** (cmd/PowerShell), pois os serviços do sistema são acessados de outra forma. Use o WSL, que roda um Linux dentro do Windows:

1. Confira a versão: `Win + R`, digite `winver`. O `wsl --install` exige **Windows 10 versão 2004 ou superior (build 19041+)**.
2. No menu Iniciar, abra o "Windows PowerShell (Administrador)" e execute `wsl --install`. Depois **reinicie**.
3. Ao abrir o Ubuntu pela primeira vez, crie usuário e senha (a senha não aparece enquanto você digita; é normal).
4. No terminal do Ubuntu: `sudo apt update && sudo apt install nasm binutils`.
5. Copie o `rle.asm` para a pasta home do Linux: `cp /mnt/c/Users/SEU_USUARIO/Downloads/rle.asm ~/` (o disco do Windows aparece em `/mnt/c/`).
6. Execute os mesmos comandos da seção Linux.

Se `wsl --install` mostrar só o texto de ajuda, use `wsl --list --online` e depois `wsl --install -d Ubuntu`.

> **Computador com processador ARM** (Mac com chip M, Raspberry Pi): o erro `Exec format error` indica que o programa é x86-64. Use um PC x86 ou emulação.

## 3. Como usar o programa

```console
$ printf 'AAAAABBBCC' > teste.txt        # cria o arquivo de teste SEM quebra de linha
$ ./rle

=== Compactador RLE ===
1 - Comprimir arquivo
2 - Descomprimir arquivo
0 - Sair
Opcao: 1
Arquivo de entrada: teste.txt
Arquivo de saida: teste.rle
Arquivo gravado com sucesso!
Bytes lidos    : 10
Bytes gravados : 6

=== Compactador RLE ===
...
Opcao: 0
Ate logo!

$ cat teste.rle
5A3B2C
```

Para descomprimir, escolha `2`, informe `teste.rle` como entrada e `restaurado.txt` como saída. Para conferir:
`cmp teste.txt restaurado.txt && echo IGUAIS`.

> `echo "AAAAABBBCC" > t.txt` **inclui um Enter** no final (11 bytes). O comprimido fica `5A3B2C1` seguido de uma quebra de linha (o `1` + `\n` final), e a volta restaura o arquivo igual. Use `printf` quando quiser o resultado exato do enunciado.

## 4. Formato e limitações

| Situação | O que acontece | Tratamento no programa |
|---|---|---|
| Texto com **dígitos** (0-9) | Ambíguo: `111` viraria `31`, e na volta não dá para saber se o `1` é contador ou caractere. | `comprimir` detecta o dígito e mostra erro. |
| Texto **sem repetições** | `ABC` → `1A1B1C`: o arquivo **dobra** de tamanho (pior caso do RLE). | Comportamento normal do RLE. |
| Quebra de linha | O `\n` é um caractere como outro; um arquivo terminado em Enter gera `1` + `\n` no final do comprimido. | Ida e volta restauram o arquivo exatamente. |
| Entrada com 64 KB ou mais | Não cabe no buffer de entrada (65 536 bytes). | Mostra erro (não trunca em silêncio). O maior arquivo aceito tem 65 535 bytes. |
| Arquivo comprimido inválido | Ex.: `5A3` (número sem caractere) ou `AB` (caractere sem número). | `descomprimir` mostra erro de formato. |
| Contador gigante | Ex.: `99999999999A` geraria bilhões de bytes. | Limite de 1 MB na saída; mostra erro. |
| Nome de arquivo com mais de 255 caracteres | Não cabe no buffer do nome. | O excesso é ignorado (o nome fica truncado). |

## 5. Visão geral do código

### Fluxo do programa

```text
        _start (menu) ──── opção 0 ────► exit(0)
            │
            ▼  opção 1 ou 2  (guarda em r12 a rotina: comprimir / descomprimir)
        pedir_nomes         lê nome_in e nome_out
            │
        PASSO carregar_entrada      open + read + close   →  buf_in
            │
        PASSO r12                   comprimir ou descomprimir:  buf_in → buf_out
            │
        PASSO gravar_saida          open + write + close  ←  buf_out
            │
        mostrar_resumo              mensagem de sucesso e tamanhos
            │
            └──────────────► volta ao menu

  Se qualquer PASSO devolver rax = -1 (erro), a mensagem já foi mostrada e o programa volta ao menu.
```

### Mapa do arquivo `rle.asm`

| Parte | Linhas | Explicação |
|---|---|---|
| Cabeçalho (comentários) | 1–11 | [7.1](#71-cabeçalho) |
| Constantes | 13–24 | [7.2](#72-constantes) |
| Macros `MSG`, `PRINT`, `ERRO`, `PASSO` | 26–54 | [7.3](#73-macros) |
| `section .data` (textos) | 57–79 | [7.4](#74-seção-data-textos) |
| `section .bss` (memória reservada) | 82–91 | [7.5](#75-seção-bss-memória-reservada) |
| `_start` | 97–137 | [7.6](#76-_start-o-menu-principal) |
| `ler_linha` | 138–172 | [7.7](#77-ler_linha-ler-texto-do-teclado) |
| `pedir_nomes` | 173–186 | [7.8](#78-pedir_nomes) |
| `carregar_entrada` | 187–220 | [7.9](#79-carregar_entrada-ler-o-arquivo-para-a-memória) |
| `comprimir` | 221–267 | [7.10](#710-comprimir-o-coração-do-projeto) |
| `descomprimir` | 268–327 | [7.11](#711-descomprimir-o-caminho-inverso) |
| `escrever_decimal` | 328–359 | [7.12](#712-escrever_decimal-de-número-para-texto) |
| `gravar_saida` | 360–391 | [7.13](#713-gravar_saida-gravar-o-resultado) |
| `mostrar_resumo`, `imprimir_numero` | 392–419 | [7.14](#714-mostrar_resumo-e-imprimir_numero) |
| `section .note.GNU-stack` | 420–421 | [7.15](#715-nota-final-gnu-stack) |

### Sub-rotinas: entrada e saída

| Sub-rotina | Entrada | Saída | Syscalls |
|---|---|---|---|
| `ler_linha` | `rdi` = buffer, `rsi` = tamanho | `rax` = 0 (ok) ou -1 (EOF) | `read` |
| `pedir_nomes` | — | preenche `nome_in` e `nome_out` | `write`, `read` |
| `carregar_entrada` | `nome_in` | `buf_in`, `tam_in`; `rax` = 0 ou -1 | `open`, `read`, `close` |
| `comprimir` | `buf_in`, `tam_in` | `buf_out`, `tam_out`; `rax` = 0 ou -1 | `write` (só nos erros) |
| `descomprimir` | `buf_in`, `tam_in` | `buf_out`, `tam_out`; `rax` = 0 ou -1 | `write` (só nos erros) |
| `escrever_decimal` | `rcx` = número, `rdi` = destino | `rdi` avança; preserva `rax` e `rbx` | — |
| `gravar_saida` | `nome_out`, `buf_out`, `tam_out` | `rax` = 0 ou -1 | `open`, `write`, `close` |
| `mostrar_resumo` | `tam_in`, `tam_out` | imprime na tela | `write` |
| `imprimir_numero` | `rcx` = número | imprime o número e uma quebra de linha | `write` |

**Convenção do projeto:** toda etapa que pode falhar devolve `rax = 0` (sucesso) ou `rax = -1` (erro). O chamador testa com
`test rax, rax` e `js` (salta se negativo). A própria etapa já mostra a mensagem de erro.

## 6. Conceitos de assembly usados

### Programa sem bibliotecas: `_start` em vez de `main`

Em C, o programa começa em `main`, mas quem chama `main` é a biblioteca C. Sem ela, o programa começa em **`_start`**, o ponto de entrada do
executável (ELF): o kernel entrega o controle ali. Consequências: não há para onde "retornar", então o programa **precisa terminar com a syscall `exit`**
(senão o processador executaria bytes que não são código e o programa travaria); e para ler, escrever e abrir arquivos o programa pede serviços ao kernel com a instrução `syscall`.

### Registradores

Registradores são variáveis minúsculas dentro do processador. Os de uso geral têm 64 bits e podem ser usados em pedaços: `rax` (64) → `eax` (32) → `ax` (16) → `al` (8 bits baixos).

| Registrador | Partes | Uso neste projeto |
|---|---|---|
| `rax` | `eax`, `al` | Número da syscall (entrada) e valor de retorno (saída). Na compressão, `al` guarda o caractere da sequência. |
| `rbx` | `ebx` | Divisor 10 em `escrever_decimal`; número lido em `descomprimir`. |
| `rcx` | `ecx` | Contador (tamanho da sequência / repetições). **A `syscall` destrói `rcx`.** |
| `rdx` | `edx`, `dl` | 3º argumento das syscalls; resto da divisão por `div`. |
| `rsi` | `esi` | 2º argumento das syscalls; ponteiro de **leitura** nos laços. |
| `rdi` | `edi` | 1º argumento das syscalls; ponteiro de **escrita** nos laços. |
| `r8`–`r10` | `r8d`… | Auxiliares: fim da entrada, descritor de arquivo, bytes lidos, flags. |
| `r12` | — | Endereço da rotina escolhida no menu (`comprimir` ou `descomprimir`). |
| `rsp` | — | Topo da pilha (usado por `push`, `pop`, `call`, `ret`). |

> Escrever em um registrador de 32 bits (ex.: `mov eax, 1`) **zera automaticamente** os 32 bits altos do de 64 bits. Por isso o código usa `mov eax, ...` e `xor eax, eax`: a instrução fica mais curta e o efeito é o mesmo.

### Instruções usadas

| Instrução | O que faz | Exemplo no código |
|---|---|---|
| `mov d, s` | Copia `s` para `d`. | `mov r8, rax` |
| `movzx d, s` | Copia um byte completando com zeros. | `movzx eax, byte [rsi]` |
| `lea d, [expr]` | Calcula um endereço **sem acessar a memória**. | `lea rdx, [rdi + rbx]` |
| `add`, `sub` | Soma e subtrai. | `add r8, rsi` |
| `inc`, `dec` | Soma/subtrai 1. | `inc rsi` |
| `imul d, s, k` | Multiplica (com sinal). | `imul rbx, rbx, 10` |
| `div r` | Divide `rdx:rax` por `r`. Quociente em `rax`, resto em `rdx`. | `div rbx` |
| `xor a, a` | Zera `a` (truque rápido). | `xor ecx, ecx` |
| `rep stosb` | Grava `al` em `[rdi]` e avança `rdi`, repetindo `rcx` vezes. | `rep stosb` |
| `cmp a, b` | Calcula `a - b` **só para ajustar as flags**. | `cmp al, '0'` |
| `test a, a` | AND de `a` com `a`: ajusta as flags conforme o valor de `a`. | `test rax, rax` |
| `jmp`, `je`, `jne`… | Saltos (incondicional e condicionais). | `jae .fim` |
| `push`, `pop` | Empilha / desempilha 8 bytes. | `push rdx` |
| `call`, `ret` | Chama uma sub-rotina / volta dela. | `call ler_linha` |
| `syscall` | Pede um serviço ao kernel. | `syscall` |

### Flags e saltos condicionais

`cmp` e `test` não guardam resultado: só **ajustam flags** (ZF = zero, SF = sinal, CF = vai-um/empréstimo). O salto seguinte decide olhando as flags.

| Salto | Significa | Onde aparece e por quê |
|---|---|---|
| `je` / `jne` | igual / diferente | Comparar o caractere atual com o da sequência; opção do menu. |
| `jb` `jbe` `ja` `jae` | abaixo / acima, **sem sinal** | Caracteres e **endereços** são valores sem sinal. Ex.: `cmp al, '0'` + `jb`. |
| `js` | resultado negativo (SF = 1) | As syscalls devolvem erro como número **negativo**: `test rax, rax` + `js .erro`. |
| `jle` | menor ou igual a zero (com sinal) | `ler_linha` testa o retorno de `read`: 0 (EOF) ou negativo (erro). |

### Pilha, `call` e `ret`

A pilha é como uma pilha de pratos: `push` coloca no topo, `pop` retira do topo (o último a entrar é o primeiro a sair). `call rotina` empilha o endereço da próxima instrução e salta; `ret` desempilha esse endereço e volta. **Tudo que for empilhado dentro de uma rotina precisa ser desempilhado antes do `ret`**, senão o `ret` volta para o lugar errado.

### Syscalls do Linux x86-64

O **número** da syscall vai em `rax`; os argumentos em `rdi`, `rsi`, `rdx` (nessa ordem); depois executa-se `syscall`. O resultado volta em `rax`; valor **negativo = erro**. A instrução destrói `rcx` e `r11`.

| Syscall | `rax` | `rdi` | `rsi` | `rdx` | Uso no projeto |
|---|---|---|---|---|---|
| `read` | 0 | fd | endereço do buffer | máx. de bytes | Ler teclado (fd 0) e arquivo. |
| `write` | 1 | fd | endereço do texto | nº de bytes | Escrever na tela (fd 1) e em arquivo. |
| `open` | 2 | endereço do nome (texto terminado em 0) | flags | permissões | Abrir/criar arquivo; devolve o fd. |
| `close` | 3 | fd | — | — | Fechar o arquivo. |
| `exit` | 60 | código de saída | — | — | Terminar o programa. |

**Descritor de arquivo (fd):** número que identifica um arquivo aberto. Já existem 0 = teclado (stdin), 1 = tela (stdout) e 2 = erros (stderr); `open` devolve o próximo livre (3, 4…).

### ASCII: texto também é número

| Caractere | Código | Uso |
|---|---|---|
| `'0'` … `'9'` | 48 … 57 | Dígito → valor: `c - '0'`. Valor → dígito: `v + '0'`. |
| `'\n'` (Enter) | 10 | Marca o fim de uma linha digitada. |
| `'A'` | 65 | Exemplo de caractere comum. |

## 7. O código, parte a parte

Cada subseção mostra o trecho **exatamente como está em `rle.asm`**, seguido da explicação.

### 7.1 Cabeçalho

```nasm
; =====================================================================
; rle.asm - Compactador de texto usando Run-Length Encoding (RLE)
; Projeto Final de Organização e Arquitetura de Computadores - UFAL
;
; x86-64, Linux, NASM. Sem bibliotecas (nem libc): só syscalls.
; Exemplo:  AAAAABBBCC  ->  5A3B2C   (e o caminho inverso)
;
;     nasm -f elf64 rle.asm -o rle.o
;     ld rle.o -o rle
;     ./rle
; =====================================================================
```

Tudo que começa com `;` é **comentário** (o montador ignora). O cabeçalho identifica o projeto, a plataforma, a regra de não usar bibliotecas e os três
comandos para montar e executar. As linhas de `=====` e `-----` são só separadores visuais.

### 7.2 Constantes

```nasm
; ---------- Constantes ------------------------------------------------
SYS_READ    equ 0
SYS_WRITE   equ 1
SYS_OPEN    equ 2
SYS_CLOSE   equ 3
SYS_EXIT    equ 60

O_WRONLY_CREAT_TRUNC equ 0x241  ; só escrita + criar + apagar conteúdo
PERMISSAO   equ 0o644           ; rw-r--r--

BUF_IN_MAX  equ 65536           ; buffer de entrada (64 KB)
BUF_OUT_MAX equ 1048576         ; buffer de saída (1 MB)
```

`equ` dá um **nome a um número**. O NASM troca o nome pelo valor na hora de montar: a constante **não ocupa memória** e não é uma variável.
Sem elas, o código teria "números mágicos" (`mov eax, 2` em vez de `mov eax, SYS_OPEN`).

| Constante | Valor | Significado |
|---|---|---|
| `SYS_READ` | 0 | Número da syscall `read` (ler bytes). |
| `SYS_WRITE` | 1 | Número da syscall `write` (escrever bytes). |
| `SYS_OPEN` | 2 | Número da syscall `open` (abrir/criar arquivo). |
| `SYS_CLOSE` | 3 | Número da syscall `close` (fechar arquivo). |
| `SYS_EXIT` | 60 | Número da syscall `exit` (terminar o programa). |
| `O_WRONLY_CREAT_TRUNC` | `0x241` | Flags do `open` para **gravar** (detalhe abaixo). |
| `PERMISSAO` | `0o644` | Permissões do arquivo criado, em octal. |
| `BUF_IN_MAX` | 65536 | Tamanho do buffer de entrada (64 KB = 2¹⁶). |
| `BUF_OUT_MAX` | 1048576 | Tamanho do buffer de saída (1 MB = 2²⁰). |

Os números das syscalls são definidos pelo kernel do Linux para x86-64 (em ARM ou no Windows seriam outros).

**Como `0x241` é formado.** São três flags, combinadas somando os bits:

| Flag | Hexadecimal | Binário (12 bits) | Efeito |
|---|---|---|---|
| `O_WRONLY` | `0x001` | `0000 0000 0001` | Abrir somente para escrita |
| `O_CREAT` | `0x040` | `0000 0100 0000` | Criar o arquivo se ele não existir |
| `O_TRUNC` | `0x200` | `0010 0000 0000` | Apagar o conteúdo anterior |
| **Soma** | **`0x241`** | `0010 0100 0001` | Tudo junto |

**Como `0o644` é lido.** Cada dígito octal são 3 bits de permissão (r = ler, w = escrever, x = executar): `6` = `110` = `rw-` (dono lê e escreve),
`4` = `100` = `r--` (grupo só lê), `4` = `r--` (outros só leem). Equivale a `rw-r--r--`. A permissão só vale quando o arquivo é **criado** agora.

**Por que esses tamanhos de buffer.** A compressão nunca passa do **dobro** da entrada (pior caso: cada caractere vira "1" + caractere), ou seja, no máximo
2 × 65 535 = 131 070 bytes, que cabe com folga em 1 MB. Já a descompressão pode expandir muito (`1000A` gera 1000 bytes a partir de 5), por isso o limite de 1 MB é conferido
durante a execução.

### 7.3 Macros

Uma **macro** é um "recorte e cola" feito pelo montador: em cada lugar onde ela é usada, o NASM copia o corpo da macro, trocando os parâmetros
(`%1`, `%2`...) pelos valores passados. **Não é uma função**: não há `call`/`ret`, e o código é repetido em cada uso.

#### `MSG`: definir um texto e seu tamanho

```nasm
; MSG nome, bytes... : define um texto e calcula o seu tamanho (nome_len)
%macro MSG 2+
%1:         db %2
%1_len      equ $ - %1
%endmacro
```

`%macro MSG 2+` define uma macro com 2 parâmetros; o `+` significa que o **último parâmetro engole todo o resto da linha**, inclusive as vírgulas
(por isso dá para escrever vários textos e números separados por vírgula). `%1` é o nome e `%2` é o conteúdo.

| Linha | O que faz |
|---|---|
| `%1:         db %2` | Cria o rótulo `nome` e grava na memória os bytes dados (`db` = define byte). |
| `%1_len      equ $ - %1` | `$` é o endereço atual (logo depois do texto). Subtrair o endereço do início dá o **tamanho em bytes**, calculado automaticamente. O nome fica `nome_len`. |

```nasm
MSG msg_nl, 10
; o NASM transforma em:
msg_nl:      db 10
msg_nl_len   equ $ - msg_nl        ; = 1
```

#### `PRINT`: escrever na tela

```nasm
; PRINT nome : escreve na tela o texto definido por MSG
%macro PRINT 1
    mov eax, SYS_WRITE
    mov edi, 1                  ; fd 1 = tela
    mov rsi, %1                 ; endereço do texto
    mov edx, %1_len             ; quantidade de bytes
    syscall
%endmacro
```

Escreve na tela um texto criado por `MSG`. Usa a syscall `write` (`rax` = 1):

| Linha | O que faz |
|---|---|
| `mov eax, SYS_WRITE` | `rax` = 1: número da syscall `write`. |
| `mov edi, 1` | 1º argumento: descritor 1 = saída padrão (tela). |
| `mov rsi, %1` | 2º argumento: **endereço** do texto. |
| `mov edx, %1_len` | 3º argumento: quantidade de bytes (`%1_len` vira, por exemplo, `msg_tchau_len`). |
| `syscall` | O kernel escreve o texto. |

Depois de um `PRINT`, os registradores `rax`, `rcx`, `rdx`, `rsi`, `rdi` e `r11` **foram alterados**.

#### `ERRO`: mostrar mensagem e sair da rotina com erro

```nasm
; ERRO nome : mostra a mensagem e sai da rotina devolvendo rax = -1
%macro ERRO 1
    PRINT %1
    mov rax, -1
    ret
%endmacro
```

Mostra a mensagem, coloca `-1` em `rax` (sinal de erro) e executa `ret`. Por terminar com `ret`, só se usa `ERRO` no **fim** de uma rotina, em um rótulo de erro (ex.: `.erro:`).

#### `PASSO`: chamar uma etapa e tratar o erro

```nasm
; PASSO rotina : chama a rotina; se ela devolver erro (rax < 0), volta ao menu
%macro PASSO 1
    call %1
    test rax, rax
    js .menu
%endmacro
```

```nasm
PASSO carregar_entrada
; o NASM transforma em:
call carregar_entrada      ; executa a etapa
test rax, rax              ; ajusta as flags conforme rax (0 = ok, -1 = erro)
js .menu                   ; se rax for negativo, volta ao menu
```

O `.menu` é um rótulo **local** de `_start`, onde a macro é usada, por isso o salto funciona.

|  | Macro | Função (`call`/`ret`) |
|---|---|---|
| Como funciona | O montador **copia** o corpo em cada uso | Existe **uma vez** na memória; é chamada com `call` |
| Custo | Mais código, mas sem `call`/`ret` | Menos código, com pequeno custo de chamada |
| Usada aqui para | Trechos curtos e repetitivos (`PRINT`, `ERRO`, `PASSO`, `MSG`) | Rotinas maiores (`comprimir`, `ler_linha`...) |

### 7.4 Seção `.data`: textos

```nasm
section .data

MSG msg_menu, 10, "=== Compactador RLE ===", 10, \
              "1 - Comprimir arquivo", 10, \
              "2 - Descomprimir arquivo", 10, \
              "0 - Sair", 10, \
              "Opcao: "
MSG msg_pede_in,  "Arquivo de entrada: "
MSG msg_pede_out, "Arquivo de saida: "
MSG msg_invalida, "Opcao invalida!", 10
MSG msg_tchau,    "Ate logo!", 10
MSG msg_ok,       "Arquivo gravado com sucesso!", 10
MSG msg_tam_in,   "Bytes lidos    : "
MSG msg_tam_out,  "Bytes gravados : "
MSG msg_nl,       10

MSG msg_erro_ler, "Erro: nao foi possivel abrir/ler o arquivo de entrada", 10, \
                  "      (ele precisa existir e ter menos de 64 KB).", 10
MSG msg_erro_gravar, "Erro: nao foi possivel gravar o arquivo de saida.", 10
MSG msg_erro_digito, "Erro: o texto contem digitos (0-9). Eles nao sao", 10, \
                     "      suportados porque confundem o formato 5A3B2C.", 10
MSG msg_erro_formato, "Erro: arquivo comprimido invalido (esperado: numero + letra).", 10
MSG msg_erro_tam, "Erro: o resultado ficaria grande demais (limite de 1 MB).", 10
```

A seção `.data` guarda **dados com valor inicial**, gravados dentro do executável. Cada `MSG` cria um texto e seu `_len`.

- O número `10` é o código ASCII da quebra de linha (`\n`). O menu começa com `10` para deixar uma linha em branco antes dele.
- A barra invertida `\` no fim da linha **continua o comando na linha seguinte**. É assim que o menu, com várias linhas, é definido por uma só `MSG`.
- Os textos **não terminam em zero**: a syscall `write` recebe o tamanho (`_len`), então não precisa de terminador.
- As mensagens não têm acentos de propósito, para não depender da codificação do terminal.
- Os espaços no início da segunda linha das mensagens de erro só alinham o texto na tela.

| Texto | Quando aparece |
|---|---|
| `msg_menu` | A cada volta do menu. |
| `msg_pede_in`, `msg_pede_out` | Ao pedir os nomes dos arquivos. |
| `msg_invalida` | Opção diferente de 1, 2 ou 0. |
| `msg_tchau` | Ao sair. |
| `msg_ok`, `msg_tam_in`, `msg_tam_out`, `msg_nl` | Resumo após gravar o arquivo (`msg_nl` é só a quebra de linha, 1 byte). |
| `msg_erro_ler` | Não conseguiu abrir/ler a entrada, ou ela tem 64 KB ou mais. |
| `msg_erro_gravar` | Não conseguiu criar/gravar a saída. |
| `msg_erro_digito` | Compressão de um texto que contém dígitos. |
| `msg_erro_formato` | Descompressão de um arquivo que não segue o formato número + caractere. |
| `msg_erro_tam` | Descompressão cujo resultado passaria de 1 MB. |

### 7.5 Seção `.bss`: memória reservada

```nasm
section .bss                    ; memória reservada, começa zerada

opcao       resb 64             ; linha digitada no menu
nome_in     resb 256            ; nome do arquivo de entrada
nome_out    resb 256            ; nome do arquivo de saída
num_buf     resb 24             ; texto de um número (para imprimir)
tam_in      resq 1              ; bytes lidos do arquivo
tam_out     resq 1              ; bytes produzidos
buf_in      resb BUF_IN_MAX     ; conteúdo do arquivo de entrada
buf_out     resb BUF_OUT_MAX    ; resultado da compressão/descompressão
```

A `.bss` reserva memória que **começa zerada** e **não ocupa espaço no arquivo executável** (por isso um buffer de 1 MB não deixa o programa pesado).
`resb n` reserva `n` **bytes**; `resq n` reserva `n` **quadwords** (8 bytes cada), o suficiente para um número de 64 bits.

| Nome | Tamanho | Para quê |
|---|---|---|
| `opcao` | 64 bytes | Linha digitada no menu (só o 1º caractere é usado). |
| `nome_in`, `nome_out` | 256 bytes cada | Nomes dos arquivos, como texto terminado em 0 (exigência da syscall `open`). |
| `num_buf` | 24 bytes | Texto de um número a imprimir. Um número de 64 bits tem no máximo 20 dígitos (18446744073709551615). |
| `tam_in`, `tam_out` | 8 bytes cada | Quantos bytes há em `buf_in` / `buf_out`. |
| `buf_in` | 65536 bytes | Conteúdo do arquivo de entrada. |
| `buf_out` | 1048576 bytes | Resultado da compressão/descompressão. |

### 7.6 `_start`: o menu principal

Em `section .text` ficam as instruções. `global _start` torna o rótulo `_start` visível para o linker, que o usa como **ponto de entrada** do programa.

```nasm
; ---------------------------------------------------------------------
; _start: programa principal (menu em laço)
; ---------------------------------------------------------------------
_start:
.menu:
    PRINT msg_menu
    mov rdi, opcao
    mov esi, 64
    call ler_linha
    test rax, rax
    js .sair                    ; EOF (Ctrl+D): encerra
    mov al, [opcao]             ; primeiro caractere digitado
    cmp al, '1'
    je .comprimir
    cmp al, '2'
    je .descomprimir
    cmp al, '0'
    je .sair
    PRINT msg_invalida
    jmp .menu

.comprimir:
    mov r12, comprimir          ; r12 = rotina que será executada
    jmp .processa
.descomprimir:
    mov r12, descomprimir

.processa:                      ; etapas comuns às duas opções
    call pedir_nomes
    PASSO carregar_entrada
    PASSO r12                   ; comprimir ou descomprimir
    PASSO gravar_saida
    call mostrar_resumo
    jmp .menu

.sair:
    PRINT msg_tchau
    mov eax, SYS_EXIT
    xor edi, edi                ; código de saída 0
    syscall
```

#### Mostrar o menu e ler a opção

```nasm
_start:
.menu:
    PRINT msg_menu
    mov rdi, opcao
    mov esi, 64
    call ler_linha
    test rax, rax
    js .sair                    ; EOF (Ctrl+D): encerra
    mov al, [opcao]             ; primeiro caractere digitado
    cmp al, '1'
    je .comprimir
    cmp al, '2'
    je .descomprimir
    cmp al, '0'
    je .sair
    PRINT msg_invalida
    jmp .menu
```

| Linha | O que faz |
|---|---|
| `.menu:` | Rótulo **local** (começa com ponto): pertence ao último rótulo global, `_start`. É para onde o programa volta depois de cada operação. |
| `PRINT msg_menu` | Mostra o menu. |
| `mov rdi, opcao` / `mov esi, 64` | Argumentos de `ler_linha`: onde guardar a linha e o tamanho do buffer. |
| `call ler_linha` | Lê a linha digitada (termina no Enter). |
| `test rax, rax` / `js .sair` | `ler_linha` devolve -1 no fim da entrada (por exemplo, Ctrl+D). Nesse caso o programa encerra. |
| `mov al, [opcao]` | Pega o **primeiro caractere** digitado (os colchetes significam "o conteúdo do endereço"). |
| `cmp al, '1'` / `je .comprimir` | Se for `'1'`, vai para a compressão. Igual para `'2'` e `'0'`. |
| `PRINT msg_invalida` / `jmp .menu` | Se não for nenhuma das três, avisa e mostra o menu de novo. |

#### Escolher a rotina e executar as etapas

```nasm
.comprimir:
    mov r12, comprimir          ; r12 = rotina que será executada
    jmp .processa
.descomprimir:
    mov r12, descomprimir

.processa:                      ; etapas comuns às duas opções
    call pedir_nomes
    PASSO carregar_entrada
    PASSO r12                   ; comprimir ou descomprimir
    PASSO gravar_saida
    call mostrar_resumo
    jmp .menu
```

| Linha | O que faz |
|---|---|
| `mov r12, comprimir` | Guarda em `r12` o **endereço** da rotina `comprimir`. Em `.descomprimir` o mesmo é feito com `descomprimir`. Assim as duas opções compartilham o mesmo código em `.processa`. As outras rotinas não alteram `r12`. |
| `jmp .processa` | Pula o `mov` da outra opção. (`.descomprimir` não precisa de `jmp`: ele já "cai" em `.processa`, que vem logo abaixo.) |
| `call pedir_nomes` | Pergunta e lê os nomes dos arquivos de entrada e de saída. |
| `PASSO carregar_entrada` | Lê o arquivo para a memória; se der erro, volta ao menu. |
| `PASSO r12` | `call r12` é uma **chamada indireta**: chama a rotina cujo endereço está em `r12`, ou seja, `comprimir` ou `descomprimir`. |
| `PASSO gravar_saida` | Grava o resultado no arquivo de saída; se der erro, volta ao menu. |
| `call mostrar_resumo` / `jmp .menu` | Mostra os tamanhos e recomeça o laço. |

#### Encerrar

```nasm
.sair:
    PRINT msg_tchau
    mov eax, SYS_EXIT
    xor edi, edi                ; código de saída 0
    syscall
```

Mostra a despedida e chama a syscall `exit` (`rax` = `SYS_EXIT` = 60) com código de saída 0 (`xor edi, edi`). **Esse `exit` é essencial**: sem ele, depois do `syscall`
o processador continuaria executando o que estiver na memória logo abaixo e o programa daria falha de segmentação.

### 7.7 `ler_linha`: ler texto do teclado

Lê uma linha da entrada padrão (fd 0) e troca o `\n` final por `0`, produzindo um "texto terminado em zero".
Entrada: `rdi` = endereço do buffer, `rsi` = tamanho do buffer. Saída: `rax` = 0 (ok) ou -1 (fim da entrada).
Usa `r8` (início do buffer), `r9` (última posição usável) e `r10` (posição onde o próximo byte será guardado).

```nasm
; ---------------------------------------------------------------------
; ler_linha: lê uma linha do teclado, UM BYTE POR VEZ, até o '\n',
;            e troca o '\n' por 0 (fim do texto).
;   entrada: rdi = buffer, rsi = tamanho do buffer
;   saída  : rax = 0 (ok) ou -1 (fim da entrada / EOF)
;   usa    : r8 = início, r9 = última posição usável, r10 = posição atual
; (Ler byte a byte funciona igual com teclado ou com entrada redirecionada.)
; ---------------------------------------------------------------------
ler_linha:
    mov r8, rdi
    lea r9, [rdi + rsi - 1]     ; reserva 1 byte para o 0 final
    mov r10, rdi
.le_byte:
    mov eax, SYS_READ
    xor edi, edi                ; fd 0 = teclado
    mov rsi, r10                ; guarda o byte direto na posição atual
    mov edx, 1                  ; lê apenas 1 byte
    syscall
    test rax, rax
    jle .eof                    ; 0 = EOF, negativo = erro
    cmp byte [r10], 10          ; chegou ao '\n'?
    je .fim_linha
    cmp r10, r9
    jae .le_byte                ; buffer cheio: ignora o resto da linha
    inc r10
    jmp .le_byte
.fim_linha:
    mov byte [r10], 0           ; troca '\n' por 0
    xor eax, eax
    ret
.eof:
    mov byte [r10], 0
    mov rax, -1
    ret
```

**Por que um byte por vez?** A syscall `read` devolve o que estiver disponível. Com o teclado vem uma linha por vez, mas com entrada redirecionada (arquivo ou pipe)
ela pode devolver **várias linhas de uma vez** e o programa se perderia. Lendo 1 byte e parando no `\n`, o comportamento é o mesmo nos dois casos.
(A primeira versão lia em bloco e falhou justamente nesse teste, por isso foi corrigida.)

#### Preparação

```nasm
ler_linha:
    mov r8, rdi
    lea r9, [rdi + rsi - 1]     ; reserva 1 byte para o 0 final
    mov r10, rdi
```

| Linha | O que faz |
|---|---|
| `mov r8, rdi` | `r8` guarda o início do buffer (vai servir para saber o tamanho lido). |
| `lea r9, [rdi + rsi - 1]` | Calcula o endereço da **última posição** do buffer (início + tamanho − 1). Essa posição fica reservada para o `0` final. `lea` só faz a conta do endereço, sem ler a memória. |
| `mov r10, rdi` | `r10` = posição atual de escrita, começando no início. |

#### Laço de leitura

```nasm
.le_byte:
    mov eax, SYS_READ
    xor edi, edi                ; fd 0 = teclado
    mov rsi, r10                ; guarda o byte direto na posição atual
    mov edx, 1                  ; lê apenas 1 byte
    syscall
    test rax, rax
    jle .eof                    ; 0 = EOF, negativo = erro
    cmp byte [r10], 10          ; chegou ao '\n'?
    je .fim_linha
    cmp r10, r9
    jae .le_byte                ; buffer cheio: ignora o resto da linha
    inc r10
    jmp .le_byte
```

| Linha | O que faz |
|---|---|
| `mov eax, SYS_READ` | Syscall `read`. |
| `xor edi, edi` | 1º argumento: fd 0 (teclado). `xor` de um registrador com ele mesmo zera. |
| `mov rsi, r10` | 2º argumento: o byte é guardado **direto na posição atual** do buffer. |
| `mov edx, 1` | 3º argumento: lê apenas 1 byte. |
| `syscall` | Executa. `rax` = bytes lidos (1), 0 (fim da entrada) ou negativo (erro). |
| `test rax, rax` / `jle .eof` | Se for 0 ou negativo, vai para `.eof`. |
| `cmp byte [r10], 10` | O byte lido é o Enter (`\n` = 10)? `byte` informa o tamanho do acesso à memória. |
| `je .fim_linha` | Se for, a linha acabou. |
| `cmp r10, r9` / `jae .le_byte` | Se o buffer já encheu (`r10` chegou à última posição), **não avança** e lê o próximo byte: o excesso da linha é descartado sem estourar o buffer. |
| `inc r10` / `jmp .le_byte` | Senão, avança a posição e repete. |

#### Finais

```nasm
.fim_linha:
    mov byte [r10], 0           ; troca '\n' por 0
    xor eax, eax
    ret
.eof:
    mov byte [r10], 0
    mov rax, -1
    ret
```

| Rótulo | O que faz |
|---|---|
| `.fim_linha` | Troca o `\n` por `0` (`mov byte [r10], 0`), formando o texto terminado em zero que a syscall `open` exige, e devolve `rax = 0` (ok). |
| `.eof` | Também termina o texto com `0` e devolve `rax = -1`, avisando o chamador que a entrada acabou. |

**Exemplo:** buffer de 8 bytes e o usuário digita `ab` + Enter. `r9` = início + 7. Lê `a` (vai para a posição 0, `r10` → 1), lê `b` (posição 1, `r10` → 2), lê `\n` (posição 2) → `.fim_linha` grava `0` na posição 2. O buffer fica `a b 0`.

### 7.8 `pedir_nomes`

```nasm
; ---------------------------------------------------------------------
; pedir_nomes: lê o nome dos arquivos de entrada e de saída
; ---------------------------------------------------------------------
pedir_nomes:
    PRINT msg_pede_in
    mov rdi, nome_in
    mov esi, 256
    call ler_linha
    PRINT msg_pede_out
    mov rdi, nome_out
    mov esi, 256
    call ler_linha
    ret
```

Mostra "Arquivo de entrada: ", lê o nome em `nome_in`; depois mostra "Arquivo de saida: " e lê o nome em `nome_out`. São duas chamadas a `ler_linha`, cada uma com buffer de 256 bytes.
O retorno não é testado: se a entrada acabar no meio, o nome incompleto falha ao abrir, o erro é mostrado e, no menu seguinte, o EOF encerra o programa.

### 7.9 `carregar_entrada`: ler o arquivo para a memória

Equivale, em C, a: `fd = open(nome_in, O_RDONLY); n = read(fd, buf_in, 65536); close(fd);` com verificação de erros.

```nasm
; ---------------------------------------------------------------------
; carregar_entrada: abre nome_in, lê para buf_in e fecha o arquivo
;   saída: rax = 0 (ok) ou -1 (erro); tam_in = bytes lidos
; ---------------------------------------------------------------------
carregar_entrada:
    mov eax, SYS_OPEN
    mov rdi, nome_in
    xor esi, esi                ; flags = 0 (somente leitura)
    syscall
    test rax, rax
    js .erro                    ; rax negativo = erro
    mov r8, rax                 ; r8 = descritor do arquivo (fd)

    mov eax, SYS_READ
    mov rdi, r8
    mov rsi, buf_in
    mov edx, BUF_IN_MAX
    syscall
    mov r9, rax                 ; r9 = bytes lidos (ou erro)

    mov eax, SYS_CLOSE
    mov rdi, r8
    syscall

    test r9, r9
    js .erro                    ; falha na leitura
    cmp r9, BUF_IN_MAX
    jae .erro                   ; arquivo grande demais
    mov [tam_in], r9
    xor eax, eax                ; sucesso
    ret
.erro:
    ERRO msg_erro_ler
```

| Linha | O que faz |
|---|---|
| `mov eax, SYS_OPEN` / `mov rdi, nome_in` / `xor esi, esi` | `open(nome_in, 0)`: flags 0 = somente leitura. O 3º argumento (permissões) só importa ao criar arquivo, por isso é ignorado. |
| `test rax, rax` / `js .erro` | `rax` negativo = erro (por exemplo, arquivo inexistente). |
| `mov r8, rax` | Guarda o descritor (fd). `r8` é usado porque a `syscall` só destrói `rax`, `rcx` e `r11`: `r8` sobrevive às chamadas seguintes. |
| `mov eax, SYS_READ` ... `syscall` | `read(fd, buf_in, BUF_IN_MAX)`: lê até 65 536 bytes do arquivo. |
| `mov r9, rax` | Guarda o resultado da leitura (bytes lidos ou erro), pois `rax` será reutilizado. |
| `mov eax, SYS_CLOSE` ... `syscall` | Fecha o arquivo. Vem **antes** de verificar o erro da leitura, para o arquivo ser sempre fechado. |
| `test r9, r9` / `js .erro` | Falha na leitura. |
| `cmp r9, BUF_IN_MAX` / `jae .erro` | Se leu o buffer inteiro, o arquivo pode ser maior que o limite. Em vez de truncar em silêncio, o programa recusa. Por isso o maior arquivo aceito tem 65 535 bytes. |
| `mov [tam_in], r9` / `xor eax, eax` | Guarda o tamanho e devolve 0 (sucesso). |
| `.erro: ERRO msg_erro_ler` | A macro mostra a mensagem e devolve -1. |

### 7.10 `comprimir`: o coração do projeto

Percorre `buf_in` e escreve `contador + caractere` em `buf_out`. Em vez de índices, usa **ponteiros**: `rsi` aponta para o byte atual, `rdi` para onde escrever e
`r8` para o endereço logo depois do último byte da entrada. Terminar a entrada vira simplesmente `cmp rsi, r8` / `jae` (comparação sem sinal de endereços).

```nasm
; ---------------------------------------------------------------------
; comprimir: percorre buf_in e escreve "contador + caractere" em buf_out
;   saída: rax = 0 (ok) ou -1 (erro); tam_out = bytes gerados
;   usa  : rsi = leitura, rdi = escrita, r8 = fim da entrada,
;          al = caractere da sequência, rcx = tamanho da sequência
; ---------------------------------------------------------------------
comprimir:
    mov rsi, buf_in
    mov r8, [tam_in]
    add r8, rsi                 ; r8 = endereço logo após o último byte
    mov rdi, buf_out

.proxima_seq:
    cmp rsi, r8
    jae .fim                    ; acabou a entrada
    mov al, [rsi]               ; al = caractere que inicia a sequência
    cmp al, '0'
    jb .conta_seq               ; menor que '0': não é dígito
    cmp al, '9'
    jbe .erro_digito            ; entre '0' e '9': dígito, não suportado

.conta_seq:
    xor ecx, ecx                ; contador = 0
.conta:
    cmp rsi, r8
    jae .grava                  ; acabou a entrada
    cmp [rsi], al
    jne .grava                  ; caractere diferente: sequência terminou
    inc rcx
    inc rsi
    jmp .conta

.grava:
    call escrever_decimal       ; escreve rcx em decimal, em [rdi]
    mov [rdi], al               ; escreve o caractere
    inc rdi
    jmp .proxima_seq

.fim:
    sub rdi, buf_out            ; rdi = total de bytes escritos
    mov [tam_out], rdi
    xor eax, eax
    ret

.erro_digito:
    ERRO msg_erro_digito
```

| Registrador | Papel |
|---|---|
| `rsi` | Ponteiro de **leitura** em `buf_in`. |
| `rdi` | Ponteiro de **escrita** em `buf_out`. |
| `r8` | Fim da entrada (`buf_in + tam_in`). |
| `al` | Caractere da sequência atual. |
| `rcx` | Tamanho da sequência atual. |

#### Preparação

```nasm
comprimir:
    mov rsi, buf_in
    mov r8, [tam_in]
    add r8, rsi                 ; r8 = endereço logo após o último byte
    mov rdi, buf_out
```

`add r8, rsi` transforma o tamanho em **endereço final**: `r8 = tam_in + buf_in`. `rdi` começa no início da saída.

#### Início de cada sequência e rejeição de dígitos

```nasm
.proxima_seq:
    cmp rsi, r8
    jae .fim                    ; acabou a entrada
    mov al, [rsi]               ; al = caractere que inicia a sequência
    cmp al, '0'
    jb .conta_seq               ; menor que '0': não é dígito
    cmp al, '9'
    jbe .erro_digito            ; entre '0' e '9': dígito, não suportado
```

| Linha | O que faz |
|---|---|
| `cmp rsi, r8` / `jae .fim` | Se o ponteiro chegou ao fim, acabou a entrada. |
| `mov al, [rsi]` | `al` = caractere que **inicia** a próxima sequência. |
| `cmp al, '0'` / `jb .conta_seq` | Menor que 48 (`'0'`): não é dígito, segue. |
| `cmp al, '9'` / `jbe .erro_digito` | Chegou aqui, então é ≥ 48. Se também for ≤ 57 (`'9'`), é dígito: erro. Se for maior que `'9'`, "cai" naturalmente em `.conta_seq`. |

#### Contar a sequência

```nasm
.conta_seq:
    xor ecx, ecx                ; contador = 0
.conta:
    cmp rsi, r8
    jae .grava                  ; acabou a entrada
    cmp [rsi], al
    jne .grava                  ; caractere diferente: sequência terminou
    inc rcx
    inc rsi
    jmp .conta
```

| Linha | O que faz |
|---|---|
| `xor ecx, ecx` | `rcx` = 0: nenhum caractere contado ainda. |
| `cmp rsi, r8` / `jae .grava` | Se a entrada acabou, a sequência termina aqui. |
| `cmp [rsi], al` / `jne .grava` | Compara o byte da memória com `al`. Se for **diferente**, a sequência terminou. |
| `inc rcx` / `inc rsi` / `jmp .conta` | Mais um caractere igual: conta e avança. |

Ao sair do laço, `rcx` é o tamanho da sequência e `rsi` já aponta para o **primeiro byte da próxima sequência**, então o laço externo continua dali sem nenhuma conta extra.

#### Gravar contador e caractere

```nasm
.grava:
    call escrever_decimal       ; escreve rcx em decimal, em [rdi]
    mov [rdi], al               ; escreve o caractere
    inc rdi
    jmp .proxima_seq
```

| Linha | O que faz |
|---|---|
| `call escrever_decimal` | Escreve `rcx` em decimal em `[rdi]` e avança `rdi` (veja 7.12). |
| `mov [rdi], al` | Escreve o caractere logo depois do número. `al` ainda vale o caractere porque `escrever_decimal` **guarda e restaura** `rax`. |
| `inc rdi` / `jmp .proxima_seq` | Avança a escrita e volta para a próxima sequência. |

#### Final e erro

```nasm
.fim:
    sub rdi, buf_out            ; rdi = total de bytes escritos
    mov [tam_out], rdi
    xor eax, eax
    ret

.erro_digito:
    ERRO msg_erro_digito
```

| Linha | O que faz |
|---|---|
| `sub rdi, buf_out` | endereço atual − endereço inicial = **quantidade de bytes escritos**. |
| `mov [tam_out], rdi` | Guarda o tamanho do resultado. |
| `xor eax, eax` / `ret` | Devolve 0 (sucesso). |
| `.erro_digito: ERRO ...` | Mostra "o texto contem digitos" e devolve -1. |

**Rastreio com `AAAAABBBCC`:**

| Etapa | `rsi` aponta para | `al` | `rcx` | O que acontece | Saída (`buf_out`) |
|---|---|---|---|---|---|
| `.proxima_seq` | índice 0 | `A` | — | Não é dígito. |  |
| `.conta` (5 voltas) | 0 → 5 | `A` | 0 → 5 | No índice 5 está `B`, diferente de `A`: vai para `.grava`. |  |
| `.grava` | 5 | `A` | 5 | `escrever_decimal(5)` e depois `A`. | `5A` |
| `.proxima_seq` | índice 5 | `B` | — | Nova sequência. |  |
| `.conta` (3 voltas) | 5 → 8 | `B` | 0 → 3 | No índice 8 está `C`. |  |
| `.grava` | 8 | `B` | 3 | `escrever_decimal(3)` e depois `B`. | `5A3B` |
| `.conta` (2 voltas) | 8 → 10 | `C` | 0 → 2 | `rsi == r8`: a entrada acabou. |  |
| `.grava` | 10 | `C` | 2 | `escrever_decimal(2)` e depois `C`. | `5A3B2C` |
| `.proxima_seq` | 10 | — | — | `rsi == r8` → `.fim`. `tam_out` = 6. | 6 bytes |

### 7.11 `descomprimir`: o caminho inverso

Lê `número + caractere` e escreve o caractere o número de vezes pedido. Vai montando o número dígito a dígito e, quando encontra um não dígito, esse é o caractere a repetir.

```nasm
; ---------------------------------------------------------------------
; descomprimir: lê "número + caractere" e repete o caractere
;   saída: rax = 0 (ok) ou -1 (erro); tam_out = bytes gerados
;   usa  : rsi = leitura, rdi = escrita, r8 = fim da entrada,
;          r9 = fim de buf_out, rbx = número lido até agora,
;          r10 = 1 se já leu algum dígito do número atual
; ---------------------------------------------------------------------
descomprimir:
    mov rsi, buf_in
    mov r8, [tam_in]
    add r8, rsi
    mov rdi, buf_out
    mov r9, buf_out + BUF_OUT_MAX
    xor ebx, ebx                ; número atual = 0
    xor r10d, r10d              ; ainda não leu dígito

.proximo:
    cmp rsi, r8
    jae .fim
    movzx eax, byte [rsi]       ; eax = byte atual
    inc rsi
    cmp al, '0'
    jb .simbolo
    cmp al, '9'
    ja .simbolo

    ; é dígito: número = número * 10 + (dígito - '0')
    sub eax, '0'
    imul rbx, rbx, 10
    add rbx, rax
    mov r10d, 1
    cmp rbx, BUF_OUT_MAX
    ja .erro_tam                ; número absurdo: evita estouro
    jmp .proximo

.simbolo:                       ; al = caractere a ser repetido
    test r10d, r10d
    jz .erro_formato            ; caractere sem número antes dele
    lea rdx, [rdi + rbx]        ; onde a escrita terminaria
    cmp rdx, r9
    ja .erro_tam                ; não cabe no buffer de saída
    mov rcx, rbx                ; rcx = quantas repetições
    rep stosb                   ; escreve al em [rdi], rcx vezes (rdi avança)
    xor ebx, ebx                ; prepara o próximo par número+caractere
    xor r10d, r10d
    jmp .proximo

.fim:
    test r10d, r10d
    jnz .erro_formato           ; terminou com número sem caractere
    sub rdi, buf_out
    mov [tam_out], rdi
    xor eax, eax
    ret

.erro_formato:
    ERRO msg_erro_formato
.erro_tam:
    ERRO msg_erro_tam
```

| Registrador | Papel |
|---|---|
| `rsi` | Ponteiro de leitura em `buf_in`. |
| `rdi` | Ponteiro de escrita em `buf_out`. |
| `r8` | Fim da entrada. |
| `r9` | Fim do buffer de saída (`buf_out + BUF_OUT_MAX`), calculado pelo montador. |
| `rbx` | Número lido até agora. |
| `r10` | 1 se já apareceu pelo menos um dígito do número atual (para detectar caractere sem número). |

#### Preparação

```nasm
descomprimir:
    mov rsi, buf_in
    mov r8, [tam_in]
    add r8, rsi
    mov rdi, buf_out
    mov r9, buf_out + BUF_OUT_MAX
    xor ebx, ebx                ; número atual = 0
    xor r10d, r10d              ; ainda não leu dígito
```

#### Ler o próximo byte e montar o número

```nasm
.proximo:
    cmp rsi, r8
    jae .fim
    movzx eax, byte [rsi]       ; eax = byte atual
    inc rsi
    cmp al, '0'
    jb .simbolo
    cmp al, '9'
    ja .simbolo

    ; é dígito: número = número * 10 + (dígito - '0')
    sub eax, '0'
    imul rbx, rbx, 10
    add rbx, rax
    mov r10d, 1
    cmp rbx, BUF_OUT_MAX
    ja .erro_tam                ; número absurdo: evita estouro
    jmp .proximo
```

| Linha | O que faz |
|---|---|
| `cmp rsi, r8` / `jae .fim` | Fim da entrada? |
| `movzx eax, byte [rsi]` | Copia o byte atual completando com zeros (assim `rax` inteiro vale só aquele byte). |
| `inc rsi` | Avança a leitura. |
| `cmp al, '0'` / `jb .simbolo` e `cmp al, '9'` / `ja .simbolo` | Se for menor que `'0'` ou maior que `'9'`, **não é dígito**: é o caractere a repetir. Se passou pelos dois testes, é dígito. |
| `sub eax, '0'` | Converte o caractere em valor (`'7'` = 55 → 7). |
| `imul rbx, rbx, 10` / `add rbx, rax` | `rbx = rbx * 10 + dígito`. Ex.: lendo `1` e depois `2`: 0×10+1 = 1; 1×10+2 = 12. |
| `mov r10d, 1` | Marca que já apareceu um dígito. |
| `cmp rbx, BUF_OUT_MAX` / `ja .erro_tam` | Se o número já passou do limite da saída, para. Também evita estouro de 64 bits com sequências enormes de dígitos. |
| `jmp .proximo` | Próximo byte. |

#### Repetir o caractere

```nasm
.simbolo:                       ; al = caractere a ser repetido
    test r10d, r10d
    jz .erro_formato            ; caractere sem número antes dele
    lea rdx, [rdi + rbx]        ; onde a escrita terminaria
    cmp rdx, r9
    ja .erro_tam                ; não cabe no buffer de saída
    mov rcx, rbx                ; rcx = quantas repetições
    rep stosb                   ; escreve al em [rdi], rcx vezes (rdi avança)
    xor ebx, ebx                ; prepara o próximo par número+caractere
    xor r10d, r10d
    jmp .proximo
```

| Linha | O que faz |
|---|---|
| `test r10d, r10d` / `jz .erro_formato` | Apareceu um caractere **sem número antes** dele (ex.: `AB`): erro de formato. |
| `lea rdx, [rdi + rbx]` | Calcula onde a escrita **terminaria**, sem escrever nada. |
| `cmp rdx, r9` / `ja .erro_tam` | Se passa do fim do buffer de saída, não cabe: erro. |
| `mov rcx, rbx` | `rcx` = quantas repetições. |
| `rep stosb` | `stosb` grava `al` em `[rdi]` e avança `rdi`; o prefixo `rep` repete isso `rcx` vezes. É o mesmo que um laço "grava `al`, `inc rdi`, `dec rcx`" até `rcx` chegar a 0, em uma só instrução. Com `rcx = 0` não faz nada. (A flag de direção começa em 0 no Linux, então `rdi` avança.) |
| `xor ebx, ebx` / `xor r10d, r10d` | Zera o número e a flag para o próximo par número+caractere. |
| `jmp .proximo` | Continua. |

#### Final e erros

```nasm
.fim:
    test r10d, r10d
    jnz .erro_formato           ; terminou com número sem caractere
    sub rdi, buf_out
    mov [tam_out], rdi
    xor eax, eax
    ret

.erro_formato:
    ERRO msg_erro_formato
.erro_tam:
    ERRO msg_erro_tam
```

| Linha | O que faz |
|---|---|
| `test r10d, r10d` / `jnz .erro_formato` | Se `r10` ainda é 1, o arquivo terminou com um número sem caractere (ex.: `5A3`): erro de formato. |
| `sub rdi, buf_out` / `mov [tam_out], rdi` | Calcula e guarda o tamanho gerado. |
| `xor eax, eax` / `ret` | Devolve 0 (sucesso). |
| `.erro_formato`, `.erro_tam` | Cada um mostra sua mensagem com `ERRO` e devolve -1. |

**Rastreio com `5A3B2C`:**

| Byte lido | Tipo | `rbx` depois | `r10` | O que acontece |
|---|---|---|---|---|
| `5` | dígito | 0×10+5 = 5 | 1 | Acumula o número. |
| `A` | símbolo | 5 | 1 | `rep stosb` grava `AAAAA`. Zera `rbx` e `r10`. |
| `3` | dígito | 3 | 1 | Acumula. |
| `B` | símbolo | 3 | 1 | Grava `BBB`. Zera. |
| `2` | dígito | 2 | 1 | Acumula. |
| `C` | símbolo | 2 | 1 | Grava `CC`. Zera. |
| fim | — | 0 | 0 | `r10` = 0: tudo certo. Resultado: `AAAAABBBCC` (10 bytes). |

### 7.12 `escrever_decimal`: de número para texto

**O problema:** o contador (por exemplo, 12) é um valor binário, mas o arquivo precisa dos **caracteres** `'1'` e `'2'`. Dividir por 10 dá o último dígito (o resto), só que ele sai **primeiro**,
na ordem inversa. A pilha, que devolve na ordem contrária à de entrada, resolve: empilhamos os dígitos à medida que saem e desempilhamos já na ordem certa.
Entrada: `rcx` = número, `rdi` = onde escrever. Saída: `rdi` avança. Preserva `rax` e `rbx` (altera `rcx` e `rdx`).

```nasm
; ---------------------------------------------------------------------
; escrever_decimal: escreve um número em texto (decimal) na memória
;   entrada: rcx = número, rdi = onde escrever
;   saída  : rdi avança para depois do último dígito
;   preserva: rax, rbx, rsi, r8-r10 (altera rcx e rdx)
; Método: divide por 10 várias vezes; os restos saem do último dígito
; para o primeiro, então são empilhados e depois desempilhados.
; ---------------------------------------------------------------------
escrever_decimal:
    push rax
    push rbx
    mov rax, rcx                ; rax = número a converter
    mov ebx, 10
    xor ecx, ecx                ; ecx = quantidade de dígitos
.divide:
    xor edx, edx
    div rbx                     ; rax = rax / 10, rdx = rax % 10
    add dl, '0'                 ; resto -> caractere ASCII
    push rdx
    inc rcx
    test rax, rax
    jnz .divide
.desempilha:
    pop rax
    mov [rdi], al
    inc rdi
    dec rcx
    jnz .desempilha
    pop rbx
    pop rax
    ret
```

| Linha | O que faz |
|---|---|
| `push rax` / `push rbx` | Salva os registradores que a rotina vai usar e que o chamador espera intactos (em `comprimir`, `rax` guarda o caractere!). |
| `mov rax, rcx` | `rax` = número a converter. |
| `mov ebx, 10` | `rbx` = divisor. |
| `xor ecx, ecx` | `rcx` = quantidade de dígitos (recomeça em 0). |
| `.divide:` `xor edx, edx` | `div` divide o par `rdx:rax` (128 bits); `rdx` precisa ser 0 para a conta valer só para `rax`. |
| `div rbx` | `rax` = quociente, `rdx` = resto (0 a 9). |
| `add dl, '0'` | Converte o resto no caractere ASCII (0 → `'0'`). |
| `push rdx` / `inc rcx` | Empilha o dígito e conta. |
| `test rax, rax` / `jnz .divide` | Repete até o quociente chegar a 0. O teste fica **depois** da divisão, então o número 0 também gera um dígito. |
| `.desempilha:` `pop rax` | Tira o dígito do topo (o primeiro dígito do número). |
| `mov [rdi], al` / `inc rdi` | Grava o dígito no destino e avança. |
| `dec rcx` / `jnz .desempilha` | Repete para todos os dígitos. A pilha termina vazia (equilibrada). |
| `pop rbx` / `pop rax` | Restaura os registradores na **ordem inversa** da que foram salvos. |

**Rastreio com o número 205:**

| Passo | `rax` (quociente) | Resto | Pilha (topo à direita) | `rcx` |
|---|---|---|---|---|
| 1ª divisão | 205 ÷ 10 = 20 | 5 → `'5'` | `'5'` | 1 |
| 2ª divisão | 20 ÷ 10 = 2 | 0 → `'0'` | `'5'` `'0'` | 2 |
| 3ª divisão | 2 ÷ 10 = 0 | 2 → `'2'` | `'5'` `'0'` `'2'` | 3 |
| `rax` = 0 | laço termina | — | — | 3 |
| 1º `pop` | — | — | sai `'2'` → grava em `[rdi]` | 2 |
| 2º `pop` | — | — | sai `'0'` → grava em `[rdi+1]` | 1 |
| 3º `pop` | — | — | sai `'5'` → grava em `[rdi+2]` | 0 |
| Resultado | texto `205` (3 bytes) |  |  |  |

### 7.13 `gravar_saida`: gravar o resultado

Equivale, em C, a: `fd = open(nome_out, O_WRONLY|O_CREAT|O_TRUNC, 0644); write(fd, buf_out, tam_out); close(fd);`.

```nasm
; ---------------------------------------------------------------------
; gravar_saida: cria/sobrescreve nome_out com o conteúdo de buf_out
;   saída: rax = 0 (ok) ou -1 (erro)
; ---------------------------------------------------------------------
gravar_saida:
    mov eax, SYS_OPEN
    mov rdi, nome_out
    mov esi, O_WRONLY_CREAT_TRUNC
    mov edx, PERMISSAO
    syscall
    test rax, rax
    js .erro
    mov r8, rax                 ; r8 = fd

    mov eax, SYS_WRITE
    mov rdi, r8
    mov rsi, buf_out
    mov rdx, [tam_out]
    syscall
    mov r9, rax                 ; r9 = bytes gravados (ou erro)

    mov eax, SYS_CLOSE
    mov rdi, r8
    syscall

    test r9, r9
    js .erro
    xor eax, eax
    ret
.erro:
    ERRO msg_erro_gravar
```

| Linha | O que faz |
|---|---|
| `mov esi, O_WRONLY_CREAT_TRUNC` / `mov edx, PERMISSAO` | `open` com escrita + criar + apagar o conteúdo antigo (`0x241`) e permissões `0o644`, usadas só se o arquivo for criado agora. |
| `test rax, rax` / `js .erro` | Falha ao abrir (por exemplo, sem permissão na pasta). |
| `mov r8, rax` | Guarda o fd. |
| `mov rsi, buf_out` / `mov rdx, [tam_out]` | `write(fd, buf_out, tam_out)`: grava os bytes produzidos. Os colchetes em `[tam_out]` leem o **valor** guardado na variável. |
| `mov r9, rax` | Guarda o resultado do `write` antes do `close`, pois `rax` será reutilizado. |
| `mov eax, SYS_CLOSE` ... `syscall` | Fecha o arquivo. |
| `test r9, r9` / `js .erro` | Falha na gravação. |
| `xor eax, eax` / `ret` | Devolve 0 (sucesso). |

Com entrada vazia, `tam_out` = 0: o `write` grava 0 bytes e o resultado é um arquivo vazio, o que está correto.

### 7.14 `mostrar_resumo` e `imprimir_numero`

```nasm
; ---------------------------------------------------------------------
; mostrar_resumo: mensagem de sucesso e tamanhos dos arquivos
; ---------------------------------------------------------------------
mostrar_resumo:
    PRINT msg_ok
    PRINT msg_tam_in
    mov rcx, [tam_in]
    call imprimir_numero
    PRINT msg_tam_out
    mov rcx, [tam_out]
    call imprimir_numero
    ret

; ---------------------------------------------------------------------
; imprimir_numero: imprime rcx em decimal, seguido de quebra de linha
; ---------------------------------------------------------------------
imprimir_numero:
    mov rdi, num_buf
    call escrever_decimal       ; converte rcx para texto em num_buf
    mov rdx, rdi
    sub rdx, num_buf            ; rdx = quantidade de dígitos
    mov rsi, num_buf
    mov edi, 1
    mov eax, SYS_WRITE
    syscall
    PRINT msg_nl
    ret
```

`mostrar_resumo` imprime "Arquivo gravado com sucesso!" e os dois tamanhos (lidos e gravados), o que permite ver a taxa de compressão.
Para imprimir um número, `imprimir_numero` **reaproveita** `escrever_decimal`: converte `rcx` em texto dentro de `num_buf`; depois `rdx = rdi - num_buf` é a quantidade de dígitos escritos,
e uma syscall `write` imprime esse trecho. Por fim, `PRINT msg_nl` imprime a quebra de linha.

Esta parte **não faz parte dos requisitos** do enunciado: pode ser removida sem afetar a compressão e a descompressão (basta tirar o `call mostrar_resumo` de `_start`).

### 7.15 Nota final GNU-stack

```nasm
; evita aviso do linker sobre pilha executável
section .note.GNU-stack noalloc noexec nowrite progbits
```

Uma linha de **metadados** para o linker: informa que o programa não precisa de pilha executável. Sem ela, versões novas do `ld` mostram um aviso. Não gera código.

## 8. Execução de ponta a ponta

Veja o que acontece ao comprimir `teste.txt` (`AAAAABBBCC`) em `teste.rle`, na ordem das syscalls:

| # | Quem | Syscall | O que faz |
|---|---|---|---|
| 1 | `PRINT msg_menu` | `write` | Mostra o menu. |
| 2 | `ler_linha` | `read` (1 byte por vez) | Lê `1` e o Enter. `_start` vê `'1'`: guarda `comprimir` em `r12`. |
| 3 | `pedir_nomes` | `write` + `read`... | Mostra "Arquivo de entrada: " e lê `teste.txt`; mostra "Arquivo de saida: " e lê `teste.rle`. |
| 4 | `carregar_entrada` | `open`, `read`, `close` | Abre `teste.txt`, lê 10 bytes para `buf_in`, `tam_in` = 10, fecha. |
| 5 | `comprimir` (via `call r12`) | — | Processa `buf_in` e gera `5A3B2C` em `buf_out`; `tam_out` = 6. |
| 6 | `gravar_saida` | `open`, `write`, `close` | Cria `teste.rle` e grava os 6 bytes. |
| 7 | `mostrar_resumo` | `write`... | Mostra "Arquivo gravado com sucesso!", "Bytes lidos : 10" e "Bytes gravados : 6". |
| 8 | `_start` | — | `jmp .menu`: volta ao menu. Digitando `0`, `PRINT msg_tchau` e `exit(0)`. |

## 9. Testes

| Caso | Arquivo de entrada | Resultado esperado |
|---|---|---|
| Exemplo do professor | `AAAAABBBCC` | Comprimir: `5A3B2C` |
| Letras variadas | `xxyyyz` | Comprimir: `2x3y1z` |
| Sem repetição | `ABC` | Comprimir: `1A1B1C` (o arquivo dobra) |
| Sequência muito longa | 20 000 letras `Z` | Comprimir: `20000Z` |
| Arquivo vazio | (vazio) | Saída vazia; ida e volta iguais |
| Texto com dígitos | `abc123` | Erro: "o texto contem digitos" |
| Arquivo inexistente | — | Erro ao abrir/ler o arquivo de entrada |
| Descomprimir válido | `5A3B2C` | `AAAAABBBCC` |
| Descomprimir inválido | `5A3` ou `AB` | Erro de formato |
| Número gigante | `99999999999A` | Erro: resultado grande demais |

Teste automático de ida e volta (cria os arquivos, comprime, descomprime e compara):

```bash
printf 'AAAAABBBCC' > t1.txt
printf 'xxyyyz'     > t2.txt
head -c 20000 /dev/zero | tr '\0' 'Z' > t3.txt

for f in t1 t2 t3; do
  printf '1\n%s.txt\n%s.rle\n2\n%s.rle\n%s.out\n0\n' $f $f $f $f | ./rle > /dev/null
  cmp $f.txt $f.out && echo "OK $f ($(wc -c < $f.txt) -> $(wc -c < $f.rle) bytes)"
done
```

Dicas: `od -c arquivo` mostra cada byte (inclusive quebras de linha); `wc -c arquivo` mostra o tamanho; `file rle` mostra "statically linked" e `ldd rle` responde "not a dynamic executable",
provando que o programa **não usa bibliotecas**.

### Depurando com o GDB

O GDB executa **uma instrução por vez** e mostra os registradores. Instale com `sudo apt install gdb` e remonte com informações de depuração:

```bash
nasm -f elf64 -g -F dwarf rle.asm -o rle.o
ld rle.o -o rle
printf '1\nt1.txt\nt1.rle\n0\n' > respostas.txt
gdb ./rle
```

| Comando do GDB | O que faz |
|---|---|
| `set disassembly-flavor intel` | Mostra instruções na sintaxe Intel (a mesma do NASM). |
| `break comprimir` | Pausa quando a execução chegar em `comprimir`. |
| `run < respostas.txt` | Executa usando o arquivo de respostas como teclado. |
| `info registers rax rcx rsi rdi` | Mostra o valor dos registradores. |
| `stepi` (ou `si`) | Executa **uma** instrução. |
| `x/10cb &buf_in` | Mostra 10 bytes de `buf_in` como caracteres. |
| `x/s &buf_out` | Mostra `buf_out` como texto (depois de comprimir). |
| `layout regs` | Tela dividida: código + registradores. |
| `continue`, `quit` | Continua / sai do GDB. |

## 10. Problemas comuns

| Mensagem / sintoma | Causa provável | Solução |
|---|---|---|
| `nasm: command not found` | NASM não instalado. | `sudo apt install nasm` |
| `ld: command not found` | binutils não instalado. | `sudo apt install binutils` |
| `nasm: fatal: unable to open input file` | Pasta ou nome errado. | `ls` para ver os arquivos; `cd` para a pasta certa. |
| `bash: ./rle: Permission denied` | Sem permissão de execução (comum em pastas do Windows em `/mnt/c`). | `chmod +x rle` ou copie o projeto para `~`. |
| `Exec format error` | Processador ARM. | O programa é x86-64: use um PC x86 ou emulação. |
| `ld: warning: cannot find entry symbol _start` | Falta `global _start` ou o nome está errado. | Conferir a seção `.text`. |
| `Segmentation fault` | Programa não chegou ao `exit` ou acessou memória inválida. | Depurar com o GDB; conferir `push`/`pop` equilibrados. |
| "Erro: nao foi possivel abrir/ler o arquivo..." | Arquivo não existe na pasta atual, nome errado, ou tem 64 KB ou mais. | `ls`; digite o nome exatamente como aparece. |

## 11. Limitações e ideias de melhoria

1. **Aceitar dígitos no texto:** invente um escape (um caractere especial antes do dígito) e ajuste a descompressão.
2. **Formato binário:** 1 byte de contador (1–255) + 1 byte de caractere, sem `escrever_decimal`. Sequências maiores que 255 precisam ser divididas, e o problema dos dígitos desaparece.
3. **Mostrar a taxa de compressão** em porcentagem (`tam_out × 100 ÷ tam_in`, com `div`; cuidado com `tam_in = 0`).
4. **Ler arquivos maiores que 64 KB:** fazer `read` em laço, acumulando em `buf_in`, até devolver 0.
5. **Nomes de arquivo pela linha de comando** (`./rle c entrada saida`): no início de `_start`, a pilha tem `argc` em `[rsp]` e os ponteiros de `argv` em seguida.
6. **Portar para ARM (AArch64):** a lógica é a mesma; mudam registradores, instruções e números das syscalls.