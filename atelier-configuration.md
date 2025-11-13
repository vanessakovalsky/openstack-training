# Atelier OpenStack : Configuration de la base de données, du service de messagerie et Keystone

**Durée :** 1 heure  
**Niveau :** Intermédiaire  
**Prérequis :** Connaissances Linux de base, notions de cloud computing  
**Environnement :** Ubuntu 22.04 avec DevStack pré-installé

> ⚠️ **Note importante :** Cet atelier utilise DevStack. Les services (MariaDB, RabbitMQ, Keystone) sont déjà installés. Nous nous concentrerons sur la **compréhension**, la **vérification** et la **configuration avancée** plutôt que l'installation from scratch.

---

## Objectifs pédagogiques

À l'issue de cet atelier, les participants seront capables de :
- Configurer une base de données MariaDB pour OpenStack
- Installer et configurer RabbitMQ comme service de messagerie
- Déployer et configurer Keystone (service d'identité)
- Créer et gérer des utilisateurs, groupes, rôles et projets
- Comprendre le modèle RBAC (Role-Based Access Control) d'OpenStack

---

## Partie 1 : Configuration de la base de données (15 min)

### 1.1 Installation de MariaDB

```bash
# Installation
apt update
apt install mariadb-server python3-pymysql -y

# Sécurisation de l'installation
mysql_secure_installation
```

### 1.2 Configuration pour OpenStack

Créer le fichier `/etc/mysql/mariadb.conf.d/99-openstack.cnf` :

```ini
[mysqld]
bind-address = 10.0.0.11
default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
```

```bash
# Redémarrage du service
systemctl restart mysql
```

### 1.3 Création de la base Keystone

```sql
mysql -u root -p

CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' \
  IDENTIFIED BY 'KEYSTONE_DBPASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' \
  IDENTIFIED BY 'KEYSTONE_DBPASS';
FLUSH PRIVILEGES;
EXIT;
```

**💡 Point de vigilance :** Remplacer `KEYSTONE_DBPASS` par un mot de passe fort en production.

---

## Partie 2 : Configuration du service de messagerie (10 min)

### 2.1 Installation de RabbitMQ

```bash
apt install rabbitmq-server -y
systemctl enable rabbitmq-server
systemctl start rabbitmq-server
```

### 2.2 Configuration de l'utilisateur OpenStack

```bash
# Création de l'utilisateur
rabbitmqctl add_user openstack RABBIT_PASS

# Attribution des permissions
rabbitmqctl set_permissions openstack ".*" ".*" ".*"

# Vérification
rabbitmqctl list_users
```

### 2.3 Vérification du service

```bash
# Statut du service
systemctl status rabbitmq-server

# Ports d'écoute
netstat -tulpn | grep 5672
```

**📌 Info :** RabbitMQ utilise le port 5672 pour AMQP et 15672 pour l'interface web de gestion.

---

## Partie 3 : Installation et configuration de Keystone (15 min)

### 3.1 Installation des paquets

```bash
apt install keystone apache2 libapache2-mod-wsgi-py3 -y
```

### 3.2 Configuration de Keystone

Éditer `/etc/keystone/keystone.conf` :

```ini
[database]
connection = mysql+pymysql://keystone:KEYSTONE_DBPASS@controller/keystone

[token]
provider = fernet
```

### 3.3 Population de la base de données

```bash
# Synchronisation de la base
su -s /bin/sh -c "keystone-manage db_sync" keystone

# Initialisation des dépôts de clés Fernet
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
```

### 3.4 Bootstrap du service

```bash
keystone-manage bootstrap --bootstrap-password ADMIN_PASS \
  --bootstrap-admin-url http://controller:5000/v3/ \
  --bootstrap-internal-url http://controller:5000/v3/ \
  --bootstrap-public-url http://controller:5000/v3/ \
  --bootstrap-region-id RegionOne
```

### 3.5 Configuration d'Apache

```bash
echo "ServerName controller" >> /etc/apache2/apache2.conf
systemctl restart apache2
```

---

## Partie 4 : Gestion des utilisateurs, groupes et rôles (20 min)

### 4.1 Configuration des variables d'environnement

Créer le fichier `admin-openrc` :

```bash
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=ADMIN_PASS
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
```

```bash
source admin-openrc
```

### 4.2 Création d'un domaine

```bash
# Création d'un domaine personnalisé
openstack domain create --description "Domaine Entreprise" entreprise

# Liste des domaines
openstack domain list
```

### 4.3 Création d'un projet

```bash
# Projet de service
openstack project create --domain default \
  --description "Service Project" service

# Projet métier
openstack project create --domain entreprise \
  --description "Projet Développement" dev-team
```

### 4.4 Création de rôles

```bash
# Rôles par défaut
openstack role list

# Création d'un rôle personnalisé
openstack role create developer
openstack role create team_lead
```

### 4.5 Création d'utilisateurs

```bash
# Utilisateur de service (ex: pour Nova)
openstack user create --domain default \
  --password SERVICE_PASS nova

# Utilisateur métier
openstack user create --domain entreprise \
  --password USER_PASS \
  --email john.doe@entreprise.com \
  john.doe
```

### 4.6 Attribution des rôles

```bash
# Rôle admin pour l'utilisateur de service
openstack role add --project service --user nova admin

# Rôle developer pour l'utilisateur métier
openstack role add --project dev-team --user john.doe developer

# Vérification
openstack role assignment list --user john.doe --project dev-team --names
```

### 4.7 Création de groupes

```bash
# Création d'un groupe
openstack group create --domain entreprise \
  --description "Équipe de développement" dev-group

# Ajout d'utilisateurs au groupe
openstack group add user dev-group john.doe

# Attribution de rôle au groupe
openstack role add --project dev-team --group dev-group developer

# Liste des membres
openstack group list --user john.doe
```

---

## Exercice pratique (dernières minutes)

### Scénario

Créez la structure suivante :
1. Un domaine "Production"
2. Deux projets : "WebApp" et "Database"
3. Trois utilisateurs : "alice" (admin), "bob" (developer), "charlie" (viewer)
4. Un groupe "ops-team" contenant bob et charlie
5. Assignez les rôles appropriés

### Solution


<details>
  <summary>Afficher la solution</summary>
  
  ```bash
  # 1. Domaine
  openstack domain create --description "Environnement Production" production
  
  # 2. Projets
  openstack project create --domain production --description "Application Web" webapp
  openstack project create --domain production --description "Base de données" database
  
  # 3. Utilisateurs
  openstack user create --domain production --password AlicePass alice
  openstack user create --domain production --password BobPass bob
  openstack user create --domain production --password CharliePass charlie
  
  # 4. Groupe
  openstack group create --domain production --description "Équipe Ops" ops-team
  openstack group add user ops-team bob
  openstack group add user ops-team charlie
  
  # 5. Rôles
  openstack role add --project webapp --user alice admin
  openstack role add --project database --user alice admin
  openstack role add --project webapp --group ops-team developer
  openstack role create viewer
  openstack role add --project database --user charlie viewer
  ```

  
</details>

---

## Points clés à retenir

✅ **Base de données** : MariaDB centralise les métadonnées de tous les services OpenStack  
✅ **RabbitMQ** : Assure la communication asynchrone entre les composants  
✅ **Keystone** : Point d'entrée unique pour l'authentification et l'autorisation  
✅ **Hiérarchie** : Domaine → Projet → Utilisateur/Groupe → Rôle  
✅ **RBAC** : Le contrôle d'accès se fait par l'assignation de rôles sur des projets

---

## Ressources complémentaires

- [Documentation officielle Keystone](https://docs.openstack.org/keystone/)
- [Guide d'installation OpenStack](https://docs.openstack.org/install-guide/)
- [Best practices de sécurité](https://docs.openstack.org/security-guide/)

---

## Questions de validation

1. Quel est le rôle de Fernet dans Keystone ?
2. Quelle est la différence entre un domaine et un projet ?
3. Comment vérifier les rôles d'un utilisateur sur un projet ?
4. Pourquoi utilise-t-on RabbitMQ plutôt que des appels API directs ?
5. Comment révoquer un rôle à un utilisateur ?
