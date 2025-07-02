# Atelier - Administration OpenStack

#### 🛠️ Atelier 1 : Administration via Horizon 

**Objectif :** Maîtriser l'interface Horizon pour les tâches d'administration courantes.

**Étapes :**
1. **Connexion à Horizon** (2 minutes)
   - Accéder à http://controller/horizon
   - Se connecter avec les identifiants admin

2. **Gestion des projets** (3 minutes)
   - Créer un nouveau projet "Formation"
   - Ajouter un utilisateur au projet
   - Configurer les quotas

3. **Gestion des instances** (4 minutes)
   - Créer une nouvelle instance
   - Associer une IP flottante
   - Créer un snapshot

4. **Monitoring** (3 minutes)
   - Consulter les métriques d'utilisation
   - Vérifier les logs
   - Analyser la topologie réseau

#### 🛠️ Atelier 2 : Automatisation avec Cloud-init 

**Objectif :** Déployer automatiquement un serveur web avec Cloud-init.

**Préparation :**
```yaml
#cloud-config
hostname: webserver-auto
fqdn: webserver-auto.local

users:
  - name: webadmin
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh-authorized-keys:
      - ssh-rsa VOTRE_CLE_PUBLIQUE

packages:
  - apache2
  - mysql-server

runcmd:
  - systemctl enable apache2
  - systemctl start apache2
  - systemctl enable mysql
  - systemctl start mysql

write_files:
  - path: /var/www/html/info.php
    content: |
      <?php
      phpinfo();
      ?>
  - path: /var/www/html/index.html
    content: |
      <!DOCTYPE html>
      <html>
      <head><title>Serveur Auto-déployé</title></head>
      <body>
        <h1>Serveur déployé automatiquement</h1>
        <p>Déployé le: $(date)</p>
        <a href="info.php">PHP Info</a>
      </body>
      </html>
```

**Étapes pratiques :**
1. **Création via Horizon** 
   - Aller dans Project > Compute > Instances
   - Cliquer sur "Launch Instance"
   - Coller le cloud-config dans "Configuration"

2. **Création via CLI** 
   ```bash
   # Sauvegarder le cloud-config
   cat > user-data.yaml << 'EOF'
   [contenu yaml ci-dessus]
   EOF
   
   # Lancer l'instance
   openstack server create \
     --image ubuntu-20.04 \
     --flavor m1.small \
     --network private \
     --user-data user-data.yaml \
     webserver-auto
   ```

3. **Vérification** (4 minutes)
   - Attendre le démarrage complet
   - Se connecter en SSH
   - Vérifier les services : `systemctl status apache2`
   - Tester l'accès web
  

