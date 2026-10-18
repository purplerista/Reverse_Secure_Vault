; =====================================================================
; cours.inc : bibliotheque de fonctions (NASM, x86-64, Linux)
;
; Convention d'appel (System V) :
;   arguments : rdi, rsi, rdx      retour : rax
; Chaque fonction a un prologue (push rbp / mov rbp, rsp ou enter)
; et un epilogue (leave / ret).
; Registres preserves (callee-saved) : rbx, rbp, r12 a r15 ; une fonction
; qui les utilise les sauvegarde sur la pile (read_all, write_all).
; Registres modifiables (caller-saved) : rax, rcx, rdx, rsi, rdi, r8 a r11.
; L'instruction syscall modifie toujours rax, rcx et r11.
;
; A inclure dans la section .text :  %include "./inc/cours.inc"
; =====================================================================

; ---------------------------------------------------------------------
; Affichage
; ---------------------------------------------------------------------

; print_hex(val)
; rdi = valeur a afficher en hexadecimal (16 chiffres).
print_hex:
    push rbp
    mov rbp, rsp
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    xor r8, r8
L9: ; print_char
    rol rdi, 4
    mov rbx, rdi
    and rbx, 0xf
    cmp rbx, 0xa
    jae L11
L10: ; print_0123456789
    add rbx, 0x30
    jmp L12
L11: ; print_abcdef
    add rbx, 0x57
L12: ; print
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
L13: ; end_print_hex
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    leave
    ret

; print_string(buff, size)
; rdi = adresse du texte, rsi = nombre d'octets a afficher.
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

; print(char*)
; rdi = adresse d'une chaine terminee par 0.
; Affiche la chaine : sa longueur est calculee par strlen.
print:
    push rbp
    mov rbp, rsp
    push rsi
    call strlen             ; rax = longueur, rdi inchange.
    mov rsi, rax
    call print_string
    pop rsi
    leave
    ret

; ---------------------------------------------------------------------
; Chaines de caracteres
; ---------------------------------------------------------------------

; strlen(char*)
; rdi = adresse d'une chaine terminee par 0.
; Retour : rax = nombre de caracteres, sans compter le 0.
strlen:
    push rbp
    mov rbp, rsp
    xor rax, rax
loop_strlen:
    cmp byte [rdi + rax], 0
    je strlen_end
    inc rax
    jmp loop_strlen
strlen_end:
    leave
    ret

; strcmp(char*, char*)
; rdi = chaine 1, rsi = chaine 2, toutes deux terminees par 0.
; Retour : rax = 0 si les chaines sont egales, sinon la difference
; entre les deux premiers caracteres differents.
strcmp:
    push rbp
    mov rbp, rsp
    push rcx
    push rdx
    xor rcx, rcx            ; Position courante.
strcmp_compare:
    xor rax, rax
    mov al, [rdi + rcx]
    xor rdx, rdx
    mov dl, [rsi + rcx]
    cmp rax, rdx
    jne strcmp_different
    cmp rax, 0
    je strcmp_end                 ; Meme fin de chaine : rax vaut deja 0.
    inc rcx
    jmp strcmp_compare
strcmp_different:
    sub rax, rdx
strcmp_end:
    pop rdx
    pop rcx
    leave
    ret

; ---------------------------------------------------------------------
; Saisie au clavier
; ---------------------------------------------------------------------

; read_string(char* dst, int size)
; rdi = adresse du tampon, rsi = capacite totale (zero final compris).
; Lit jusqu'a Entree, sans garder le saut de ligne, et termine par 0.
; Les caracteres en trop sont lus puis ignores.
; Retour : rax = nombre de caracteres stockes.
read_string:
    enter 32, 0
    push rdi
    push rsi
    push rdx

    mov [rbp - 8], rdi       ; Adresse du tampon.
    mov qword [rbp - 24], 0  ; Nombre de caracteres stockes.
    cmp rsi, 0
    je read_string_return
    dec rsi                 ; Reserver un octet pour le zero final.
    mov [rbp - 16], rsi     ; Nombre maximal de caracteres utiles.

