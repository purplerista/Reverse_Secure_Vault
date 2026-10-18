global _start

; Un enregistrement : 32 octets pour chaque champ.
struc credential
    .login:    resb 32
    .password: resb 32
endstruc

section .text

; Fonctions de la bibliotheque (print_string, read_string, fichiers...).
%include "./inc/cours.inc"

_start:
    ;afficher la demande du mot de passe
    mov rdi, message_db       ; Adresse du texte a afficher.
    mov rsi, message_db_size  ; Nombre d'octets du texte.
    call print_string        ; Appeler la fonction du prof.

    ; ===== DEBUT AJOUT ETAPE 2 : lire le mot de passe =====
    mov rdi, db_password     ; Adresse ou stocker la saisie.
    mov rsi, 32              ; Capacite : 31 caracteres et un zero final.
    call read_string         ; Attendre la saisie jusqu'a Entree.
    ; ===== FIN AJOUT ETAPE 2 : lecture =====

    ; ===== DEBUT AJOUT ETAPE 3 : conserver la cle XOR =====
    mov rax, [db_password]   ; Lire les 8 premiers octets dans rax.
    mov [db_key], rax        ; Copier ces 8 octets dans la cle.
    ; ===== FIN AJOUT ETAPE 3 : copie de la cle =====

    ; ===== DEBUT AJOUT ETAPE 4 : ouvrir ou creer puis fermer la base =====
    mov rdi, db_filename    ; Adresse du nom "vault.db".
    call open_file
    cmp rax, 0
    jl file_error           ; Ne pas utiliser un descripteur invalide.

    mov rdi, rax            ; Donner le descripteur a close_file.
    call close_file
    cmp rax, 0
    jl file_error
    ; ===== FIN AJOUT ETAPE 4 : ouverture et fermeture =====

    ; ===== DEBUT AJOUT ETAPE 5 : menu et lecture du choix =====
menu:
    mov rdi, msg_menu
    mov rsi, msg_menu_size
    call print_string

    mov rdi, menu_choice
    mov rsi, 3              ; Deux caracteres utiles et un zero final.
    call read_string
    cmp rax, 1              ; Le choix doit contenir un seul caractere.
    jne exit_program

    cmp byte [menu_choice], '1'
    je F1
    cmp byte [menu_choice], '2'
    je F2
    jmp exit_program

F1:
    ; ===== DEBUT AJOUT ETAPE 6 : saisir les deux champs de la structure =====
    mov rdi, msg_login
    mov rsi, msg_login_size
    call print_string

    mov rdi, credential1 + credential.login
    mov rsi, 32              ; Capacite du champ login, zero final compris.
    call read_string

    mov rdi, msg_password
    mov rsi, msg_password_size
    call print_string

    mov rdi, credential1 + credential.password
    mov rsi, 32              ; Capacite du champ password, zero final compris.
    call read_string
    ; Les deux champs de la nouvelle entree sont maintenant en memoire.
    ; ===== FIN AJOUT ETAPE 6 : saisie =====

    ; ===== DEBUT AJOUT ETAPE 7 : charger la base dans le tampon =====
    mov rdi, db_filename
    call open_file
    cmp rax, 0
    jl file_error
    mov [db_fd], rax        ; Conserver le descripteur pendant la lecture.

    mov rdi, [db_fd]        ; Fichier a lire.
    mov rsi, db_buffer      ; Adresse du tampon.
    mov rdx, 4096           ; Capacite du tampon.
    call read_all
    cmp rax, 0
    jl read_db_error
    mov [db_size], rax      ; Nombre d'octets charges.

    mov rdi, [db_fd]
    call close_file
    cmp rax, 0
    jl file_error
    ; db_buffer contient les octets du fichier, db_size leur nombre.
    ; ===== FIN AJOUT ETAPE 7 : chargement =====

    ; ===== DEBUT AJOUT ETAPE 8 : terminer F1 =====
    ; Une entree fait 64 octets : verifier le format et la place pour l'ajout.
    mov rax, [db_size]
    and rax, 63
    cmp rax, 0
    jne db_invalid
    cmp qword [db_size], 4096 - credential_size
    ja db_full              ; Refuser aussi un fichier qui remplit le tampon.

    ; Dechiffrer la base chargee.
    mov rdi, db_buffer      ; Adresse du tampon.
    mov rsi, [db_size]      ; Taille : valeur de db_size.
    mov rdx, [db_key]       ; Cle : valeur de db_key.
    call xor_ecb

append_credential:
    ; Copier les 64 octets de credential1 a la fin de la base en clair.
    mov rdi, db_buffer
    add rdi, [db_size]
    xor rbx, rbx
copy_credential_loop:
    cmp rbx, credential_size
    jae credential_copied
    mov al, [credential1 + rbx]
    mov [rdi + rbx], al
    inc rbx
    jmp copy_credential_loop

credential_copied:
    add qword [db_size], credential_size
    ; Rechiffrer toute la base, nouvelle entree comprise.
    mov rdi, db_buffer
    mov rsi, [db_size]
    mov rdx, [db_key]
    call xor_ecb

save_db:
    ; Rouvrir pour repartir du debut du fichier, sans effacer son contenu.
    mov rdi, db_filename
    call open_file
    cmp rax, 0
    jl file_error
    mov [db_fd], rax

    mov rdi, [db_fd]        ; Fichier a ecrire.
    mov rsi, db_buffer      ; Donnees chiffrees.
    mov rdx, [db_size]      ; Nombre d'octets a ecrire.
    call write_all
    cmp rax, 0
    jl write_db_error

    mov rdi, [db_fd]
    call close_file
    cmp rax, 0
    jl file_error
    mov rdi, msg_saved
    mov rsi, msg_saved_size
    call print_string
    jmp exit_program

write_db_error:
    mov rdi, [db_fd]
    call close_file
    jmp file_error

db_invalid:
    mov rdi, msg_invalid
    mov rsi, msg_invalid_size
    call print_string
    jmp file_error

db_full:
    mov rdi, msg_full
    mov rsi, msg_full_size
    call print_string
    jmp file_error
    ; ===== FIN AJOUT ETAPE 8 : F1 =====

; ===== DEBUT AJOUT ETAPE 7 : fermer aussi si la lecture echoue =====
read_db_error:
    mov rdi, [db_fd]
    call close_file
    jmp file_error
; ===== FIN AJOUT ETAPE 7 : erreur de lecture =====

F2:
    ; ===== DEBUT AJOUT ETAPE 9 : lire, dechiffrer et afficher la base =====
    mov rdi, db_filename
    call open_file
    cmp rax, 0
    jl file_error
    mov [db_fd], rax

    mov rdi, [db_fd]
    mov rsi, db_buffer
    mov rdx, 4096
    call read_all
    cmp rax, 0
    jl read_db_error
    mov [db_size], rax
    cmp rax, 4096
    jb f2_read_done         ; Tampon pas plein : tout le fichier est lu.

f2_check_end:
    ; Tampon plein : verifier qu'aucun octet du fichier ne reste a lire.
    mov rdi, [db_fd]
    mov rsi, db_probe
    mov rdx, 1
    call read_file
    cmp rax, 0
    jl read_db_error
    je f2_read_done
    mov rdi, [db_fd]
    call close_file
    mov rdi, msg_large
    mov rsi, msg_large_size
    call print_string
    jmp file_error

f2_read_done:
    mov rdi, [db_fd]
    call close_file
    cmp rax, 0
    jl file_error
    mov rax, [db_size]
    and rax, 63             ; Chaque entree doit occuper exactement 64 octets.
    cmp rax, 0
    jne db_invalid

    ; Dechiffrer la copie en memoire (le fichier reste chiffre).
    mov rdi, db_buffer
    mov rsi, [db_size]
    mov rdx, [db_key]
    call xor_ecb

f2_display_start:
    xor rbx, rbx           ; Position de l'entree courante : 0, 64, 128...
f2_display_loop:
    cmp rbx, [db_size]
    jae exit_program

    mov rdi, msg_login
    mov rsi, msg_login_size
    call print_string
    mov rdi, db_buffer + credential.login
    add rdi, rbx
    xor rsi, rsi
f2_login_length:
    cmp rsi, 32             ; Ne jamais lire au-dela du champ login.
    jae f2_print_login
    cmp byte [rdi + rsi], 0
    je f2_print_login
    inc rsi
    jmp f2_login_length
f2_print_login:
    call print_string
    mov rdi, nl
    mov rsi, 1
    call print_string

    mov rdi, msg_password
    mov rsi, msg_password_size
    call print_string
    mov rdi, db_buffer + credential.password
    add rdi, rbx
    xor rsi, rsi
