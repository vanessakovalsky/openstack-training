### 🎯 Objectifs du TP
- Comparer les méthodes d'installation
- Installer OpenStack avec DevStack
- Explorer l'interface Horizon

### 📋 Prérequis Techniques
- VM Ubuntu 20.04 LTS (4 CPU, 8GB RAM, 80GB disk)
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

### 🚀 Atelier 2 : Installation DevStack (25 min)

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
- [ ] Projet "demo" créé
- [ ] Réseau par défaut configuré

### 📝 Questions de Synthèse

1. **Analyse** : Quels sont les avantages et inconvénients de DevStack ?
2. **Réflexion** : Dans quels cas utiliser chaque méthode d'installation ?
3. **Observation** : Quels services sont installés par défaut ?
