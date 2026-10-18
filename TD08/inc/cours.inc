# rdi = val
print_hex: # print_hex
    push rbp
    mov rbp, rsp
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    xor r8, r8
L9: # print_char
    rol rdi, 4
    mov rbx, rdi 
    and rbx, 0xf
    cmp rbx, 0xa
    jae L11
L10: # print_0123456789
    add rbx, 0x30
    jmp L12
L11: # print_abcdef
    add rbx, 0x57
L12: # print 
    push rdi 
    push rbx
    mov rdi, 1
    mov rsi, rsp
    mov rdx, 1
    mov rax, 1
    syscall
    pop rbx
    pop rdi
    inc r8
    cmp r8, 0x10 
    jae L13 
    jmp L9 
L13: # end_print_hex
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    leave
    ret

# (buff, size)
print_string:
    push rbp
    mov rbp, rsp
    push rax
    push rdi
    push rsi
    push rdx
    mov rax, 1
    mov rdx, rsi
    mov rsi, rdi
    mov rdi, 1
    syscall
    pop rdx
    pop rsi
    pop rdi
    pop rax
    leave
    ret

# strlen(char*)
strlen:
    xor eax, eax
    mov [esp+4], eax
loop_strlen:
    ...

# strcmp(char*, char*)
strcmp:

# read_hex(char* dst)
read_hex:

# read_string(char* dst, int size)
read_string:

# open_file(char* fname)
open_file:

# write_file(int fd, char* buff, int size)
write_file:

# read_file(int fd, char* buff, int size)
read_file:

# close_file(int fd)
close_file: