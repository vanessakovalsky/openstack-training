# Atelier Trove - Database as a Service (1h)
## Installation et utilisation sur DevStack

---

## 🎯 Objectifs de l'atelier

À la fin de cet atelier, vous serez capable de :
- Installer et configurer Trove sur DevStack
- Comprendre l'architecture de Trove
- Créer et gérer des instances de bases de données (MySQL, PostgreSQL)
- Effectuer des sauvegardes et restaurations
- Gérer les utilisateurs et bases de données

**Durée estimée** : 60 minutes  
**Niveau** : Intermédiaire  
**Prérequis** : Connaissance de base d'OpenStack, accès à une machine Ubuntu

---

## 📋 Plan de l'atelier

| Temps | Module | Durée |
|-------|--------|-------|
| 0-15 min | Installation de Trove sur DevStack | 15 min |
| 15-25 min | Préparation des datastores | 10 min |
| 25-40 min | Création d'instances de bases de données | 15 min |
| 40-50 min | Gestion et opérations | 10 min |
| 50-60 min | Sauvegarde et restauration | 10 min |

---

## Module 1 : Installation de Trove sur DevStack (15 min)

### 📖 Contexte

**Trove** est le service Database as a Service (DBaaS) d'OpenStack. Il permet de provisionner et gérer des bases de données relationnelles et NoSQL sans se soucier de l'infrastructure sous-jacente.

### Étape 1.1 : Préparer l'environnement DevStack (3 min)

```bash
# Se connecter en tant qu'utilisateur stack (ou créer l'utilisateur)
sudo useradd -s /bin/bash -d /opt/stack -m stack
echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack
sudo su - stack

# Cloner DevStack
git clone https://opendev.org/openstack/devstack
cd devstack
```

### Étape 1.2 : Configurer local.conf pour Trove (5 min)

```bash
# Créer le fichier local.conf avec Trove activé
cat > local.conf << 'EOF'
[[local|localrc]]

# Credentials
ADMIN_PASSWORD=secret
DATABASE_PASSWORD=$ADMIN_PASSWORD
RABBIT_PASSWORD=$ADMIN_PASSWORD
SERVICE_PASSWORD=$ADMIN_PASSWORD

# Enable Trove
enable_plugin trove https://opendev.org/openstack/trove

# Trove specific settings
TROVE_RESIZE_TIME_OUT=1800

# Enable additional services needed
enable_service trove,tr-api,tr-tmgr,tr-cond

# Network configuration
HOST_IP=10.0.2.15  # Adapter selon votre IP
FIXED_RANGE=10.1.0.0/24
FLOATING_RANGE=172.24.4.0/24
PUBLIC_NETWORK_GATEWAY=172.24.4.1

# Image service
DOWNLOAD_DEFAULT_IMAGES=True

# Logs
LOGFILE=$DEST/logs/stack.sh.log
VERBOSE=True
LOG_COLOR=True
SCREEN_LOGDIR=$DEST/logs

# Disable unnecessary services for faster setup
disable_service horizon
disable_service tempest
EOF
```

**💡 Explication des paramètres clés** :
- `enable_plugin trove` : Active le plugin Trove
- `tr-api` : API Trove
- `tr-tmgr` : Task Manager (gestion des tâches)
- `tr-cond` : Conductor (orchestration)

### Étape 1.3 : Lancer l'installation DevStack (7 min)

```bash
# Lancer le script d'installation
./stack.sh

# ⏱️ Cette étape prend environ 15-20 minutes
# Profitez-en pour lire la documentation Trove
```

**Attendu** : À la fin, vous devriez voir :
```
This is your host IP address: 10.0.2.15
Horizon is now available at http://10.0.2.15/dashboard
Keystone is serving at http://10.0.2.15/identity/
Services are running under systemd unit files.
DevStack Version: [version]
```

### Étape 1.4 : Vérifier l'installation (1 min)

```bash
# Source les credentials
source ~/devstack/openrc admin admin

# Vérifier que Trove est installé
openstack service list | grep trove
openstack endpoint list | grep trove

# Vérifier les services Trove
sudo systemctl status devstack@tr-*

# Tester la connexion à l'API Trove
openstack database service list
```

**✅ Checkpoint** : Vous devez voir les services `trove` et les endpoints API

---

## Module 2 : Préparation des datastores (10 min)

### 📖 Contexte

Un **datastore** dans Trove représente un type de base de données (MySQL, PostgreSQL, MongoDB, etc.). Chaque datastore nécessite une image spécifique.

### Étape 2.1 : Comprendre les datastores (2 min)

```bash
# Lister les datastores disponibles
openstack database datastore list

# Lister les versions disponibles pour un datastore
openstack database datastore version list mysql
```

**Note** : Par défaut, DevStack installe MySQL comme datastore de test.

