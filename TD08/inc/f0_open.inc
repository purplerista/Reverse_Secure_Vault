; F0 : mot de passe de la base et creation du fichier.
; Inclus par secure_vault.asm dans la section .text.

; f0_open_vault()
; F0 : demande le mot de passe de la base, garde ses 8 premiers octets
; comme cle (db_key) et cree vault.db s'il n'existe pas.
; Retour : rax = 0 si succes, valeur negative si erreur.
f0_open_vault:
    push rbp
    mov rbp, rsp

    mov rdi, message_db
    call print

    mov rdi, db_password
    mov rsi, 32              ; Capacite : 31 caracteres et un zero final.
    call read_string

    mov rax, [db_password]   ; Lire les 8 premiers octets dans rax.
    mov [db_key], rax        ; Copier ces 8 octets dans la cle.

    mov rdi, db_filename     ; Ouvrir ou creer la base...
    call open_file
    cmp rax, 0
    jl f0_open_vault_end
    mov rdi, rax
    call close_file          ; ...puis la fermer : rax = 0 ou erreur.
f0_open_vault_end:
    leave
    ret
