;     nasm -f elf64 rle.asm -o rle.o
;     ld rle.o -o rle
;     ./rle

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

; ---------- Macros ----------------------------------------------------
; MSG nome, bytes... : define um texto e calcula o seu tamanho (nome_len)
%macro MSG 2+
%1:         db %2
%1_len      equ $ - %1
%endmacro

; PRINT nome : escreve na tela o texto definido por MSG
%macro PRINT 1
    mov eax, SYS_WRITE
    mov edi, 1                  ; fd 1 = tela
    mov rsi, %1                 ; endereço do texto
    mov edx, %1_len             ; quantidade de bytes
    syscall
%endmacro

; ERRO nome : mostra a mensagem e sai da rotina devolvendo rax = -1
%macro ERRO 1
    PRINT %1
    mov rax, -1
    ret
%endmacro

; PASSO rotina : chama a rotina; se ela devolver erro (rax < 0), volta ao menu
%macro PASSO 1
    call %1
    test rax, rax
    js .menu
%endmacro

; =====================================================================
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

; =====================================================================
section .bss                    ; memória reservada, começa zerada

opcao       resb 64             ; linha digitada no menu
nome_in     resb 256            ; nome do arquivo de entrada
nome_out    resb 256            ; nome do arquivo de saída
num_buf     resb 24             ; texto de um número (para imprimir)
tam_in      resq 1              ; bytes lidos do arquivo
tam_out     resq 1              ; bytes produzidos
buf_in      resb BUF_IN_MAX     ; conteúdo do arquivo de entrada
buf_out     resb BUF_OUT_MAX    ; resultado da compressão/descompressão

; =====================================================================
section .text
global _start

; _start: programa principal (menu em laço)
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

; ---------------------------------------------------------------------
; ler_linha: lê uma linha do teclado, UM BYTE POR VEZ, até o '\n',
;            e troca o '\n' por 0 (fim do texto).
;   entrada: rdi = buffer, rsi = tamanho do buffer
;   saída  : rax = 0 (ok) ou -1 (fim da entrada / EOF)
;   usa    : r8 = início, r9 = última posição usável, r10 = posição atual
; (Ler byte a byte funciona igual com teclado ou com entrada redirecionada.)

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

; --------- pedir_nomes: lê o nome da entrada e da saída
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

; carregar_entrada: abre nome_in, lê para buf_in e fecha o arquivo
;   saída: rax = 0 (ok) ou -1 (erro); tam_in = bytes lidos
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

; -------->gravar_saida: cria/sobrescreve nome_out com o conteúdo de buf_out
;   saída: rax = 0 (ok) ou -1 (erro)
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

; --------> mostrar_resumo: mensagem de sucesso e tamanhos dos arquivos
mostrar_resumo:
    PRINT msg_ok
    PRINT msg_tam_in
    mov rcx, [tam_in]
    call imprimir_numero
    PRINT msg_tam_out
    mov rcx, [tam_out]
    call imprimir_numero
    ret

; -------> imprimir_numero: imprime rcx em decimal, seguido de quebra de linha
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

; evita aviso do linker sobre pilha executável
section .note.GNU-stack noalloc noexec nowrite progbits