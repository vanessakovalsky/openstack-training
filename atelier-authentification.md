# Atelier Authentification

### 🎯 Objectifs pratiques
- Créer une structure organisationnelle complète
- Configurer l'authentification multi-domaines
- Tester les autorisations et permissions
- Gérer le catalogue de services

### 🛠️ Atelier 1 : Création d'une structure organisationnelle (15 minutes)

#### Scénario
Vous devez créer une structure pour une entreprise fictive "TechCorp" avec plusieurs départements.

#### Étapes à réaliser


1. **Créer les utilisateurs**
```bash
# Configurer le compte admin

source /home/stack/devstack/openrc admin admin

# Administrateur système
openstack user create --domain default --password SecurePass123 --email admin@techcorp.com admin-tc

# Développeur
openstack user create --domain default --password DevPass123 --email dev@techcorp.com dev-tc

# Utilisateur partenaire
openstack user create --domain default --password PartnerPass123 --email partner@external.com partner-user
```

2. **Créer les projets**
```bash
# Projet production
openstack project create --domain default --description "Environnement de production" production

# Projet développement
openstack project create --domain default --description "Environnement de développement" development

# Projet test
openstack project create --domain default --description "Environnement de test" testing
```

3. **Créer les rôles personnalisés**
```bash
# Rôle développeur
openstack role create developer

# Rôle testeur
openstack role create tester

# Rôle observateur
openstack role create observer
```

### 🛠️ Atelier 2 : Configuration des autorisations (15 minutes)

#### Assignation des rôles

1. **Administrateur système**
```bash
# Admin sur tous les projets
openstack role add --project production --user admin-tc admin
openstack role add --project development --user admin-tc admin
openstack role add --project testing --user admin-tc admin
```

2. **Développeur**
```bash
# Développeur sur dev et test, observateur sur prod
openstack role add --project development --user dev-tc developer
openstack role add --project testing --user dev-tc developer
openstack role add --project production --user dev-tc observer
```

3. **Partenaire**
```bash
# Accès limité au projet test uniquement
openstack role add --project testing --user partner-user observer
```

#### Vérification des assignations
```bash
# Vérifier les rôles d'un utilisateur
openstack role assignment list --user dev-tc

# Vérifier les rôles sur un projet
openstack role assignment list --project development
```

### 🛠️ Atelier 3 : Gestion du catalogue de services (15 minutes)

#### Créer et configurer des services

1. **Créer un service personnalisé**
```bash
# Créer un service de monitoring
openstack service create --name monitoring --description "Service de monitoring" monitoring

# Créer un service de backup
openstack service create --name backup --description "Service de sauvegarde" backup
```

2. **Créer les endpoints**
```bash
# Endpoints pour le service monitoring
openstack endpoint create --region RegionOne monitoring public http://monitoring.techcorp.com:8080
openstack endpoint create --region RegionOne monitoring internal http://monitoring.internal:8080
openstack endpoint create --region RegionOne monitoring admin http://monitoring.admin:8080

# Endpoints pour le service backup
openstack endpoint create --region RegionOne backup public http://backup.techcorp.com:9090
openstack endpoint create --region RegionOne backup internal http://backup.internal:9090
openstack endpoint create --region RegionOne backup admin http://backup.admin:9090
```

3. **Vérifier le catalogue**
```bash
# Afficher le catalogue de services
openstack catalog list

# Afficher les détails d'un service
openstack catalog show monitoring
```

### 🧪 Tests et validation

#### Test d'authentification
```bash
# Tester l'authentification avec différents utilisateurs
# Créer un fichier RC pour le développeur
cat > dev-openrc.sh << EOF
export OS_PROJECT_DOMAIN_NAME=techcorp
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=development
export OS_USERNAME=dev-tc
export OS_PASSWORD=DevPass123
export OS_IDENTITY_API_VERSION=3
EOF

# Sourcer et tester
source dev-openrc.sh
openstack token issue
openstack project list
```

### 📝 Exercices d'approfondissement

1. **Créer un groupe "Développeurs"** et y ajouter des utilisateurs
2. **Configurer une politique personnalisée** pour limiter les actions des développeurs
3. **Mettre en place l'authentification LDAP** (simulation)
4. **Créer des rôles hiérarchiques** avec héritage

### ✅ Points de contrôle
- [ ] Structure organisationnelle créée
- [ ] Utilisateurs authentifiés avec succès
- [ ] Autorisations configurées correctement
- [ ] Catalogue de services fonctionnel
- [ ] Tests de validation réussis