read_string_read_char:
    mov rax, 0              ; Syscall read.
    mov rdi, 0              ; Entree standard : clavier.
    lea rsi, [rbp - 32]     ; Case temporaire pour un caractere.
    mov rdx, 1              ; Lire un seul octet.
    syscall
    cmp rax, 0
    jle read_string_finish             ; Fin de l'entree ou erreur de lecture.
    cmp byte [rbp - 32], 10
    je read_string_finish              ; Entree produit le saut de ligne 10.

    mov rdx, [rbp - 24]
    cmp rdx, [rbp - 16]
    jae read_string_read_char          ; Tampon plein : consommer jusqu'a Entree.
    mov rdi, [rbp - 8]
    mov al, [rbp - 32]
    mov [rdi + rdx], al      ; Stocker le caractere dans le tampon.
    inc qword [rbp - 24]
    jmp read_string_read_char

read_string_finish:
    mov rdi, [rbp - 8]
    mov rdx, [rbp - 24]
    mov byte [rdi + rdx], 0  ; Marquer la fin de la chaine.
read_string_return:
    mov rax, [rbp - 24]
    pop rdx
    pop rsi
    pop rdi
    leave
    ret

; read_hex()
; Lit une ligne au clavier et la convertit depuis l'hexadecimal
; (chiffres 0-9, a-f ou A-F, sans prefixe 0x). La conversion
; s'arrete au premier caractere qui n'est pas un chiffre hexadecimal.
; Retour : rax = valeur lue.
read_hex:
    enter 32, 0
    push rdi
    push rsi
    push rdx

    lea rdi, [rbp - 32]     ; Tampon local de 32 octets.
    mov rsi, 32
    call read_string

    xor rax, rax            ; Valeur en cours de construction.
    lea rdi, [rbp - 32]
read_hex_next_digit:
    xor rdx, rdx
    mov dl, [rdi]
    cmp dl, '0'
    jb read_hex_end                 ; Le zero final arrete aussi la boucle.
    cmp dl, '9'
    jbe read_hex_decimal
    or dl, 0x20             ; Majuscule -> minuscule.
    cmp dl, 'a'
    jb read_hex_end
    cmp dl, 'f'
    ja read_hex_end
    sub dl, 'a' - 10        ; 'a' -> 10 ... 'f' -> 15.
    jmp read_hex_add_digit
read_hex_decimal:
    sub dl, '0'             ; '0' -> 0 ... '9' -> 9.
read_hex_add_digit:
    shl rax, 4              ; Decaler d'un chiffre hexadecimal.
    add rax, rdx
    inc rdi
    jmp read_hex_next_digit
read_hex_end:
    pop rdx
    pop rsi
    pop rdi
    leave
    ret

; ---------------------------------------------------------------------
; Chiffrement
; ---------------------------------------------------------------------

; xor_ecb(buff, size, key)
; rdi = adresse du tampon, rsi = taille en octets (multiple de 8),
; rdx = cle de 8 octets.
; Chiffre ou dechiffre le tampon sur place : chaque bloc de 8 octets
; est combine par XOR avec la meme cle (ECB).
xor_ecb:
    push rbp
    mov rbp, rsp
    xor rcx, rcx                 ; Position dans le tampon.
xor_ecb_next_block:
    cmp rcx, rsi
    jae xor_ecb_end
    xor qword [rdi + rcx], rdx
    add rcx, 8                   ; Bloc suivant.
    jmp xor_ecb_next_block
xor_ecb_end:
    leave
    ret

; ---------------------------------------------------------------------
; Fichiers
; ---------------------------------------------------------------------

; open_file(char* fname)
; rdi = adresse du nom termine par 0.
; Ouvre en lecture/ecriture et cree le fichier s'il n'existe pas.
; Retour : rax = descripteur du fichier, ou valeur negative si erreur.
open_file:
    push rbp
    mov rbp, rsp
    push rsi
    push rdx
    mov rax, 2              ; Syscall open.
    mov rsi, 66             ; Drapeaux : O_RDWR (2) + O_CREAT (64) = 66.
    mov rdx, 0x180          ; Droits si creation : rw------- (600 en octal = 0x180).
    syscall
    pop rdx
    pop rsi
    leave
    ret

