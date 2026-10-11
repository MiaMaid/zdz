default rel

section .data
    dot_str         db ".", 0
    align 8
    color_dir       db 27, "[1;34m", 0
    color_lnk       db 27, "[1;36m", 0
    color_fifo      db 27, "[33m", 0, 0, 0
    color_sock      db 27, "[1;35m", 0
    color_blk       db 27, "[1;33m", 0
    color_chr       db 27, "[1;33m", 0
    color_exec      db 27, "[1;32m", 0
    color_script    db 27, "[32m", 0, 0, 0
    color_image     db 27, "[1;35m", 0
    color_video     db 27, "[1;31m", 0
    color_audio     db 27, "[1;36m", 0
    color_archive   db 27, "[31m", 0, 0, 0
    color_reg       db 27, "[0m", 0

section .bss
    align 16
    dir_buf         resb 8192
    str_pool        resb 65536
    ptrs            resq 1024
    out_buf         resb 262144
    num_files       resq 1
    pool_offset     resq 1
    max_len         resq 1
    col_width       resq 1
    cols            resq 1
    cur_col         resq 1
    winsize         resw 4

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
    xor r9, r9
.copy_str:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    test al, al
    jz .copy_done
    inc r9
    jmp .copy_str

.copy_done:
    mov rcx, r9
    cmp rcx, 24
    jle .skip_cap
    mov rcx, 24
.skip_cap:
    cmp rcx, [rel max_len]
    jle .skip_max
    mov [rel max_len], rcx
.skip_max:

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
    jl .calc_layout

    xor rdi, rdi
    mov rsi, rcx
    dec rsi
    call quicksort

.calc_layout:
    mov rax, 16
    mov rdi, 1
    mov rsi, 0x5413
    lea rdx, [rel winsize]
    syscall

    mov r10, 80
    cmp rax, 0
    jl .width_ok
    movzx rax, word [rel winsize + 2]
    test rax, rax
    jz .width_ok
    mov r10, rax

.width_ok:
    mov rax, [rel max_len]
    add rax, 2
    mov [rel col_width], rax

    xor rdx, rdx
    mov rax, r10
    div qword [rel col_width]
    test rax, rax
    jnz .cols_ok
    mov rax, 1
.cols_ok:
    mov [rel cols], rax
    mov qword [rel cur_col], 0

.print_files:
    lea rdi, [rel out_buf]
    xor r12, r12
    lea r8, [rel ptrs]

.print_loop:
    cmp r12, [rel num_files]
    jge .flush_out

    mov r13, [r8 + r12 * 8]
    movzx rbx, byte [r13 - 1]

    cmp bl, 4
    je .is_dir
    cmp bl, 10
    je .is_lnk
    cmp bl, 1
    je .is_fifo
    cmp bl, 12
    je .is_sock
    cmp bl, 6
    je .is_blk
    cmp bl, 2
    je .is_chr
    cmp bl, 8
    je .is_reg
    jmp .reg_default

.is_dir:
    mov rax, [rel color_dir]
    mov [rdi], rax
    add rdi, 7
    jmp .copy_filename_prep

.is_lnk:
    mov rax, [rel color_lnk]
    mov [rdi], rax
    add rdi, 7
    jmp .copy_filename_prep

.is_fifo:
    mov rax, [rel color_fifo]
    mov [rdi], rax
    add rdi, 5
    jmp .copy_filename_prep

.is_sock:
    mov rax, [rel color_sock]
    mov [rdi], rax
    add rdi, 7
    jmp .copy_filename_prep

.is_blk:
    mov rax, [rel color_blk]
    mov [rdi], rax
    add rdi, 7
    jmp .copy_filename_prep

.is_chr:
    mov rax, [rel color_chr]
    mov [rdi], rax
    add rdi, 7
    jmp .copy_filename_prep

.is_reg:
    push r13
    mov rsi, r13
    xor rdx, rdx
.find_dot:
    mov al, [rsi]
    test al, al
    jz .found_dot_done
    cmp al, '.'
    jne .not_dot
    mov rdx, rsi
