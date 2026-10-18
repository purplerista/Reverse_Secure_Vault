# Secure Vault — Gestionnaire de login et de mots de passe

## 1. Ce que demande le sujet

Le travail consiste à réaliser un programme qui conserve des couples **login / password** dans un fichier chiffré.

Le programme doit proposer trois fonctionnalités :

- **F0 :** demander le mot de passe de la base, préparer la clé et ouvrir ou créer le fichier de la base.
- **F1 :** demander de nouveaux identifiants, déchiffrer la base existante, ajouter les identifiants, rechiffrer et sauvegarder.
- **F2 :** déchiffrer le contenu du fichier et l’afficher.

Après F0, le programme demande à l’utilisateur de choisir `1` pour F1 ou `2` pour F2.

La réalisation est écrite en assembleur NASM x86-64 pour Linux, avec les structures, registres, boucles, fonctions, opérations sur la pile et syscalls travaillés dans les cours. Le programme est prévu pour être exécuté avec Qiling (section 12).

Les exercices préparatoires du TD (`exo1_people_note.asm`, `exo2_crack_me.asm`) ne font pas partie de ce rendu.

## 2. Déroulement général

```text
Début du programme
        |
        v
F0 : demander le mot de passe de la base
        |
        v
Prendre les 8 premiers octets comme clé
        |
        v
Ouvrir la base ou la créer si elle n’existe pas
        |
        v
Demander le choix 1 ou 2
        |
        +---- 1 : F1 — ajouter des identifiants
        |
        +---- 2 : F2 — afficher les identifiants
        |
        v
Fin du programme
```

Notre version effectue une seule action par lancement. Pour réaliser une autre action, on relance le programme.

## 3. F0 — Mot de passe et préparation de la base

### Ce qui est demandé

Le sujet demande un mot de passe pour la base. Ses **8 premiers octets** doivent servir de clé pour le chiffrement XOR. La base est un fichier plat, créé s’il n’existe pas.

Un fichier plat est ici un fichier contenant directement les données, sans serveur de base de données ni tables SQL.

### Ce que nous avons réalisé

Le programme affiche :

```text
Entrez le mot de passe de la base :
```

F0 est réalisée par la fonction `f0_open_vault` (`inc/f0_open.inc`). La saisie est stockée dans `db_password` avec la fonction `read_string`.

La clé est ensuite préparée :

```nasm
mov rax, [db_password]
mov [db_key], rax
```

`rax` est un registre de 64 bits, soit 8 octets. La première instruction charge donc les huit premiers octets de la zone `db_password`. La seconde les copie dans `db_key`.

Exemple avec des caractères ASCII :

```text
Mot de passe saisi : a b c d e f g h i j
Clé utilisée      : a b c d e f g h
```

Le programme ouvre ensuite le fichier nommé `vault.db` avec `open_file` (`inc/cours.inc`) :

- S’il n’existe pas, il est créé vide.
- S’il existe, son contenu est conservé.

Les paramètres d’ouverture sont :

```nasm
mov rax, 2
mov rsi, 66
mov rdx, 0o600
syscall
```

`2` dans `rax` sélectionne le syscall `open`. `66` combine l’ouverture en lecture/écriture et la création si nécessaire. `0o600` demande les permissions de lecture et d’écriture pour le propriétaire lors de la création.

Le fichier est fermé après cette initialisation. F0 ne chiffre encore aucune donnée : elle prépare la clé et le fichier.

### Règles sur le mot de passe

L’énoncé ne demande ni majuscule, ni chiffre, ni caractère spécial obligatoire. Notre programme n’ajoute pas ces contraintes et ne demande pas de longueur minimale.

Pour une saisie de moins de huit octets, les positions restantes de la clé sont à zéro dans cette version : le tampon est initialement nul et `read_string` écrit un zéro final.

Pour retrouver les données ou ajouter une entrée à une base existante, il faut réutiliser la même clé, donc les mêmes huit premiers octets du mot de passe.

## 4. Menu — Choisir F1 ou F2

Le programme affiche :

```text
1 : Ajouter des identifiants
2 : Afficher la base
Votre choix :
```

La réponse est lue avec `read_string`, puis comparée aux caractères `1` et `2`. Selon le choix, `_start` appelle la fonction correspondante :

```nasm
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
```

`cmp` compare les valeurs, `je` saute si elles sont égales. F1 et F2 sont des fonctions : `call` y entre, leur `ret` revient dans `_start`, qui examine ensuite la valeur de retour (`rax < 0` : erreur, sortie avec le code 1).

