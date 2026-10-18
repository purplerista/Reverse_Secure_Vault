global _start

; Une entree de la base : 32 octets pour chaque champ.
struc credential
    .login:    resb 32
    .password: resb 32
endstruc

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
    call print

    mov rdi, menu_choice
    mov rsi, 3              ; Deux caracteres utiles et un zero final.
    call read_string
    cmp rax, 1              ; Le choix doit contenir un seul caractere.
    jne exit_program

    cmp byte [menu_choice], '1'
    je start_choice_f1
    cmp byte [menu_choice], '2'
    je start_choice_f2
    jmp exit_program

start_choice_f1:
    call f1_add_credential
    jmp start_check_result
start_choice_f2:
    call f2_show_vault
start_check_result:
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
%include "./inc/db.inc"
%include "./inc/f0_open.inc"
%include "./inc/f1_add.inc"
%include "./inc/f2_show.inc"


section .data
    message_db: db "Entrez le mot de passe de la base : ", 0
    db_filename: db "vault.db", 0   ; Zero final requis par open.

    msg_menu: db "1 : Ajouter des identifiants", 10
              db "2 : Afficher la base", 10
              db "Votre choix : ", 0
    msg_login: db "Login : ", 0
    msg_password: db "Password : ", 0
    nl: db 10

    msg_saved: db "Identifiants enregistres.", 10, 0
    msg_invalid: db "Format de base invalide : taille non multiple de 64.", 10, 0
    msg_full: db "Base trop grande pour ajouter une entree dans le tampon.", 10, 0
    msg_large: db "Base trop grande pour le tampon de 4096 octets.", 10, 0
    msg_empty: db "Base vide.", 10, 0

section .bss
    db_password: resb 32        ; Mot de passe de la base (F0).
    db_key: resq 1              ; Cle XOR : 8 premiers octets du mot de passe.
    menu_choice: resb 3         ; Reponse au menu.
    credential1: resb credential_size   ; Entree saisie dans F1.
    db_buffer: resb 4096        ; Contenu de la base : 64 entrees maximum.
    db_size: resq 1             ; Nombre d'octets utiles dans db_buffer.
    db_fd: resq 1               ; Descripteur du fichier vault.db ouvert.
    db_probe: resb 1            ; Octet de test : reste-t-il des donnees ?
