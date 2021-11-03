# Connect-OneDriveAutomagically

## Description

Ce duo de scripts permet de préparer OneDrive et de lancer la connexion d’un compte utilisateur professionnel ou scolaire automatiquement puis d’y préparer la synchronisation de bibliothèques SharePoint Online automatiquement.

### Environnement d’exécution

Le tout est conçu pour rouler dans un environnement sans authentification unifiée avec Microsoft365 et où il est possible d’y déployer des politiques de configuration sur un domaine (GPO) qui permettront de déployer un raccourcis lançant le script.

### Provisionnement des bibliothèques SharePoint Online

La synchronisation des bibliothèques est effectuée par le script `Sync-SharePointLibraries` qui parcours un document `.csv` où chaque ligne correspond à une bibliothèque unique avec les propriétés de nom de site (`SiteName`), nom de bibliothèque (`LibraryName`) et la chaîne de synchronisation (`SynchronizationString`).

## Prérequis

Les logiciels suivants sont requis pour l’utilisation du script.

| Nom                                                          | Version | Description                                            | Utilisation                                                  |
| ------------------------------------------------------------ | ------- | ------------------------------------------------------ | ------------------------------------------------------------ |
| [Windows PowerShell](https://docs.microsoft.com/fr-ca/powershell/scripting/install/installing-powershell-on-windows) | 5+      | Environnement de commandes et de scripting.            | Exécution des scripts.                                       |
| [Client de gestion de paquet Windows (`winget`)](https://github.com/microsoft/winget-cli) | 1.1+    | Gestionnaire de paquet à-la Linux pour Windows.        | Installation et validation de la présence de OneDrive sur l’ordinateur. |
| [Outils d’administration de serveur distant (RSAT) pour Windows](https://docs.microsoft.com/fr-ca/troubleshoot/windows-server/system-management-components/remote-server-administration-tools) (facultatif) |         | Trousse d’outils d’administration de serveurs Windows. | Obtention de l’adresse courriel de l’utilisateur courant dans son objet ActiveDirectory lors de configuration sur un serveur de bureau à distance. |

## Paramètres par script

### Connect-OneDriveAutomagically

| Nom                 |         Type         | Obligatoire | Description                                                  |                                            Valeur par défaut |
| ------------------- | :------------------: | :---------: | ------------------------------------------------------------ | -----------------------------------------------------------: |
| ForceInstall        |       `switch`       |      ⬜      | Effectue l’installation de OneDrive même si déjà présent.    |                                                     `$false` |
| ForceSync           |       `switch`       |      ⬜      | Effectue la synchronisation des bibliothèques même si déjà présentes. |                                                     `$false` |
| UserEmail           |       `string`       |      ⬜      | Spécifie l’adresse courriel de l’usager à préparer.          | (Déduit via le nom d’utilisateur et le paramètre *TenantEmailDomain*) |
| TenantEmailDomain   |       `string`       |      ⬜      | Spécifie le nom de domaine par défaut de l’adresse courriel de l’usager. |                       `contoso.com`<br />(À titre d’exemple) |
| OneDrivePackageName |       `string`       |      ⬜      | Spécifie le nom du paquet *winget* au logiciel OneDrive.     |                                         `Microsoft.OneDrive` |
| LibrariesListPath   | `System.IO.FileInfo` |      ⬜      | Spécifie le chemin où trouver la liste de bibliothèques à connecter. |                                               `.\SharePoint` |



### Sync-SharePointLibraries

| Nom               |         Type         | Obligatoire | Description                                                  | Valeur par défaut |
| ----------------- | :------------------: | :---------: | ------------------------------------------------------------ | ----------------: |
| Force             |       `switch`       |      ⬜      | Effectue la synchronisation des bibliothèques même si déjà présentes. |          `$false` |
| UserEmail         |       `string`       |      ☑️      | Spécifie l’adresse courriel de l’usager à préparer.          |                   |
| LibrariesListPath | `System.IO.FileInfo` |      ☑️      | Spécifie le chemin où trouver la liste de bibliothèques à connecter. |                   |
| DelayBetweenSyncs |        `int`         |      ⬜      | Spécifie le délai d’attente entre chaque connexion de bibliothèque. |                 5 |



## Utilisation

### En tant que raccourcis

> Cette méthode convient pour fournir un moyen manuel aux utilisateurs de demander la connexion de leur compte OneDrive et de leur bibliothèque(s) SharePoint Online.

Créer un raccourcis avec les détails suivants :

**Cible**

```
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
```

**Arguments**

```
-NoProfile -NoLogo -ExecutionPolicy Bypass -File "\\Contoso.com\SYSVOL\Contoso.com\Scripts\OneDrive\Connect-OneDriveAutomagically.ps1" -ForceSync
```

### En tant que politique de configuration d’ordinateur

> Cette méthode convient pour fournir un moyen automatisé aux utilisateurs d’effectuer la connexion de leur compte OneDrive et de leur bibliothèque(s) SharePoint Online.

Créer un raccourcis utilisateur (Configuration utilisateur ➡️ Préférences ➡️ Paramètres Windows ➡️ Raccourcis) et le remplir avec les détails suivants :

| Page    | Propriété                                                    | Valeur                                                       |
| ------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| Général | Action                                                       | Remplacer                                                    |
| Général | Nom                                                          | (Nom de raccourcis désiré)                                   |
| Général | Type de cible                                                | Objet du système de fichiers                                 |
| Général | Emplacement                                                  | Démarrage                                                    |
| Général | Chemin cible                                                 | C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe    |
| Général | Arguments                                                    | -NoProfile -NoLogo -ExecutionPolicy Bypass -File "\\\Contoso.com\SYSVOL\Contoso.com\Scripts\OneDrive\Connect-OneDriveAutomagically.ps1" |
| Général | Démarrer dans                                                | \\\Contoso.com\SYSVOL\Contoso.com\Scripts\OneDrive\          |
| Commun  | Exécuter dans le contexte de sécurité de l’utilisateur connecté | ☑️                                                            |
| Commun  | Supprimer l'élément lorsqu'il n'est plus appliqué            | ☑️                                                            |

