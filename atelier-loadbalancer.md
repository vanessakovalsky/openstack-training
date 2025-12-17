# TP OpenStack Octavia - Load Balancer

## Objectifs du TP
- Comprendre le fonctionnement d'un load balancer (répartiteur de charge)
- Déployer un load balancer avec Octavia
- Configurer des health checks pour la haute disponibilité
- Tester le basculement automatique en cas de panne

**Durée estimée :** 1h30

---

## Partie 0 : Préparation de l'environnement (20 min)

### Étape 0.1 : Vérifier Octavia dans DevStack

```bash
cd ~/devstack
source openrc admin admin
openstack service list | grep octavia
```

**Si Octavia n'apparaît pas**, vous devez l'activer.

### Étape 0.2 : Activer Octavia (si nécessaire)

Arrêter DevStack :
```bash
cd ~/devstack
./unstack.sh
```

Modifier `local.conf` :
```bash
nano local.conf
```

Ajouter ces lignes :
```ini
# Activer Octavia
enable_plugin octavia https://opendev.org/openstack/octavia
enable_service octavia o-cw o-hk o-hm o-api
```

Relancer DevStack :
```bash
./stack.sh
```

### Étape 0.3 : Créer le réseau et le routeur

```bash
# Créer un réseau privé
openstack network create reseau-lb

# Créer un sous-réseau
openstack subnet create --network reseau-lb \
  --subnet-range 192.168.100.0/24 \
  --dns-nameserver 8.8.8.8 \
  subnet-lb

# Créer un routeur
openstack router create routeur-lb

# Connecter le routeur au réseau externe
openstack router set routeur-lb --external-gateway public

# Connecter le routeur au sous-réseau privé
openstack router add subnet routeur-lb subnet-lb
```

### Étape 0.4 : Créer un groupe de sécurité

```bash
# Créer le groupe de sécurité
openstack security group create sg-web

# Autoriser SSH
openstack security group rule create --protocol tcp \
  --dst-port 22 sg-web

# Autoriser HTTP
openstack security group rule create --protocol tcp \
  --dst-port 80 sg-web

# Autoriser ICMP (ping)
openstack security group rule create --protocol icmp sg-web
```

### Étape 0.5 : Créer une paire de clés SSH

```bash
openstack keypair create --public-key ~/.ssh/id_rsa.pub ma-cle
```

**Si vous n'avez pas de clé SSH :**
```bash
ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
openstack keypair create --public-key ~/.ssh/id_rsa.pub ma-cle
```

### Étape 0.6 : Créer un script cloud-init pour nginx

```bash
cat > cloud-init-nginx.sh << 'EOF'
#!/bin/bash
apt-get update
apt-get install -y nginx
HOSTNAME=$(hostname)
IP=$(hostname -I | awk '{print $1}')
cat > /var/www/html/index.html << HTML
<!DOCTYPE html>
<html>
<head>
    <title>Load Balancer Test</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            padding: 50px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            background: rgba(255,255,255,0.1);
            padding: 30px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        h1 { font-size: 48px; margin: 0; }
        .info { font-size: 24px; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Serveur Web</h1>
        <div class="info">
            <p><strong>Hostname:</strong> ${HOSTNAME}</p>
            <p><strong>IP:</strong> ${IP}</p>
            <p><strong>Date:</strong> <span id="date"></span></p>
        </div>
    </div>
    <script>
        document.getElementById('date').textContent = new Date().toLocaleString();
        setInterval(() => {
            document.getElementById('date').textContent = new Date().toLocaleString();
        }, 1000);
    </script>
</body>
</html>
HTML
systemctl restart nginx
EOF
```

### Étape 0.7 : Déployer deux instances web

```bash
# Récupérer l'ID de l'image Ubuntu
IMAGE_ID=$(openstack image list -f value -c ID -c Name | grep -i ubuntu | head -1 | awk '{print $1}')

# Créer la première instance
openstack server create \
  --flavor m1.small \
  --image $IMAGE_ID \
  --network reseau-lb \
  --security-group sg-web \
  --key-name ma-cle \
  --user-data cloud-init-nginx.sh \
  web-server-1

# Créer la deuxième instance
openstack server create \
  --flavor m1.small \
  --image $IMAGE_ID \
  --network reseau-lb \
  --security-group sg-web \
  --key-name ma-cle \
  --user-data cloud-init-nginx.sh \
  web-server-2
```

