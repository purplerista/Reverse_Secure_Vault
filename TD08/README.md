# Secure Vault — TD08

Gestionnaire de login / password en NASM x86-64 (Linux), stockés dans un fichier chiffré en XOR ECB, exécuté sous Qiling.

Les exercices préparatoires (`exo1_people_note.asm`, `exo2_crack_me.asm`) ne font pas partie de ce rendu.

## Lancer le projet

Environnement Docker (Ubuntu 24.04, `nasm`, `ld`, Qiling 1.4.11, repris du docker du cours sans Ghidra) :

```bash
cd docker
docker compose up -d --build          # construit l'image au premier lancement
docker exec -it secure_vault bash     # shell dans /opt/secure_vault (= TD08)
```

Compilation et exécution, dans le conteneur :

```bash
./build_nasm.sh secure_vault.asm      # exécutable : rootfs/secure_vault
./qiling_run.py rootfs/secure_vault   # ou : ./ql_run.sh rootfs/secure_vault
```

Sous Qiling, la base est `rootfs/vault.db`. Sans émulation (`./rootfs/secure_vault`), c’est `vault.db` dans le répertoire courant.

Exemple :

```text
Entrez le mot de passe de la base : abcdefgh
1 : Ajouter des identifiants
2 : Afficher la base
Votre choix : 1
Login : alice
Password : exemple123
Identifiants enregistres.
```

Relancer avec le même mot de passe et choisir `2` affiche les entrées. Le programme fait une seule action par lancement.

## Fonctionnalités

| | Fonction | Réalisation |
|---|---|---|
| F0 | `f0_open_vault` | Demande le mot de passe de la base (31 caractères max). La clé XOR est formée de ses 8 premiers octets. `vault.db` est créé s’il n’existe pas. |
| F1 | `f1_add_credential` | Saisit login et password dans une `struc credential` (2 × 32 octets), charge la base, la déchiffre, ajoute l’entrée à la fin, rechiffre l’ensemble et sauvegarde. |
| F2 | `f2_show_vault` | Charge la base, la déchiffre en mémoire et affiche chaque entrée (`Base vide.` s’il n’y en a aucune). Le fichier n’est pas modifié. |

En cas d’erreur (fichier, format, base pleine), le programme s’arrête avec le code de sortie 1.

## Format de `vault.db`

- Entrées de 64 octets placées à la suite, sans en-tête : login (32 octets) puis password (32 octets), chacun terminé par 0.
- Chiffrement XOR ECB : chaque bloc de 8 octets est combiné avec la même clé de 8 octets.
- Taille = 64 × nombre d’entrées, 4096 octets au maximum (64 entrées, taille du tampon `db_buffer`).
- Un fichier dont la taille n’est pas un multiple de 64, ou qui dépasse 4096 octets, est refusé.

## Organisation du code

```text
TD08/
├── secure_vault.asm     _start, menu, données
├── inc/
│   ├── cours.inc        bibliothèque générique, réutilisable
│   ├── db.inc           load_db, save_db
│   ├── f0_open.inc      F0
│   ├── f1_add.inc       F1
│   └── f2_show.inc      F2
├── build_nasm.sh        nasm + ld vers rootfs/
├── qiling_run.py        exécution sous Qiling
├── ql_run.sh            exécution sous Qiling (qltool)
└── docker/              Dockerfile, docker-compose.yaml
```

Les `.inc` sont recopiés dans `secure_vault.asm` par `%include` : un seul fichier est assemblé et lié.

### Bibliothèque `inc/cours.inc`

| Fonction | Arguments | Retour (`rax`) |
|---|---|---|
| `print_hex` | `rdi` = valeur | – |
| `print_string` | `rdi` = texte, `rsi` = taille | – |
| `print` | `rdi` = chaîne terminée par 0 | longueur |
| `strlen` | `rdi` = chaîne terminée par 0 | longueur |
| `strcmp` | `rdi`, `rsi` = chaînes | 0 si égales |
| `read_string` | `rdi` = tampon, `rsi` = capacité | caractères stockés |
| `read_hex` | – | valeur lue |
| `xor_ecb` | `rdi` = tampon, `rsi` = taille, `rdx` = clé | – |
| `open_file` | `rdi` = nom | fd, ou < 0 |
| `read_file` | `rdi` = fd, `rsi` = tampon, `rdx` = taille max | octets lus, ou < 0 |
| `write_file` | `rdi` = fd, `rsi` = données, `rdx` = taille | octets écrits, ou < 0 |
| `read_all` | `rdi` = fd, `rsi` = tampon, `rdx` = capacité | total lu, ou < 0 |
| `write_all` | `rdi` = fd, `rsi` = données, `rdx` = taille | taille, ou < 0 |
| `close_file` | `rdi` = fd | 0, ou < 0 |

`print_hex` et `print_string` sont le code fourni. `strcmp` et `read_hex` ne servent pas au Secure Vault mais complètent le squelette de `cours.inc`.

