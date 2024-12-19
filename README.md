# Processus pour automatiser les mises à jour Windows :
## 1. Préparation de l'image Windows avec NTLite :
### Ajout des éléments suivants à l'image :
Clé de registre RunOnce :
- Commande utilisée :
```powershell
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "CheckForUpdatesAfterReboot" -Value "Powershell.exe -ExecutionPolicy Bypass -File C:\Windows\Setup\Files\AutomateUpdates.ps1"
```
- Cette clé configure le script `AutomateUpdates.ps1` pour qu’il s’exécute automatiquement après le premier démarrage.
- Script `AutomateUpdates.ps1` : Copié dans `C:\Windows\Setup\Files\`.
## 2. Fonctionnement du script AutomateUpdates.ps1 :
- À chaque redémarrage, le script vérifie les mises à jour Windows, les installe et configure les redémarrages nécessaires jusqu’à ce que toutes les mises à jour soient appliquées.
- Une fois le système à jour, le script s’autosupprime pour nettoyer l’environnement.
### Avantages :
- Automatisation complète des mises à jour Windows sans intervention manuelle.
- Logs détaillés dans le fichier `C:\Windows\Setup\Files\AutomateUpdates.log` pour suivre chaque étape et identifier les éventuelles erreurs.
- Maintenance réduite grâce à la suppression automatique du script une fois le processus terminé.
