
# ELF Triage - Analyse statique d'un fichier ELF64

## Présentation

**elf-triage** est un petit outil développé en assembleur x86-64 sous Linux permettant d'effectuer une première analyse statique d'un fichier ELF (Executable and Linkable Format).

L'objectif est de lire l'en-tête d'un fichier ELF afin d'en extraire quelques informations essentielles, sans exécuter le programme analysé.

Ce projet a été réalisé dans le cadre de mon apprentissage de l'assembleur et de la compréhension des exécutables Linux.

## Fonctionnalités

Le programme permet de :

- Vérifier qu'un fichier possède une signature ELF valide.
- Identifier l'architecture cible du fichier.
- Identifier le type de fichier ELF.
- Récupérer l'adresse du point d'entrée (Entry Point).
- Détecter les fichiers invalides ou les en-têtes incomplets.
- Afficher des messages d'erreur en cas de problème.

L'analyse est entièrement statique : le fichier est uniquement ouvert en lecture et son code n'est jamais exécuté.

## Technologies utilisées

- **Langage :** Assembleur x86-64
- **Syntaxe :** Intel (GNU Assembler)
- **Système :** Linux x86-64
- **Outils :** GNU `as`, `ld`, `readelf`
- **Interface :** Ligne de commande (CLI)

Le programme utilise directement les appels système Linux, sans bibliothèque standard C.

## Installation et compilation

### Prérequis

Disposer d'un environnement Linux x86-64 avec GNU binutils installé.

Sur Debian ou Ubuntu :

```bash
sudo apt update
sudo apt install binutils
```

### Compilation

Depuis le répertoire du projet :

```bash
as --64 -o elf-triage.o elf-triage.s
ld -o elf-triage elf-triage.o
```

Ces commandes permettent d'assembler le fichier source puis de générer l'exécutable `elf-triage`.

## Utilisation

Le programme prend en argument le chemin d'un fichier à analyser.

Exemple :

```bash
./elf-triage /bin/ls
```

Le programme affiche les informations extraites de l'en-tête ELF :

- Architecture (`e_machine`)
- Type ELF (`e_type`)
- Point d'entrée (`e_entry`)

Pour vérifier les résultats, il est possible de les comparer avec l'outil `readelf` :

```bash
readelf -h /bin/ls
```

Les champs à comparer sont :

- `Machine`
- `Type`
- `Entry point address`

Selon les fichiers, le type `ET_DYN` peut correspondre à une bibliothèque partagée ou à un exécutable PIE.

## Gestion des erreurs

Le programme prend en compte plusieurs situations :

- Aucun argument ou nombre d'arguments incorrect.
- Fichier inexistant ou impossible à ouvrir.
- Erreur de lecture.
- Fichier trop court pour contenir un en-tête ELF64 complet.
- Signature ELF incorrecte.
- Format ELF non pris en charge.

### Tests simples

**Test avec un fichier non ELF :**

```bash
printf 'bonjour\n' > exemple.txt
./elf-triage exemple.txt
echo $?
```

**Test avec un en-tête incomplet :**

```bash
head -c 32 /bin/ls > tronque.elf
./elf-triage tronque.elf
echo $?
```

**Test avec un fichier ELF valide :**

```bash
./elf-triage /bin/ls
echo $?
```

### Codes de retour

| Code | Signification |
|------|---------------|
| `0` | Analyse réussie |
| `1` | Erreur de lecture ou fichier invalide |
| `2` | Arguments incorrects |

## Fonctionnement technique

Le programme commence par ouvrir le fichier en lecture seule, puis lit les 64 premiers octets correspondant à l'en-tête ELF64.

Il vérifie ensuite plusieurs informations :

1. La signature ELF (`0x7F`, `E`, `L`, `F`).
2. La classe du fichier (ELF64).
3. L'ordre des octets (Little Endian).
4. La version du format ELF.
5. La taille de l'en-tête.

Une fois les vérifications effectuées, les informations principales sont extraites.

### Structure de l'en-tête

| Champ | Offset | Taille | Description |
|-------|--------|--------|-------------|
| `e_type` | 16 | 2 octets | Type de fichier ELF |
| `e_machine` | 18 | 2 octets | Architecture cible |
| `e_entry` | 24 | 8 octets | Adresse du point d'entrée |

Ces champs sont lus directement depuis les données de l'en-tête.

### Appels système utilisés

Le programme repose sur les appels système Linux suivants :

| Syscall | Utilisation |
|---------|-------------|
| `open` | Ouvrir le fichier |
| `read` | Lire son en-tête |
| `close` | Fermer le descripteur |
| `write` | Afficher les résultats |
| `exit` | Terminer le programme |

L'utilisation directe des syscalls permet de travailler au plus près du système et de mieux comprendre la gestion des fichiers en assembleur.

## Limites du projet

Cet outil est volontairement limité à une première analyse de l'en-tête ELF.

Il ne permet pas :

- D'analyser les sections et segments du fichier.
- De désassembler les instructions.
- D'examiner les symboles ou les dépendances.
- De détecter un éventuel comportement malveillant.
- D'analyser les fichiers ELF32 ou Big Endian.

Les architectures ou types non reconnus par les libellés du programme peuvent être affichés sous forme hexadécimale.

Il ne remplace donc pas des outils comme `readelf`, `objdump` ou `file`.

## Ce que ce projet m'a apporté

Ce projet m'a permis de mettre en pratique plusieurs notions abordées pendant mon apprentissage de l'assembleur :

- La manipulation des registres x86-64.
- L'utilisation des appels système Linux.
- La lecture et l'interprétation de données binaires.
- La compréhension de la structure d'un fichier ELF.
- La gestion des erreurs et des codes de retour.
- La conversion et l'affichage de valeurs hexadécimales.

Il constitue également une première approche de l'analyse statique des exécutables, une compétence utile notamment en reverse engineering et en analyse de malware.

## Pistes d'amélioration

Plusieurs évolutions pourraient être envisagées :

- Ajouter la prise en charge des fichiers ELF32.
- Analyser les Program Headers.
- Afficher les sections ELF.
- Identifier davantage d'architectures.
- Ajouter des tests automatisés.
- Proposer un affichage plus détaillé des métadonnées.

## Références

- [ELF Specification - System V ABI](https://gabi.xinuos.com/elf/02-eheader.html)
- [GNU Binutils](https://www.gnu.org/software/binutils/)
- [Linux man-pages](https://man7.org/linux/man-pages/)

---

Projet réalisé dans le cadre de mon apprentissage de l'assembleur x86-64 et de la cybersécurité.