
# Atelier OpenStack : Configuration du réseau et lancement d'instances

**Durée :** 60 minutes  
**Niveau :** Débutant à Intermédiaire  
**Prérequis :** OpenStack fonctionnel (DevStack), accès CLI et Horizon  
**Environnement :** Ubuntu 22.04 avec DevStack

---

## Objectifs pédagogiques

À l'issue de cet atelier, les participants seront capables de :
- Comprendre l'architecture réseau d'OpenStack (Neutron)
- Créer et configurer des réseaux privés et publics
- Configurer des routeurs et des security groups
- Créer et gérer des paires de clés SSH
- Lancer et accéder à des instances
- Assigner des IP flottantes pour l'accès externe
- Diagnostiquer les problèmes réseau courants

---

## Partie 1 : Concepts réseau OpenStack (10 min)

### 1.1 Architecture réseau Neutron

```
┌──────────────────────────────────────────────────────────────┐
│                    INTERNET / RÉSEAU EXTERNE                  │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Floating IPs (publiques)
                         │
┌────────────────────────▼─────────────────────────────────────┐
│                      ROUTEUR NEUTRON                          │
│  • NAT (SNAT/DNAT)                                           │
│  • Routage inter-réseaux                                      │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Gateway
                         │
┌────────────────────────▼─────────────────────────────────────┐
│                  RÉSEAU PRIVÉ (Tenant)                        │
│  • Subnet: 192.168.1.0/24                                    │
│  • DHCP activé                                                │
└──────┬───────────┬───────────┬───────────┬───────────────────┘
       │           │           │           │
       ▼           ▼           ▼           ▼
   ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐
   │ VM 1 │   │ VM 2 │   │ VM 3 │   │ VM 4 │
   │.1.10 │   │.1.11 │   │.1.12 │   │.1.13 │
   └──────┘   └──────┘   └──────┘   └──────┘
```

### 1.2 Composants réseau Neutron

| Composant | Rôle | Exemple |
|-----------|------|---------|
| **Network** | Couche 2 (broadcast domain) | Réseau privé d'un projet |
| **Subnet** | Couche 3 (plage IP) | 192.168.1.0/24 |
| **Router** | Routage entre réseaux | Connecte privé ↔ public |
| **Port** | Point d'attachement | Interface réseau d'une VM |
| **Floating IP** | IP publique | Accès depuis Internet |
| **Security Group** | Firewall virtuel | Règles de filtrage |

### 1.3 Types de réseaux

**Réseau Provider (externe) :**
- Géré par l'administrateur
- Connecté à l'infrastructure physique
- Utilisé pour les Floating IPs

**Réseau Tenant (privé) :**
- Créé par les utilisateurs/projets
- Isolé des autres projets
- Connecté au réseau provider via routeur

---

## Partie 2 : Configuration réseau via CLI (15 min)

### 2.1 Préparation de l'environnement

```bash
# Se connecter en tant qu'admin
cd /opt/stack/devstack
source openrc admin admin

# Vérifier les réseaux existants
openstack network list

# Vérifier le réseau public (créé par DevStack)
openstack network show public
```

### 2.2 Création d'un réseau privé

```bash
# Créer le réseau privé
openstack network create \
    --description "Réseau privé pour le projet demo" \
    private-network

# Vérifier la création
openstack network list
openstack network show private-network

# Observer les détails
# - ID unique
# - Status: ACTIVE
# - admin_state_up: UP
# - shared: False (non partagé entre projets)
```

### 2.3 Création d'un sous-réseau

```bash
# Créer le subnet avec DHCP
openstack subnet create \
    --network private-network \
    --subnet-range 192.168.100.0/24 \
    --dns-nameserver 8.8.8.8 \
    --dns-nameserver 8.8.4.4 \
    --allocation-pool start=192.168.100.10,end=192.168.100.100 \
    private-subnet

# Vérifier la création
openstack subnet show private-subnet

# Observer :
# - CIDR: 192.168.100.0/24
# - Gateway IP: 192.168.100.1 (automatique)
# - DHCP: Enabled
# - Pool d'allocation: .10 à .100
```

**💡 Explication des paramètres :**
- `--subnet-range` : Plage d'adresses réseau (CIDR)
- `--dns-nameserver` : Serveurs DNS pour les instances
- `--allocation-pool` : Plage d'IPs assignables aux instances

### 2.4 Création et configuration du routeur

