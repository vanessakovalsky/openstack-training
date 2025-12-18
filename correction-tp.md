# Solution TP OpenStack - Infrastructure Web Multi-Tiers

## 📑 Table des matières
1. [Mission 1 : Organisation projet et identités (Keystone)](#mission-1--keystone)
2. [Mission 2 : Préparation des images (Glance)](#mission-2--glance)
3. [Mission 3 : Infrastructure réseau (Neutron)](#mission-3--neutron)
4. [Mission 4 : Stockage bloc (Cinder)](#mission-4--cinder)
5. [Mission 5 : Déploiement des instances (Nova)](#mission-5--nova)
6. [Mission 6 : Validation et sauvegarde](#mission-6--validation)
7. [Tests de connectivité](#tests-de-connectivité)

---

## Mission 1 : Keystone

### Étape 1.1 : Créer le projet webapp-prod

```bash
# Créer le projet
openstack project create \
  --description "Projet pour l'application web de production" \
  --domain default \
  webapp-prod

# Vérifier la création
openstack project list | grep webapp-prod
```

**Résultat attendu** : Un ID de projet est généré

### Étape 1.2 : Créer les utilisateurs

```bash
# Créer l'utilisateur développeur
openstack user create \
  --domain default \
  --password-prompt \
  dev-user

# Créer l'utilisateur administrateur
openstack user create \
  --domain default \
  --password-prompt \
  admin-user

# Vérifier
openstack user list
```

**Note** : Utilisez des mots de passe forts et conservez-les de manière sécurisée

### Étape 1.3 : Attribuer les rôles

```bash
# Attribuer le rôle member au développeur
openstack role add \
  --project webapp-prod \
  --user dev-user \
  member

# Attribuer le rôle admin à l'administrateur projet
openstack role add \
  --project webapp-prod \
  --user admin-user \
  admin

# Vérifier les assignations
openstack role assignment list \
  --project webapp-prod \
  --names
```

### Étape 1.4 : Vérifier les permissions

```bash
# Se connecter en tant que dev-user pour tester
# Créer un fichier RC pour le projet
cat > webapp-prod-rc.sh << EOF
export OS_PROJECT_NAME=webapp-prod
export OS_USERNAME=dev-user
export OS_PASSWORD=VotreMotDePasse
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_DOMAIN_NAME=default
EOF

# Source le fichier
source webapp-prod-rc.sh

# Vérifier l'accès
openstack token issue
```

---

## Mission 2 : Glance

### Étape 2.1 : Télécharger l'image Ubuntu 22.04

```bash
# Télécharger l'image officielle
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
```

### Étape 2.2 : Uploader l'image dans Glance

```bash
# Créer l'image dans Glance
openstack image create \
  --file jammy-server-cloudimg-amd64.img \
  --disk-format qcow2 \
  --container-format bare \
  --min-disk 10 \
  --min-ram 512 \
  --property os_type=linux \
  --property os_distro=ubuntu \
  --property os_version=22.04 \
  --public \
  "Ubuntu 22.04 LTS"
```

**Paramètres expliqués** :
- `--disk-format qcow2` : Format de l'image
- `--min-disk 10` : Espace disque minimum requis (10 GB)
- `--min-ram 512` : RAM minimum requise (512 MB)
- `--public` : Image accessible à tous les projets

### Étape 2.3 : Vérifier l'image

```bash
# Lister les images
openstack image list

# Détails de l'image
openstack image show "Ubuntu 22.04 LTS"

# Vérifier le statut (doit être "active")
openstack image show "Ubuntu 22.04 LTS" -c status -c size
```

### Étape 2.4 : Rendre l'image accessible au projet (si non publique)

```bash
# Si l'image n'est pas publique, partager avec le projet
openstack image add project \
  "Ubuntu 22.04 LTS" \
  webapp-prod

# Accepter le partage (depuis le compte du projet)
openstack image set \
  --accept \
  "Ubuntu 22.04 LTS"
```

---

## Mission 3 : Neutron

### Étape 3.1 : Créer le réseau privé

```bash
# Créer le réseau
openstack network create \
  --project webapp-prod \
  webapp-network

# Récupérer l'ID du réseau
NETWORK_ID=$(openstack network show webapp-network -c id -f value)
echo "Network ID: $NETWORK_ID"
```

### Étape 3.2 : Créer le sous-réseau

```bash
# Créer le sous-réseau avec DHCP
openstack subnet create \
  --network webapp-network \
  --subnet-range 10.0.1.0/24 \
  --gateway 10.0.1.1 \
  --dns-nameserver 8.8.8.8 \
  --dns-nameserver 8.8.4.4 \
  --allocation-pool start=10.0.1.10,end=10.0.1.250 \
  --dhcp \
  webapp-subnet

# Vérifier
openstack subnet show webapp-subnet
```

**Paramètres expliqués** :
- `--subnet-range` : Plage d'adresses IP
- `--gateway` : Passerelle par défaut
- `--allocation-pool` : Plage d'IPs distribuées par DHCP
- `--dhcp` : Active le serveur DHCP

### Étape 3.3 : Créer le routeur

```bash
# Identifier le réseau externe (peut varier selon l'installation)
EXT_NET=$(openstack network list --external -c ID -f value)

# Créer le routeur
openstack router create webapp-router

# Définir la gateway externe
openstack router set \
  --external-gateway $EXT_NET \
  webapp-router

# Connecter le sous-réseau privé au routeur
openstack router add subnet \
  webapp-router \
  webapp-subnet

# Vérifier la configuration
openstack router show webapp-router
openstack port list --router webapp-router
```

### Étape 3.4 : Créer les groupes de sécurité

```bash
# Groupe de sécurité pour le Frontend (Web)
openstack security group create \
  --description "Règles pour serveur web frontend" \
  sg-web

# Règles pour sg-web
openstack security group rule create \
  --protocol tcp \
  --dst-port 22 \
  --remote-ip 0.0.0.0/0 \
  sg-web

openstack security group rule create \
  --protocol tcp \
  --dst-port 80 \
  --remote-ip 0.0.0.0/0 \
  sg-web

openstack security group rule create \
  --protocol tcp \
  --dst-port 443 \
  --remote-ip 0.0.0.0/0 \
  sg-web

openstack security group rule create \
  --protocol icmp \
  sg-web

# Groupe de sécurité pour le Backend (Application)
openstack security group create \
  --description "Règles pour serveur applicatif" \
  sg-app

# Règles pour sg-app (accessible uniquement depuis le réseau privé)
openstack security group rule create \
  --protocol tcp \
  --dst-port 22 \
  --remote-ip 10.0.1.0/24 \
  sg-app

openstack security group rule create \
  --protocol tcp \
  --dst-port 8080 \
  --remote-ip 10.0.1.0/24 \
  sg-app

openstack security group rule create \
  --protocol icmp \
  --remote-ip 10.0.1.0/24 \
  sg-app

# Groupe de sécurité pour la Database
openstack security group create \
  --description "Règles pour serveur de base de données" \
  sg-database

# Règles pour sg-database (accessible uniquement depuis le backend)
openstack security group rule create \
  --protocol tcp \
  --dst-port 22 \
  --remote-ip 10.0.1.0/24 \
  sg-database

openstack security group rule create \
  --protocol tcp \
  --dst-port 3306 \
  --remote-ip 10.0.1.0/24 \
  sg-database

openstack security group rule create \
  --protocol icmp \
  --remote-ip 10.0.1.0/24 \
  sg-database

# Lister les groupes de sécurité
openstack security group list
```

### Étape 3.5 : Allouer les IP flottantes

```bash
# Créer les IP flottantes
openstack floating ip create \
  --description "IP pour frontend" \
  $EXT_NET

openstack floating ip create \
  --description "IP pour backend (admin)" \
  $EXT_NET

# Lister les IPs flottantes disponibles
openstack floating ip list

# Sauvegarder les IPs pour plus tard
FIP_FRONTEND=$(openstack floating ip list -c "Floating IP Address" -f value | head -n 1)
FIP_BACKEND=$(openstack floating ip list -c "Floating IP Address" -f value | tail -n 1)

echo "Frontend IP: $FIP_FRONTEND"
echo "Backend IP: $FIP_BACKEND"
```

---

## Mission 4 : Cinder

### Étape 4.1 : Créer le volume pour la base de données

```bash
# Créer le volume de 50 GB
openstack volume create \
  --size 50 \
  --description "Volume pour données MySQL" \
  --type __DEFAULT__ \
  volume-database

# Vérifier le statut (doit être "available")
openstack volume show volume-database
```

### Étape 4.2 : Créer le volume pour le frontend

```bash
# Créer le volume de 20 GB
openstack volume create \
  --size 20 \
  --description "Volume pour fichiers statiques web" \
  --type __DEFAULT__ \
  volume-web

# Vérifier
openstack volume show volume-web
```

### Étape 4.3 : Lister tous les volumes

```bash
# Lister les volumes du projet
openstack volume list

# Vérifier les détails
openstack volume list --long
```

**Note** : Les volumes sont créés avec l'attribut `bootable=false` et `status=available`. Ils seront attachés après la création des instances.

---

## Mission 5 : Nova

### Étape 5.1 : Créer la paire de clés SSH

```bash
# Générer une nouvelle paire de clés
ssh-keygen -t rsa -b 4096 -f ~/.ssh/webapp-key -N ""

# Importer la clé publique dans Nova
openstack keypair create \
  --public-key ~/.ssh/webapp-key.pub \
  webapp-keypair

# Vérifier
openstack keypair list
openstack keypair show webapp-keypair
```

### Étape 5.2 : Identifier les flavors appropriées

```bash
# Lister les flavors disponibles
openstack flavor list

# Pour les besoins du TP :
# Frontend/Backend : m1.medium (2 vCPU, 4GB RAM)
# Database : m1.large (4 vCPU, 8GB RAM)

# Si les flavors n'existent pas, les créer (nécessite privilèges admin)
openstack flavor create \
  --ram 4096 \
  --disk 20 \
  --vcpus 2 \
  m1.medium

openstack flavor create \
  --ram 8192 \
  --disk 40 \
  --vcpus 4 \
  m1.large
```

### Étape 5.3 : Récupérer les IDs nécessaires

```bash
# ID de l'image
IMAGE_ID=$(openstack image show "Ubuntu 22.04 LTS" -c id -f value)

# ID du réseau
NETWORK_ID=$(openstack network show webapp-network -c id -f value)

# IDs des security groups
SG_WEB_ID=$(openstack security group show sg-web -c id -f value)
SG_APP_ID=$(openstack security group show sg-app -c id -f value)
SG_DB_ID=$(openstack security group show sg-database -c id -f value)

echo "Image: $IMAGE_ID"
echo "Network: $NETWORK_ID"
echo "SG Web: $SG_WEB_ID"
echo "SG App: $SG_APP_ID"
echo "SG DB: $SG_DB_ID"
```

### Étape 5.4 : Lancer l'instance Frontend

```bash
openstack server create \
  --flavor m1.medium \
  --image "$IMAGE_ID" \
  --network "$NETWORK_ID" \
  --security-group sg-web \
  --key-name webapp-keypair \
  --wait \
  instance-frontend

# Vérifier le statut
openstack server show instance-frontend
openstack server list
```

### Étape 5.5 : Lancer l'instance Backend

```bash
openstack server create \
  --flavor m1.medium \
  --image "$IMAGE_ID" \
  --network "$NETWORK_ID" \
  --security-group sg-app \
  --key-name webapp-keypair \
  --wait \
  instance-backend

# Vérifier
openstack server show instance-backend
```

### Étape 5.6 : Lancer l'instance Database

```bash
openstack server create \
  --flavor m1.large \
  --image "$IMAGE_ID" \
  --network "$NETWORK_ID" \
  --security-group sg-database \
  --key-name webapp-keypair \
  --wait \
  instance-database

# Vérifier
openstack server show instance-database
```

### Étape 5.7 : Attacher les volumes

```bash
# Attendre que les instances soient ACTIVE
openstack server list

# Attacher le volume web au frontend
openstack server add volume \
  instance-frontend \
  volume-web

# Attacher le volume database à l'instance database
openstack server add volume \
  instance-database \
  volume-database

# Vérifier les attachements
openstack volume list
openstack server show instance-frontend -c volumes_attached
openstack server show instance-database -c volumes_attached
```

### Étape 5.8 : Assigner les IP flottantes

```bash
# Assigner l'IP flottante au frontend
openstack server add floating ip \
  instance-frontend \
  $FIP_FRONTEND

# Assigner l'IP flottante au backend (pour administration)
openstack server add floating ip \
  instance-backend \
  $FIP_BACKEND

# Vérifier les assignations
openstack server list
openstack floating ip list
```

### Étape 5.9 : Récupérer les informations de connexion

```bash
# Afficher toutes les instances avec leurs IPs
openstack server list --long

# Détails complets
echo "=== Frontend ==="
openstack server show instance-frontend -c name -c status -c addresses -c flavor

echo "=== Backend ==="
openstack server show instance-backend -c name -c status -c addresses -c flavor

echo "=== Database ==="
openstack server show instance-database -c name -c status -c addresses -c flavor
```

---

## Mission 6 : Validation

### Étape 6.1 : Créer un snapshot du frontend

```bash
# Arrêter l'instance (recommandé pour un snapshot cohérent)
openstack server stop instance-frontend

# Attendre que l'instance soit stoppée
openstack server show instance-frontend -c status

# Créer le snapshot
openstack server image create \
  --name "frontend-configured-snapshot" \
  --wait \
  instance-frontend

# Redémarrer l'instance
openstack server start instance-frontend

# Vérifier le snapshot dans Glance
openstack image list | grep frontend
openstack image show frontend-configured-snapshot
```

### Étape 6.2 : Vérifier tous les composants

```bash
# Script de vérification complète
cat > verify_deployment.sh << 'EOF'
#!/bin/bash

echo "========================================="
echo "VÉRIFICATION DE L'INFRASTRUCTURE OPENSTACK"
echo "========================================="

echo ""
echo "=== PROJET (Keystone) ==="
openstack project show webapp-prod -c name -c id -c enabled

echo ""
echo "=== UTILISATEURS ==="
openstack user list | grep -E "dev-user|admin-user"

echo ""
echo "=== RÉSEAU (Neutron) ==="
openstack network show webapp-network -c name -c status -c subnets
openstack subnet show webapp-subnet -c name -c cidr -c gateway_ip
openstack router show webapp-router -c name -c status -c external_gateway_info

echo ""
echo "=== GROUPES DE SÉCURITÉ ==="
openstack security group list | grep sg-

echo ""
echo "=== IP FLOTTANTES ==="
openstack floating ip list

echo ""
echo "=== IMAGES (Glance) ==="
openstack image list | grep -E "Ubuntu|frontend"

echo ""
echo "=== VOLUMES (Cinder) ==="
openstack volume list

echo ""
echo "=== INSTANCES (Nova) ==="
openstack server list --long

echo ""
echo "=== ATTACHEMENTS VOLUMES ==="
openstack volume list -c Name -c Status -c "Attached to"

echo ""
echo "========================================="
echo "VÉRIFICATION TERMINÉE"
echo "========================================="
EOF

chmod +x verify_deployment.sh
./verify_deployment.sh
```

---

## Tests de connectivité

### Test 1 : Connexion SSH au frontend

```bash
# Depuis votre machine locale
ssh -i ~/.ssh/webapp-key ubuntu@$FIP_FRONTEND

# Une fois connecté, vérifier le volume attaché
lsblk
sudo fdisk -l

# Vérifier la connectivité réseau
ip addr show
ping -c 3 8.8.8.8
```

### Test 2 : Connectivité entre instances

```bash
# Depuis le frontend, tester la connexion au backend
ssh ubuntu@$FIP_FRONTEND

# Récupérer l'IP privée du backend
BACKEND_IP=$(openstack server show instance-backend -c addresses -f value | cut -d'=' -f2 | cut -d',' -f1)

# Ping vers le backend
ping -c 3 $BACKEND_IP

# Ping vers la database
DATABASE_IP=$(openstack server show instance-database -c addresses -f value | cut -d'=' -f2 | cut -d',' -f1)
ping -c 3 $DATABASE_IP
```

### Test 3 : Vérifier les volumes

```bash
# Se connecter au frontend
ssh -i ~/.ssh/webapp-key ubuntu@$FIP_FRONTEND

# Lister les disques
lsblk

# Formater et monter le volume (exemple)
sudo mkfs.ext4 /dev/vdb
sudo mkdir /mnt/web-data
sudo mount /dev/vdb /mnt/web-data
df -h

# Se connecter à la database
ssh -i ~/.ssh/webapp-key ubuntu@$FIP_BACKEND  # via IP flottante backend
ssh ubuntu@$DATABASE_IP  # depuis le frontend ou backend

# Vérifier le volume de 50GB
lsblk
sudo mkfs.ext4 /dev/vdb
sudo mkdir /mnt/mysql-data
sudo mount /dev/vdb /mnt/mysql-data
df -h
```

### Test 4 : Vérifier les règles de sécurité

```bash
# Depuis le frontend, tester l'accès au port MySQL du database
BACKEND_IP=10.0.1.11  # IP du backend
DATABASE_IP=10.0.1.12  # IP du database

# Depuis le frontend vers le backend (doit fonctionner)
nc -zv $BACKEND_IP 8080

# Depuis le backend vers le database (doit fonctionner)
nc -zv $DATABASE_IP 3306

# Depuis l'extérieur vers le database (doit échouer - pas d'IP flottante)
# Ce test confirme l'isolation
```

---

## Résumé des ressources créées

### Keystone
- ✅ Projet : `webapp-prod`
- ✅ Utilisateur : `dev-user` (role: member)
- ✅ Utilisateur : `admin-user` (role: admin)

### Neutron
- ✅ Réseau : `webapp-network`
- ✅ Sous-réseau : `webapp-subnet` (10.0.1.0/24)
- ✅ Routeur : `webapp-router`
- ✅ Groupe de sécurité : `sg-web` (22, 80, 443)
- ✅ Groupe de sécurité : `sg-app` (22, 8080)
- ✅ Groupe de sécurité : `sg-database` (22, 3306)
- ✅ IP flottante : Frontend
- ✅ IP flottante : Backend

### Glance
- ✅ Image : `Ubuntu 22.04 LTS`
- ✅ Snapshot : `frontend-configured-snapshot`

### Cinder
- ✅ Volume : `volume-web` (20 GB) → attaché à instance-frontend
- ✅ Volume : `volume-database` (50 GB) → attaché à instance-database

### Nova
- ✅ Keypair : `webapp-keypair`
- ✅ Instance : `instance-frontend` (m1.medium, IP flottante)
- ✅ Instance : `instance-backend` (m1.medium, IP flottante)
- ✅ Instance : `instance-database` (m1.large, pas d'IP flottante)

---

## Commandes utiles pour le nettoyage

Si vous devez supprimer l'infrastructure :

```bash
# Détacher et supprimer les IP flottantes
openstack server remove floating ip instance-frontend $FIP_FRONTEND
openstack server remove floating ip instance-backend $FIP_BACKEND
openstack floating ip delete $FIP_FRONTEND
openstack floating ip delete $FIP_BACKEND

# Détacher les volumes
openstack server remove volume instance-frontend volume-web
openstack server remove volume instance-database volume-database

# Supprimer les instances
openstack server delete instance-frontend instance-backend instance-database

# Attendre que les instances soient supprimées
sleep 30

# Supprimer les volumes
openstack volume delete volume-web volume-database

# Supprimer les snapshots/images
openstack image delete frontend-configured-snapshot

# Déconnecter le routeur
openstack router remove subnet webapp-router webapp-subnet
openstack router unset --external-gateway webapp-router
openstack router delete webapp-router

# Supprimer le réseau
openstack network delete webapp-network

# Supprimer les groupes de sécurité
openstack security group delete sg-web sg-app sg-database

# Supprimer les utilisateurs et le projet
openstack user delete dev-user admin-user
openstack project delete webapp-prod
```

---

## Points d'attention et erreurs courantes

### ❌ Erreur : "No valid host was found"
**Cause** : Pas assez de ressources disponibles ou mauvaise configuration du scheduler
**Solution** : Vérifier les quotas et la disponibilité des compute nodes

### ❌ Erreur : Volume attachment failed
**Cause** : Le volume et l'instance ne sont pas dans le même availability zone
**Solution** : Créer le volume dans la même AZ que l'instance

### ❌ Erreur : Cannot attach floating IP
**Cause** : Le routeur n'a pas de gateway externe configurée
**Solution** : Vérifier `openstack router show webapp-router`

### ❌ Erreur : SSH timeout
**Cause** : Groupe de sécurité ne permet pas SSH ou l'instance n'a pas démarré
**Solution** : Vérifier les règles de sécurité et le statut de l'instance

### ⚠️ Bonne pratique : Toujours vérifier le statut
```bash
# Attendre qu'une ressource soit prête avant de continuer
openstack server show instance-frontend -c status -f value
# Doit retourner "ACTIVE" avant d'attacher des volumes ou IPs
```

---

## Pour aller plus loin

### Automatisation avec Heat

Voici un template Heat basique pour déployer l'infrastructure :

```yaml
heat_template_version: 2021-04-16

description: Infrastructure Web Multi-Tiers

parameters:
  key_name:
    type: string
    description: Nom de la keypair SSH
    default: webapp-keypair

resources:
  webapp_network:
    type: OS::Neutron::Net
    properties:
      name: webapp-network

  webapp_subnet:
    type: OS::Neutron::Subnet
    properties:
      network: { get_resource: webapp_network }
      cidr: 10.0.1.0/24
      gateway_ip: 10.0.1.1
      dns_nameservers: [8.8.8.8, 8.8.4.4]

  # ... (définir tous les autres composants)
```

### Monitoring avec Ceilometer

```bash
# Créer des alarmes sur l'utilisation CPU
openstack alarm create \
  --name high-cpu-frontend \
  --type threshold \
  --metric cpu_util \
  --threshold 80 \
  --comparison-operator gt \
  --evaluation-periods 3 \
  --resource-id <INSTANCE_ID>
```

---

**Durée de réalisation** : 2h30  
**Difficulté** : ✅ Complétée  
**Date** : $(date +%Y-%m-%d)

🎉 **Félicitations !** Vous avez déployé avec succès une infrastructure complète sur OpenStack !
