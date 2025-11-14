# Atelier OpenStack : Déploiement en masse et automatisation avec scripts

**Durée :** 30 minutes  
**Niveau :** Intermédiaire  
**Prérequis :** Connaissance de base d'OpenStack CLI, notions de scripting Bash/Python  
**Environnement :** Ubuntu 22.04 avec DevStack

---

## Objectifs pédagogiques

À l'issue de cet atelier, les participants seront capables de :
- Automatiser la création d'instances avec des scripts Bash
- Utiliser Heat pour orchestrer des déploiements d'infrastructure
- Déployer des ressources en masse avec des boucles et fichiers de configuration
- Utiliser cloud-init pour la configuration automatique des instances
- Appliquer des bonnes pratiques d'automatisation

---

## Partie 1 : Automatisation avec scripts Bash (10 min)

### 1.1 Script de déploiement simple

```bash
#!/bin/bash
# deploy-instance.sh - Script de déploiement d'une instance

# Chargement des credentials
source /opt/stack/devstack/openrc admin admin

# Variables de configuration
INSTANCE_NAME="web-server-01"
IMAGE="cirros-0.6.3-x86_64-disk"
FLAVOR="m1.tiny"
NETWORK="private"
KEY_NAME="mykey"

# Création de l'instance
echo "Déploiement de l'instance ${INSTANCE_NAME}..."
openstack server create \
    --image ${IMAGE} \
    --flavor ${FLAVOR} \
    --network ${NETWORK} \
    --key-name ${KEY_NAME} \
    ${INSTANCE_NAME}

# Attente que l'instance soit ACTIVE
echo "Attente du démarrage..."
while [ $(openstack server show ${INSTANCE_NAME} -f value -c status) != "ACTIVE" ]; do
    sleep 2
    echo -n "."
done

echo -e "\n✅ Instance déployée avec succès!"
openstack server show ${INSTANCE_NAME}
```

**Rendre le script exécutable :**
```bash
chmod +x deploy-instance.sh
./deploy-instance.sh
```

### 1.2 Script de déploiement en masse

```bash
#!/bin/bash
# deploy-multiple-instances.sh - Déploiement de plusieurs instances

source /opt/stack/devstack/openrc admin admin

# Configuration
BASE_NAME="web-server"
COUNT=5
IMAGE="cirros-0.6.3-x86_64-disk"
FLAVOR="m1.tiny"
NETWORK="private"

echo "🚀 Déploiement de ${COUNT} instances..."

for i in $(seq 1 ${COUNT}); do
    INSTANCE_NAME="${BASE_NAME}-$(printf "%02d" $i)"
    
    echo "Création de ${INSTANCE_NAME}..."
    openstack server create \
        --image ${IMAGE} \
        --flavor ${FLAVOR} \
        --network ${NETWORK} \
        ${INSTANCE_NAME} &
done

# Attendre tous les processus en arrière-plan
wait

echo -e "\n✅ Toutes les instances sont en cours de création"
openstack server list --name ${BASE_NAME}
```

### 1.3 Script avec fichier de configuration

**Fichier de configuration : `instances.conf`**
```ini
# Format: nom,image,flavor,network
db-server-01,ubuntu-22.04,m1.small,private
db-server-02,ubuntu-22.04,m1.small,private
app-server-01,ubuntu-22.04,m1.medium,private
app-server-02,ubuntu-22.04,m1.medium,private
cache-server-01,ubuntu-22.04,m1.tiny,private
```

**Script de déploiement : `deploy-from-config.sh`**
```bash
#!/bin/bash
# deploy-from-config.sh - Déploiement depuis fichier de configuration

source /opt/stack/devstack/openrc admin admin

CONFIG_FILE="instances.conf"

# Lecture du fichier ligne par ligne
while IFS=',' read -r name image flavor network; do
    # Ignorer les commentaires et lignes vides
    [[ "$name" =~ ^#.*$ ]] && continue
    [[ -z "$name" ]] && continue
    
    echo "📦 Déploiement de ${name}..."
    openstack server create \
        --image ${image} \
        --flavor ${flavor} \
        --network ${network} \
        ${name} &
    
done < ${CONFIG_FILE}

wait
echo -e "\n✅ Déploiement terminé"
openstack server list
```

---

## Partie 2 : Utilisation de cloud-init (8 min)

### 2.1 Script cloud-init simple