; write_file(int fd, char* buff, int size)
; rdi = descripteur, rsi = adresse des donnees, rdx = nombre d'octets.
; Retour : rax = nombre d'octets ecrits, valeur negative si erreur.
write_file:
    push rbp
    mov rbp, rsp
    mov rax, 1              ; Syscall write : meme principe que print_string.
    syscall
    leave
    ret

; read_file(int fd, char* buff, int size)
; rdi = descripteur, rsi = adresse du tampon, rdx = taille maximale.
; Retour : rax = nombre d'octets lus, 0 en fin de fichier, negatif si erreur.
read_file:
    push rbp
    mov rbp, rsp
    mov rax, 0              ; Syscall read, comme pour la lecture au clavier.
    syscall                 ; Ici rdi designe le fichier, pas le clavier.
    leave
    ret

; read_all(int fd, char* buff, int max)
; rdi = descripteur, rsi = adresse du tampon, rdx = capacite du tampon.
; Appelle read_file jusqu'a la fin du fichier ou jusqu'a remplir le tampon.
; Retour : rax = nombre total d'octets lus, valeur negative si erreur.
read_all:
    push rbp
    mov rbp, rsp
    push rbx                ; rbx, r12, r13, r14 sont callee-saved :
    push r12                ; on les sauvegarde avant de s'en servir.
    push r13
    push r14
    mov r12, rdi            ; fd
    mov r13, rsi            ; Adresse du tampon.
    mov r14, rdx            ; Capacite du tampon.
    xor rbx, rbx            ; Total des octets lus.
read_all_next_read:
    cmp rbx, r14
    jae read_all_done               ; Tampon plein.
    mov rdi, r12
    lea rsi, [r13 + rbx]    ; Lire apres les octets deja charges.
    mov rdx, r14
    sub rdx, rbx            ; Place encore disponible.
    call read_file
    cmp rax, 0
    jl read_all_end                 ; Erreur : rax negatif renvoye tel quel.
    je read_all_done                ; Zero octet lu : fin du fichier.
    add rbx, rax
    jmp read_all_next_read
read_all_done:
    mov rax, rbx
read_all_end:
    pop r14
    pop r13
    pop r12
    pop rbx
    leave
    ret

; write_all(int fd, char* buff, int size)
; rdi = descripteur, rsi = adresse des donnees, rdx = nombre d'octets.
; Appelle write_file jusqu'a ce que les size octets soient ecrits.
; Retour : rax = size si tout est ecrit, valeur negative si erreur.
write_all:
    push rbp
    mov rbp, rsp
    push rbx                ; Registres callee-saved utilises :
    push r12                ; sauvegarde obligatoire.
    push r13
    push r14
    mov r12, rdi            ; fd
    mov r13, rsi            ; Adresse des donnees.
    mov r14, rdx            ; Nombre d'octets a ecrire.
    xor rbx, rbx            ; Total des octets ecrits.
write_all_next_write:
    cmp rbx, r14
    jae write_all_done               ; Tout est ecrit.
    mov rdi, r12
    lea rsi, [r13 + rbx]    ; Reprendre apres les octets deja ecrits.
    mov rdx, r14
    sub rdx, rbx            ; Octets restants.
    call write_file
    cmp rax, 0
    jl write_all_end                 ; Erreur : rax negatif renvoye tel quel.
    je write_all_stuck               ; Rien ecrit : eviter une boucle infinie.
    add rbx, rax
    jmp write_all_next_write
write_all_stuck:
    mov rax, -1
    jmp write_all_end
write_all_done:
    mov rax, rbx
write_all_end:
    pop r14
    pop r13
    pop r12
    pop rbx
    leave
    ret

; close_file(int fd)
; rdi = descripteur du fichier a fermer.
; Retour : rax = 0 si fermeture reussie, valeur negative si erreur.
close_file:
    push rbp
    mov rbp, rsp
    mov rax, 3              ; Syscall close.
    syscall
    leave
    ret
