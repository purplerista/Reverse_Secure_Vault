# Secure Vault — Gestionnaire de login et de mots de passe

## 1. Ce que demande le sujet

Le travail consiste à réaliser un programme qui conserve des couples **login / password** dans un fichier chiffré.

Le programme doit proposer trois fonctionnalités :

- **F0 :** demander le mot de passe de la base, préparer la clé et ouvrir ou créer le fichier de la base.
- **F1 :** demander de nouveaux identifiants, déchiffrer la base existante, ajouter les identifiants, rechiffrer et sauvegarder.
- **F2 :** déchiffrer le contenu du fichier et l’afficher.

Après F0, le programme demande à l’utilisateur de choisir `1` pour F1 ou `2` pour F2.

La réalisation est écrite en assembleur NASM x86-64 pour Linux, avec les structures, registres, boucles, fonctions, opérations sur la pile et syscalls travaillés dans les cours.

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

La saisie est stockée dans `db_password` avec la fonction `read_string`.

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

Le programme ouvre ensuite le fichier nommé `vault.db` avec `open_file` :

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

La réponse est lue avec `read_string`, puis comparée aux caractères `1` et `2` :

```nasm
cmp byte [menu_choice], '1'
je F1

cmp byte [menu_choice], '2'
je F2
```

`cmp` compare les valeurs. `je` effectue le saut si elles sont égales.

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

```nasm
xor qword [db_buffer + rbx], rax
add rbx, 8
```

- `rax` contient la clé.
- `rbx` indique la position dans le tampon.
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

### Étape 1 : demander le login et le password

Le programme affiche successivement :

```text
Login :
Password :
```

Les deux réponses sont stockées directement dans les champs de `credential1`.

Le mot de passe saisi à cette étape est celui de l’identifiant à conserver. Il est distinct du mot de passe de la base demandé dans F0.

### Étape 2 : charger le fichier en mémoire

Le fichier est ouvert, puis lu avec `read_file` dans `db_buffer`. Le nombre d’octets chargés est conservé dans `db_size`.

```text
Disque                           Mémoire
vault.db ---- lecture ---->      db_buffer
```

`db_buffer` est un tampon : une zone temporaire dans laquelle le programme peut modifier les données avant de les sauvegarder.

La lecture continue jusqu’à la fin du fichier ou jusqu’à la capacité du tampon, puis le fichier est fermé.

### Étape 3 : vérifier le format et la place disponible

Chaque entrée fait 64 octets. Le programme vérifie donc que la taille chargée est un multiple de 64.

Il vérifie aussi qu’il reste au moins 64 octets pour ajouter la nouvelle entrée. En cas de refus, le fichier n’est pas réécrit.

### Étape 4 : déchiffrer la base

La boucle XOR déchiffre les blocs déjà présents dans `db_buffer`.

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

Le programme recharge la clé et applique le XOR sur la totalité des données : anciennes entrées et nouvelle entrée.

La clé est rechargée parce que la copie utilise `al`, qui est une partie de `rax`.

### Étape 7 : écrire dans le fichier

La base est rouverte pour repartir du début du fichier. `write_file` écrit les `db_size` octets chiffrés.

La variable `db_written` permet de suivre l’avancement : si une écriture ne transfère qu’une partie des données, la boucle continue avec les octets restants.

Après fermeture du fichier, le programme affiche :

```text
Identifiants enregistres.
```

## 8. F2 — Déchiffrer et afficher

### Ce qui est demandé

F2 doit déchiffrer le contenu du fichier et l’afficher.

### Ce que nous avons réalisé

1. Ouvrir `vault.db`.
2. Lire ses octets dans `db_buffer` et conserver leur nombre dans `db_size`.
3. Fermer le fichier.
4. Vérifier que sa taille correspond à des entrées complètes.
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
- Chaque champ est affiché jusqu’au zéro final, sans dépasser ses 32 octets.

Exemple :

```text
Login : alice
Password : exemple123
Login : bob
Password : exemple456
```

F2 ne réécrit pas le fichier. Seule la copie en mémoire est déchiffrée ; les octets sauvegardés sur le disque restent chiffrés.

## 9. Fonctions qui permettent de réaliser le sujet

| Fonction | Utilité dans le programme |
|---|---|
| `print_string` | Afficher les questions, le menu, les messages et les identifiants. |
| `read_string` | Recevoir le mot de passe de base, le choix et les deux champs des identifiants. |
| `open_file` | Ouvrir ou créer la base. |
| `read_file` | Copier les octets du fichier dans le tampon. |
| `write_file` | Sauvegarder les octets chiffrés. |
| `close_file` | Fermer le fichier après utilisation. |

Ces fonctions se trouvent dans la bibliothèque `inc/cours.inc`, incluse par `secure_vault.asm` avec `%include "./inc/cours.inc"`. `print_hex` et `print_string` reprennent le code fourni ; les autres sont adaptées ou implémentées à partir des exemples et des signatures prévues dans les supports du cours.

La bibliothèque contient aussi `strlen`, `strcmp` et `read_hex`, qui ne servent pas au Secure Vault mais complètent les signatures prévues dans le squelette de `cours.inc`, pour qu’elle puisse être réutilisée dans d’autres programmes.