**Fichier : `cloud-init-web.yaml`**
```yaml
#cloud-config
hostname: web-server
fqdn: web-server.example.com

# Mise à jour et installation de paquets
package_update: true
package_upgrade: true

packages:
  - nginx
  - curl
  - git

# Commandes à exécuter au démarrage
runcmd:
  - systemctl enable nginx
  - systemctl start nginx
  - echo "<h1>Serveur déployé automatiquement</h1>" > /var/www/html/index.html
  - echo "Déploiement terminé à $(date)" >> /var/log/deployment.log

# Création d'utilisateurs
users:
  - name: devops
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2E... devops@example.com

# Messages finaux
final_message: "Le système est prêt après $UPTIME secondes"
```

**Déploiement avec cloud-init :**
```bash
#!/bin/bash
# deploy-with-cloudinit.sh

source /opt/stack/devstack/openrc admin admin

openstack server create \
    --image ubuntu-22.04 \
    --flavor m1.small \
    --network private \
    --user-data cloud-init-web.yaml \
    web-server-cloudinit

echo "Instance créée avec configuration cloud-init"
```

### 2.2 Cloud-init pour cluster applicatif

**Fichier : `cloud-init-app-cluster.yaml`**
```yaml
#cloud-config

# Variables
write_files:
  - path: /etc/app-config.env
    content: |
      APP_ENV=production
      DB_HOST=10.0.0.50
      REDIS_HOST=10.0.0.51
      API_KEY=SECRET_KEY_HERE

  - path: /usr/local/bin/setup-app.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      source /etc/app-config.env
      
      # Installation de l'application
      cd /opt
      git clone https://github.com/example/app.git
      cd app
      
      # Configuration
      sed -i "s/DB_HOST=.*/DB_HOST=${DB_HOST}/" .env
      sed -i "s/REDIS_HOST=.*/REDIS_HOST=${REDIS_HOST}/" .env
      
      # Démarrage
      docker-compose up -d

runcmd:
  - apt-get update
  - apt-get install -y docker.io docker-compose git
  - systemctl enable docker
  - systemctl start docker
  - /usr/local/bin/setup-app.sh
```

---

## Partie 3 : Orchestration avec Heat (12 min)

### 3.0 Activer heat sur DevStack

* Ajouter dans le fichier local.conf (a la fin) les lignes suivantes :
```
# Activer Heat
enable_plugin heat https://opendev.org/openstack/heat
 
enable_service h-eng
enable_service h-api
enable_service h-api-cfn
enable_service h-api-cw
```
* relancer le script stack.sh pour installer et configurer heat : `./stack.sh`
* Attendre que l'installation et la configuration de heat soit terminer
* Une fois terminé vous pouvez tester avec la commande : `openstack stack list`

### 3.1 Template Heat basique

**Fichier : `simple-stack.yaml`**
```yaml
heat_template_version: 2021-04-16

description: Stack simple avec instance et réseau

parameters:
  instance_name:
    type: string
    description: Nom de l'instance
    default: heat-instance
  
  image:
    type: string
    description: Image à utiliser
    default: cirros-0.6.2-x86_64-disk
  
  flavor:
    type: string
    description: Flavor de l'instance
    default: m1.tiny

resources:
  server:
    type: OS::Nova::Server
    properties:
      name: { get_param: instance_name }
      image: { get_param: image }
      flavor: { get_param: flavor }
      networks:
        - network: private

outputs:
  server_ip:
    description: Adresse IP de l'instance
    value: { get_attr: [server, first_address] }
  
  server_id:
    description: ID de l'instance
    value: { get_resource: server }
```

**Déploiement du stack :**
```bash
# Création du stack
openstack stack create -t simple-stack.yaml \
    --parameter instance_name=my-heat-vm \
    my-first-stack

# Vérification du statut
openstack stack list
openstack stack show my-first-stack

# Voir les outputs
openstack stack output show my-first-stack server_ip

# Suppression du stack (et toutes ses ressources)
openstack stack delete my-first-stack
```

### 3.2 Template Heat avancé - Infrastructure complète