### Étape 2.2 : Télécharger une image Trove pour MySQL (3 min)

```bash
# Trove nécessite des images spéciales avec l'agent Trove préinstallé
# Pour ce workshop, nous utiliserons une image de test

# Télécharger l'image Trove MySQL (Ubuntu-based)
wget http://tarballs.openstack.org/trove/images/ubuntu/mysql.qcow2

# Alternative : Construire votre propre image (plus long)
# git clone https://opendev.org/openstack/trove
# cd trove/integration/scripts
# ./trovestack build-image mysql
```

### Étape 2.3 : Enregistrer l'image dans Glance (2 min)

```bash
# Upload l'image dans Glance
openstack image create \
  --disk-format qcow2 \
  --container-format bare \
  --file mysql.qcow2 \
  --public \
  trove-mysql-5.7

# Récupérer l'ID de l'image
IMAGE_ID=$(openstack image show trove-mysql-5.7 -c id -f value)
echo "Image ID: $IMAGE_ID"

# Vérifier
openstack image list | grep trove
```

### Étape 2.4 : Configurer le datastore (3 min)

```bash
# Créer ou mettre à jour le datastore MySQL
# Note: Cette commande nécessite l'accès direct à la base Trove
# En production, cela est fait via l'API admin

# Vérifier la configuration du datastore
openstack database datastore list
openstack database datastore version list mysql

# Si nécessaire, mettre à jour la version du datastore avec l'image
# (commande administrative, normalement faite lors de l'installation)
sudo mysql trove -e "
  UPDATE datastore_versions 
  SET image_id='$IMAGE_ID' 
  WHERE name='5.7';
"

# Vérifier les flavors disponibles pour Trove
openstack flavor list
```

**✅ Checkpoint** : L'image Trove est uploadée et le datastore est configuré

---

## Module 3 : Création d'instances de bases de données (15 min)

### 📖 Contexte

Une **instance Trove** est une base de données complètement provisionnée et managée. Trove s'occupe du déploiement, de la configuration et de la maintenance.

### Étape 3.1 : Préparer le réseau (2 min)

```bash
# Vérifier le réseau disponible
openstack network list

# Récupérer l'ID du réseau privé
PRIVATE_NET_ID=$(openstack network show private -c id -f value)
echo "Network ID: $PRIVATE_NET_ID"

# Créer un groupe de sécurité pour Trove
openstack security group create trove-access \
  --description "Acces aux bases de donnees Trove"

# Autoriser MySQL (port 3306)
openstack security group rule create \
  --protocol tcp \
  --dst-port 3306 \
  trove-access

# Autoriser ICMP (ping)
openstack security group rule create \
  --protocol icmp \
  trove-access
```

### Étape 3.2 : Créer une instance MySQL (5 min)

```bash
# Créer une instance de base de données MySQL
openstack database instance create \
  mysql-instance-01 \
  --flavor m1.small \
  --size 5 \
  --nic net-id=$PRIVATE_NET_ID \
  --datastore mysql \
  --datastore-version 5.7 \
  --databases testdb \
  --users testuser:password123 \
  --is-public

# Suivre la progression de la création
watch -n 5 "openstack database instance list"
# Appuyez sur Ctrl+C quand le statut est ACTIVE
```

**💡 Explication des paramètres** :
- `--flavor` : Taille de l'instance (CPU/RAM)
- `--size` : Taille du volume pour les données (en GB)
- `--databases` : Base de données à créer automatiquement
- `--users` : Utilisateur avec mot de passe (format user:password)
- `--is-public` : Rend l'instance accessible publiquement

### Étape 3.3 : Vérifier l'instance créée (3 min)

```bash
# Lister les instances Trove
openstack database instance list

# Détails de l'instance
openstack database instance show mysql-instance-01

# Obtenir l'adresse IP
INSTANCE_IP=$(openstack database instance show mysql-instance-01 \
  -c ip -f value | tr -d '[]" ')
echo "Instance IP: $INSTANCE_IP"

# Vérifier le statut
openstack database instance show mysql-instance-01 -c status -f value
```

**Attendu** : Le statut doit être `ACTIVE`

### Étape 3.4 : Tester la connexion à la base de données (5 min)

```bash
# Installer le client MySQL si nécessaire
sudo apt-get update && sudo apt-get install -y mysql-client

# Se connecter à la base de données
mysql -h $INSTANCE_IP -u testuser -ppassword123 testdb

# Une fois connecté, tester quelques commandes SQL
```

**Dans le shell MySQL** :
```sql
-- Créer une table
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100)
);

-- Insérer des données
INSERT INTO users (name, email) VALUES 
    ('Alice', 'alice@example.com'),
    ('Bob', 'bob@example.com');

-- Interroger les données
SELECT * FROM users;

-- Quitter
EXIT;
```

