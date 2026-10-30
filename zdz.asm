default rel
%define PREFAULT 1

section .date
   align 8
   dot_str:        db ".", 0
   align 8
   color_dir:      db 27, "[1;34m", 0
   color_lnk:      db 27, "[1;36m", 0
   color_fifo:     db 27, "[33m", 0, 0, 0
   color_sock:     db 27, "[1;35m", 0
   color_blk:      db 27, "[1;33m", 0
   color_chr:      db 27, "[1;33m", 0
   color_exec:     db 27, "[1;32m", 0
   color_script:   db 27, "[32m", 0, 0, 0
   color_image:    db 27, "[1;35m", 0
   color_video:    db 27, "[1;31m", 0
   color_audio:    db 27, "[1;36m", 0
   color_archive:  db 27, "[31m", 0, 0, 0
   color_reg:      db 27, "[0m", 0, 0, 0, 0

section .bss
    alignb 4096
ptrs:       resq 1024
outbuf:     resb 4096 - 512
out_limit:  resb 512
    alignb 4096
dir_buf:    resb 131072
dir_end:    resb 64

section .text
global _start

_start:
%if PREFAULT
    mov     eax, 28
    lea     rdi, [rel ptrs]
    mov     esi, 8192 + 4096
    mov     edx, 23
    syscall
%endif

    mov     eax, 2
    lea     rdi, [rel dot_str]
    xor     esi, esi
    xor     edx, edx
    syscall
    test    rax, rax
    js      .exit
    mov     r14, rax

    lea     r8, [rel ptrs]
    lea     rbx, [rel dir_buf]
    xor     r12d, r12d
    xor     r13d, r13d

.read_dir:
    lea     rdx, [rel dir_end]
    sub     rdx, rbx
    cmp     rdx, 1024
    jb      .read_done
    mov     eax, 217
    mov     rdi, r14
    mov     rsi, rbx
    syscall
    test    rax, rax
    jle     .read_done
    mov     rbp, rbx
    add     rbx, rax
    mov     r15, rbx

.parse:
    lea     rsi, [rbp + 19]
    cmp     byte [rsi], '.'
    je      .next_dirent
    cmp     r12, 1024
    jge     .next_dirent

    call    str_width
    mov     ecx, eax
    cmp     ecx, 24
    jle     .cap_ok
    mov     ecx, 24
.cap_ok:
    cmp     rcx, r13
    jle     .max_ok
    mov     r13, rcx
.max_ok:
    shl     rax, 32
    lea     rdx, [rbp + 19]
    or      rax, rdx
    mov     [r8 + r12*8], rax
    inc     r12

.next_dirent:
    movzx   eax, word [rbp + 16]
    add     rbp, rax
    cmp     rbp, r15
    jb      .parse
    jmp     .read_dir

.read_done:
    mov     eax, 3
    mov     rdi, r14
    syscall

    cmp     r12, 2
    jl      .layout
    xor     edi, edi
    lea     rsi, [r12 - 1]
    call    quicksort

.layout:
    push    0
    mov     eax, 16
    mov     edi, 1
    mov     esi, 0x5413
    mov     rdx, rsp
    syscall
    mov     r10d, 80
    test    rax, rax
    js      .width_ok
    movzx   eax, word [rsp + 2]
    test    eax, eax
    jz      .width_ok
    mov     r10d, eax
.width_ok:
    pop     rax
    lea     rcx, [r13 + 2]
    mov     rax, r10
    xor     edx, edx
    div     rcx
    test    rax, rax
    jnz     .cols_ok
    mov     eax, 1
.cols_ok:
    mov     r9, rax
    mov     r10, rcx
    lea     rdi, [rel outbuf]
    xor     ebp, ebp
    xor     ebx, ebx

.print_loop:
    cmp     rbp, r12
    jge     .flush_out
    lea     rax, [rel out_limit]
    cmp     rdi, rax
    jb      .room
    call    flush
