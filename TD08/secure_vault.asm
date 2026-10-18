global _start

; Une entree de la base : 32 octets pour chaque champ.
struc credential
    .login:    resb 32
    .password: resb 32
endstruc

DB_CAPACITY equ 4096        ; Taille du tampon de la base : 64 entrees.

section .text

; Bibliotheque generique (print_string, read_string, fichiers, xor_ecb...).
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
; Fonctions du Secure Vault (un fichier par fonctionnalite)
; =====================================================================
%include "./vault/db.inc"
%include "./vault/f0_open.inc"
%include "./vault/f1_add.inc"
%include "./vault/f2_show.inc"


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