f2_password_length:
    cmp rsi, 32             ; Ne jamais lire au-dela du champ password.
    jae f2_print_password
    cmp byte [rdi + rsi], 0
    je f2_print_password
    inc rsi
    jmp f2_password_length
f2_print_password:
    call print_string
    mov rdi, nl
    mov rsi, 1
    call print_string

    add rbx, credential_size ; Passer a l'entree suivante.
    jmp f2_display_loop
    ; Aucun write_file : le fichier sur disque reste chiffre.
    ; ===== FIN AJOUT ETAPE 9 : F2 =====

exit_program:
    ; ===== FIN AJOUT ETAPE 5 : menu =====
    ; Quitter proprement le programme.
    mov rax, 60
    xor rdi, rdi
    syscall

; ===== DEBUT AJOUT ETAPE 4 : sortie en cas d'erreur fichier =====
file_error:
    mov rax, 60             ; Correction : syscall exit = 60 (0x3c).
    mov rdi, 1              ; Code de sortie 1 : echec de l'operation fichier.
    syscall
; ===== FIN AJOUT ETAPE 4 : sortie erreur =====


section .data
    message_db: db "Entrez le mot de passe de la base : "
    message_db_size: equ $ - message_db ; Longueur du texte en octets.
    ; ===== DEBUT AJOUT ETAPE 4 : nom du fichier de la base =====
    db_filename: db "vault.db", 0 ; Zero final requis par open.
    ; ===== FIN AJOUT ETAPE 4 : nom du fichier =====
    ; ===== DEBUT AJOUT ETAPE 5 : messages du menu =====
    msg_menu: db "1 : Ajouter des identifiants", 10
              db "2 : Afficher la base", 10
              db "Votre choix : "
    msg_menu_size: equ $ - msg_menu
    ; ===== FIN AJOUT ETAPE 5 : messages =====
    ; ===== DEBUT AJOUT ETAPE 6 : questions pour les identifiants =====
    msg_login: db "Login : "
    msg_login_size: equ $ - msg_login
    msg_password: db "Password : "
    msg_password_size: equ $ - msg_password
    ; ===== FIN AJOUT ETAPE 6 : questions =====
    ; ===== DEBUT AJOUT ETAPE 8 : resultat de F1 =====
    msg_saved: db "Identifiants enregistres.", 10
    msg_saved_size: equ $ - msg_saved
    msg_invalid: db "Format de base invalide : taille non multiple de 64.", 10
    msg_invalid_size: equ $ - msg_invalid
    msg_full: db "Base trop grande pour ajouter une entree dans le tampon.", 10
    msg_full_size: equ $ - msg_full
    ; ===== FIN AJOUT ETAPE 8 : messages =====
    ; ===== DEBUT AJOUT ETAPE 9 : affichage de F2 =====
    nl: db 10
    msg_large: db "Base trop grande pour le tampon de 4096 octets.", 10
    msg_large_size: equ $ - msg_large
    ; ===== FIN AJOUT ETAPE 9 : messages =====

section .bss
    credential1: resb credential_size
    ; ===== DEBUT AJOUT ETAPE 2 : tampon du mot de passe =====
    db_password: resb 32
    ; ===== FIN AJOUT ETAPE 2 : tampon =====
    ; ===== DEBUT AJOUT ETAPE 3 : cle de 8 octets =====
    db_key: resq 1
    ; ===== FIN AJOUT ETAPE 3 : cle =====
    ; ===== DEBUT AJOUT ETAPE 5 : tampon du choix =====
    menu_choice: resb 3
    ; ===== FIN AJOUT ETAPE 5 : tampon =====
    ; ===== DEBUT AJOUT ETAPE 7 : tampon de lecture de la base =====
    db_buffer: resb 4096    ; Capacite fixe pour cette version : 4096 octets.
    db_size: resq 1         ; Nombre d'octets effectivement charges.
    db_fd: resq 1           ; Descripteur du fichier ouvert.
    ; ===== FIN AJOUT ETAPE 7 : tampon de la base =====
    ; ===== DEBUT AJOUT ETAPE 9 : verification de la fin du fichier =====
    db_probe: resb 1
    ; ===== FIN AJOUT ETAPE 9 : verification =====
