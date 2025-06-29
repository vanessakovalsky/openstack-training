# Installation OpenStack

## 🎯 Objectifs du TP
- Comparer les méthodes d'installation
- Installer OpenStack avec DevStack
- Explorer l'interface Horizon

## 📋 Prérequis Techniques
- VM Ubuntu 24.04 LTS (4 CPU, 8GB RAM, 80GB disk)
- Accès Internet
- Accès root/sudo

### 🛠️ Atelier 1 : Analyse des Méthodes (10 min)

#### Activité
Remplir le tableau comparatif suivant en équipe :

| Critère | DevStack | Packstack | Kolla-Ansible | Manuel |
|---------|----------|-----------|---------------|--------|
| Temps d'installation | | | | |
| Complexité | | | | |
| Production-ready | | | | |
| Apprentissage | | | | |

### 🚀 Atelier 2 : Installation Openstack

### Pour Ubuntu 24.04 : 


#### Etape 1 : Préparation de l'environnement
```bash
# Mise à jour du système
sudo apt update && sudo apt upgrade -y

# Création d'un utilisateur kaosu
sudo adduser kaosu

sudo usermod -aG sudo kaosu

sudo mkdir /openstack
```


#### Etape 2  : Installation de Docker


```bash
# Remove potential older versions
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER

# logout from ssh and log back in, test that a sudo-less docker is available to your user
docker run hello-world
```

#### Etape 3 : Suppression du mot de passe pour sudo

```bash
sudo visudo -f /etc/sudoers.d/kaosu-Overrides

# Add and adapt kaosu as needed
kaosu ALL=(ALL) NOPASSWD:ALL

# save the file and test in a new terminal or login
sudo echo works
```

#### Etape 4 : NFS pour Cinder

```bash
# Install nfs server
sudo apt-get install -y nfs-kernel-server

# Create the destination directory and make it nfs-permissions ready
sudo mkdir -p /openstack/nfs
sudo chown nobody:nogroup /openstack/nfs

# edit the `exports` configuration file
sudo nano /etc/exports

# Wihin this file: add the directory and the access host (ourselves, ie, our 10. IP) to the authorized list
/openstack/nfs       10.30.0.20(rw,sync,no_subtree_check)

# After saving, restart the nfs server
sudo systemctl restart nfs-kernel-server

# Prepare the cinder configuration to enable the NFS mount
sudo mkdir -p /etc/kolla/config
sudo nano /etc/kolla/config/nfs_shares

# Add the "remote" to mount in the file and save
10.30.0.20:/openstack/nfs
```

#### Etape 5 : Kolla Ansible OpenStack (KAOS)

##### Préparation 

```bash
cd /openstack
sudo mkdir kaos
sudo chown $USER:$USER kaos
cd kaos

# Install a few things that might otherwise fail during ansible prechecks
sudo apt-get install -y git python3-dev libffi-dev gcc \
  libssl-dev build-essential libdbus-glib-1-dev libpython3-dev \
  cmake libglib2.0-dev python3-venv python3-pip

# Activate a venv
python3 -m venv venv
source venv/bin/activate
pip install -U pip

# Install extra python packages
pip install docker pkgconfig dbus-python

# Install Kolla Ansible from git
pip install git+https://opendev.org/openstack/kolla-ansible@master

# Create the /etc/kolla director, and populate it
sudo mkdir -p /etc/kolla
sudo chown $USER:$USER /etc/kolla
cp -r venv/share/kolla-ansible/etc_examples/kolla/* /etc/kolla
# we are going to do an all-in-one (single host) install, copy it in the current folder for easy edits
cp venv/share/kolla-ansible/ansible/inventory/all-in-one .

# Install Ansible Galaxy requirements
kolla-ansible install-deps

# generate random passwords (stored into /etc/kolla/passwords.yml)
kolla-genpwd
```

* Récupérer les fichiers de configurations
```
rm allinone
wget https://raw.githubusercontent.com/mmartial/geekierblog-artifacts/refs/heads/main/20250424-u24_openstack/all-in-one

rm /etc/kolla/globals.yml
wget https://raw.githubusercontent.com/vanessakovalsky/openstack-training/refs/heads/master/globals.yml
mv globals.yml /etc/kolla/globals.yml
```