Dans notre version, un choix différent ou une réponse dont la longueur stockée n’est pas un caractère provoque la fin du programme.

## 5. Structure des identifiants

### Ce qui est demandé

Chaque couple doit être stocké dans une structure comprenant deux champs :

- Un login de **32 octets**.
- Un password de **32 octets**.

### Ce que nous avons réalisé

```nasm
struc credential
    .login:    resb 32
    .password: resb 32
endstruc
```

Une structure occupe donc **64 octets**.

```text
Une entrée
+--------------------------+--------------------------+
| login : 32 octets        | password : 32 octets     |
+--------------------------+--------------------------+
Début                      Début + 32                 Fin : 64
```

NASM calcule les positions et la taille :

| Élément | Valeur |
|---|---:|
| `credential.login` | 0 |
| `credential.password` | 32 |
| `credential_size` | 64 |

La mémoire de l’entrée à ajouter est réservée par :

```nasm
credential1: resb credential_size
```

Pour lire le login, on fournit à `read_string` l’adresse du premier champ :

```nasm
mov rdi, credential1 + credential.login
mov rsi, 32
call read_string
```

Pour le password, on utilise la même méthode avec `credential.password`, qui vaut 32.

Les champs font bien 32 octets. Notre lecture réserve un octet pour terminer chaque chaîne par zéro : elle accepte donc **31 octets utiles par champ**, soit 31 caractères pour du texte ASCII.

## 6. Chiffrement XOR ECB demandé

### Principe

Le sujet impose un XOR ECB avec une clé de huit octets. Chaque bloc de huit octets de la base est traité indépendamment avec cette même clé.

```text
Bloc clair XOR clé = bloc chiffré
Bloc chiffré XOR clé = bloc clair
```

L’opération est réversible :

```text
(A XOR K) XOR K = A
```

Exemple simplifié sur quatre bits :

```text
Chiffrement                Déchiffrement

Donnée : 0101              Chiffré : 0110
Clé    : 0011              Clé     : 0011
         ----                       ----
Résultat 0110              Résultat  0101
```

### Dans notre code

Le chiffrement est réalisé par la fonction `xor_ecb(buff, size, key)` de la bibliothèque `inc/cours.inc`. Le même appel sert à chiffrer et à déchiffrer, puisque `(A XOR K) XOR K = A` :

```nasm
    mov rdi, db_buffer      ; adresse du tampon
    mov rsi, [db_size]      ; taille : valeur de db_size
    mov rdx, [db_key]       ; clé : valeur de db_key
    call xor_ecb
```

Dans la fonction :

```nasm
.next_block:
    cmp rcx, rsi
    jae .end
    xor qword [rdi + rcx], rdx
    add rcx, 8
    jmp .next_block
```

- `rdx` contient la clé.
- `rcx` indique la position dans le tampon.
- `qword` désigne un bloc de huit octets.
- Après chaque opération, on avance de huit octets.

Les positions successives sont donc `0`, `8`, `16`, `24`, etc.

Une entrée de 64 octets correspond à huit blocs. Une base composée d’entrées complètes a toujours une taille multiple de huit ; aucun remplissage de bloc supplémentaire n’est nécessaire.

## 7. F1 — Ajouter des identifiants

### Ce qui est demandé

L’ordre indiqué par le sujet est :

```text
Demander les identifiants
        ↓
Les stocker dans une structure
        ↓
Déchiffrer la base existante
        ↓
Ajouter la structure au contenu
        ↓
Rechiffrer la base complète
        ↓
Sauvegarder dans le fichier
```

F1 est réalisée par la fonction `f1_add_credential` (`inc/f1_add.inc`).

### Étape 1 : demander le login et le password

Le programme affiche successivement :

```text
Login :
Password :
```

Les deux réponses sont stockées directement dans les champs de `credential1`.

Le mot de passe saisi à cette étape est celui de l’identifiant à conserver. Il est distinct du mot de passe de la base demandé dans F0.

### Étape 2 : charger le fichier en mémoire

La fonction `load_db` (`inc/db.inc`) ouvre le fichier, le lit dans `db_buffer` avec `read_all`, puis le ferme. Le nombre d’octets chargés est conservé dans `db_size`.

```text
Disque                           Mémoire
vault.db ---- lecture ---->      db_buffer
```