```bash
# Créer un routeur
openstack router create \
    --description "Routeur pour private-network" \
    private-router

# Connecter le routeur au réseau externe (gateway)
openstack router set \
    --external-gateway public \
    private-router

# Connecter le routeur au réseau privé (interface interne)
openstack router add subnet \
    private-router \
    private-subnet

# Vérifier la configuration
openstack router show private-router

# Voir les ports du routeur
openstack port list --router private-router
```

**🔍 Vérification de la connectivité :**
```bash
# Voir la table de routage
openstack router show private-router -f json | grep -A 10 routes

# Lister les interfaces
openstack port list --device-id $(openstack router show private-router -f value -c id)
```

### 2.5 Vérification de l'infrastructure réseau

```bash
# Vue d'ensemble
echo "=== RÉSEAUX ==="
openstack network list

echo "=== SUBNETS ==="
openstack subnet list

echo "=== ROUTEURS ==="
openstack router list

echo "=== TOPOLOGIE ==="
# Réseau public → Routeur → Réseau privé → Instances (à venir)
```

---

## Partie 3 : Security Groups (10 min)

### 3.1 Concept et fonctionnement

**Security Groups = Firewall stateful au niveau de l'instance**

- Par défaut : tout le trafic sortant autorisé, entrant bloqué
- Règles appliquées au niveau des ports réseau
- Stateful : réponses aux connexions sortantes automatiquement autorisées

### 3.2 Security Group par défaut

```bash
# Lister les security groups
openstack security group list

# Examiner le security group "default"
openstack security group show default

# Lister les règles du security group default
openstack security group rule list default

# Par défaut dans DevStack :
# - Egress (sortant) : tout autorisé (IPv4 et IPv6)
# - Ingress (entrant) : seulement depuis le même security group
```

### 3.3 Création d'un Security Group personnalisé

```bash
# Créer un security group pour serveur web
openstack security group create \
    --description "Règles pour serveur web (HTTP, HTTPS, SSH)" \
    web-sg

# Ajouter les règles

# 1. SSH (port 22)
openstack security group rule create \
    --protocol tcp \
    --dst-port 22 \
    --remote-ip 0.0.0.0/0 \
    --description "SSH depuis n'importe où" \
    web-sg

# 2. HTTP (port 80)
openstack security group rule create \
    --protocol tcp \
    --dst-port 80 \
    --remote-ip 0.0.0.0/0 \
    --description "HTTP depuis n'importe où" \
    web-sg

# 3. HTTPS (port 443)
openstack security group rule create \
    --protocol tcp \
    --dst-port 443 \
    --remote-ip 0.0.0.0/0 \
    --description "HTTPS depuis n'importe où" \
    web-sg

# 4. ICMP (ping)
openstack security group rule create \
    --protocol icmp \
    --remote-ip 0.0.0.0/0 \
    --description "ICMP (ping)" \
    web-sg

# Vérifier les règles
openstack security group rule list web-sg --long
```

**🔒 Bonnes pratiques :**
```bash
# Security group restrictif (SSH depuis une IP spécifique)
openstack security group create secure-sg

openstack security group rule create \
    --protocol tcp \
    --dst-port 22 \
    --remote-ip 203.0.113.5/32 \
    --description "SSH depuis admin uniquement" \
    secure-sg
```

---

## Partie 4 : Préparation au lancement d'instances (10 min)

### 4.1 Gestion des paires de clés SSH

```bash
# Lister les paires de clés existantes
openstack keypair list

# Méthode 1 : Générer une nouvelle paire
ssh-keygen -t rsa -b 4096 -f ~/.ssh/openstack-key -N ""

# Importer la clé publique dans OpenStack
openstack keypair create \
    --public-key ~/.ssh/openstack-key.pub \
    mykey

# Méthode 2 : Laisser OpenStack générer la paire
openstack keypair create \
    --private-key ~/.ssh/openstack-generated.pem \
    generated-key

# Définir les permissions
chmod 600 ~/.ssh/openstack-generated.pem

# Vérifier
openstack keypair list
openstack keypair show mykey
```

### 4.2 Exploration des images disponibles

```bash
# Lister les images
openstack image list

# Détails d'une image
openstack image show cirros-0.6.2-x86_64-disk

# Images typiques dans DevStack :
# - cirros : Image de test légère (~13MB)
# - ubuntu : Si ajoutée manuellement
```

**📦 Télécharger une image Ubuntu (optionnel) :**
```bash
# Télécharger Ubuntu 22.04 cloud image
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# Uploader dans Glance
openstack image create \
    --disk-format qcow2 \
    --container-format bare \
    --public \
    --file jammy-server-cloudimg-amd64.img \
    ubuntu-22.04

# Vérifier
openstack image list
```

