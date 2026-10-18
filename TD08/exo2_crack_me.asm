global _start
section text
%include "./inc/cours.inc"

_start:
    enter 24, 0
    call read_hex
    mov [rbp - 8], rax
    call read_hex
    mov [rbp - 16], rax
    call read_hex
    mov [rbp - 24], rax
    
    mov rax, [rbp - 8]
    mov rbx, [rbp - 16]
    mov rcx, [rbp - 24]
    xor rdx, rdx
    add rdx, rbx
    shl rax, 1
    add rdx, rax
    shl rbx, 1
    add rdx, rbx
    add rdx, rcx
    sub rdx, 287
    cmp rdx, 0
    jne fail

    mov rax, [rbp - 8]
    mov rbx, [rbp - 16]
    mov rcx, [rbp - 24]
    xor rdx, rdx
    add rdx, rax
    shl rbx, 2
    sub rdx, rbx
    add rdx, rcx
    shl rcx, 1
    add rdx, rcx
    add rdx, 36
    cmp rdx, 0
    jne fail

    mov rax, [rbp - 8]
    mov rbx, [rbp - 16]
    mov rcx, [rbp - 24]
    xor rdx, rdx
    add rdx, rax
    shl rax, 1
    add rdx, rax
    add rdx, rbx
    sub rdx, rcx
    sub rdx, 394
    jne fail

    mov rdi, good_job
    mov rsi, 7
    call print_string
    mov rax, 60
    syscall

fail:
    mov rdi, bad_job
    mov rsi, 9
    call print_string
    mov rax, 60
    syscall

section .data
    good_job: db 'Bravo!', 0xa, 0
    bad_job: db 'Reessaye', 0xa, 0
