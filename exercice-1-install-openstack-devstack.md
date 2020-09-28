# Installation de l'environnement DevStack

Ce première exercice va nous permettre d'installer Devstack qui est un moyen rapide et facile pour avoir une solution OpenStack installé en local sur son propre pc.

## Pré-requis

* Il est nécessaire d'avoir un hyperviseur de type 1 ou de type 2 d'installé et de fonctionnel sur son poste.
* Par exemple :
** VirtualBox : https://www.oracle.com/fr/virtualization/virtualbox/
* Il est aussi indispensable d'avoir une connexion internet correcte, car le téléchargement des images nécessaires peut prendre du temps 
* Niveau matériel, voici les recommandations d'OpenStack :
**  Au moins 8GB de RAM
** Au moins 10Gb d'espace disque doit être disponible pour faire l'installation

##Création d'un VM dédié
* Dans VirtualBox,créer une nouvelle VM avec les caractéristique suivantes :
** RAM : 8G
** DD : 20 Go (dynamiquement alloué et de type dynamique)
** Os Linux Ubutnu
* Télécharger la dernière version stable d'Ubuntu recommandé par Devstack : http://cdimage.ubuntu.com/releases/18.04/release/ 
* Lancer la machine en insérant le ISO téléchargé puis faire l'installation 

## Installation de DevStack

* Se connecter à la VM en SSH
* Cloner le dépôt git suivant 
```
git clone https://opendev.org/openstack/devstack.git 
```
* Récupérer et noter l'adresse IP de l'hôte :
```
ip addr show
```
* Créer un fichier local.conf (utilisé pendant l'installation avec le contenu suivant (que vous pouvez modifier pour changer les IP ou mots de passe)
```
[[local|localrc]]
HOST_IP=0.0.0.0 #a remplacer avec votre propre adresse IP
FLOATING_RANGE=192.168.1.224/27
FIXED_RANGE=10.11.12.0/24
FIXED_NETWORK_SIZE=256
FLAT_INTERFACE=eth0
ADMIN_PASSWORD=supersecret
DATABASE_PASSWORD=iheartdatabases
RABBIT_PASSWORD=flopsymopsy
SERVICE_PASSWORD=iheartksl
```
* Lancer le script d'installation :
```
cd devstack
./stack.sh
```
* Celui-ci prend 15 à 20 minutes à s'éxecuter, laisser le tourner

## Vérification de l'installation 
* Vérifier avec l'adresse IP obtenu en fin script, que vous accédez bien à l'interface Horizon 

-> Félicitations vous disposez maintenant d'un environnement fonctionnel pour découvrir OpenStack
