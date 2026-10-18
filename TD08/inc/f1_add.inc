; F1 : ajout d'identifiants dans la base.
; Inclus par secure_vault.asm dans la section .text.

; f1_add_credential()
; F1 : demande login et password, dechiffre la base, ajoute l'entree,
; rechiffre l'ensemble et sauvegarde.
; Retour : rax = 0 si succes, valeur negative si erreur.
f1_add_credential:
    push rbp
    mov rbp, rsp

    mov rdi, msg_login
    call print
    mov rdi, credential1 + credential.login
    mov rsi, 32              ; Capacite du champ, zero final compris.
    call read_string

    mov rdi, msg_password
    call print
    mov rdi, credential1 + credential.password
    mov rsi, 32
    call read_string

    call load_db             ; rax = taille de la base chiffree.
    cmp rax, 0
    jl f1_add_credential_end
    cmp rax, 4096 - credential_size
    jbe f1_add_credential_has_room
    mov rdi, msg_full
    call print
    mov rax, -1
    jmp f1_add_credential_end

f1_add_credential_has_room:
    ; Dechiffrer la base chargee.
    mov rdi, db_buffer
    mov rsi, [db_size]
    mov rdx, [db_key]
    call xor_ecb

    ; Copier les 64 octets de credential1 a la fin de la base en clair.
    mov rdi, db_buffer
    add rdi, [db_size]
    xor rcx, rcx             ; rcx est caller-saved : pas de sauvegarde.
f1_add_credential_copy:
    cmp rcx, credential_size
    jae f1_add_credential_copied
    mov al, [credential1 + rcx]
    mov [rdi + rcx], al
    inc rcx
    jmp f1_add_credential_copy
f1_add_credential_copied:
    add qword [db_size], credential_size

    ; Rechiffrer toute la base, nouvelle entree comprise.
    mov rdi, db_buffer
    mov rsi, [db_size]
    mov rdx, [db_key]
    call xor_ecb

    call save_db
    cmp rax, 0
    jl f1_add_credential_end
    mov rdi, msg_saved
    call print
    xor rax, rax
f1_add_credential_end:
    leave
    ret