**Fichier : `web-infrastructure.yaml`**
```yaml
heat_template_version: 2021-04-16

description: Infrastructure Web complète (Load Balancer + Web Servers + Database)

parameters:
  key_name:
    type: string
    description: Nom de la clé SSH
    default: mykey
  
  web_server_count:
    type: number
    description: Nombre de serveurs web
    default: 3
  
  image:
    type: string
    default: ubuntu-22.04
  
  flavor:
    type: string
    default: m1.small

resources:
  # Réseau privé
  private_network:
    type: OS::Neutron::Net
    properties:
      name: web-network

  private_subnet:
    type: OS::Neutron::Subnet
    properties:
      network: { get_resource: private_network }
      cidr: 192.168.100.0/24
      dns_nameservers: [8.8.8.8, 8.8.4.4]

  # Security Group Web
  web_security_group:
    type: OS::Neutron::SecurityGroup
    properties:
      name: web-sg
      rules:
        - protocol: tcp
          port_range_min: 22
          port_range_max: 22
        - protocol: tcp
          port_range_min: 80
          port_range_max: 80
        - protocol: tcp
          port_range_min: 443
          port_range_max: 443
        - protocol: icmp

  # Security Group Database
  db_security_group:
    type: OS::Neutron::SecurityGroup
    properties:
      name: db-sg
      rules:
        - protocol: tcp
          port_range_min: 3306
          port_range_max: 3306
          remote_group: { get_resource: web_security_group }

  # Serveur de base de données
  database_server:
    type: OS::Nova::Server
    properties:
      name: db-server
      image: { get_param: image }
      flavor: m1.medium
      key_name: { get_param: key_name }
      networks:
        - network: { get_resource: private_network }
      security_groups:
        - { get_resource: db_security_group }
      user_data: |
        #!/bin/bash
        apt-get update
        apt-get install -y mariadb-server
        systemctl enable mariadb
        systemctl start mariadb

  # Groupe de serveurs web
  web_server_group:
    type: OS::Heat::ResourceGroup
    properties:
      count: { get_param: web_server_count }
      resource_def:
        type: OS::Nova::Server
        properties:
          name: web-server-%index%
          image: { get_param: image }
          flavor: { get_param: flavor }
          key_name: { get_param: key_name }
          networks:
            - network: { get_resource: private_network }
          security_groups:
            - { get_resource: web_security_group }
          user_data:
            str_replace:
              template: |
                #!/bin/bash
                apt-get update
                apt-get install -y nginx
                echo "<h1>Web Server %index%</h1>" > /var/www/html/index.html
                echo "<p>Database: $db_ip</p>" >> /var/www/html/index.html
                systemctl enable nginx
                systemctl start nginx
              params:
                $db_ip: { get_attr: [database_server, first_address] }

outputs:
  database_ip:
    description: IP du serveur de base de données
    value: { get_attr: [database_server, first_address] }
  
  web_server_ips:
    description: IPs des serveurs web
    value: { get_attr: [web_server_group, first_address] }
  
  network_id:
    description: ID du réseau créé
    value: { get_resource: private_network }
```

**Déploiement :**
```bash
# Création du stack complet
openstack stack create -t web-infrastructure.yaml \
    --parameter web_server_count=3 \
    --parameter key_name=mykey \
    web-infra-prod

# Monitoring du déploiement
watch -n 2 'openstack stack resource list web-infra-prod'

# Voir les outputs
openstack stack output list web-infra-prod
openstack stack output show web-infra-prod database_ip
openstack stack output show web-infra-prod web_server_ips

# Mise à jour du nombre de serveurs web
openstack stack update -t web-infrastructure.yaml \
    --parameter web_server_count=5 \
    web-infra-prod
```

---

## Exercice pratique : Déploiement d'un cluster applicatif (5 min)

### Objectif
Créer un script qui déploie automatiquement :
- 1 serveur de base de données
- 3 serveurs d'application
- 1 serveur de cache Redis
- Tous avec cloud-init pour la configuration

### Solution

