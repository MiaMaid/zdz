default rel

section .data
    dot_str         db ".", 0
    align 8
    color_dir       db 27, "[1;34m", 0
    color_lnk       db 27, "[1;36m", 0
    color_fifo      db 27, "[33m", 0, 0, 0
    color_sock      db 27, "[1;35m", 0
    color_reset_nl  db 27, "[0m", 10, 0, 0, 0

section .bss
    align 16
    dir_buf         resb 8192
    str_pool        resb 65536
    ptrs            resq 1024
    out_buf         resb 262144
    num_files       resq 1
    pool_offset     resq 1

section .text
    global _start

_start:
    mov rax, 2
    lea rdi, [rel dot_str]
    xor rsi, rsi
    xor rdx, rdx
    syscall

    cmp rax, 0
    jl .exit
    mov r14, rax

.read_dir:
    mov rax, 217
    mov rdi, r14
    lea rsi, [rel dir_buf]
    mov rdx, 8192
    syscall

    cmp rax, 0
    jle .sort_files

    lea rdx, [rel dir_buf]
    add rdx, rax
    lea rbx, [rel dir_buf]

.parse_dirent:
    movzx r12, word [rbx + 16]
    lea r13, [rbx + 19]

    cmp byte [r13], '.'
    je .next_dirent

    mov r10, [rel num_files]
    cmp r10, 1024
    jge .next_dirent
    mov r15, [rel pool_offset]
    lea rdi, [rel str_pool]
    add rdi, r15
    mov al, byte [rbx + 18]
    mov [rdi], al
    inc rdi
    lea r8, [rel ptrs]
    mov [r8 + r10 * 8], rdi

    mov rsi, r13
.copy_str:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz .copy_str

    lea rax, [rel str_pool]
    sub rdi, rax
    mov [rel pool_offset], rdi
    inc qword [rel num_files]

.next_dirent:
    add rbx, r12
    cmp rbx, rdx
    jl .parse_dirent

    jmp .read_dir

.sort_files:
    mov rax, 3
    mov rdi, r14
    syscall

    mov rcx, [rel num_files]
    cmp rcx, 2
    jl .print_files

    xor rdi, rdi
    mov rsi, rcx
    dec rsi
    call quicksort

.print_files:
    lea rdi, [rel out_buf]
    xor r12, r12
    lea r8, [rel ptrs]

.print_loop:
    cmp r12, [rel num_files]
    jge .flush_out

    mov r13, [r8 + r12 * 8]
    movzx rbx, byte [r13 - 1]

    ; >>> MAID PLACE <<<
    cmp bl, 4
    je .is_dir
    cmp bl, 10
    je .is_lnk
    cmp bl, 1
    je .is_fifo
    cmp bl, 12
    je .is_sock
    jmp .copy_filename

.is_dir:
    mov rax, [rel color_dir]
    mov [rdi], rax
    add rdi, 7
    jmp .copy_filename

.is_lnk:
    mov rax, [rel color_lnk]
    mov [rdi], rax
    add rdi, 7
    jmp .copy_filename

.is_fifo:
    mov rax, [rel color_fifo]
    mov [rdi], rax
    add rdi, 5
    jmp .copy_filename

.is_sock:
    mov rax, [rel color_sock]
    mov [rdi], rax
    add rdi, 7

.copy_filename:
    mov al, [r13]
    test al, al
    jz .fn_done
    mov [rdi], al
    inc r13
    inc rdi
    jmp .copy_filename

.fn_done:
    mov rax, [rel color_reset_nl]
    mov [rdi], rax
    add rdi, 5
    inc r12
    jmp .print_loop

.flush_out:
    lea rdx, [rel out_buf]
    sub rdi, rdx
    jz .exit

    mov rdx, rdi
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel out_buf]
    syscall

.exit:
    mov rax, 60
    xor rdi, rdi
    syscall

quicksort:
    cmp rdi, rsi
    jge .qs_done

    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

.qs_loop:
    cmp rdi, rsi
    jge .qs_pop_done
    mov r12, rdi
    mov r13, rsi

    lea r8, [rel ptrs]
    mov r14, [r8 + r13 * 8]
    mov r15, r12
    dec r15
    mov rbx, r12

.partition_loop:
    cmp rbx, r13
    jge .partition_end
    mov rdi, [r8 + rbx * 8]
    mov rsi, r14

.inline_strcmp:
    mov al, [rdi]
    mov dl, [rsi]
    cmp al, dl
    jne .cmp_diff
    test al, al
    jz .no_swap
    inc rdi
    inc rsi
    jmp .inline_strcmp

.cmp_diff:
    ja .no_swap
    ; Da, bez swapa XD
    inc r15
    mov rdi, [r8 + r15 * 8]
    mov rsi, [r8 + rbx * 8]
    mov [r8 + r15 * 8], rsi
    mov [r8 + rbx * 8], rdi

.no_swap:
    inc rbx
    jmp .partition_loop

.partition_end:
    inc r15
    mov rdi, [r8 + r15 * 8]
    mov rsi, [r8 + r13 * 8]
    mov [r8 + r15 * 8], rsi
    mov [r8 + r13 * 8], rdi

    mov rdi, r12
    mov rsi, r15
    dec rsi
    push r15
    push r13
    call quicksort
    pop r13
    pop r15
    mov rdi, r15
    inc rdi
    mov rsi, r13
    jmp .qs_loop

.qs_pop_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp

.qs_done:
    ret