**✅ Checkpoint** : Vous pouvez vous connecter et utiliser votre base de données MySQL

---

## Module 4 : Gestion et opérations (10 min)

### Étape 4.1 : Gérer les bases de données (3 min)

```bash
# Lister les bases de données de l'instance
openstack database db list mysql-instance-01

# Créer une nouvelle base de données
openstack database db create mysql-instance-01 appdb

# Supprimer une base de données
# openstack database db delete mysql-instance-01 appdb

# Vérifier
openstack database db list mysql-instance-01
```

### Étape 4.2 : Gérer les utilisateurs (3 min)

```bash
# Lister les utilisateurs
openstack database user list mysql-instance-01

# Créer un nouveau utilisateur
openstack database user create \
  mysql-instance-01 \
  appuser \
  password456 \
  --databases appdb

# Voir les accès d'un utilisateur
openstack database user show mysql-instance-01 appuser

# Accorder l'accès à une autre base
openstack database user grant access \
  mysql-instance-01 \
  appuser \
  testdb

# Révoquer un accès
# openstack database user revoke access \
#   mysql-instance-01 \
#   appuser \
#   testdb

# Vérifier
openstack database user show mysql-instance-01 appuser --databases
```

### Étape 4.3 : Redimensionner l'instance (2 min)

```bash
# Voir les flavors disponibles
openstack flavor list

# Redimensionner l'instance (changer la flavor)
openstack database instance resize instance \
  mysql-instance-01 \
  m1.medium

# Suivre la progression
watch -n 5 "openstack database instance show mysql-instance-01 -c status"
# Appuyez sur Ctrl+C quand terminé

# Redimensionner le volume (augmenter le stockage)
openstack database instance resize volume \
  mysql-instance-01 \
  10

# Vérifier
openstack database instance show mysql-instance-01 -c flavor -c volume
```

**⚠️ Note** : Le redimensionnement peut prendre plusieurs minutes

### Étape 4.4 : Redémarrer l'instance (2 min)

```bash
# Redémarrer l'instance
openstack database instance restart mysql-instance-01

# Suivre le statut
openstack database instance show mysql-instance-01 -c status

# Attendre que le statut redevienne ACTIVE
```

**✅ Checkpoint** : Vous savez gérer les bases, utilisateurs et dimensionner les instances

---

## Module 5 : Sauvegarde et restauration (10 min)

### 📖 Contexte

Trove offre des capacités de **backup** et **restore** intégrées pour protéger vos données.

### Étape 5.1 : Créer une sauvegarde (3 min)

```bash
# Ajouter des données avant la sauvegarde
mysql -h $INSTANCE_IP -u testuser -ppassword123 testdb << EOF
INSERT INTO users (name, email) VALUES 
    ('Charlie', 'charlie@example.com'),
    ('Diana', 'diana@example.com');
SELECT COUNT(*) as total FROM users;
EOF

# Créer un backup
openstack database backup create \
  mysql-instance-01 \
  backup-before-maintenance \
  --description "Backup avant maintenance"

# Suivre la création du backup
watch -n 5 "openstack database backup list"
# Appuyez sur Ctrl+C quand le statut est COMPLETED
```

### Étape 5.2 : Lister et examiner les backups (2 min)

```bash
# Lister tous les backups
openstack database backup list

# Détails du backup
BACKUP_ID=$(openstack database backup list -c ID -f value | head -n 1)
openstack database backup show $BACKUP_ID

# Voir la taille du backup
openstack database backup show $BACKUP_ID -c size
```

### Étape 5.3 : Restaurer depuis un backup (5 min)

```bash
# Créer une nouvelle instance depuis le backup
openstack database instance create \
  mysql-restored-instance \
  --flavor m1.small \
  --size 5 \
  --nic net-id=$PRIVATE_NET_ID \
  --datastore mysql \
  --datastore-version 5.7 \
  --backup $BACKUP_ID \
  --is-public

# Suivre la création
watch -n 5 "openstack database instance list"
# Appuyez sur Ctrl+C quand le statut est ACTIVE

# Obtenir l'IP de la nouvelle instance
RESTORED_IP=$(openstack database instance show mysql-restored-instance \
  -c ip -f value | tr -d '[]" ')
echo "Restored Instance IP: $RESTORED_IP"

# Vérifier les données restaurées
mysql -h $RESTORED_IP -u testuser -ppassword123 testdb << EOF
SELECT * FROM users;
SELECT COUNT(*) as total FROM users;
EOF
```

**Attendu** : Les 4 utilisateurs (Alice, Bob, Charlie, Diana) doivent être présents

**✅ Checkpoint** : Vous savez sauvegarder et restaurer une base de données

---

## 🎓 Récapitulatif de l'atelier

### Ce que vous avez appris :

