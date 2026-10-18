; Chargement et sauvegarde de vault.db (load_db, save_db).
; Inclus par secure_vault.asm dans la section .text.

; load_db()
; Charge vault.db (chiffre) dans db_buffer et sa taille dans db_size.
; Refuse un fichier plus grand que le tampon, ou dont la taille n'est
; pas un multiple de 64 (un message est affiche).
; Retour : rax = taille chargee, valeur negative si erreur.
load_db:
    push rbp
    mov rbp, rsp

    mov rdi, db_filename
    call open_file
    cmp rax, 0
    jl .end
    mov [db_fd], rax

    mov rdi, [db_fd]
    mov rsi, db_buffer
    mov rdx, DB_CAPACITY
    call read_all
    cmp rax, 0
    jl .close_error
    mov [db_size], rax
    cmp rax, DB_CAPACITY
    jb .close                ; Tampon pas plein : tout le fichier est lu.

    ; Tampon plein : verifier qu'il ne reste rien a lire.
    mov rdi, [db_fd]
    mov rsi, db_probe
    mov rdx, 1
    call read_file
    cmp rax, 0
    jl .close_error
    je .close
    mov rdi, msg_large
    mov rsi, msg_large_size
    call print_string
    jmp .close_error

.close:
    mov rdi, [db_fd]
    call close_file
    cmp rax, 0
    jl .end
    mov rax, [db_size]
    and rax, 63              ; Chaque entree occupe exactement 64 octets.
    cmp rax, 0
    jne .invalid
    mov rax, [db_size]
    jmp .end

.invalid:
    mov rdi, msg_invalid
    mov rsi, msg_invalid_size
    call print_string
    mov rax, -1
    jmp .end

.close_error:
    mov rdi, [db_fd]
    call close_file
    mov rax, -1
.end:
    leave
    ret

; save_db()
; Ecrit les db_size octets de db_buffer au debut de vault.db.
; Le fichier n'est pas vide avant l'ecriture : la nouvelle base est
; toujours plus grande que l'ancienne, elle la recouvre entierement.
; Retour : rax = 0 si succes, valeur negative si erreur.
save_db:
    push rbp
    mov rbp, rsp

    mov rdi, db_filename
    call open_file
    cmp rax, 0
    jl .end
    mov [db_fd], rax

    mov rdi, [db_fd]
    mov rsi, db_buffer
    mov rdx, [db_size]
    call write_all
    cmp rax, 0
    jl .close_error

    mov rdi, [db_fd]
    call close_file          ; rax = 0 ou erreur.
    jmp .end

.close_error:
    mov rdi, [db_fd]
    call close_file
    mov rax, -1
.end:
    leave
    ret
