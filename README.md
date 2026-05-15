# SFTP Natif Azure — Blob Storage + Firewall + Private Endpoint

![Azure](https://img.shields.io/badge/Cloud-Microsoft%20Azure-0089D6?style=flat&logo=microsoftazure)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=flat&logo=terraform)
![SFTP](https://img.shields.io/badge/Protocol-SFTP-00897B?style=flat&logo=files)
![Azure Firewall](https://img.shields.io/badge/Security-Azure_Firewall-0C6F82?style=flat&logo=microsoftazure)
![Private Endpoint](https://img.shields.io/badge/Network-Private_Endpoint-0078D4?style=flat&logo=microsoftazure)
![Blob Storage](https://img.shields.io/badge/Storage-Azure_Blob-0089D6?style=flat&logo=microsoftazure)
![Cloud Shell](https://img.shields.io/badge/Environnement-Cloud_Shell_Bash-5391FE?style=flat&logo=gnubash)
![Lab](https://img.shields.io/badge/Type-Lab_Personnel-brightgreen?style=flat)

Ce lab est basé sur l'architecture proposée par **PHIL_IT** sur YouTube.  
## Chaîne : [youtube.com/@phil_it](https://www.youtube.com/@phil_it)  
## Vidéo du tuto : [Azure SFTP natif sur Blob Storage](https://www.youtube.com/watch?v=5uoyecoJCZ4&t=312s)

---

## Description & Objectif

L'objectif est de déployer un serveur SFTP **sans VM à maintenir**, en s'appuyant sur le support natif SFTP d'Azure Blob Storage. L'infrastructure est sécurisée via un **Azure Firewall** (règle DNAT sur le port 22) et un **Private Endpoint** qui isole le compte de stockage du réseau public. Tout le déploiement est automatisé en Infrastructure-as-Code avec Terraform, exécuté directement depuis Azure Cloud Shell.

---

## Table des matières
 
- [Architecture](#-architecture)
- [Prérequis](#-prérequis)
- [Structure du projet](#-structure-du-projet)
- [Déploiement pas-à-pas](#-déploiement-pas-à-pas)
  - [Étape 1 - Ouvrir Azure Cloud Shell](#étape-1--ouvrir-azure-cloud-shell)
  - [Étape 2 — Récupérer les fichiers Terraform](#étape-2--récupérer-les-fichiers-terraform)
  - [Étape 3 — Personnaliser les variables](#étape-3--personnaliser-les-variables)
  - [Étape 4 — Vérifier la disponibilité des noms](#étape-4--vérifier-la-disponibilité-des-noms-azure)
  - [Étape 5 — Initialiser Terraform](#étape-5--initialiser-terraform)
  - [Étape 6 — Formater et valider le code](#étape-6--formater-et-valider-le-code)
  - [Étape 7 — Vérifier le plan de déploiement](#étape-7--vérifier-le-plan-de-déploiement)
  - [Étape 8 — Appliquer le déploiement](#étape-8--appliquer-le-déploiement)
  - [Étape 9 — Récupérer les outputs](#étape-9--récupérer-les-outputs)
  - [Étape 10 — Récupérer le mot de passe SFTP](#étape-10--récupérer-le-mot-de-passe-sftp)
- [Ressources déployées](#-ressources-déployées)
- [Configuration détaillée](#-configuration-détaillée)
- [Test de connexion SFTP](#-test-de-connexion-sftp)
- [Outputs Terraform](#-outputs-terraform)
- [Bonnes pratiques de sécurité](#-bonnes-pratiques-de-sécurité)
- [Nettoyage](#-nettoyage)
- [Référence](#-référence)
---

## Architecture

```
                         ┌─────────────────────────────────────────────┐
                         │         Azure Virtual Network                │
                         │              10.0.0.0/16                     │
                         │                                              │
   Client externe        │  ┌──────────────────────┐                   │
   (protocole SFTP) ─────►  │    Azure Firewall     │                   │
   TCP port 22           │  │  AzureFirewallSubnet  │                   │
                         │  │    10.0.1.0/26        │                   │
                         │  │   (IP pub: DNAT→:22)  │                   │
                         │  └──────────┬────────────┘                   │
                         │             │ DNAT TCP:22                    │
                         │             ▼                                 │
                         │  ┌──────────────────────┐   ┌─────────────┐ │
                         │  │   Private Endpoint    │──►│   Storage   │ │
                         │  │   10.0.2.10 / TCP:22  │   │   Account   │ │
                         │  │  Workload SN subnet   │   │  (SFTP ON)  │ │
                         │  │    10.0.2.0/24        │   │  Container  │ │
                         │  └──────────────────────┘   │    "ftp"    │ │
                         │                              └─────────────┘ │
                         └─────────────────────────────────────────────┘
```

**Flux réseau :**  
`Client → IP publique Firewall:22 → DNAT → Private Endpoint IP:22 → Storage Account SFTP`

---

## Prérequis

| Élément | Détail |
|---|---|
| Compte Azure | Abonnement actif avec droits Contributor |
| Azure Cloud Shell | Bash, directement depuis le portail Azure |
| Terraform | Pré-installé dans Cloud Shell (≥ 1.5.0) |
| Quota Firewall | Vérifier les quotas régionaux Azure Firewall Standard |

> **Pourquoi Cloud Shell ?** Terraform est nativement disponible, l'authentification Azure CLI est automatique - aucune configuration de credentials requise.

---

## Structure du projet

```
sftp-azure-terraform/
├── providers.tf        # Configuration du provider AzureRM
├── variables.tf        # Déclaration de toutes les variables
├── terraform.tfvars    # Valeurs personnalisées (à adapter)
├── main.tf             # Toutes les ressources Azure
├── outputs.tf          # Sorties utiles post-déploiement
└── check-names.sh      # Vérification des noms uniques avant déploiement
```

---

## Déploiement pas-à-pas

### Étape 1 - Ouvrir Azure Cloud Shell

1. Connectez-vous sur [portal.azure.com](https://portal.azure.com)
2. Cliquez sur l'icône **Cloud Shell** `>_` en haut à droite
3. Choisissez **Bash**
4. Vérifiez que Terraform est disponible :

```bash
terraform version
az account show
```

### Étape 2 - Récupérer les fichiers Terraform

```bash
# Option A — Cloner depuis Git (si vous avez pushé le projet)
git clone https://github.com/<votre-org>/sftp-azure-terraform.git
cd sftp-azure-terraform

# Option B — Créer manuellement le répertoire
mkdir sftp-azure-terraform && cd sftp-azure-terraform
```

Copiez chaque fichier `.tf` dans ce répertoire via l'éditeur Cloud Shell ou `nano`.

### Étape 3 - Personnaliser les variables

```bash
nano terraform.tfvars
```

>  **Important** : Le nom du `storage_account_name` doit être **globalement unique** sur Azure (3-24 caractères, minuscules et chiffres uniquement). Changez `sftpdemopp` par un nom unique.

```hcl
# Exemple de personnalisation minimale
storage_account_name = "sftpmonentreprise2024"
sftp_local_user_name = "monuser"
location             = "norwayeast"
```

### Étape 4 - Vérifier la disponibilité des noms Azure

Avant tout déploiement, vérifiez que les noms de ressources sont disponibles (notamment le Storage Account qui doit être **unique mondialement**).

```bash
chmod +x check-names.sh
./check-names.sh
```

> Par exemple, si un ❌ apparaît sur le Storage Account, modifiez `storage_account_name` dans `terraform.tfvars` et relancez le script jusqu'à obtenir tous les ✅.

### Étape 5 - Initialiser Terraform

```bash
terraform init
```

Résultat attendu :
```
Terraform has been successfully initialized!
```

### Étape 6 - Formater et valider le code

**Formatage automatique** - harmonise l'indentation et le style de tous les fichiers `.tf` :

```bash
terraform fmt
```

> `terraform fmt` modifie les fichiers en place. Si aucun fichier n'est besoin de correction, la commande ne retourne rien.

**Validation de la syntaxe** - vérifie la cohérence du code sans contacter Azure :

```bash
terraform validate
```

Résultat attendu :
```
Success! The configuration is valid.
```

> Ces deux commandes sont à lancer **à chaque modification** des fichiers `.tf` avant d'aller plus loin. Elles détectent les erreurs de syntaxe, les références manquantes et les types incorrects sans coût.

### Étape 7 - Vérifier le plan de déploiement

```bash
terraform plan -out=tfplan
```

Terraform affichera les ressources qui seront créées. Vérifiez notamment :
- Le nom du Storage Account (unique)
- La région (`norwayeast`)
- Les plages IP des subnets

### Étape 8 - Appliquer le déploiement

```bash
terraform apply tfplan
```

Confirmez avec `yes` si vous n'avez pas utilisé `-out=tfplan`, ou lancez directement :

```bash
terraform apply -auto-approve
```

>  **Durée estimée** : 10 à 20 minutes (le déploiement du Firewall Standard est le plus long ~8-12 min)

### Étape 9 - Récupérer les outputs

```bash
terraform output
```

Vous obtiendrez notamment :
- L'IP publique du Firewall (point d'entrée SFTP)
- La commande de connexion SFTP prête à l'emploi
- L'IP privée du Private Endpoint
- Et autres

### Étape 10 - Récupérer le mot de passe SFTP

Le mot de passe est généré par Azure. Pour le récupérer depuis le portail :

1. Portail Azure → **Storage Account** → `sftpdemoatt2024`
2. Volet gauche → **SFTP** → **Local users**
3. Cliquez sur `...` à côté de votre utilisateur → **Generate password**
4. Copiez et sauvegardez le mot de passe (il n'est affiché qu'une seule fois)

Ou via Azure CLI :

```bash
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name)
RG=$(terraform output -raw resource_group_name)

az storage account local-user regenerate-password \
  --account-name $STORAGE_ACCOUNT \
  --resource-group $RG \
  --name test
```

---

## Ressources déployées

| Ressource | Nom | Description |
|---|---|---|
| Resource Group | `RG-DEMO-ATT` | Conteneur de toutes les ressources |
| Virtual Network | `vnet-prod-fr-sftp` | Réseau virtuel `10.0.0.0/16` |
| Subnet Firewall | `AzureFirewallSubnet` | `10.0.1.0/26` — réservé au Firewall |
| Subnet PE | `privateendpoint` | `10.0.2.0/24` — Private Endpoint |
| IP publique | `public-ip-azfw` | IP statique Standard du Firewall |
| Azure Firewall | `vnet-prod-fr-Firewall` | SKU Standard, avec Firewall Policy |
| Firewall Policy | `fw-policy-sftp` | Policy + règle DNAT |
| Règle NAT | `dnat-rule-sftp` | DNAT TCP:22 → Private Endpoint:22 |
| Storage Account | `sftpdemoatt2024` | HNS activé, SFTP activé, accès public désactivé |
| Container Blob | `ftp` | Répertoire racine des utilisateurs SFTP |
| Private Endpoint | `privateendpoint-sftp` | Accès privé au Storage (sous-ressource `blob`) |
| Private DNS Zone | `privatelink.blob.core.windows.net` | Résolution DNS interne |
| Utilisateur local | `test` | Utilisateur SFTP avec auth par mot de passe |

---

## Configuration détaillée

### Règle DNAT (NAT Firewall)

```
Politique      : fw-policy-sftp        (Priorité: 100)
Règle          : dnat-rule-sftp
Protocole      : TCP + UDP
Source         : * (tout)
Destination    : <IP_publique_Firewall>
Port entrant   : 22
Traduit vers   : <IP_privée_Private_Endpoint>
Port sortant   : 22
```

### Utilisateur SFTP local

```
Nom             : test
Auth            : SSH Password (mot de passe généré par Azure)
Home directory  : ftp
Permissions     : Read, Write, List, Delete, Create
```

### Accès réseau Storage Account

```
Accès public    : Désactivé
Règle réseau    : Deny par défaut
Bypass          : AzureServices
Accès autorisé  : Via Private Endpoint uniquement
```

---

##  Test de connexion SFTP

### Depuis un client Linux/macOS

```bash
# Récupérer la commande de connexion depuis les outputs
terraform output sftp_connection_string

# Connexion (username format : <storage_account>.<local_user>)
sftp sftpdemopp.test@<IP_PUBLIQUE_FIREWALL>

# Saisir le mot de passe quand demandé
# Commandes SFTP de base :
sftp> ls              # Lister les fichiers
sftp> put fichier.txt # Uploader un fichier
sftp> get fichier.txt # Télécharger un fichier
sftp> exit            # Se déconnecter
```

### Depuis Windows (WinSCP ou FileZilla)

```
Protocole  : SFTP
Hôte       : <IP_PUBLIQUE_FIREWALL>
Port       : 22
Utilisateur: sftpdemopp.test
Mot de passe: <mot_de_passe_généré>
```

### Vérification de la connectivité

```bash
# Tester la connectivité TCP sur le port 22
nc -zv <IP_PUBLIQUE_FIREWALL> 22

# Ou depuis PowerShell
Test-NetConnection -ComputerName <IP_PUBLIQUE_FIREWALL> -Port 22
```

---

## Outputs Terraform

| Output | Description |
|---|---|
| `resource_group_name` | Nom du RG déployé |
| `firewall_public_ip` | IP publique du Firewall (entrée SFTP) |
| `storage_account_name` | Nom du Storage Account |
| `private_endpoint_ip` | IP privée du Private Endpoint |
| `sftp_connection_string` | Commande sftp complète |
| `sftp_user_name` | Username au format `storage.user` |
| `nat_rule_summary` | Récapitulatif de la règle DNAT |

---

## Bonnes pratiques de sécurité

### À faire

- **Préférer SSH Key pair** à SSH Password pour les utilisateurs SFTP en production
- **Restreindre la source** dans la règle DNAT (remplacer `*` par les IPs de confiance)
- **Activer les logs** du Firewall vers un Log Analytics Workspace
- **Utiliser un coffre-fort** (Azure Key Vault) pour stocker les mots de passe générés
- **Audit régulier** des utilisateurs locaux et de leurs permissions

### Erreurs courantes à éviter

| Erreur | Risque | Solution |
|---|---|---|
| Laisser le source `*` en production | Exposition à toute IP internet | Restreindre aux IPs autorisées |
| Oublier de désactiver l'accès public du Storage | Contourne le Private Endpoint | `public_network_access_enabled = false` |
| Utiliser SSH Password sans rotation | Compromission silencieuse | SSH Key pair ou rotation automatique |
| Ne pas activer HNS | SFTP non disponible | `is_hns_enabled = true` obligatoire |
| Permissions trop larges sur le container | Risque de suppression accidentelle | Minimaliser les permissions selon l'usage |

---

## Nettoyage

Pour supprimer toutes les ressources déployées et éviter des coûts inutiles :

```bash
terraform destroy -auto-approve
```

> Cette commande supprime **toutes** les ressources du projet de manière irréversible.

---

## Référence

-  [Vidéo du Lab original](https://www.youtube.com/watch?v=5uoyecoJCZ4)
-  [Documentation Azure — SFTP sur Blob Storage](https://learn.microsoft.com/fr-fr/azure/storage/blobs/secure-file-transfer-protocol-support)
-  [Documentation Azure Firewall DNAT](https://learn.microsoft.com/fr-fr/azure/firewall/tutorial-firewall-dnat)
-  [Documentation Private Endpoint](https://learn.microsoft.com/fr-fr/azure/private-link/private-endpoint-overview)
-  [Provider Terraform AzureRM](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

---

##  Notes

- Le **Firewall Standard** génère des coûts significatifs (~1,25 €/heure). Pensez à détruire l'infra après les tests.
- Le nom du **Storage Account** doit être modifié — `sftpdemopp` est pris dans le lab d'origine.
- Le **mot de passe** de l'utilisateur SFTP est généré par Azure et récupérable une seule fois via le portail ou l'API.
- Le déploiement d'un Azure Firewall peut prendre **8 à 12 minutes**.

---

*Déploiement automatisé avec Terraform | Infrastructure Azure SFTP sécurisée*