### Fonctions du Secure Vault

| Fonction | Rôle | Retour (`rax`) |
|---|---|---|
| `f0_open_vault`, `f1_add_credential`, `f2_show_vault` | F0, F1, F2 | 0, ou < 0 |
| `load_db` | ouvrir, `read_all`, fermer, vérifier la taille | taille, ou < 0 |
| `save_db` | ouvrir, `write_all`, fermer | 0, ou < 0 |

`_start` appelle F0 puis F1 ou F2 selon le menu. Les fonctions ne quittent jamais le programme : elles renvoient une valeur négative, et `_start` décide de la sortie.

### Convention d’appel et pile

- Convention System V x86-64 : arguments dans `rdi`, `rsi`, `rdx`, retour dans `rax`.
- Chaque fonction a un prologue (`push rbp` / `mov rbp, rsp`, ou `enter`) et un épilogue (`leave` / `ret`).
- Les registres *callee-saved* utilisés (`rbx`, `r12` à `r14`) sont sauvegardés et restaurés dans l’ordre inverse (`read_all`, `write_all`, `f2_show_vault`) : ils conservent des valeurs à travers des appels.
- Une valeur qui n’a pas à survivre à un appel est mise dans un registre *caller-saved* (`rcx` dans `xor_ecb`), sans sauvegarde.
- `read_string` et `read_hex` réservent leurs variables locales avec `enter 32, 0`.

Le code se limite aux notions du cours : chaînes terminées par 0 affichées avec `print` (comme au TD06), étiquettes préfixées par le nom de leur fonction (`xor_ecb_next_block`, comme `loop_strlen`), constantes en décimal ou en hexadécimal. Seuls les drapeaux de `open` (`66` = `O_RDWR` + `O_CREAT`) n’apparaissent pas dans les supports ; ils sont nécessaires pour créer le fichier.

## Limites et analyse de sécurité

Le XOR ECB à clé de 8 octets imposé par le sujet est réalisé conformément à l’énoncé, mais il est faible :

- **La clé apparaît en clair dans le fichier.** Les champs sont complétés par des 0, et `0 XOR clé = clé` ; l’ECB répète la même clé sur chaque bloc. Avec la clé `abcdefgh`, `od -A d -t x1 vault.db` montre :

  ```text
  0000000 00 0e 0a 07 00 66 67 68 61 62 63 64 65 66 67 68
  0000016 61 62 63 64 65 66 67 68 61 62 63 64 65 66 67 68
  ```

  `61 … 68` est `abcdefgh` en ASCII : il suffit d’ouvrir le fichier pour lire la clé.
- **Mot de passe vide ou court.** Les octets manquants de la clé valent 0, et `X XOR 0 = X` : avec un mot de passe vide, les identifiants sont écrits en clair.
- **Blocs identiques.** Deux blocs clairs identiques (même password, par exemple) donnent deux blocs chiffrés identiques.
- **Pas de vérification du mot de passe.** Avec une mauvaise clé, F2 affiche des données incorrectes. F1 ne détruit pas les entrées existantes (déchiffrées puis rechiffrées avec la même clé), mais chiffre la nouvelle avec une autre clé : la base mélange alors deux clés.
- **Longueur des champs dans F2.** `strlen` cherche le 0 final, toujours présent avec une saisie normale (`read_string` le réserve). Après une mauvaise clé, un champ peut ne plus en contenir et l’affichage déborde sur le champ suivant. Une version bornée (`strnlen`) corrigerait ce cas ; elle n’a pas été ajoutée pour garder le code simple.

Autres limites : une seule action par lancement ; pas de suppression, modification ni recherche d’entrée (non demandées) ; les saisies sont visibles dans le terminal ; une erreur d’ouverture ou de fermeture de fichier termine le programme (code 1) sans message.

## Tests réalisés

Dans le conteneur Docker du projet, sous Qiling et sans émulation :

| Cas | Résultat |
|---|---|
| Base absente | `vault.db` créé, 0 octet |
| Deux ajouts (F1) puis affichage (F2) | 128 octets, les deux entrées affichées en clair |
| F2 sur une base vide | `Base vide.` |
| Login de plus de 31 caractères | tronqué à 31, password correct |
| Base pleine (64 entrées) puis F1 | ajout refusé, fichier inchangé, code 1 |
| Fichier de plus de 4096 octets | refusé, code 1 |
| Taille non multiple de 64 | refusée, code 1 |
| Choix invalide au menu | fin sans action, code 0 |

## Utilisation de l’IA

Un assistant IA a été utilisé pour :

- expliquer les notions du cours (registres, adresses, pile, convention d’appel, syscalls, XOR) ;
- décomposer le sujet en étapes et proposer du code à partir des supports du cours ;
- restructurer le code en fonctions et en fichiers, et préparer l’environnement Docker et Qiling ;
- interpréter les résultats des essais et rédiger cette documentation.

Le code produit avec cette aide n’est pas un corrigé officiel. Les notions utilisées restent celles du cours.
