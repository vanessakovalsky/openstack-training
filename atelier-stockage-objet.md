# TP OpenStack Swift - Stockage Objet avec DevStack

## Objectifs du TP
- Activer et configurer Swift dans DevStack
- Comprendre les concepts du stockage objet Swift
- Manipuler des conteneurs et des objets via CLI
- Gérer les permissions et métadonnées

**Durée estimée :** 1 heure

---

## Partie 0 : Activation de Swift dans DevStack (15 min)

### Étape 0.1 : Vérifier l'état actuel de Swift

```bash
cd ~/devstack
source openrc admin admin
openstack service list | grep swift
```

**Si Swift n'apparaît pas**, vous devez l'activer.

### Étape 0.2 : Arrêter DevStack (si déjà démarré)

```bash
cd ~/devstack
./unstack.sh
```

### Étape 0.3 : Modifier le fichier local.conf

```bash
cd ~/devstack
nano local.conf
```

Ajoutez les lignes suivantes dans la section appropriée (après `[[local|localrc]]`) :

```ini
# Activer Swift
enable_service s-proxy s-object s-container s-account

# Configuration Swift
SWIFT_HASH=secret_hash_value_change_me
SWIFT_REPLICAS=1
SWIFT_DATA_DIR=$DEST/data/swift
```