### Étape 0.8 : Attendre le démarrage des instances

```bash
# Vérifier l'état des instances
watch -n 5 'openstack server list'
```

**Attendez que les deux instances soient en statut ACTIVE** (Ctrl+C pour quitter).

```bash
# Vérifier que nginx est démarré (attendre 2-3 minutes)
sleep 180
```

### Étape 0.9 : Récupérer les adresses IP des instances

```bash
# Lister les serveurs avec leurs IPs
openstack server list --name web-server

# Récupérer les IPs dans des variables
SERVER1_IP=$(openstack server show web-server-1 -f value -c addresses | cut -d'=' -f2)
SERVER2_IP=$(openstack server show web-server-2 -f value -c addresses | cut -d'=' -f2)

echo "Serveur 1 : $SERVER1_IP"
echo "Serveur 2 : $SERVER2_IP"
```

---

## Partie 1 : Création du Load Balancer (15 min)

### Étape 1.1 : Créer le load balancer

```bash
openstack loadbalancer create \
  --name mon-load-balancer \
  --vip-subnet-id subnet-lb
```

**Note :** La création du load balancer prend quelques minutes.

### Étape 1.2 : Surveiller la création

```bash
watch -n 5 'openstack loadbalancer show mon-load-balancer -c provisioning_status -c operating_status'
```

**Attendez que le `provisioning_status` soit `ACTIVE`** (Ctrl+C pour quitter).

### Étape 1.3 : Récupérer l'adresse VIP du load balancer

```bash
LB_VIP=$(openstack loadbalancer show mon-load-balancer -f value -c vip_address)
echo "Adresse VIP du Load Balancer : $LB_VIP"
```

### Étape 1.4 : Afficher les détails du load balancer

```bash
openstack loadbalancer show mon-load-balancer
```

**Observation :** Notez le `vip_address`, le `vip_port_id`, et les statuts.

---

## Partie 2 : Configuration du Listener (10 min)

### Étape 2.1 : Créer un listener HTTP

```bash
openstack loadbalancer listener create \
  --name listener-http \
  --protocol HTTP \
  --protocol-port 80 \
  mon-load-balancer
```

### Étape 2.2 : Vérifier le statut

```bash
# Attendre que le LB soit à nouveau ACTIVE
watch -n 5 'openstack loadbalancer show mon-load-balancer -c provisioning_status'
```

### Étape 2.3 : Afficher les détails du listener

```bash
openstack loadbalancer listener show listener-http
```

---

## Partie 3 : Création du Pool (10 min)

### Étape 3.1 : Créer un pool avec algorithme ROUND_ROBIN

```bash
openstack loadbalancer pool create \
  --name mon-pool-web \
  --lb-algorithm ROUND_ROBIN \
  --listener listener-http \
  --protocol HTTP
```

**Explication des algorithmes disponibles :**
- `ROUND_ROBIN` : Distribution équitable en rotation
- `LEAST_CONNECTIONS` : Vers le serveur avec le moins de connexions
- `SOURCE_IP` : Basé sur l'IP source (affinité de session)

### Étape 3.2 : Attendre que le pool soit actif

```bash
watch -n 5 'openstack loadbalancer show mon-load-balancer -c provisioning_status'
```

### Étape 3.3 : Afficher les détails du pool

```bash
openstack loadbalancer pool show mon-pool-web
```

---

## Partie 4 : Ajout des Members (15 min)

### Étape 4.1 : Ajouter la première instance au pool

```bash
openstack loadbalancer member create \
  --subnet-id subnet-lb \
  --address $SERVER1_IP \
  --protocol-port 80 \
  --name member-web-1 \
  mon-pool-web
```

### Étape 4.2 : Attendre la synchronisation

```bash
watch -n 5 'openstack loadbalancer show mon-load-balancer -c provisioning_status'
```

### Étape 4.3 : Ajouter la deuxième instance au pool

```bash
openstack loadbalancer member create \
  --subnet-id subnet-lb \
  --address $SERVER2_IP \
  --protocol-port 80 \
  --name member-web-2 \
  mon-pool-web
```

### Étape 4.4 : Attendre la synchronisation

```bash
watch -n 5 'openstack loadbalancer show mon-load-balancer -c provisioning_status'
```

### Étape 4.5 : Lister les members du pool

```bash
openstack loadbalancer member list mon-pool-web
```

