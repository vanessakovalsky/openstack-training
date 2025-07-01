# Gérer les images

### 🎯 Objectifs
- Configurer Glance pour la gestion des images
- Créer et personnaliser des images
- Gérer différents formats d'images
- Importer des images externes

### 📋 Prérequis
- Environnement OpenStack avec Glance installé
- Accès administrateur
- Images de test disponibles

### 🔧 TP 4.1 : Configuration et test de Glance (15 minutes)

#### Étape 1 : Vérification de l'installation

```bash
# Vérification du service Glance
openstack service list | grep glance
openstack endpoint list | grep glance

# Test de connectivité
openstack image list
```

#### Étape 2 : Configuration des backends

```bash
# Édition de la configuration
sudo nano /etc/glance/glance-api.conf

# Ajout du backend Swift (si disponible)
[glance_store]
stores = file,swift
default_store = file
filesystem_store_datadir = /var/lib/glance/images/
```

#### Étape 3 : Test de fonctionnement

```bash
# Redémarrage du service
sudo systemctl restart glance-api

# Vérification des logs
sudo tail -f /var/log/glance/api.log
```

### 🔧 TP 4.2 : Création et gestion d'images (20 minutes)

#### Étape 1 : Téléchargement d'une image de test

```bash
# Téléchargement d'une image Ubuntu Cloud
wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img

# Vérification de l'image
file focal-server-cloudimg-amd64.img
qemu-img info focal-server-cloudimg-amd64.img
```

#### Étape 2 : Import de l'image

```bash
# Création de l'image dans Glance
openstack image create \
    --container-format bare \
    --disk-format qcow2 \
    --min-disk 1 \
    --min-ram 512 \
    --public \
    --property os_type=linux \
    --property os_distro=ubuntu \
    --property os_version=20.04 \
    --file focal-server-cloudimg-amd64.img \
    "Ubuntu 20.04 Cloud"

# Vérification
openstack image list
openstack image show "Ubuntu 20.04 Cloud"
```

#### Étape 3 : Modification des propriétés

```bash
# Ajout de métadonnées
openstack image set \
    --property hw_disk_bus=virtio \
    --property hw_vif_model=virtio \
    --property hw_watchdog_action=reset \
    --tag production \
    --tag ubuntu \
    "Ubuntu 20.04 Cloud"

# Vérification des propriétés
openstack image show "Ubuntu 20.04 Cloud"
```

### 🔧 TP 4.3 : Création d'une image personnalisée (15 minutes)

#### Étape 1 : Lancement d'une instance de base

```bash
# Création d'une instance pour personnalisation
openstack server create \
    --flavor m1.small \
    --image "Ubuntu 20.04 Cloud" \
    --key-name mykey \
    --security-group default \
    --network private \
    ubuntu-custom

# Attente du démarrage
openstack server show ubuntu-custom
```

#### Étape 2 : Personnalisation de l'instance

```bash
# Connexion SSH à l'instance
ssh ubuntu@<instance-ip>

# Mise à jour et installation de packages
sudo apt update
sudo apt upgrade -y
sudo apt install -y nginx htop git

# Configuration personnalisée
echo "Custom Image - $(date)" | sudo tee /etc/motd

# Nettoyage avant snapshot
sudo apt clean
sudo rm -rf /tmp/*
history -c
```

#### Étape 3 : Création du snapshot

```bash
# Arrêt de l'instance
openstack server stop ubuntu-custom

# Création de l'image personnalisée
openstack server image create \
    --name "Ubuntu 20.04 Custom" \
    --wait \
    ubuntu-custom

# Vérification
openstack image list
openstack image show "Ubuntu 20.04 Custom"
```

### ✅ Résultats attendus

À la fin de ce TP, vous devriez avoir :
- ✓ Glance configuré et fonctionnel
- ✓ Une image Ubuntu importée depuis le cloud
- ✓ Des propriétés et métadonnées configurées
- ✓ Une image personnalisée créée depuis une instance
- ✓ Une compréhension des différents formats d'images
