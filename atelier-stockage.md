### 🎯 Objectif
Configurer et utiliser Cinder pour la gestion du stockage bloc

### 📋 Prérequis
- Environnement OpenStack fonctionnel
- Accès administrateur
- Espace disque disponible pour LVM

### 🔧 TP 3.1 : Configuration de base de Cinder (20 minutes)

#### Étape 1 : Préparation du stockage LVM

```bash
# Création d'un volume group pour Cinder
sudo pvcreate /dev/sdb
sudo vgcreate cinder-volumes /dev/sdb

# Vérification
sudo vgdisplay cinder-volumes
```

#### Étape 2 : Configuration de Cinder

```bash
# Édition du fichier de configuration
sudo nano /etc/cinder/cinder.conf

# Ajout de la configuration LVM
[lvm]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
iscsi_protocol = iscsi
iscsi_helper = tgtadm
volume_backend_name = LVM
```

#### Étape 3 : Redémarrage des services

```bash
sudo systemctl restart cinder-volume
sudo systemctl restart cinder-scheduler
sudo systemctl status cinder-volume
```

### 🔧 TP 3.2 : Gestion des volumes (20 minutes)

#### Création d'un volume

```bash
# Création d'un volume de 10GB
openstack volume create --size 10 --type lvm volume-test

# Vérification
openstack volume list
openstack volume show volume-test
```

#### Attachement à une instance

```bash
# Liste des instances
openstack server list

# Attachement du volume
openstack server add volume <instance-id> volume-test

# Vérification
openstack volume list
```

#### Création d'un snapshot

```bash
# Création du snapshot
openstack volume snapshot create --volume volume-test snapshot-test

# Vérification
openstack volume snapshot list
```

### 🔧 TP 3.3 : Types de volumes et quotas (10 minutes)

#### Création d'un type de volume

```bash
# Création d'un type de volume
openstack volume type create --property volume_backend_name=LVM lvm-type

# Configuration des propriétés
openstack volume type set --property fast=true lvm-type

# Vérification
openstack volume type list
```

#### Gestion des quotas

```bash
# Affichage des quotas actuels
openstack quota show

# Modification des quotas de volumes
openstack quota set --volumes 50 --gigabytes 1000 <project-id>
```

### ✅ Résultats attendus

À la fin de ce TP, vous devriez avoir :
- ✓ Un backend LVM configuré et fonctionnel
- ✓ Un volume créé et attaché à une instance
- ✓ Un snapshot de volume créé
- ✓ Des types de volumes personnalisés
- ✓ Une compréhension des quotas de stockage