**Résultat attendu :** Vous devez voir vos deux membres avec leur adresse IP et leur statut.

---

## Partie 5 : Configuration du Health Monitor (10 min)

### Étape 5.1 : Créer un health monitor HTTP

```bash
openstack loadbalancer healthmonitor create \
  --name health-check-http \
  --delay 5 \
  --max-retries 3 \
  --timeout 5 \
  --type HTTP \
  --url-path / \
  mon-pool-web
```

**Explication des paramètres :**
- `--delay 5` : Vérification toutes les 5 secondes
- `--max-retries 3` : 3 échecs avant de marquer le serveur DOWN
- `--timeout 5` : Timeout de 5 secondes par vérification
- `--url-path /` : Chemin à vérifier (page d'accueil)

### Étape 5.2 : Attendre la synchronisation

```bash
watch -n 5 'openstack loadbalancer show mon-load-balancer -c provisioning_status'
```

### Étape 5.3 : Afficher les détails du health monitor

```bash
openstack loadbalancer healthmonitor show health-check-http
```

### Étape 5.4 : Vérifier l'état des members

```bash
openstack loadbalancer member list mon-pool-web
```

**Observation :** Le `operating_status` des members devrait passer à `ONLINE` après quelques vérifications réussies.

---

## Partie 6 : Association d'une IP Flottante (10 min)

### Étape 6.1 : Récupérer le port VIP du load balancer

```bash
VIP_PORT_ID=$(openstack loadbalancer show mon-load-balancer -f value -c vip_port_id)
echo "Port ID : $VIP_PORT_ID"
```

### Étape 6.2 : Créer une IP flottante

```bash
openstack floating ip create public
```

### Étape 6.3 : Récupérer l'adresse IP flottante

```bash
FLOATING_IP=$(openstack floating ip list --status DOWN -f value -c "Floating IP Address" | head -1)
echo "IP Flottante : $FLOATING_IP"
```

### Étape 6.4 : Associer l'IP flottante au load balancer

```bash
openstack floating ip set --port $VIP_PORT_ID $FLOATING_IP
```

### Étape 6.5 : Vérifier l'association

```bash
openstack floating ip show $FLOATING_IP
```

---

## Partie 7 : Tests du Load Balancing (15 min)

### Étape 7.1 : Tester l'accès au load balancer

```bash
curl http://$FLOATING_IP
```

**Résultat attendu :** Vous devriez voir la page HTML avec le hostname et l'IP d'un des serveurs.

### Étape 7.2 : Tester la distribution ROUND_ROBIN

```bash
# Faire 10 requêtes
for i in {1..10}; do
  echo "=== Requête $i ==="
  curl -s http://$FLOATING_IP | grep -E "Hostname|IP"
  sleep 1
done
```

**Observation :** Les requêtes doivent alterner entre web-server-1 et web-server-2.

### Étape 7.3 : Surveiller les connexions en temps réel

Ouvrir un nouveau terminal et exécuter :
```bash
cd ~/devstack
source openrc admin admin
watch -n 2 'openstack loadbalancer member list mon-pool-web'
```

**Observation :** Vous verrez les statistiques des membres (connexions actives, totales, etc.).

### Étape 7.4 : Générer du trafic continu

Dans le premier terminal :
```bash
while true; do
  curl -s http://$FLOATING_IP | grep "Hostname"
  sleep 1
done
```

**Laissez tourner pour observer la distribution.**

---

## Partie 8 : Test de Haute Disponibilité (15 min)

### Étape 8.1 : Vérifier l'état initial des members

```bash
openstack loadbalancer member list mon-pool-web
```

**Les deux membres doivent être `ONLINE`.**

### Étape 8.2 : Arrêter la première instance

Ouvrir un nouveau terminal :
```bash
cd ~/devstack
source openrc admin admin
openstack server stop web-server-1
```

### Étape 8.3 : Observer le health check

Dans le terminal de surveillance :
```bash
watch -n 2 'openstack loadbalancer member list mon-pool-web'
```

**Observation :** Après 3 échecs consécutifs (environ 15-20 secondes), le member-web-1 passera à `ERROR` ou `OFFLINE`.

### Étape 8.4 : Vérifier que le trafic continue

Le trafic doit maintenant être dirigé uniquement vers web-server-2 :
```bash
for i in {1..10}; do
  echo "=== Requête $i ==="
  curl -s http://$FLOATING_IP | grep "Hostname"
  sleep 1
done
```

**Résultat attendu :** Toutes les requêtes vont vers web-server-2.

### Étape 8.5 : Redémarrer la première instance

```bash
openstack server start web-server-1
```

### Étape 8.6 : Attendre la récupération

```bash
# Attendre que l'instance soit active
sleep 60

# Surveiller le health check
watch -n 2 'openstack loadbalancer member list mon-pool-web'
```

**Observation :** Après quelques vérifications réussies, member-web-1 repassera à `ONLINE` et recevra à nouveau du trafic.

### Étape 8.7 : Vérifier le retour à la normale

```bash
for i in {1..10}; do
  echo "=== Requête $i ==="
  curl -s http://$FLOATING_IP | grep "Hostname"
  sleep 1
done
```

**Le load balancing ROUND_ROBIN doit reprendre entre les deux serveurs.**

---

## Partie 9 : Tests avancés (bonus)

### Test 9.1 : Simuler une panne nginx

```bash
# Se connecter à web-server-1
ssh ubuntu@$(openstack server show web-server-1 -f value -c addresses | cut -d'=' -f2)

# Arrêter nginx
sudo systemctl stop nginx

# Quitter
exit
```

Observer le comportement du health check et du load balancer.

### Test 9.2 : Modifier l'algorithme du pool

```bash
openstack loadbalancer pool set \
  --lb-algorithm LEAST_CONNECTIONS \
  mon-pool-web
```

Testez la différence de comportement.

### Test 9.3 : Ajouter un poids aux members

```bash
openstack loadbalancer member set \
  --weight 2 \
  mon-pool-web member-web-1

openstack loadbalancer member set \
  --weight 1 \
  mon-pool-web member-web-2
```

**Résultat :** web-server-1 recevra 2x plus de trafic que web-server-2.

---

## Nettoyage

### Supprimer le load balancer (suppression en cascade)

```bash
openstack loadbalancer delete --cascade mon-load-balancer
```

**Attention :** Cela supprime le LB, le listener, le pool, les members et le health monitor.

### Supprimer les instances

```bash
openstack server delete web-server-1
openstack server delete web-server-2
```

### Libérer l'IP flottante

```bash
openstack floating ip delete $FLOATING_IP
```

### Supprimer le réseau (optionnel)

```bash
openstack router remove subnet routeur-lb subnet-lb
openstack router delete routeur-lb
openstack subnet delete subnet-lb
openstack network delete reseau-lb
```

---

## Points clés à retenir

✅ **Architecture du Load Balancer :**
- **Load Balancer** : Point d'entrée avec VIP
- **Listener** : Écoute sur un port/protocole
- **Pool** : Groupe de serveurs backend
- **Members** : Serveurs individuels dans le pool
- **Health Monitor** : Surveillance de la santé des membres

✅ **Algorithmes de distribution :**
- `ROUND_ROBIN` : Rotation équitable
- `LEAST_CONNECTIONS` : Charge la moins connectée
- `SOURCE_IP` : Affinité de session

✅ **Health Checks :**
- Détection automatique des pannes
- Retrait automatique des membres défaillants
- Réintégration automatique après récupération

✅ **Haute Disponibilité :**
- Pas d'interruption de service lors d'une panne
- Basculement automatique transparent
- Répartition de charge optimale

---

## Questions de débriefing

1. Quelle est la différence entre un load balancer Layer 4 (TCP) et Layer 7 (HTTP) ?
2. Pourquoi est-il important d'avoir un health monitor ?
3. Quel algorithme choisir pour une application avec sessions utilisateur ?
4. Comment éviter le split-brain dans un load balancer ?
5. Quels sont les cas d'usage typiques d'un load balancer ?

---

## Exercice final : Configuration avancée

**Défi :** Créer un load balancer HTTPS avec :
- Certificat SSL/TLS
- Redirection HTTP → HTTPS
- Cookie de session pour l'affinité
- Health check sur une URL spécifique (/health)

---

## Ressources complémentaires

- Documentation Octavia : https://docs.openstack.org/octavia/latest/
- API Reference : https://docs.openstack.org/api-ref/load-balancer/
- Best Practices : https://docs.openstack.org/octavia/latest/user/guides/basic-cookbook.html

**Félicitations ! Vous maîtrisez maintenant les load balancers avec Octavia !**