.room:
    mov     rax, [r8 + rbp*8]
    mov     r15, rax
    shr     r15, 32
    mov     r13d, eax
    movzx   eax, byte [r13 - 1]

    cmp     al, 8
    je      .is_reg
    cmp     al, 4
    je      .is_dir
    cmp     al, 10
    je      .is_lnk
    cmp     al, 1
    je      .is_fifo
    cmp     al, 12
    je      .is_sock
    cmp     al, 6
    je      .is_blk
    cmp     al, 2
    je      .is_chr
    jmp     .reg_default

; MAID PLACE
.is_dir:
    mov     rax, [rel color_dir]
    mov     [rdi], rax
    add     rdi, 7
    jmp     .copy_filename
.is_lnk:
    mov     rax, [rel color_lnk]
    mov     [rdi], rax
    add     rdi, 7
    jmp     .copy_filename
.is_fifo:
    mov     rax, [rel color_fifo]
    mov     [rdi], rax
    add     rdi, 5
    jmp     .copy_filename
.is_sock:
    mov     rax, [rel color_sock]
    mov     [rdi], rax
    add     rdi, 7
    jmp     .copy_filename
.is_blk:
    mov     rax, [rel color_blk]
    mov     [rdi], rax
    add     rdi, 7
    jmp     .copy_filename
.is_chr:
    mov     rax, [rel color_chr]
    mov     [rdi], rax
    add     rdi, 7
    jmp     .copy_filename

.is_reg:
    mov     rsi, r13
    xor     edx, edx
.find_dot:
    mov     al, [rsi]
    test    al, al
    jz      .dot_done
    cmp     al, '.'
    jne     .not_dot
    mov     rdx, rsi
.not_dot:
    inc     rsi
    jmp     .find_dot
.dot_done:
    test    rdx, rdx
    jz      .reg_default

    mov     eax, [rdx + 1]
    mov     ecx, eax
    and     ecx, 0x00FFFFFF

    cmp     ecx, 'sh'
    je      .is_script
    cmp     ecx, 'py'
    je      .is_script
    cmp     ecx, 'gz'
    je      .is_archive
    cmp     eax, 'exe'
    je      .is_exec
    cmp     eax, 'bin'
    je      .is_exec
    cmp     eax, 'png'
    je      .is_image
    cmp     eax, 'jpg'
    je      .is_image
    cmp     eax, 'gif'
    je      .is_image
    cmp     eax, 'svg'
    je      .is_image
    cmp     eax, 'mp4'
    je      .is_video
    cmp     eax, 'mkv'
    je      .is_video
    cmp     eax, 'avi'
    je      .is_video
    cmp     eax, 'mp3'
    je      .is_audio
    cmp     eax, 'wav'
    je      .is_audio
    cmp     eax, 'zip'
    je      .is_archive
    cmp     eax, 'tar'
    je      .is_archive
    cmp     eax, 'rar'
    je      .is_archive
    cmp     eax, 'flac'
    jne     .reg_default
    cmp     byte [rdx + 5], 0
    jne     .reg_default

.is_audio:
    mov     rax, [rel color_audio]
    mov     [rdi], rax
    add     rdi, 7
    jmp     .copy_filename
.reg_default:
    mov     rax, [rel color_reg]
    mov     [rdi], rax
    add     rdi, 4
    jmp     .copy_filename
.is_script:
    mov     rax, [rel color_script]
    mov     [rdi], rax
    add     rdi, 5
    jmp     .copy_filename
.is_exec:
    mov     rax, [rel color_exec]
    mov     [rdi], rax
    add     rdi, 7
    jmp     .copy_filename
.is_image:
    mov     rax, [rel color_image]
    mov     [rdi], rax
    add     rdi, 7
    jmp     .copy_filename
.is_video:
    mov     rax, [rel color_video]
    mov     [rdi], rax
    add     rdi, 7
    jmp     .copy_filename
.is_archive:
    mov     rax, [rel color_archive]
    mov     [rdi], rax
    add     rdi, 5

.copy_filename:
    xor     r14d, r14d
