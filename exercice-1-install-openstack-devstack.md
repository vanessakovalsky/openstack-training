# Installation de l'environnement DevStack

Ce première exercice va nous permettre d'installer Devstack qui est un moyen rapide et facile pour avoir une solution OpenStack installé en local sur son propre pc.

## Pré-requis

* Installer s'il n'est pas déjà installé sur votre poste l'outil VirtualBox : https://www.oracle.com/fr/virtualization/virtualbox/
* Il est aussi indispensable d'avoir une connexion internet correcte, car le téléchargement des images nécessaires peut prendre du temps 
* Niveau matériel, voici les recommandations d'OpenStack :
**  Au moins 8GB de RAM
** Au moins 10Gb d'espace disque doit être disponible pour faire l'installation

## Création d'un VM dédié
* Dans VirtualBox,créer une nouvelle VM avec les caractéristique suivantes :
** RAM : 8G
** DD : 20 Go (dynamiquement alloué et de type dynamique)
** Os Linux Ubutnu
* Dans la configuration de la machine, aller dans Réseau, puis sur interface1, choisir : Accès par pont (obligatoire pour accéder à OpenStack depuis l'hôte)
* Télécharger la dernière version stable d'Ubuntu (LTS 22.04, Jammy) recommandé par Devstack : https://www.ubuntu-fr.org/download/  
* Lancer la machine en insérant le ISO téléchargé puis faire l'installation 

## Installation de DevStack

* Se connecter à la VM en SSH
* Suivre les instructions d'installation sur le site officiel : https://docs.openstack.org/devstack/latest/ 

## Vérification de l'installation 
* Dans la VM, taper la commande :
```
ip addr show
```
* Vérifier avec l'adresse IP obtenu , que vous accédez bien à l'interface Horizon dans le navigateur de votre machine hôte
** Login : admin
** Mot de passe : supersecret (ou celui que vous avez défini dans ADMIN_PASSWORD)

-> Félicitations vous disposez maintenant d'un environnement fonctionnel pour découvrir OpenStack