.not_dot:
    inc rsi
    jmp .find_dot
.found_dot_done:
    pop r13
    test rdx, rdx
    jz .reg_default

; MAID PLACE
    cmp byte [rdx + 1], 's'
    jne .chk_py
    cmp byte [rdx + 2], 'h'
    jne .chk_py
    cmp byte [rdx + 3], 0
    je .is_script

.chk_py:
    cmp byte [rdx + 1], 'p'
    jne .chk_exe
    cmp byte [rdx + 2], 'y'
    jne .chk_exe
    cmp byte [rdx + 3], 0
    je .is_script

.chk_exe:
    cmp byte [rdx + 1], 'e'
    jne .chk_bin
    cmp byte [rdx + 2], 'x'
    jne .chk_bin
    cmp byte [rdx + 3], 'e'
    jne .chk_bin
    cmp byte [rdx + 4], 0
    je .is_exec

.chk_bin:
    cmp byte [rdx + 1], 'b'
    jne .chk_img
    cmp byte [rdx + 2], 'i'
    jne .chk_img
    cmp byte [rdx + 3], 'n'
    jne .chk_img
    cmp byte [rdx + 4], 0
    je .is_exec

.chk_img:
    cmp byte [rdx + 1], 'p'
    jne .chk_jpg
    cmp byte [rdx + 2], 'n'
    jne .chk_jpg
    cmp byte [rdx + 3], 'g'
    jne .chk_jpg
    cmp byte [rdx + 4], 0
    je .is_image

.chk_jpg:
    cmp byte [rdx + 1], 'j'
    jne .chk_gif
    cmp byte [rdx + 2], 'p'
    jne .chk_gif
    cmp byte [rdx + 3], 'g'
    jne .chk_gif
    cmp byte [rdx + 4], 0
    je .is_image

.chk_gif:
    cmp byte [rdx + 1], 'g'
    jne .chk_svg
    cmp byte [rdx + 2], 'i'
    jne .chk_svg
    cmp byte [rdx + 3], 'f'
    jne .chk_svg
    cmp byte [rdx + 4], 0
    je .is_image

.chk_svg:
    cmp byte [rdx + 1], 's'
    jne .chk_vid
    cmp byte [rdx + 2], 'v'
    jne .chk_vid
    cmp byte [rdx + 3], 'g'
    jne .chk_vid
    cmp byte [rdx + 4], 0
    je .is_image

.chk_vid:
    cmp byte [rdx + 1], 'm'
    jne .chk_avi
    cmp byte [rdx + 2], 'p'
    jne .chk_mkv
    cmp byte [rdx + 3], '4'
    jne .reg_default
    cmp byte [rdx + 4], 0
    je .is_video

.chk_mkv:
    cmp byte [rdx + 2], 'k'
    jne .reg_default
    cmp byte [rdx + 3], 'v'
    jne .reg_default
    cmp byte [rdx + 4], 0
    je .is_video

.chk_avi:
    cmp byte [rdx + 1], 'a'
    jne .chk_aud
    cmp byte [rdx + 2], 'v'
    jne .chk_aud
    cmp byte [rdx + 3], 'i'
    jne .chk_aud
    cmp byte [rdx + 4], 0
    je .is_video

.chk_aud:
    cmp byte [rdx + 1], 'm'
    jne .chk_wav
    cmp byte [rdx + 2], 'p'
    jne .chk_wav
    cmp byte [rdx + 3], '3'
    jne .reg_default
    cmp byte [rdx + 4], 0
    je .is_audio

.chk_wav:
    cmp byte [rdx + 1], 'w'
    jne .chk_flac
    cmp byte [rdx + 2], 'a'
    jne .chk_flac
    cmp byte [rdx + 3], 'v'
    jne .reg_default
    cmp byte [rdx + 4], 0
    je .is_audio

