# Création de VMs

## 🎯 Objectifs du TP
- Créer et configurer des machines virtuelles
- Gérer les réseaux et la sécurité
- Utiliser les interfaces CLI et Web

## 📋 Prérequis
- Installation OpenStack fonctionnelle (Module 1)
- Accès CLI et Dashboard
- Images cloud disponibles

## 🛠️ Atelier 1 : Préparation de l'Environnement (10 min)

#### Vérification des Services
```bash
# Vérification des services Nova
openstack compute service list

# Vérification des hyperviseurs
openstack hypervisor list

# Liste des images disponibles
openstack image list

# Liste des flavors
openstack flavor list

# Vérification réseau
openstack network list
```

#### Création d'une Keypair
```bash
# Génération de clé SSH
ssh-keygen -t rsa -b 2048 -f ~/.ssh/openstack_key -N ""

# Import dans OpenStack
openstack keypair create \
  --public-key ~/.ssh/openstack_key.pub \
  demo-key

# Vérification
openstack keypair list
```

## 🌐 Atelier 2 : Configuration Réseau (10 min)

#### Création d'un Réseau Privé
```bash
# Réseau privé
openstack network create \
  --internal \
  private-network

# Sous-réseau
openstack subnet create \
  --network private-network \
  --subnet-range 192.168.100.0/24 \
  --gateway 192.168.100.1 \
  --dns-nameserver 8.8.8.8 \
  --allocation-pool start=192.168.100.10,end=192.168.100.100 \
  private-subnet
```

### Configuration du Routeur
```bash
# Création du routeur
openstack router create demo-router2

# Connexion au réseau externe
openstack router set \
  --external-gateway public \
  demo-router2

# Ajout du sous-réseau privé
openstack router add subnet \
  demo-router2 \
  private-subnet

# Vérification
openstack router show demo-router2
```

### Configuration Security Group
```bash
# Création d'un security group
openstack security group create \
  --description "Web and SSH access" \
  web-sg

# Règles SSH
openstack security group rule create \
  --protocol tcp \
  --dst-port 22 \
  --remote-ip 0.0.0.0/0 \
  web-sg

# Règles HTTP
openstack security group rule create \
  --protocol tcp \
  --dst-port 80 \
  --remote-ip 0.0.0.0/0 \
  web-sg

# Règles ICMP
openstack security group rule create \
  --protocol icmp \
  --remote-ip 0.0.0.0/0 \
  web-sg
```

## 🚀 Atelier 3 : Création d'Instances (10 min)

#### Instance Web Server
```bash
# Création de l'instance web
openstack server create \
  --flavor m1.small \
  --image cirros \
  --key-name demo-key \
  --security-group web-sg \
  --network private-network \
  --user-data cloud-init.txt \
  web-server-01

# Script cloud-init (cloud-init.txt)
cat > cloud-init.txt << EOF
#cloud-config
package_update: true
packages:
  - nginx
runcmd:
  - systemctl start nginx
  - systemctl enable nginx
  - echo "<h1>OpenStack Web Server</h1>" > /var/www/html/index.html
EOF
```

### Ajout d'une Image

* Télécharger l'image iso d'ubuntu desktop sur cette page : https://www.ubuntu-fr.org/download/ 
* Dans l'UI de Openstack, allez dans Images puis cliquer sur `Créer une image`
* Nomme l'image ubuntu-24.04 et valider avec `Créer une image`
* Votre image est prête à être utilisé pour la création d'une instance

### Instance Base de Données
```bash
# Création de l'instance DB
openstack server create \
  --flavor m1.small \
  --image ubuntu-24.04 \
  --key-name demo-key \
  --security-group default \
  --network private-network \
  db-server-01
```

### Vérification et Monitoring
```bash
# État des instances
openstack server list

# Détails d'une instance
openstack server show web-server-01

# Console log
openstack console log show web-server-01

# URL console VNC
openstack console url show \
  --vnc \
  web-server-01
```

## 🌍 Atelier 4 : Gestion des IPs Flottantes (5 min)

### Allocation et Association
```bash
# Création d'une IP flottante
openstack floating ip create public

# Association à l'instance web
FLOATING_IP=$(openstack floating ip list -c "Floating IP Address" -f value | head -1)
openstack server add floating ip web-server-01 $FLOATING_IP

# Test de connectivité
ping -c 3 $FLOATING_IP
ssh -i ~/.ssh/openstack_key ubuntu@$FLOATING_IP
```

### Test de Service
```bash
# Test du serveur web
curl http://$FLOATING_IP

# Connexion SSH
ssh -i ~/.ssh/openstack_key \
  -o StrictHostKeyChecking=no \
  ubuntu@$FLOATING_IP
```

## 🔧 Exercices Avancés (pour aller plus loin si vous avez terminés les premiers exercices et en attendant le reste du groupe)

#### Exercice 1 : Snapshot et Restauration
```bash
# Arrêt propre de l'instance
openstack server stop web-server-01

# Création d'un snapshot
openstack server image create \
  --name "web-server-backup-$(date +%Y%m%d)" \
  web-server-01

# Création d'une nouvelle instance depuis le snapshot
openstack server create \
  --flavor m1.small \
  --image "web-server-backup-$(date +%Y%m%d)" \
  --key-name demo-key \
  --security-group web-sg \
  --network private-network \
  web-server-restored
```

#### Exercice 2 : Redimensionnement
```bash
# Arrêt de l'instance
openstack server stop db-server-01

# Redimensionnement vers un flavor plus gros
openstack server resize \
  --flavor m1.medium \
  db-server-01

# Confirmation du redimensionnement
openstack server resize confirm db-server-01

# Redémarrage
openstack server start db-server-01
```

#### Exercice 3 : Migration Live
```bash
# Liste des hyperviseurs
openstack hypervisor list

# Migration live (si plusieurs compute nodes)
openstack server migrate \
  --live-migration \
  web-server-01

# Vérification de la migration
openstack server show web-server-01
```

### 📝 Questions de Validation

#### Questions Techniques
1. **Architecture** : Expliquez le rôle de chaque composant Nova dans la création d'une VM
2. **Réseau** : Comment les security groups et les floating IPs interagissent-ils ?
3. **Stockage** : Quelle est la différence entre stockage éphémère et persistent ?
4. **Performance** : Quels facteurs influencent les performances d'une instance ?

#### Diagnostic et Dépannage
1. **Instance en ERROR** : Quelles sont les étapes de diagnostic ?
2. **Problème réseau** : Comment identifier un problème de connectivité ?
3. **Performance dégradée** : Quels outils utiliser pour le monitoring ?

### Validation Technique
- [ ] Instances créées avec succès
- [ ] Connectivité réseau fonctionnelle
- [ ] Services web accessibles
- [ ] Snapshots créés
- [ ] IPs flottantes associées


