# Installation OpenStack

## 🎯 Objectifs du TP
- Comparer les méthodes d'installation
- Installer OpenStack avec DevStack
- Explorer l'interface Horizon

## 📋 Prérequis Techniques
- VM Ubuntu 24.04 LTS (8 CPU, 16GB RAM, 80GB disk)
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

### Sur Ubuntu avec multipass:

* Lancement de la VM et déploiement de devstack automatisé

```bash

sudo snap install multipass
multipass launch --name devstack --cpus 4 --disk 40G --memory 8G --cloud-init https://raw.githubusercontent.com/vanessakovalsky/openstack-training/refs/heads/master/cloud-init.yml jammy

```
* Récupération du nom de la machine et de l'adresse IP de la machine (pour accéder à horizon)
```
multipass list
```
* La suite se fait dans la machine crée par multipass
* Pour se connecter utiliser la commande pour arriver dans la machine

```
multipass shell devstack
```

* Utilisation de l'utilisateur devstack
```
# définir un mot de passe
sudo passwd stack
# se connecter avec l'utilisateur stack
su - stack
```
* Installation de la stack openstack avec devstack :
```
cd devstack
cat <<EOF > local.conf
[[local|localrc]]
ADMIN_PASSWORD=password
DATABASE_PASSWORD=password
RABBIT_PASSWORD=password
SERVICE_PASSWORD=password
HOST_IP=$(hostname -I | awk '{print $1}')
EOF
./stack.sh
```

* Configuration Openstack cli

```
pip install python-openstackclient
# depuis le dossier devstack toujours
source openrc
# pour vérifier afficher la liste des flavos
openstack flavor list
```
* Génération d'une clé SSH

```
ssh-keygen -t rsa -b 2048 -f ~/.ssh/openstack_key -N ""
openstack keypair create \
  --public-key ~/.ssh/openstack_key.pub \
  demo-key
```

## Debug

### Erreur DNS

* Résoudre Erreur host name not found

* Supprimé le fichier /etc/resolve.conf
* Recreer le avec seulement le contenu `nameserver 8.8.8.8`
* essayer de ping google.com

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