`db_buffer` est un tampon : une zone temporaire dans laquelle le programme peut modifier les données avant de les sauvegarder.

`read_all` appelle `read_file` jusqu’à la fin du fichier ou jusqu’à la capacité du tampon.

### Étape 3 : vérifier le format et la place disponible

Chaque entrée fait 64 octets. `load_db` vérifie donc que la taille chargée est un multiple de 64, et refuse un fichier plus grand que le tampon.

Il vérifie aussi qu’il reste au moins 64 octets pour ajouter la nouvelle entrée. En cas de refus, le fichier n’est pas réécrit.

### Étape 4 : déchiffrer la base

`xor_ecb` déchiffre les blocs déjà présents dans `db_buffer`.

Si le fichier est vide, `db_size` vaut zéro : aucun ancien bloc n’est à déchiffrer.

### Étape 5 : ajouter les 64 octets

La destination de la nouvelle structure est calculée ainsi :

```nasm
mov rdi, db_buffer
add rdi, [db_size]
```

Si la base contient déjà une entrée, sa taille est 64. La nouvelle structure est donc copiée à partir de `db_buffer + 64`.

```text
Avant : [entrée 1]
Après : [entrée 1][entrée 2]
```

Une boucle copie les 64 octets de `credential1`, puis augmente la taille :

```nasm
add qword [db_size], credential_size
```

### Étape 6 : rechiffrer tout le contenu

`xor_ecb` est appelée une seconde fois, sur la totalité des données : anciennes entrées et nouvelle entrée.

### Étape 7 : écrire dans le fichier

La fonction `save_db` (`inc/db.inc`) rouvre la base pour repartir du début du fichier, puis `write_all` écrit les `db_size` octets chiffrés. Si une écriture ne transfère qu’une partie des données, `write_all` continue avec les octets restants.

Le fichier n’est pas vidé avant l’écriture : la nouvelle base est toujours plus grande que l’ancienne (une entrée de plus), elle la recouvre donc entièrement.

Après fermeture du fichier, le programme affiche :

```text
Identifiants enregistres.
```

## 8. F2 — Déchiffrer et afficher

### Ce qui est demandé

F2 doit déchiffrer le contenu du fichier et l’afficher.

### Ce que nous avons réalisé

F2 est réalisée par la fonction `f2_show_vault` (`inc/f2_show.inc`) :

1. Ouvrir `vault.db`.
2. Lire ses octets dans `db_buffer` et conserver leur nombre dans `db_size`.
3. Fermer le fichier.
4. Vérifier que sa taille correspond à des entrées complètes.

   Les étapes 1 à 4 sont celles de `load_db`, partagée avec F1.
5. Déchiffrer le tampon avec la clé préparée dans F0.
6. Afficher le login et le password de chaque entrée.
7. Quitter après la dernière entrée.

L’affichage parcourt les structures par pas de 64 octets :

```text
Entrée 1 : position 0
Entrée 2 : position 64
Entrée 3 : position 128
```

Pour chaque entrée :

- Le login commence à sa position de départ.
- Le password commence 32 octets plus loin.
- Chaque champ est affiché jusqu’à son zéro final, dont la position est donnée par `strlen` (voir la faille décrite en section 11).

Exemple :

```text
Login : alice
Password : exemple123
Login : bob
Password : exemple456
```

F2 ne réécrit pas le fichier. Seule la copie en mémoire est déchiffrée ; les octets sauvegardés sur le disque restent chiffrés.

## 9. Organisation du code et fonctions

### Fichiers

```text
TD08/
├── secure_vault.asm     programme principal : _start, menu, données
├── inc/
│   ├── cours.inc        bibliothèque générique, réutilisable
│   ├── db.inc           Secure Vault : load_db, save_db
│   ├── f0_open.inc      Secure Vault : f0_open_vault
│   ├── f1_add.inc       Secure Vault : f1_add_credential
│   └── f2_show.inc      Secure Vault : f2_show_vault
├── build_nasm.sh        compilation vers rootfs/
├── qiling_run.py        exécution sous Qiling
├── ql_run.sh            exécution sous Qiling (qltool)
└── docker/              environnement Docker
```

Les fichiers `.inc` sont recopiés par NASM dans `secure_vault.asm` grâce à `%include`, dans la section `.text`. Un seul fichier est donc assemblé et lié : `build_nasm.sh` ne change pas.

### Bibliothèque générique : `inc/cours.inc`