### 4.3 Exploration des flavors

```bash
# Lister les flavors (gabarits)
openstack flavor list

# Détails d'un flavor
openstack flavor show m1.tiny

# Flavors DevStack typiques :
# - m1.tiny:   1 vCPU, 512MB RAM, 1GB disk
# - m1.small:  1 vCPU, 2GB RAM, 20GB disk
# - m1.medium: 2 vCPU, 4GB RAM, 40GB disk
# - m1.large:  4 vCPU, 8GB RAM, 80GB disk
```

**🔧 Créer un flavor personnalisé (optionnel) :**
```bash
openstack flavor create \
    --vcpus 2 \
    --ram 2048 \
    --disk 10 \
    --public \
    custom.small

openstack flavor list
```

---

## Partie 5 : Création et lancement d'instances (10 min)

### 5.1 Lancement d'une première instance

```bash
# Vérifier les prérequis
openstack network list        # private-network existe
openstack security group list # web-sg existe
openstack keypair list        # mykey existe
openstack image list          # cirros disponible
openstack flavor list         # m1.tiny disponible

# Lancer l'instance
openstack server create \
    --image cirros-0.6.2-x86_64-disk \
    --flavor m1.tiny \
    --network private-network \
    --security-group web-sg \
    --key-name mykey \
    web-server-01

# Suivre la création
watch -n 2 'openstack server list'
# Attendre status = ACTIVE (20-30 secondes)
```

### 5.2 Vérification de l'instance

```bash
# Informations détaillées
openstack server show web-server-01

# Observer :
# - Status: ACTIVE
# - Addresses: private-network=192.168.100.X
# - Security groups: web-sg
# - Key name: mykey

# Voir les logs de démarrage
openstack console log show web-server-01

# Obtenir l'URL de la console VNC
openstack console url show web-server-01
```

### 5.3 Lancement de plusieurs instances

```bash
# Script pour lancer 3 instances
for i in {1..3}; do
    openstack server create \
        --image cirros-0.6.2-x86_64-disk \
        --flavor m1.tiny \
        --network private-network \
        --security-group web-sg \
        --key-name mykey \
        app-server-0${i}
    
    echo "Instance app-server-0${i} créée"
    sleep 2
done

# Vérifier
openstack server list
```

---

## Partie 6 : Accès aux instances via Floating IPs (10 min)

### 6.1 Concept de Floating IP

**Floating IP = IP publique assignable dynamiquement**

- Permet l'accès externe aux instances sur réseau privé
- Peut être déplacée d'une instance à une autre
- Utilise DNAT (Destination NAT) sur le routeur

### 6.2 Allocation et assignation d'une Floating IP

```bash
# Créer/allouer une Floating IP depuis le pool public
openstack floating ip create public

# Voir les Floating IPs disponibles
openstack floating ip list

# Assigner la Floating IP à l'instance
# Méthode 1 : Avec l'IP directement
FLOATING_IP=$(openstack floating ip list -f value -c "Floating IP Address" | head -1)
openstack server add floating ip web-server-01 ${FLOATING_IP}

# Méthode 2 : Avec l'ID
FIP_ID=$(openstack floating ip list -f value -c ID | head -1)
openstack floating ip set --port $(openstack port list --server web-server-01 -f value -c ID) ${FIP_ID}

# Vérifier l'assignation
openstack server show web-server-01 | grep addresses
openstack floating ip list
```

### 6.3 Tester la connexion

```bash
# Récupérer la Floating IP
FLOATING_IP=$(openstack server show web-server-01 -f value -c addresses | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | tail -1)

echo "Floating IP: ${FLOATING_IP}"

# Test ping
ping -c 3 ${FLOATING_IP}

# Test SSH (avec cirros, user: cirros, password: gocubsgo)
ssh cirros@${FLOATING_IP}
# Ou avec la clé
ssh -i ~/.ssh/openstack-key cirros@${FLOATING_IP}

# Une fois connecté dans l'instance :
# - ip addr
# - ping 8.8.8.8
# - curl http://example.com
```

**🔍 Troubleshooting si pas de connexion :**
```bash
# Vérifier le security group
openstack security group rule list web-sg

# Vérifier le routeur
openstack router show private-router

# Vérifier les ports
openstack port list --server web-server-01

# Logs Neutron (sur le controller)
sudo journalctl -u devstack@q-* -f
```

---

## Partie 7 : Gestion via Horizon (5 min)