**Fichier : `deploy-app-cluster.sh`**
```bash
#!/bin/bash
set -e

source /opt/stack/devstack/openrc admin admin

PROJECT="app-cluster"
NETWORK="private"
IMAGE="ubuntu-22.04"

echo "🚀 Déploiement du cluster applicatif..."

# 1. Déploiement du serveur de base de données
cat > db-cloud-init.yaml << 'EOF'
#cloud-config
runcmd:
  - apt-get update
  - apt-get install -y mariadb-server
  - systemctl enable mariadb
  - systemctl start mariadb
  - mysql -e "CREATE DATABASE appdb;"
  - echo "DB_READY" > /tmp/db-status
EOF

echo "📦 Création du serveur DB..."
openstack server create \
    --image ${IMAGE} \
    --flavor m1.medium \
    --network ${NETWORK} \
    --user-data db-cloud-init.yaml \
    ${PROJECT}-db &

# 2. Déploiement du serveur Redis
cat > redis-cloud-init.yaml << 'EOF'
#cloud-config
runcmd:
  - apt-get update
  - apt-get install -y redis-server
  - sed -i 's/bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf
  - systemctl enable redis-server
  - systemctl restart redis-server
EOF

echo "📦 Création du serveur Redis..."
openstack server create \
    --image ${IMAGE} \
    --flavor m1.small \
    --network ${NETWORK} \
    --user-data redis-cloud-init.yaml \
    ${PROJECT}-redis &

# 3. Déploiement des serveurs d'application
cat > app-cloud-init.yaml << 'EOF'
#cloud-config
package_update: true
packages:
  - nginx
  - python3-pip
  - git
runcmd:
  - pip3 install flask gunicorn
  - systemctl enable nginx
  - systemctl start nginx
EOF

for i in {1..3}; do
    echo "📦 Création du serveur APP-${i}..."
    openstack server create \
        --image ${IMAGE} \
        --flavor m1.small \
        --network ${NETWORK} \
        --user-data app-cloud-init.yaml \
        ${PROJECT}-app-$(printf "%02d" $i) &
done

# Attendre tous les déploiements
wait

echo -e "\n✅ Cluster déployé avec succès!"
echo "Liste des instances :"
openstack server list --name ${PROJECT}

# Afficher les IPs
echo -e "\n📋 Configuration du cluster :"
DB_IP=$(openstack server show ${PROJECT}-db -f value -c addresses | cut -d'=' -f2)
REDIS_IP=$(openstack server show ${PROJECT}-redis -f value -c addresses | cut -d'=' -f2)

echo "Database: ${DB_IP}:3306"
echo "Redis: ${REDIS_IP}:6379"
echo "App servers:"
for i in {1..3}; do
    APP_IP=$(openstack server show ${PROJECT}-app-$(printf "%02d" $i) -f value -c addresses | cut -d'=' -f2)
    echo "  - App-${i}: ${APP_IP}"
done
```

**Exécution :**
```bash
chmod +x deploy-app-cluster.sh
./deploy-app-cluster.sh
```

---

## Bonnes pratiques d'automatisation

### ✅ À faire
- **Idempotence** : Les scripts doivent pouvoir être exécutés plusieurs fois sans effets de bord
- **Gestion des erreurs** : Utiliser `set -e` et vérifier les retours de commandes
- **Logging** : Enregistrer toutes les actions dans des logs
- **Variables** : Externaliser la configuration dans des fichiers séparés
- **Validation** : Vérifier que les ressources sont bien créées avant de continuer
- **Nettoyage** : Prévoir des scripts de suppression des ressources

### ❌ À éviter
- Mots de passe en clair dans les scripts (utiliser des variables d'environnement)
- Scripts monolithiques (découper en fonctions réutilisables)
- Pas de gestion d'erreur
- Déploiements séquentiels quand on peut paralléliser

### Exemple de script robuste

```bash
#!/bin/bash
set -euo pipefail  # Arrêt sur erreur, variables non définies, erreurs de pipe

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${SCRIPT_DIR}/deployment.log"
readonly CONFIG_FILE="${SCRIPT_DIR}/config.env"

# Fonctions
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

error() {
    log "ERROR: $*" >&2
    exit 1
}

check_prerequisites() {
    command -v openstack >/dev/null 2>&1 || error "OpenStack CLI not found"
    [[ -f "${CONFIG_FILE}" ]] || error "Config file not found"
    source "${CONFIG_FILE}"
}

cleanup() {
    log "Nettoyage en cas d'erreur..."
    # Votre code de nettoyage ici
}

trap cleanup ERR

# Main
main() {
    log "Début du déploiement"
    check_prerequisites
    
    # Votre code de déploiement ici
    
    log "Déploiement terminé avec succès"
}

main "$@"
```

---

## Ressources complémentaires

### Documentation
- [Heat Template Guide](https://docs.openstack.org/heat/latest/template_guide/)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [OpenStack CLI Reference](https://docs.openstack.org/python-openstackclient/latest/)

### Outils avancés
- **Terraform** : Infrastructure as Code multi-cloud
- **Ansible** : Automatisation de configuration
- **Packer** : Création d'images personnalisées

---

## Questions de validation

1. Quelle est la différence entre déployer avec un script Bash et avec Heat ?
2. À quoi sert cloud-init et à quel moment est-il exécuté ?
3. Comment déployer 10 instances identiques en parallèle ?
4. Quel est l'avantage d'utiliser des templates Heat plutôt que des scripts ?
5. Comment passer des variables à un template Heat lors du déploiement ?