| Fonction | Arguments | Retour (`rax`) |
|---|---|---|
| `print_hex` | `rdi` = valeur | – |
| `print_string` | `rdi` = texte, `rsi` = taille | – |
| `strlen` | `rdi` = chaîne terminée par 0 | longueur |
| `strcmp` | `rdi`, `rsi` = chaînes | 0 si égales |
| `read_string` | `rdi` = tampon, `rsi` = capacité | caractères stockés |
| `read_hex` | – | valeur lue |
| `xor_ecb` | `rdi` = tampon, `rsi` = taille, `rdx` = clé | – |
| `open_file` | `rdi` = nom | descripteur, ou < 0 |
| `read_file` | `rdi` = fd, `rsi` = tampon, `rdx` = taille max | octets lus, ou < 0 |
| `write_file` | `rdi` = fd, `rsi` = données, `rdx` = taille | octets écrits, ou < 0 |
| `read_all` | `rdi` = fd, `rsi` = tampon, `rdx` = capacité | total lu, ou < 0 |
| `write_all` | `rdi` = fd, `rsi` = données, `rdx` = taille | taille, ou < 0 |
| `close_file` | `rdi` = fd | 0, ou < 0 |

`print_hex` et `print_string` reprennent le code fourni ; les autres complètent les signatures prévues dans le squelette de `cours.inc`. `strcmp` et `read_hex` ne servent pas au Secure Vault mais rendent la bibliothèque utilisable par d’autres programmes.

### Fonctions du Secure Vault : `inc/db.inc`, `inc/f0_open.inc`, `inc/f1_add.inc`, `inc/f2_show.inc`

| Fonction | Rôle | Retour (`rax`) |
|---|---|---|
| `f0_open_vault` | F0 : mot de passe → clé, création de `vault.db` | 0, ou < 0 |
| `f1_add_credential` | F1 : saisie, déchiffrement, ajout, rechiffrement, sauvegarde | 0, ou < 0 |
| `f2_show_vault` | F2 : chargement, déchiffrement, affichage | 0, ou < 0 |
| `load_db` | ouvrir, lire avec `read_all`, fermer, vérifier la taille | taille, ou < 0 |
| `save_db` | ouvrir, écrire avec `write_all`, fermer | 0, ou < 0 |

`_start` appelle `f0_open_vault`, puis `f1_add_credential` ou `f2_show_vault` selon le menu. Les fonctions ne quittent jamais le programme elles-mêmes : elles renvoient une valeur négative en cas d’erreur, et `_start` termine alors avec le code de sortie 1.

### Convention d’appel et pile

- Arguments dans `rdi`, `rsi`, `rdx` ; résultat dans `rax` (convention System V x86-64).
- Chaque fonction commence par un prologue (`push rbp` / `mov rbp, rsp`, ou `enter`) et se termine par `leave` / `ret`.
- Les registres *callee-saved* utilisés (`rbx`, `r12` à `r14`) sont sauvegardés par `push` au début et restaurés par `pop`, dans l’ordre inverse, avant `leave` : c’est le cas de `read_all`, `write_all` et `f2_show_vault`, qui ont besoin de valeurs conservées à travers des appels.
- Les fonctions qui n’appellent personne (`xor_ecb`, la copie de F1) utilisent des registres *caller-saved* (`rcx`) et n’ont rien à sauvegarder.
- `read_string` et `read_hex` réservent des variables locales sur la pile avec `enter 32, 0`.

## 10. Taille du fichier et limites de notre réalisation

Les entrées sont placées les unes à la suite des autres, sans en-tête ni séparateur. Le chiffrement ne change pas leur taille.

| Nombre d’entrées | Taille de la base |
|---|---:|
| 0 | 0 octet |
| 1 | 64 octets |
| 2 | 128 octets |
| 64 | 4096 octets |

Notre tampon fixe contient 4096 octets (`DB_CAPACITY`), soit 64 entrées maximum. F1 refuse un ajout si la place manque. `load_db` refuse un fichier dépassant cette capacité, en vérifiant s’il reste un octet à lire après le remplissage du tampon.

La taille du tampon et la réservation d’un zéro final dans chaque champ sont des choix de réalisation ; l’énoncé impose les champs de 32 octets, mais ne fixe pas ces détails.

Les saisies restent visibles dans le terminal. Il n’y a pas de suppression d’entrée, de recherche, de modification d’identifiant ni de détection des doublons : ces fonctionnalités ne sont pas demandées dans l’énoncé.

## 11. Analyse de sécurité