### 7.1 Accès à Horizon

```
URL: http://<controller_ip>/dashboard
User: admin ou demo
Password: (voir /opt/stack/devstack/openrc)
```

### 7.2 Navigation dans Horizon

**Créer un réseau :**
```
Project → Network → Networks → Create Network
├─ Network tab: Nom du réseau
├─ Subnet tab: Subnet Name, CIDR (192.168.200.0/24)
└─ Subnet Details tab: DNS, Pool d'allocation
```

**Créer un routeur :**
```
Project → Network → Routers → Create Router
└─ External Network: public

Cliquer sur le routeur → Interfaces tab → Add Interface
└─ Sélectionner le subnet
```

**Lancer une instance :**
```
Project → Compute → Instances → Launch Instance

Wizard en 7 étapes :
1. Details: Nom de l'instance
2. Source: Sélectionner l'image
3. Flavor: Choisir la taille
4. Networks: Sélectionner private-network
5. Security Groups: Sélectionner web-sg
6. Key Pair: Sélectionner mykey
7. Launch Instance
```

**Assigner une Floating IP :**
```
Project → Compute → Instances
└─ Actions dropdown → Associate Floating IP
   ├─ IP Address: + (allouer nouvelle IP)
   └─ Associate
```

---

## Exercice pratique guidé (10 min)

### Scénario : Infrastructure web complète

**Objectif :**
Créer une infrastructure web avec :
- 1 réseau privé
- 1 routeur connecté au réseau public
- 1 security group personnalisé
- 1 serveur web avec Floating IP
- 1 serveur de base de données (privé, sans Floating IP)

### Solution étape par étape

```bash
# 1. Créer le réseau et subnet
openstack network create webapp-network

openstack subnet create \
    --network webapp-network \
    --subnet-range 10.0.1.0/24 \
    --dns-nameserver 8.8.8.8 \
    webapp-subnet

# 2. Créer et configurer le routeur
openstack router create webapp-router
openstack router set --external-gateway public webapp-router
openstack router add subnet webapp-router webapp-subnet

# 3. Créer les security groups

# Security group web (HTTP + SSH)
openstack security group create webapp-web-sg
openstack security group rule create --protocol tcp --dst-port 22 webapp-web-sg
openstack security group rule create --protocol tcp --dst-port 80 webapp-web-sg
openstack security group rule create --protocol icmp webapp-web-sg

# Security group database (MySQL depuis le web-sg uniquement)
openstack security group create webapp-db-sg
openstack security group rule create \
    --protocol tcp \
    --dst-port 3306 \
    --remote-group webapp-web-sg \
    webapp-db-sg

# 4. Créer les instances

# Serveur web
openstack server create \
    --image cirros-0.6.2-x86_64-disk \
    --flavor m1.small \
    --network webapp-network \
    --security-group webapp-web-sg \
    --key-name mykey \
    webapp-web

# Serveur DB
openstack server create \
    --image cirros-0.6.2-x86_64-disk \
    --flavor m1.small \
    --network webapp-network \
    --security-group webapp-db-sg \
    --key-name mykey \
    webapp-db

# Attendre que les instances soient ACTIVE
watch -n 2 'openstack server list'

# 5. Assigner Floating IP au serveur web uniquement
openstack floating ip create public
FLOATING_IP=$(openstack floating ip list -f value -c "Floating IP Address" --status DOWN | head -1)
openstack server add floating ip webapp-web ${FLOATING_IP}

# 6. Vérifications
echo "=== INFRASTRUCTURE WEB APP ==="
echo "Réseau: $(openstack network show webapp-network -f value -c id)"
echo "Routeur: $(openstack router show webapp-router -f value -c id)"
echo ""
echo "Serveur Web:"
openstack server show webapp-web -c name -c status -c addresses -c security_groups
echo ""
echo "Serveur DB:"
openstack server show webapp-db -c name -c status -c addresses -c security_groups
echo ""
echo "Floating IP Web: ${FLOATING_IP}"
echo ""
echo "Test de connexion:"
ping -c 3 ${FLOATING_IP}
```

**🔬 Tests avancés :**
```bash
# Se connecter au serveur web
ssh cirros@${FLOATING_IP}

# Depuis le serveur web, tester la connexion à la DB (IP privée)
DB_IP=$(openstack server show webapp-db -f value -c addresses | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
ping ${DB_IP}

# La DB ne devrait PAS être accessible depuis l'extérieur
# (pas de Floating IP, security group restrictif)
```

---

## Troubleshooting : Problèmes courants