Les arguments sont transmis par registres. Pour lire ou écrire un fichier, `rdi` contient le descripteur, `rsi` l’adresse du tampon et `rdx` le nombre d’octets demandé. Le résultat revient dans `rax`.

Les fonctions utilisent les mécanismes de pile vus en cours : sauvegarde avec `push`, restauration avec `pop`, cadre local avec `rbp` et retour par `ret`. La fonction `read_string` réserve ses variables locales avec `enter 32, 0` et les libère avec `leave`.

## 10. Taille du fichier et limites de notre réalisation

Les entrées sont placées les unes à la suite des autres, sans en-tête ni séparateur. Le chiffrement ne change pas leur taille.

| Nombre d’entrées | Taille de la base |
|---|---:|
| 0 | 0 octet |
| 1 | 64 octets |
| 2 | 128 octets |
| 64 | 4096 octets |

Notre tampon fixe contient 4096 octets, soit 64 entrées maximum. F1 refuse un ajout si la place manque. F2 refuse un fichier dépassant cette capacité, en vérifiant s’il reste un octet à lire après le remplissage du tampon.

La taille du tampon et la réservation d’un zéro final dans chaque champ sont des choix de réalisation ; l’énoncé impose les champs de 32 octets, mais ne fixe pas ces détails.

Le programme n’a pas de mécanisme de vérification du mot de passe de la base. Une mauvaise clé peut produire un affichage incorrect et ne doit pas être utilisée pour ajouter une entrée à une base existante. Le contrôle de taille ne permet pas de détecter une mauvaise clé.

Les saisies restent visibles dans le terminal. Il n’y a pas de suppression d’entrée, de recherche, de modification d’identifiant ni de détection des doublons : ces fonctionnalités ne sont pas demandées dans l’énoncé.

## 11. Compilation et exemple complet

Depuis le répertoire contenant le source :

```bash
./build_nasm.sh secure_vault.asm
./secure_vault
```

Les commandes d’assemblage et d’édition de liens correspondantes sont :

```bash
nasm -f elf64 secure_vault.asm -o secure_vault.o
ld secure_vault.o -o secure_vault
```

### Premier lancement : ajouter une entrée

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

Relancer `./secure_vault`, utiliser le même mot de passe de base et choisir `2` :

```text
Entrez le mot de passe de la base : abcdefgh
1 : Ajouter des identifiants
2 : Afficher la base
Votre choix : 2
Login : alice
Password : exemple123
```

Si d’autres entrées existent déjà, elles sont également affichées.

## 12. Vérifications réalisées

Les essais manuels effectués pendant la réalisation ont permis d’observer :

| Vérification | Résultat observé |
|---|---|
| Demande du mot de passe | Le programme attend la saisie et la touche Entrée. |
| Création d’une base absente | Création d’un fichier vide de 0 octet. |
| Ajout d’identifiants | Affichage du message de confirmation. |
| Taille après deux entrées | Fichier de 128 octets. |
| Affichage par F2 | Affichage de deux couples, dont le couple connu `line` / `nerista` retrouvé après déchiffrement. |

Le parcours principal F0 → F1, puis F0 → F2, a donc été exercé dans le conteneur du cours. Ces essais ne constituent pas une validation automatique de tous les cas limites ou de toutes les erreurs système.

Pour vérifier la taille du fichier :

```bash
ls -l vault.db
```

`cat vault.db` ne déchiffre pas les données. L’affichage en clair se fait avec F2.

## 13. Correspondance avec les consignes

| Consigne de l’énoncé | Réalisation |
|---|---|
| Demander le mot de passe de la base | Saisie dans F0 avec `read_string`. |
| Créer le fichier s’il n’existe pas | Ouverture avec création via `open_file`. |
| Utiliser les huit premiers octets comme clé | Copie de `db_password` vers `db_key` sur huit octets. |
| Chiffrement XOR ECB | XOR indépendant de chaque bloc de huit octets avec la même clé. |
| Proposer le choix 1 ou 2 | Menu et branchements vers F1 ou F2. |
| Saisir les identifiants | Questions login et password dans F1. |
| Structure de 32 octets par champ | Structure `credential` de 64 octets. |
| Déchiffrer, ajouter, rechiffrer | Boucles de F1 dans cet ordre. |
| Sauvegarder le fichier | Écriture complète du tampon utile avec `write_file`. |
| Déchiffrer et afficher le contenu | Lecture, XOR et affichage des champs dans F2. |

## 14. Utilisation de l’IA

Un assistant IA a été utilisé pendant la réalisation de ce projet pour :

- Expliquer les notions du cours : registres, adresses, mémoire, structures, pile, syscalls et chiffrement XOR.
- Décomposer le sujet en étapes et expliquer le fonctionnement des instructions et des fonctions.
- Proposer et écrire progressivement le code en s’appuyant sur les supports du cours.
- Aider à interpréter les résultats des essais et les messages du terminal.
- Rédiger et organiser cette documentation.

Le code produit avec cette aide ne constitue pas un corrigé officiel du professeur. Les essais manuels rapportés dans ce README ont été effectués par l’étudiant dans le conteneur du cours.
