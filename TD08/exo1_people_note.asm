global _start

struc people
    .name: resb 32
    .age: resq 1
    .notes resq 3
endstruc

section .text

%include "./inc/cours.inc"

get_people:
    enter 8, 0
    xor rcx, rcx
    mov [rbp - 8], rdi

    mov rax, [rbp - 8] 
    lea rdi, [rax + people.name]
    mov rsi, 32
    call read_string

    call read_hex
    mov rbx, [rbp - 8]
    mov [rbx + people.age], rax

    xor r8, r8
loop_notes:
    cmp r8, 3
    jae end
    call read_hex
    mov rbx, [rbp - 8]
    mov [rbx + people.notes + r8*8], rax
    inc r8
    jmp loop_notes
end:
    leave
    ret

_start:
    mov rdi, people1
    call get_people
    mov rax, 60
    syscall


section .bss
    people1: resb people_size
