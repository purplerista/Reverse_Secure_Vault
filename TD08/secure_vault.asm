global _start

; Une entree de la base : 32 octets pour chaque champ.
struc credential
    .login:    resb 32
    .password: resb 32
endstruc

DB_CAPACITY equ 4096        ; Taille du tampon de la base : 64 entrees.

section .text

; Fonctions de la bibliotheque (print_string, read_string, fichiers...).
%include "./inc/cours.inc"

; =====================================================================
; Programme principal
; =====================================================================

; F0, puis menu : 1 -> F1, 2 -> F2. Une seule action par lancement.
; Les fonctions F0/F1/F2 renvoient rax < 0 en cas d'erreur.
_start:
    call f0_open_vault
    cmp rax, 0
    jl file_error

    mov rdi, msg_menu
    mov rsi, msg_menu_size
    call print_string

    mov rdi, menu_choice
    mov rsi, 3              ; Deux caracteres utiles et un zero final.
    call read_string
    cmp rax, 1              ; Le choix doit contenir un seul caractere.
    jne exit_program

    cmp byte [menu_choice], '1'
    je .choice_f1
    cmp byte [menu_choice], '2'
    je .choice_f2
    jmp exit_program

.choice_f1:
    call f1_add_credential
    jmp .check_result
.choice_f2:
    call f2_show_vault
.check_result:
    cmp rax, 0
    jl file_error

exit_program:
    mov rax, 60             ; Syscall exit.
    xor rdi, rdi            ; Code de sortie 0 : succes.
    syscall

file_error:
    mov rax, 60             ; Syscall exit.
    mov rdi, 1              ; Code de sortie 1 : echec d'une operation fichier.
    syscall

; =====================================================================
; F0, F1, F2
; =====================================================================

; f0_open_vault()
; F0 : demande le mot de passe de la base, garde ses 8 premiers octets
; comme cle (db_key) et cree vault.db s'il n'existe pas.
; Retour : rax = 0 si succes, valeur negative si erreur.
f0_open_vault:
    push rbp
    mov rbp, rsp

    mov rdi, message_db
    mov rsi, message_db_size
    call print_string

    mov rdi, db_password
    mov rsi, 32              ; Capacite : 31 caracteres et un zero final.
    call read_string

    mov rax, [db_password]   ; Lire les 8 premiers octets dans rax.
    mov [db_key], rax        ; Copier ces 8 octets dans la cle.

    mov rdi, db_filename     ; Ouvrir ou creer la base...
    call open_file
    cmp rax, 0
    jl .end
    mov rdi, rax
    call close_file          ; ...puis la fermer : rax = 0 ou erreur.
.end:
    leave
    ret

; f1_add_credential()
; F1 : demande login et password, dechiffre la base, ajoute l'entree,
; rechiffre l'ensemble et sauvegarde.
; Retour : rax = 0 si succes, valeur negative si erreur.
f1_add_credential:
    push rbp
    mov rbp, rsp

    mov rdi, msg_login
    mov rsi, msg_login_size
    call print_string
    mov rdi, credential1 + credential.login
    mov rsi, 32              ; Capacite du champ, zero final compris.
    call read_string

    mov rdi, msg_password
    mov rsi, msg_password_size
    call print_string
    mov rdi, credential1 + credential.password
    mov rsi, 32
    call read_string

    call load_db             ; rax = taille de la base chiffree.
    cmp rax, 0
    jl .end
    cmp rax, DB_CAPACITY - credential_size
    jbe .has_room
    mov rdi, msg_full
    mov rsi, msg_full_size
    call print_string
    mov rax, -1
    jmp .end

.has_room:
    ; Dechiffrer la base chargee.
    mov rdi, db_buffer
    mov rsi, [db_size]
    mov rdx, [db_key]
    call xor_ecb

    ; Copier les 64 octets de credential1 a la fin de la base en clair.
    mov rdi, db_buffer
    add rdi, [db_size]
    xor rcx, rcx             ; rcx est caller-saved : pas de sauvegarde.
.copy:
    cmp rcx, credential_size
    jae .copied
    mov al, [credential1 + rcx]
    mov [rdi + rcx], al
    inc rcx
    jmp .copy
.copied:
    add qword [db_size], credential_size

    ; Rechiffrer toute la base, nouvelle entree comprise.
    mov rdi, db_buffer
    mov rsi, [db_size]
    mov rdx, [db_key]
    call xor_ecb

    call save_db
    cmp rax, 0
    jl .end
    mov rdi, msg_saved
    mov rsi, msg_saved_size
    call print_string
    xor rax, rax
.end:
    leave
    ret

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
    jl .end

    mov rdi, db_buffer
    mov rsi, [db_size]
    mov rdx, [db_key]
    call xor_ecb

    xor rbx, rbx             ; Position de l'entree courante : 0, 64, 128...
.next_entry:
    cmp rbx, [db_size]
    jae .done

    mov rdi, msg_login
    mov rsi, msg_login_size
    call print_string
    mov rdi, db_buffer + credential.login
    add rdi, rbx
    call strlen              ; read_string a garanti le zero final.
    mov rsi, rax             ; rdi n'a pas ete modifie par strlen.
    call print_string
    mov rdi, nl
    mov rsi, 1
    call print_string

    mov rdi, msg_password
    mov rsi, msg_password_size
    call print_string
    mov rdi, db_buffer + credential.password
    add rdi, rbx
    call strlen
    mov rsi, rax
    call print_string
    mov rdi, nl
    mov rsi, 1
    call print_string

    add rbx, credential_size ; Entree suivante.
    jmp .next_entry
.done:
    xor rax, rax
.end:
    pop rbx
    leave
    ret

; =====================================================================
; Chargement et sauvegarde de la base
; =====================================================================

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


section .data
    message_db: db "Entrez le mot de passe de la base : "
    message_db_size: equ $ - message_db
    db_filename: db "vault.db", 0   ; Zero final requis par open.

    msg_menu: db "1 : Ajouter des identifiants", 10
              db "2 : Afficher la base", 10
              db "Votre choix : "
    msg_menu_size: equ $ - msg_menu
    msg_login: db "Login : "
    msg_login_size: equ $ - msg_login
    msg_password: db "Password : "
    msg_password_size: equ $ - msg_password
    nl: db 10

    msg_saved: db "Identifiants enregistres.", 10
    msg_saved_size: equ $ - msg_saved
    msg_invalid: db "Format de base invalide : taille non multiple de 64.", 10
    msg_invalid_size: equ $ - msg_invalid
    msg_full: db "Base trop grande pour ajouter une entree dans le tampon.", 10
    msg_full_size: equ $ - msg_full
    msg_large: db "Base trop grande pour le tampon de 4096 octets.", 10
    msg_large_size: equ $ - msg_large

section .bss
    db_password: resb 32        ; Mot de passe de la base (F0).
    db_key: resq 1              ; Cle XOR : 8 premiers octets du mot de passe.
    menu_choice: resb 3         ; Reponse au menu.
    credential1: resb credential_size   ; Entree saisie dans F1.
    db_buffer: resb DB_CAPACITY ; Contenu de la base en memoire.
    db_size: resq 1             ; Nombre d'octets utiles dans db_buffer.
    db_fd: resq 1               ; Descripteur du fichier vault.db ouvert.
    db_probe: resb 1            ; Octet de test : reste-t-il des donnees ?