Le chiffrement XOR ECB avec une clé de 8 octets est imposé par le sujet. Il est réalisé conformément à l’énoncé, mais il présente des faiblesses qu’une simple analyse du fichier permet d’exploiter.

### La clé apparaît en clair dans le fichier

Un champ fait 32 octets. Le login `alice` n’en occupe que 5 : les 27 autres valent 0. Or `0 XOR K = K` : un bloc de 8 octets nuls, une fois chiffré, contient exactement la clé.

```text
  0000 0000   octet nul du champ
⊕ 0110 0001   'a', premier octet de la clé
= 0110 0001   'a' : la clé ressort telle quelle
```

Comme ECB applique la même clé à chaque bloc, la clé se répète partout où les champs sont incomplets. Exemple avec la clé `abcdefgh` (`od -A d -t x1 vault.db`) :

```text
0000000 00 0e 0a 07 00 66 67 68 61 62 63 64 65 66 67 68
0000016 61 62 63 64 65 66 67 68 61 62 63 64 65 66 67 68
```

`61 62 63 64 65 66 67 68` est le code ASCII de `abcdefgh`. Il suffit d’ouvrir le fichier pour lire la clé et déchiffrer toute la base, sans connaître le mot de passe.

### Mot de passe vide ou court

La clé est formée des 8 premiers octets du mot de passe. Avec un mot de passe de moins de 8 caractères, les octets manquants de la clé valent 0 ; avec un mot de passe vide, la clé entière vaut 0. Comme `X XOR 0 = X`, les octets correspondants ne sont pas chiffrés : avec un mot de passe vide, les identifiants sont écrits en clair dans `vault.db`.

### Blocs identiques

En ECB, deux blocs clairs identiques donnent deux blocs chiffrés identiques. Deux entrées ayant le même password, ou le même début de login, sont donc reconnaissables dans le fichier sans le déchiffrer.

### Pas de vérification du mot de passe

Le programme ne vérifie pas que le mot de passe de la base est le bon. Avec une mauvaise clé, F2 affiche des données incorrectes. F1 avec une mauvaise clé ne détruit pas les entrées existantes (elles sont « déchiffrées » puis rechiffrées avec la même mauvaise clé, donc inchangées), mais la nouvelle entrée est chiffrée avec une clé différente : la base mélange alors deux clés. Le contrôle de taille ne permet pas de détecter une mauvaise clé.

### Longueur des champs dans F2

F2 calcule la longueur du login et du password avec `strlen`, qui s’arrête au premier octet nul. Avec une saisie normale, ce zéro est toujours présent : `read_string` le réserve, un champ contient donc au plus 31 caractères suivis de 0. En revanche, après un déchiffrement avec une mauvaise clé (ou un fichier modifié à la main), un champ peut ne plus contenir de zéro : `strlen` continue alors dans le champ suivant, et l’affichage mélange les champs (le login peut s’afficher collé au password). Une version bornée (`strnlen`, arrêt à 32 octets) corrigerait ce cas ; nous avons choisi de ne pas l’ajouter pour garder le code simple, l’énoncé ne demandant pas de gérer une mauvaise clé.

## 12. Compilation et exemple complet

### Environnement Docker

Le dossier `docker/` reprend le docker du cours (Ubuntu 24.04, `nasm`, `ld`, Qiling 1.4.11), sans Ghidra. Le dossier `TD08` est partagé avec le conteneur dans `/opt/secure_vault`.

```bash
cd docker
docker compose up -d --build        # première fois : construction de l'image
docker exec -it secure_vault bash   # shell dans le conteneur, dans /opt/secure_vault
```

### Compilation

Dans le conteneur :

```bash
./build_nasm.sh secure_vault.asm
```

L’exécutable est déposé dans `rootfs/secure_vault`. Les commandes correspondantes sont :

```bash
nasm -f elf64 secure_vault.asm -o rootfs/obj/secure_vault.o
ld rootfs/obj/secure_vault.o -o rootfs/secure_vault
```

### Exécution avec Qiling

```bash
./qiling_run.py rootfs/secure_vault
# ou
./ql_run.sh rootfs/secure_vault
```

Qiling émule le programme avec `rootfs/` comme système de fichiers : la base est donc créée dans `rootfs/vault.db`.

L’exécutable fonctionne aussi sans émulation (`./rootfs/secure_vault`) ; la base est alors `vault.db` dans le répertoire courant, distincte de celle de Qiling.

