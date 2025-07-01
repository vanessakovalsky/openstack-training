# Gérer le stockage

### 🎯 Objectif
Configurer et utiliser Cinder pour la gestion du stockage bloc

### 📋 Prérequis
- Environnement OpenStack fonctionnel
- Accès administrateur
- Espace disque disponible pour LVM

### 🔧 TP 3.1 : Configuration de base de Cinder (20 minutes)

#### Étape 1 : Configuration NFS

```bash
# Editer le fichier /etct/export pour ajouter votre adresse IP
sudo nano /etc/exports

# Wihin this file: add the directory and the access host (ourselves, ie, our 10. IP) to the authorized list
/openstack/nfs       10.30.0.20(rw,sync,no_subtree_check)

# After saving, restart the nfs server
sudo systemctl restart nfs-kernel-server

# Editer le/etc/kolla/config/nfs_shares pour ajouter votre adresse IP
sudo nano /etc/kolla/config/nfs_shares

# Add the "remote" to mount in the file and save
10.30.0.20:/openstack/nfs

# Relancer la configuration
kolla-ansible reconfigure -i ./all-in-one
```

#### Étape 2 : Test

* Dans l'interface, essayer de créer un volume d'un GO
* Essayer aussi avec la commande :
```bash
openstack volume create --size 1 testcli
```
* Vos deux volumes devrait bien être créé

### 🔧 TP 3.2 : Gestion des volumes (20 minutes)

#### Création d'un volume

```bash
# Création d'un volume de 10GB
openstack volume create --size 10 volume-test

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
openstack volume type create --property fast=true fast-type

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
- ✓ Un backend NFS configuré et fonctionnel
- ✓ Un volume créé et attaché à une instance
- ✓ Un snapshot de volume créé
- ✓ Des types de volumes personnalisés
- ✓ Une compréhension des quotas de stockage
