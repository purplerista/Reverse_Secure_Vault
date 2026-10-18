; F2 : affichage de la base dechiffree.
; Inclus par secure_vault.asm dans la section .text.

; f2_show_vault()
; F2 : charge la base, la dechiffre en memoire et affiche chaque entree.
; Le fichier sur disque reste chiffre.
; Retour : rax = 0 si succes, valeur negative si erreur.
f2_show_vault:
    push rbp
    mov rbp, rsp
    push rbx                 ; callee-saved : il traverse des appels.

    call load_db
    cmp rax, 0
    jl f2_show_vault_end
    jne f2_show_vault_decrypt
    mov rdi, msg_empty       ; Aucune entree dans la base.
    call print
    jmp f2_show_vault_done

f2_show_vault_decrypt:
    mov rdi, db_buffer
    mov rsi, [db_size]
    mov rdx, [db_key]
    call xor_ecb

    xor rbx, rbx             ; Position de l'entree courante : 0, 64, 128...
f2_show_vault_next_entry:
    cmp rbx, [db_size]
    jae f2_show_vault_done

    mov rdi, msg_login
    call print
    mov rdi, db_buffer + credential.login
    add rdi, rbx
    call strlen              ; read_string a garanti le zero final.
    mov rsi, rax             ; rdi n'a pas ete modifie par strlen.
    call print_string
    mov rdi, nl
    mov rsi, 1
    call print_string

    mov rdi, msg_password
    call print
    mov rdi, db_buffer + credential.password
    add rdi, rbx
    call strlen
    mov rsi, rax
    call print_string
    mov rdi, nl
    mov rsi, 1
    call print_string

    add rbx, credential_size ; Entree suivante.
    jmp f2_show_vault_next_entry
f2_show_vault_done:
    xor rax, rax
f2_show_vault_end:
    pop rbx
    leave
    ret