.chk_flac:
    cmp byte [rdx + 1], 'f'
    jne .chk_arc
    cmp byte [rdx + 2], 'l'
    jne .chk_arc
    cmp byte [rdx + 3], 'a'
    jne .chk_arc
    cmp byte [rdx + 4], 'c'
    jne .reg_default
    cmp byte [rdx + 5], 0
    je .is_audio

.chk_arc:
    cmp byte [rdx + 1], 'z'
    jne .chk_tar
    cmp byte [rdx + 2], 'i'
    jne .chk_tar
    cmp byte [rdx + 3], 'p'
    jne .reg_default
    cmp byte [rdx + 4], 0
    je .is_archive

.chk_tar:
    cmp byte [rdx + 1], 't'
    jne .chk_gz
    cmp byte [rdx + 2], 'a'
    jne .chk_gz
    cmp byte [rdx + 3], 'r'
    jne .reg_default
    cmp byte [rdx + 4], 0
    je .is_archive

.chk_gz:
    cmp byte [rdx + 1], 'g'
    jne .chk_rar
    cmp byte [rdx + 2], 'z'
    jne .chk_rar
    cmp byte [rdx + 3], 0
    je .is_archive

.chk_rar:
    cmp byte [rdx + 1], 'r'
    jne .reg_default
    cmp byte [rdx + 2], 'a'
    jne .reg_default
    cmp byte [rdx + 3], 'r'
    jne .reg_default
    cmp byte [rdx + 4], 0
    je .is_archive

.reg_default:
    mov rax, [rel color_reg]
    mov [rdi], rax
    add rdi, 4
    jmp .copy_filename_prep

.is_script:
    mov rax, [rel color_script]
    mov [rdi], rax
    add rdi, 5
    jmp .copy_filename_prep

.is_exec:
    mov rax, [rel color_exec]
    mov [rdi], rax
    add rdi, 7
    jmp .copy_filename_prep

.is_image:
    mov rax, [rel color_image]
    mov [rdi], rax
    add rdi, 7
    jmp .copy_filename_prep

.is_video:
    mov rax, [rel color_video]
    mov [rdi], rax
    add rdi, 7
    jmp .copy_filename_prep

.is_audio:
    mov rax, [rel color_audio]
    mov [rdi], rax
    add rdi, 7
    jmp .copy_filename_prep

.is_archive:
    mov rax, [rel color_archive]
    mov [rdi], rax
    add rdi, 5
    jmp .copy_filename_prep

.copy_filename_prep:
    xor r14, r14

.copy_filename:
    mov al, [r13]
    test al, al
    jz .fn_done

    cmp r14, 22
    jl .normal_char
    cmp byte [r13 + 1], 0
    je .normal_char

    mov byte [rdi], '.'
    mov byte [rdi + 1], '.'
    add rdi, 2
    add r14, 2

.drain_str:
    inc r13
    mov al, [r13]
    test al, al
    jnz .drain_str
    jmp .fn_done

.normal_char:
    mov [rdi], al
    inc r13
    inc rdi
    inc r14
    jmp .copy_filename

.fn_done:
    mov dword [rdi], 0x6d305b1b
    add rdi, 4

    mov rcx, [rel col_width]
    sub rcx, r14
    jle .no_pad
.pad_loop:
    mov byte [rdi], ' '
    inc rdi
    dec rcx
    jnz .pad_loop
.no_pad:

    inc qword [rel cur_col]
    mov rax, [rel cur_col]
    cmp rax, [rel cols]
    jl .next_file

    mov byte [rdi], 10
    inc rdi
    mov qword [rel cur_col], 0

.next_file:
    inc r12
    jmp .print_loop

.flush_out:
    cmp qword [rel cur_col], 0
    je .do_flush
    mov byte [rdi], 10
    inc rdi

.do_flush:
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
    inc r15
    mov rdi, [r8 + r15 * 8]
    mov rsi, [r8 + rbx * 8]
    mov [r8 + r15 * 8], rsi
    mov [r8 + rbx * 8], rdi

;Da, bez swapa XD
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
