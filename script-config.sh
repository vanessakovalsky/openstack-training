#!/bin/bash
set -euo pipefail

# ==========================
# Variables
# ==========================
STACK_USER="stack"
STACK_HOME="/home/$STACK_USER"
DEVSTACK_REPO="https://opendev.org/openstack-dev/devstack"
LOCAL_CONF="$STACK_HOME/devstack/local.conf"
HOST_IP=$(hostname -I | awk '{print $1}')

# ==========================
# 1️⃣ Installer dépendances
# ==========================
sudo apt update -qq
sudo apt install -y git curl libapache2-mod-wsgi-py3 python3-pip net-tools snapd

# Activer mod_wsgi
sudo a2enmod wsgi
sudo systemctl restart apache2 || true

# ==========================
# 2️⃣ Créer l'utilisateur stack si nécessaire
# ==========================
if ! id "$STACK_USER" >/dev/null 2>&1; then
    sudo adduser --disabled-password --gecos "" $STACK_USER
    sudo usermod -aG sudo $STACK_USER
fi

# ==========================
# 3️⃣ Installer LXD via snap si nécessaire
# ==========================
if ! snap list | grep -q '^lxd'; then
    echo "Installation de LXD via snap..."
    sudo snap install lxd
else
    echo "LXD déjà installé"
fi

# Ajouter stack au groupe lxd (prise en compte à la prochaine connexion)
sudo usermod -aG lxd $STACK_USER || true

# ==========================
# 4️⃣ Initialiser LXD uniquement si nécessaire
# ==========================
if ! /snap/bin/lxc info >/dev/null 2>&1; then
    echo "Initialisation automatique de LXD..."
    sudo /snap/bin/lxd init --auto
else
    echo "LXD déjà initialisé"
fi

# ==========================
# 5️⃣ Cloner DevStack si nécessaire
# ==========================
if [ ! -d "$STACK_HOME/devstack" ]; then
    sudo -u $STACK_USER git clone $DEVSTACK_REPO $STACK_HOME/devstack
fi

# ==========================
# 6️⃣ Créer local.conf pour LXD + mod_wsgi
# ==========================
cat <<EOF | sudo tee $LOCAL_CONF > /dev/null
[[local|localrc]]
ADMIN_PASSWORD=password
DATABASE_PASSWORD=password
RABBIT_PASSWORD=password
SERVICE_PASSWORD=password
HOST_IP=$HOST_IP

# LXD comme hyperviseur
VIRT_DRIVER=lxd
LIBVIRT_TYPE=lxd
enable_plugin nova-lxd https://opendev.org/openstack/nova-lxd

# Forcer mod_wsgi pour les services HTTP
USE_UWSGI=False
APACHE_USE_UWSGI=False
ENABLE_HTTPD_MOD_WSGI=True
EOF

sudo chown $STACK_USER:$STACK_USER $LOCAL_CONF

# ==========================
# 7️⃣ Supprimer d’éventuels restes uWSGI
# ==========================
sudo apt remove -y uwsgi uwsgi-core uwsgi-plugin-python3 || true
sudo rm -rf /etc/uwsgi /run/uwsgi /var/run/uwsgi /var/log/uwsgi || true

# ==========================
# 8️⃣ Lancer DevStack
# ==========================
cd $STACK_HOME/devstack
sudo -u $STACK_USER ./stack.sh