* Modifier la ligne kolla_internal_vip_address du fichier globals.yml pour renseigner l'adresse ip de votre interface eth0 (commande : ip a pour obtenir les adresses ip de votre machine)

##### Déploiement 

```bash
# Bootstrap the host:
kolla-ansible bootstrap-servers -i ./all-in-one
# Do pre-deployment checks for the host:
kolla-ansible prechecks -i ./all-in-one
# Perform the OpenStack deployment:
kolla-ansible deploy -i ./all-in-one

```

* Si tout s'est bien passé vous obtenez un résultat de type:

```bash
PLAY RECAP ****...
localhost                  : ok=425  changed=280  unreachable=0    failed=0    skipped=249  rescued=0    ignored=1
```

* Votre Dashboard est accessible sur http://localhost
* Pour retrouver le mot de passe utilisez la commande :
```bash

   fgrep keystone_admin_password /etc/kolla/passwords.yml
```

#### Etape 6 : installer et configurer le CLI

```bash
pip install python-openstackclient -c https://releases.openstack.org/constraints/upper/master
kolla-ansible post-deploy -i ./all-in-one
source /etc/kolla/admin-openrc.sh
# Execution d'un script qui crée une configuration basique pour notre environnement (flavor, images, réseaux...)
./venv/share/kolla-ansible/init-runonce
# Pour vérifier que tout fonctionne
openstack flavor list
```


#### Pour Ubuntu 22.04 : DevStack (25 min) 

/!\ Ne fonctionne pas sur Ubuntu 24.04

#### Étape 1 : Préparation de l'environnement
```bash
# Mise à jour du système
sudo apt update && sudo apt upgrade -y

# Création d'un utilisateur stack
sudo useradd -s /bin/bash -d /opt/stack -m stack
sudo chmod +x /opt/stack
echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack
sudo -u stack -i
```

#### Étape 2 : Téléchargement de DevStack
```bash
cd /opt/stack
git clone https://opendev.org/openstack/devstack
cd devstack
```

#### Étape 3 : Configuration
```bash
# Création du fichier local.conf
cat > local.conf << EOF
[[local|localrc]]
ADMIN_PASSWORD=secret
DATABASE_PASSWORD=\$ADMIN_PASSWORD
RABBIT_PASSWORD=\$ADMIN_PASSWORD
SERVICE_PASSWORD=\$ADMIN_PASSWORD

# Désactiver IPv6
disable_service s-proxy s-object s-container s-account
disable_service heat h-api h-api-cfn h-api-cw h-eng
disable_service cinder c-sch c-api c-vol c-bak

# Activer Neutron
enable_service q-svc q-agt q-dhcp q-l3 q-meta

# Configuration réseau
HOST_IP=10.0.0.10
FIXED_RANGE=10.11.12.0/24
FLOATING_RANGE=172.16.1.0/24
PUBLIC_NETWORK_GATEWAY=172.16.1.1
Q_FLOATING_ALLOCATION_POOL=start=172.16.1.2,end=172.16.1.15
EOF
```

#### Étape 4 : Installation
```bash
# Lancement de l'installation (15-20 min)
./stack.sh
```

### 🔍 Atelier 3 : Exploration de l'Interface (5 min)

#### Connexion à Horizon
1. Ouvrir http://HOST_IP/dashboard
2. Connexion : admin / secret
3. Explorer les menus :
   - Compute → Instances
   - Network → Networks
   - Identity → Projects

#### Points de Vérification
- [ ] Horizon accessible
- [ ] Services actifs (nova, neutron, keystone)
- [ ] Projet "admin" créé
- [ ] Réseau par défaut configuré

### 📝 Questions de Synthèse

1. **Analyse** : Quels sont les avantages et inconvénients de DevStack ?
2. **Réflexion** : Dans quels cas utiliser chaque méthode d'installation ?
3. **Observation** : Quels services sont installés par défaut ?