### Premier lancement : ajouter une entrée

```bash
./qiling_run.py rootfs/secure_vault
```

```text
Entrez le mot de passe de la base : abcdefgh
1 : Ajouter des identifiants
2 : Afficher la base
Votre choix : 1
Login : alice
Password : exemple123
Identifiants enregistres.
```

### Lancement suivant : afficher la base

Relancer `./qiling_run.py rootfs/secure_vault`, utiliser le même mot de passe de base et choisir `2` :

```text
Entrez le mot de passe de la base : abcdefgh
1 : Ajouter des identifiants
2 : Afficher la base
Votre choix : 2
Login : alice
Password : exemple123
```

Si d’autres entrées existent déjà, elles sont également affichées.

## 13. Vérifications réalisées

Les essais suivants ont été effectués dans le conteneur Docker du projet, sous Qiling et en exécution directe :

| Vérification | Résultat observé |
|---|---|
| Demande du mot de passe | Le programme attend la saisie et la touche Entrée. |
| Création d’une base absente | Création d’un fichier vide de 0 octet (`rootfs/vault.db` sous Qiling). |
| Ajout d’identifiants (F1) | Affichage du message de confirmation. |
| Taille après deux entrées | Fichier de 128 octets. |
| Affichage par F2 | Les deux couples saisis sont affichés en clair, par exemple `alice` / `exemple123` et `bob` / `secret456`. |
| F2 sur une base vide | Aucun affichage, fin normale. |
| Login de plus de 31 caractères | Le login est tronqué à 31 caractères, le password reste correct. |
| Base pleine (64 entrées) puis F1 | Ajout refusé avec un message, fichier inchangé, code de sortie 1. |
| Fichier de plus de 4096 octets | Refusé avec un message, code de sortie 1. |
| Taille non multiple de 64 | Refusée avec un message, code de sortie 1. |
| Choix invalide au menu | Fin du programme sans action. |

Ces essais ne constituent pas une validation automatique de tous les cas limites ou de toutes les erreurs système.

Pour vérifier la taille du fichier :

```bash
ls -l rootfs/vault.db
```

`cat vault.db` ne déchiffre pas les données. L’affichage en clair se fait avec F2.

## 14. Correspondance avec les consignes

| Consigne de l’énoncé | Réalisation |
|---|---|
| Demander le mot de passe de la base | Saisie dans F0 avec `read_string`. |
| Créer le fichier s’il n’existe pas | Ouverture avec création via `open_file`. |
| Utiliser les huit premiers octets comme clé | Copie de `db_password` vers `db_key` sur huit octets. |
| Chiffrement XOR ECB | XOR indépendant de chaque bloc de huit octets avec la même clé. |
| Proposer le choix 1 ou 2 | Menu et branchements vers F1 ou F2. |
| Saisir les identifiants | Questions login et password dans F1. |
| Structure de 32 octets par champ | Structure `credential` de 64 octets. |
| Déchiffrer, ajouter, rechiffrer | `f1_add_credential` : `xor_ecb`, copie de l’entrée, `xor_ecb`, dans cet ordre. |
| Sauvegarder le fichier | `save_db` : écriture complète du tampon utile avec `write_all`. |
| Déchiffrer et afficher le contenu | `f2_show_vault` : `load_db`, `xor_ecb` et affichage des champs. |
| Étendre `inc/cours.inc` (fichiers, XOR) | `open_file`, `read_file`, `write_file`, `close_file`, `read_all`, `write_all`, `xor_ecb`. |
| Code structuré en fonctions, usage de la pile | Une fonction par fonctionnalité, prologue / épilogue, registres sauvegardés (section 9). |

## 15. Utilisation de l’IA

Un assistant IA a été utilisé pendant la réalisation de ce projet pour :

- Expliquer les notions du cours : registres, adresses, mémoire, structures, pile, syscalls et chiffrement XOR.
- Décomposer le sujet en étapes et expliquer le fonctionnement des instructions et des fonctions.
- Proposer et écrire progressivement le code en s’appuyant sur les supports du cours.
- Restructurer le code en fonctions réutilisables et en fichiers, et préparer l’environnement Docker et Qiling.
- Aider à interpréter les résultats des essais et les messages du terminal.
- Rédiger et organiser cette documentation.

Le code produit avec cette aide ne constitue pas un corrigé officiel du professeur. Les notions utilisées restent celles du cours (NASM, structures, pile, syscalls, `%include`).