**Explication des services :**
- `s-proxy` : Service proxy Swift (point d'entrée API)
- `s-object` : Service de stockage d'objets
- `s-container` : Service de gestion des conteneurs
- `s-account` : Service de gestion des comptes

Sauvegardez avec `Ctrl+O`, `Entrée`, puis `Ctrl+X`.

### Étape 0.4 : Relancer DevStack

```bash
./stack.sh
```

**Attention :** Cette opération peut prendre 10-15 minutes.

### Étape 0.5 : Vérifier l'installation de Swift

```bash
source openrc admin admin
openstack service list | grep swift
openstack endpoint list | grep swift
```

**Résultat attendu :** Vous devez voir le service "swift" avec ses endpoints (public, internal, admin).

### Étape 0.6 : Tester l'accès à Swift

```bash
openstack object store account show
```

**Résultat attendu :** Des informations sur votre compte Swift (0 conteneurs, 0 objets au démarrage).

---

## Partie 1 : Premiers pas avec Swift (15 min)

### Étape 1.1 : Créer vos premiers conteneurs

```bash
openstack container create formation
openstack container create images
openstack container create documents
```

### Étape 1.2 : Lister les conteneurs

```bash
openstack container list
```

### Étape 1.3 : Créer des fichiers de test

```bash
mkdir ~/swift-tp
cd ~/swift-tp

echo "Bienvenue dans Swift!" > test1.txt
echo "Formation OpenStack" > test2.txt
dd if=/dev/urandom of=fichier-5mo.bin bs=1M count=5
```

### Étape 1.4 : Uploader des objets

```bash
openstack object create formation test1.txt
openstack object create formation test2.txt
openstack object create documents fichier-5mo.bin
```

### Étape 1.5 : Lister les objets d'un conteneur

```bash
openstack object list formation
openstack object list documents
```

### Étape 1.6 : Afficher les détails d'un objet

```bash
openstack object show formation test1.txt
```

**Question :** Quelle est la taille de l'objet ? Quel est son ETag ?

### Étape 1.7 : Télécharger un objet

```bash
openstack object save formation test1.txt --file test1-copie.txt
cat test1-copie.txt
```

---

## Partie 2 : Métadonnées et propriétés (10 min)

### Étape 2.1 : Ajouter des métadonnées à un conteneur

```bash
openstack container set --property Projet=Formation --property Environnement=TP images
```

### Étape 2.2 : Vérifier les métadonnées

```bash
openstack container show images
```

### Étape 2.3 : Uploader un objet avec métadonnées

```bash
openstack object create images test1.txt \
  --property Auteur=Stagiaire \
  --property Type=Demo \
  --property Date=2024-12-17
```

### Étape 2.4 : Consulter les métadonnées de l'objet

```bash
openstack object show images test1.txt
```

### Étape 2.5 : Vérifier l'utilisation du compte

```bash
openstack object store account show
```

**Observation :** Notez le nombre de conteneurs, d'objets et l'espace utilisé.

---

## Partie 3 : Gestion des permissions (10 min)

### Étape 3.1 : Créer un conteneur public

```bash
openstack container create demo-public
openstack container set --property read=.r:*,.rlistings demo-public
```

**Explication :** 
- `.r:*` = lecture autorisée pour tous
- `.rlistings` = listing du conteneur autorisé

### Étape 3.2 : Uploader un fichier HTML

```bash
echo "<h1>Page publique Swift</h1><p>Ceci est accessible sans authentification</p>" > index.html
openstack object create demo-public index.html
```

### Étape 3.3 : Obtenir l'URL de l'objet

```bash
PROJET_ID=$(openstack token issue -f value -c project_id)
SWIFT_URL=$(openstack catalog show swift -f value -c endpoints | grep public | awk '{print $2}')

echo "${SWIFT_URL}/demo-public/index.html"
```

### Étape 3.4 : Tester l'accès public

```bash
curl http://localhost:8080/v1/AUTH_${PROJET_ID}/demo-public/index.html
```

**Résultat attendu :** Le contenu HTML doit s'afficher sans authentification.

### Étape 3.5 : Retirer l'accès public

```bash
openstack container unset --property read demo-public
```

### Étape 3.6 : Vérifier la restriction

```bash
curl http://localhost:8080/v1/AUTH_${PROJET_ID}/demo-public/index.html
```

**Résultat attendu :** Erreur 401 ou 403.

---

## Partie 4 : Manipulation avancée (10 min)

### Étape 4.1 : Créer un fichier volumineux

```bash
dd if=/dev/urandom of=gros-fichier.bin bs=1M count=20
```

### Étape 4.2 : Uploader avec segmentation automatique

```bash
openstack object create documents gros-fichier.bin --segment-size 5242880
```

**Explication :** Le fichier est divisé en segments de 5 Mo.

### Étape 4.3 : Observer les segments

```bash
openstack container list
openstack object list documents
openstack object list documents_segments
```

**Observation :** Un conteneur `documents_segments` a été créé automatiquement pour stocker les morceaux.

### Étape 4.4 : Utiliser l'API REST

Obtenir un token et l'URL Swift :

```bash
export OS_TOKEN=$(openstack token issue -f value -c id)
export SWIFT_URL=$(openstack catalog show swift -f value -c endpoints | grep public | awk '{print $2}')
```

### Étape 4.5 : Lister via API

```bash
curl -X GET -H "X-Auth-Token: $OS_TOKEN" $SWIFT_URL
```

### Étape 4.6 : Créer un conteneur via API

```bash
curl -X PUT -H "X-Auth-Token: $OS_TOKEN" $SWIFT_URL/api-test
```

### Étape 4.7 : Uploader via API

```bash
curl -X PUT -H "X-Auth-Token: $OS_TOKEN" \
     -H "Content-Type: text/plain" \
     --data "Créé via API REST" \
     $SWIFT_URL/api-test/fichier-api.txt
```

### Étape 4.8 : Vérifier avec CLI

```bash
openstack container list
openstack object list api-test
```

---

## Exercice pratique final (10 min)

**Scénario :** Vous devez créer un système de stockage pour des logs d'application.

**Consignes :**

1. Créer un conteneur nommé `logs-app`
2. Créer 3 fichiers de logs simulés :
```bash
echo "2024-12-17 10:00:00 INFO Application démarrée" > app-2024-12-17.log
echo "2024-12-17 11:30:00 ERROR Erreur de connexion" >> app-2024-12-17.log
echo "2024-12-17 14:15:00 INFO Traitement terminé" >> app-2024-12-17.log

echo "2024-12-16 09:00:00 INFO Application démarrée" > app-2024-12-16.log
echo "2024-12-15 09:00:00 INFO Application démarrée" > app-2024-12-15.log
```

3. Uploader ces fichiers avec des métadonnées appropriées (date, type, application)
4. Afficher la liste des logs
5. Récupérer le log du 17 décembre

**Solution suggérée :**

```bash
# 1. Créer le conteneur
openstack container create logs-app

# 2 & 3. Uploader avec métadonnées
openstack object create logs-app app-2024-12-17.log \
  --property Date=2024-12-17 \
  --property Type=log \
  --property App=DemoApp

openstack object create logs-app app-2024-12-16.log \
  --property Date=2024-12-16 \
  --property Type=log \
  --property App=DemoApp

openstack object create logs-app app-2024-12-15.log \
  --property Date=2024-12-15 \
  --property Type=log \
  --property App=DemoApp

# 4. Lister
openstack object list logs-app

# 5. Récupérer
openstack object save logs-app app-2024-12-17.log
cat app-2024-12-17.log
```

---

## Nettoyage (facultatif)

```bash
# Supprimer les objets
openstack object delete formation test1.txt
openstack object delete formation test2.txt
openstack object delete documents fichier-5mo.bin
openstack object delete documents gros-fichier.bin

# Supprimer les conteneurs
openstack container delete formation
openstack container delete images
openstack container delete documents
openstack container delete demo-public
openstack container delete api-test
openstack container delete logs-app

# Vérifier
openstack container list
```

---

## Points clés à retenir

✅ **Swift = Stockage objet distribué**
- Pas de hiérarchie de dossiers (seulement conteneurs et objets)
- Identifiant unique par objet
- Métadonnées personnalisables

✅ **Architecture :**
- Compte → Conteneurs → Objets
- API REST standard

✅ **Cas d'usage :**
- Stockage de fichiers média (images, vidéos)
- Backups et archives
- Logs applicatifs
- Contenu statique de sites web

✅ **Différences avec Cinder (stockage bloc) :**
- Swift : objets immuables, accès HTTP, scalabilité horizontale
- Cinder : volumes, accès bloc, attachés aux instances

---

## Questions de débriefing

1. Quelle est la différence entre un conteneur et un objet ?
2. Pourquoi utiliser des métadonnées ?
3. Dans quels cas rendre un conteneur public ?
4. Comment Swift gère-t-il les gros fichiers ?
5. Quels sont les avantages de l'API REST ?

**Félicitations ! Vous savez maintenant utiliser Swift !**

---

## Ressources complémentaires

- Documentation officielle Swift : https://docs.openstack.org/swift/
- Swift API Reference : https://docs.openstack.org/api-ref/object-store/
- OpenStack Client Commands : https://docs.openstack.org/python-openstackclient/
