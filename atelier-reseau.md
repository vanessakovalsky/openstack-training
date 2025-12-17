# Atelier Réseau

### Objectif
Créer une infrastructure réseau complète avec réseaux provider et self-service, puis tester la connectivité.

### Prérequis
- Accès à un environnement OpenStack
- Droits administrateur
- Client OpenStack CLI configuré

### Atelier 1 : Création d'un réseau provider (5 minutes)

```bash
# 1. Créer le réseau provider
openstack network create --share  external-network

# 2. Créer le sous-réseau externe
openstack subnet create --network external-network \
  --allocation-pool start=192.168.100.100,end=192.168.100.200 \
  --dns-nameserver 8.8.8.8 \
  --gateway 192.168.100.1 \
  --subnet-range 192.168.100.0/24 external-subnet

# 3. Vérifier la création
openstack network list
openstack subnet list
```
-> Sur un environnement virtualisé, la création du réseau de type provider n'est pas possible. Cela nécessiterait de disposer d'un réseau dédié branché sur la VM, ce n'est pas le cas dans les environnements de formation fournis

### Atelier 2 : Création d'un réseau self-service (5 minutes)

```bash
# 1. Créer le réseau tenant
openstack network create internal-network

# 2. Créer le sous-réseau interne
openstack subnet create --network internal-network \
  --dns-nameserver 8.8.8.8 \
  --gateway 172.16.1.1 \
  --subnet-range 172.16.1.0/24 internal-subnet

# 3. Créer un routeur
openstack router create main-router

# 4. Connecter le routeur aux réseaux
openstack router set main-router --external-gateway public
openstack router add subnet main-router internal-subnet

# 5. Vérifier la configuration
openstack router show main-router
```

### Atelier 3 : Test de connectivité (5 minutes)

```bash
# 1. Créer une instance de test # Adapter le nom de l'image aux images disponibles dans votre environnement
openstack server create --flavor m1.tiny --image cirros \
  --network internal-network test-vm

# 2. Créer et associer une floating IP
openstack floating ip create public
FLOATING_IP=$(openstack floating ip list -f value -c "Floating IP Address" | head -1)
openstack server add floating ip test-vm $FLOATING_IP

# 3. Tester la connectivité
ping $FLOATING_IP

# 4. Vérifier les namespaces réseau
sudo ip netns list
sudo ip netns exec qrouter-<router-id> ip route show
```

### Questions de validation

1. **Quels sont les avantages d'utiliser des réseaux self-service par rapport aux réseaux provider ?**

2. **Comment vérifier qu'un routeur Neutron fonctionne correctement ?**

3. **Que se passe-t-il au niveau d'Open vSwitch quand une VM envoie un paquet vers Internet ?**