### 🐛 Problème 1 : Instance ne démarre pas

**Symptômes :** Status reste en BUILD ou passe en ERROR

**Diagnostic :**
```bash
# Voir les logs détaillés
openstack server show <instance> | grep fault
openstack console log show <instance>

# Vérifier les quotas
openstack quota show

# Vérifier les ressources disponibles
openstack hypervisor stats show
```

**Solutions :**
- Ressources insuffisantes → Choisir un flavor plus petit
- Image corrompue → Retélécharger l'image
- Problème de quotas → Augmenter les quotas du projet

### 🐛 Problème 2 : Pas de connectivité réseau

**Symptômes :** Instance active mais pas d'IP ou pas de ping

**Diagnostic :**
```bash
# Vérifier l'assignation IP
openstack server show <instance> | grep addresses

# Vérifier le port réseau
openstack port list --server <instance>

# Vérifier le routeur
openstack router show <router> | grep interfaces

# Vérifier les agents Neutron
openstack network agent list
```

**Solutions :**
- Pas d'IP DHCP → Vérifier que le subnet a DHCP enabled
- Routeur non connecté → `openstack router add subnet`
- Agent DHCP down → Redémarrer l'agent : `sudo systemctl restart devstack@q-dhcp`

### 🐛 Problème 3 : Impossible de se connecter en SSH

**Symptômes :** Timeout ou "Connection refused"

**Diagnostic :**
```bash
# Vérifier la Floating IP
openstack floating ip list

# Vérifier le security group
openstack security group rule list <security-group>

# Tester depuis le controller
ping <floating_ip>
telnet <floating_ip> 22
```

**Solutions :**
- Floating IP non assignée → `openstack server add floating ip`
- Security group bloque le port 22 → Ajouter la règle SSH
- Clé SSH incorrecte → Vérifier le keypair utilisé
- SSH daemon pas démarré → Utiliser la console VNC pour diagnostiquer

---

## Récapitulatif et bonnes pratiques

### ✅ Points clés à retenir

**Architecture réseau :**
```
Réseau public → Routeur → Réseau privé → Instances
                    ↓
              Floating IPs (DNAT)
```

**Workflow de création :**
```
1. Network + Subnet
2. Router (gateway externe + interface interne)
3. Security Groups (règles firewall)
4. Key Pairs (SSH)
5. Instances (server create)
6. Floating IPs (accès externe)
```

**Commandes essentielles :**
```bash
# Réseau
openstack network create <nom>
openstack subnet create --network <réseau> --subnet-range <CIDR> <nom>
openstack router create <nom>
openstack router add subnet <routeur> <subnet>

# Sécurité
openstack security group create <nom>
openstack security group rule create --protocol tcp --dst-port <port> <sg>

# Instances
openstack server create --image <img> --flavor <flv> --network <net> <nom>
openstack floating ip create <réseau-externe>
openstack server add floating ip <instance> <ip>
```

**Bonnes pratiques :**
- 🔒 **Security Groups** : Principe du moindre privilège (ports stricts)
- 🌐 **Réseaux** : Un réseau privé par projet/environnement
- 🔑 **Key Pairs** : Une paire par utilisateur, rotation régulière
- 💰 **Floating IPs** : Libérer les IPs non utilisées (ressource limitée)
- 📝 **Naming** : Convention de nommage cohérente (env-role-index)
- 🔍 **Monitoring** : Vérifier régulièrement les agents Neutron

---

## Ressources complémentaires

### Documentation
- [Neutron Documentation](https://docs.openstack.org/neutron/latest/)
- [Nova Documentation](https://docs.openstack.org/nova/latest/)
- [Horizon User Guide](https://docs.openstack.org/horizon/latest/user/)

### Commandes de référence rapide
```bash
# Cheat sheet réseau
openstack network list
openstack subnet list
openstack router list
openstack security group list
openstack floating ip list

# Cheat sheet instances
openstack server list
openstack server show <instance>
openstack console log show <instance>
openstack console url show <instance>

# Nettoyage complet d'une infrastructure
openstack server delete <instance>
openstack floating ip delete <ip>
openstack router remove subnet <router> <subnet>
openstack router delete <router>
openstack subnet delete <subnet>
openstack network delete <network>
openstack security group delete <sg>
```

### Pour aller plus loin
- **VPNaaS** : VPN as a Service
- **LBaaS** : Load Balancer as a Service
- **FWaaS** : Firewall as a Service
- **Réseaux VLAN** : Isolation niveau 2
- **SDN avancé** : OVN, OVS flows