✅ Installer et configurer Trove sur DevStack  
✅ Comprendre l'architecture des datastores  
✅ Créer et configurer des instances de bases de données  
✅ Gérer les bases de données et utilisateurs  
✅ Redimensionner les instances (compute et storage)  
✅ Effectuer des sauvegardes et restaurations  

### Architecture Trove déployée :

```
┌─────────────────────────────────────────┐
│         OpenStack Control Plane         │
│  ┌──────────┐  ┌──────────┐            │
│  │  Trove   │  │  Trove   │            │
│  │   API    │──│TaskManager│           │
│  └──────────┘  └──────────┘            │
│       │              │                  │
└───────┼──────────────┼──────────────────┘
        │              │
        ▼              ▼
┌─────────────────────────────────────────┐
│      Instances de bases de données      │
│  ┌──────────────┐  ┌──────────────┐    │
│  │   MySQL      │  │   MySQL      │    │
│  │ Instance-01  │  │  Restored    │    │
│  │ + Trove      │  │ + Trove      │    │
│  │   Agent      │  │   Agent      │    │
│  └──────────────┘  └──────────────┘    │
│         │                  │            │
│         ▼                  ▼            │
│  [Volume 5GB]      [Volume 5GB]        │
└─────────────────────────────────────────┘
```

---

## 📊 Commandes de référence rapide

### Gestion des instances
```bash
# Créer
openstack database instance create <name> --flavor <flavor> --size <GB>

# Lister
openstack database instance list

# Détails
openstack database instance show <instance>

# Supprimer
openstack database instance delete <instance>
```

### Gestion des bases de données
```bash
# Lister
openstack database db list <instance>

# Créer
openstack database db create <instance> <database>

# Supprimer
openstack database db delete <instance> <database>
```

### Gestion des utilisateurs
```bash
# Lister
openstack database user list <instance>

# Créer
openstack database user create <instance> <user> <password>

# Donner accès
openstack database user grant access <instance> <user> <database>
```

### Sauvegardes
```bash
# Créer
openstack database backup create <instance> <backup-name>

# Lister
openstack database backup list

# Restaurer
openstack database instance create <name> --backup <backup-id>
```

---

## 🧹 Nettoyage de l'environnement

À la fin de l'atelier :

```bash
# Supprimer les instances
openstack database instance delete mysql-instance-01
openstack database instance delete mysql-restored-instance

# Attendre que les instances soient supprimées
watch -n 5 "openstack database instance list"

# Supprimer les backups
openstack database backup list
openstack database backup delete <backup-id>

# Supprimer le groupe de sécurité
openstack security group delete trove-access

# Supprimer l'image
openstack image delete trove-mysql-5.7
```

---

## 🚀 Pour aller plus loin

### Fonctionnalités avancées à explorer :

1. **Réplication** : Configurer des réplicas pour la haute disponibilité
   ```bash
   openstack database instance create replica-01 \
     --flavor m1.small \
     --size 5 \
     --replica-of mysql-instance-01
   ```

2. **Clusters** : Déployer des clusters de bases de données
   ```bash
   openstack database cluster create mongodb-cluster \
     --datastore mongodb \
     --datastore-version 3.6 \
     --instance flavor=m1.small,volume=5
   ```

3. **Configuration groups** : Personnaliser les paramètres de configuration
   ```bash
   openstack database configuration create mysql-config \
     --datastore mysql \
     --datastore-version 5.7 \
     --values '{"max_connections": 200}'
   ```

4. **Autres datastores** : PostgreSQL, MongoDB, Redis, Cassandra, etc.

### Documentation officielle :
- Trove Documentation : https://docs.openstack.org/trove/latest/
- Trove Admin Guide : https://docs.openstack.org/trove/latest/admin/
- Building Trove Images : https://docs.openstack.org/trove/latest/admin/building_guest_images.html

---

## ❓ FAQ et dépannage

### Q: L'instance reste en statut BUILD
**R:** Vérifiez les logs Trove :
```bash
sudo journalctl -u devstack@tr-tmgr -f
tail -f ~/devstack/logs/trove-*.log
```

### Q: Impossible de se connecter à la base de données
**R:** Vérifiez :
- Le groupe de sécurité autorise le port 3306
- L'IP de l'instance est correcte
- L'instance est en statut ACTIVE

### Q: Le backup échoue
**R:** Vérifiez que Swift est configuré (Trove utilise Swift pour stocker les backups)

### Q: Comment voir l'instance Nova sous-jacente ?
**R:** 
```bash
openstack server list --all-projects | grep mysql-instance
```

---

**Félicitations ! 🎉**  
Vous avez terminé l'atelier Trove et maîtrisez maintenant les bases du Database as a Service sur OpenStack !

**Durée totale** : ~60 minutes  
**Niveau atteint** : ✅ Opérationnel sur Trove