.cf_loop:
    movzx   eax, byte [r13]
    test    al, al
    jz      .fn_done
    mov     ecx, 1
    mov     r11d, 1
    cmp     al, 0xC0
    jb      .have
    mov     ecx, 2
    cmp     al, 0xE0
    jb      .have
    mov     ecx, 3
    cmp     al, 0xE3
    jb      .have
    mov     r11d, 2
    cmp     al, 0xEA
    jb      .have
    mov     r11d, 1
    cmp     al, 0xF0
    jb      .have
    mov     ecx, 4
    mov     r11d, 2
.have:
    cmp     r15, 24
    jle     .copy_char
    lea     rdx, [r14 + r11]
    cmp     rdx, 22
    jg      .truncate
.copy_char:
    mov     al, [r13]
    test    al, al
    jz      .fn_done
    mov     [rdi], al
    inc     r13
    inc     rdi
    dec     ecx
    jnz     .copy_char
    add     r14, r11
    jmp     .cf_loop

.truncate:
    mov     word [rdi], '..'
    add     rdi, 2
    add     r14, 2

.fn_done:
    mov     dword [rdi], 0x6d305b1b
    add     rdi, 4

    mov     rcx, r10
    sub     rcx, r14
    jle     .no_pad
.pad_loop:
    mov     byte [rdi], ' '
    inc     rdi
    dec     rcx
    jnz     .pad_loop
.no_pad:

    inc     rbx
    cmp     rbx, r9
    jl      .next_file
    mov     byte [rdi], 10
    inc     rdi
    xor     ebx, ebx
.next_file:
    inc     rbp
    jmp     .print_loop

.flush_out:
    test    rbx, rbx
    jz      .do_flush
    mov     byte [rdi], 10
    inc     rdi
.do_flush:
    call    flush
.exit:
    mov     eax, 60
    xor     edi, edi
    syscall

flush:
    lea     rsi, [rel outbuf]
    mov     rdx, rdi
    sub     rdx, rsi
    jz      .done
    mov     eax, 1
    mov     edi, 1
    syscall
    lea     rdi, [rel outbuf]
.done:
    ret

quicksort:
.top:
    cmp     rdi, rsi
    jge     .ret
    lea     rax, [rdi + rsi]
    shr     rax, 1
    mov     rcx, [r8 + rax*8]
    mov     rdx, [r8 + rsi*8]
    mov     [r8 + rax*8], rdx
    mov     [r8 + rsi*8], rcx
    mov     r11d, ecx
    mov     r9, rdi
    mov     r10, rdi
.scan:
    cmp     r10, rsi
    jge     .scan_end
    mov     rbx, [r8 + r10*8]
    mov     edx, ebx
    mov     ecx, r11d
.cmp:
    mov     al, [rdx]
    mov     r14b, [rcx]
    cmp     al, r14b
    jne     .diff
    test    al, al
    jz      .keep
    inc     rdx
    inc     rcx
    jmp     .cmp
.diff:
    ja      .keep
    mov     rax, [r8 + r9*8]
    mov     [r8 + r9*8], rbx
    mov     [r8 + r10*8], rax
    inc     r9
.keep:
    inc     r10
    jmp     .scan
.scan_end:
    mov     rax, [r8 + r9*8]
    mov     rbx, [r8 + rsi*8]
    mov     [r8 + r9*8], rbx
    mov     [r8 + rsi*8], rax
    push    rsi
    push    r9
    lea     rsi, [r9 - 1]
    call    quicksort
    pop     rdi
    inc     rdi
    pop     rsi
    jmp     .top
.ret:
    ret

str_width:
    xor     eax, eax
.l:
    movzx   ecx, byte [rsi]
    inc     rsi
    cmp     ecx, 0x80
    jb      .ascii
    cmp     ecx, 0xC0
    jb      .l
    cmp     ecx, 0xE3
    jb      .one
    cmp     ecx, 0xEA
    jb      .two
    cmp     ecx, 0xF0
    jb      .one
.two:
    add     eax, 2
    jmp     .l
.ascii:
    test    ecx, ecx
    jz      .done
.one:
    inc     eax
    jmp     .l
.done:
    ret
