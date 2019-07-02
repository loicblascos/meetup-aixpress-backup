#!/bin/bash
#@author Loic Blascos

# Prérequis:
# Installer WP-CLI: https://wp-cli.org/fr/#installation
# Installer zip package: sudo apt install zip (Ubuntu)
# Installer dropbox package: https://github.com/andreafabrizi/Dropbox-Uploader

# Chemin vers le dossier de WP
WP_DIR="/var/www/html/"
# Dossier temporaire pour télécharger le backup
TMP_DIR="./tmp/"
# Array contenant les noms des backups
BACKUPS=()

# Verifier l'existance de WordPress
if [ ! -f ${WP_DIR}wp-config.php ]; then
	echo "ERREUR: Impossible de détecter l'installation de WordPress..."
	exit 1
fi

# Récupérer les backups sur Dropbox
function get_backups() {
	TMP_ARRAY=($(./dropbox_uploader.sh list | awk 'NR!=1{ print $3 }'))
	if [ ${#TMP_ARRAY[@]} -eq 0 ]; then
		echo "Aucun backup trouvé!"
		exit 1;
	fi

	# Inverser l'array par afficher dans l'ordre antichronologique
	for (( idx=${#TMP_ARRAY[@]}; idx>=0 ; idx-- )); do
		BACKUPS+=(${TMP_ARRAY[idx]})
	done
}

# Lister les backups disponibles
function select_backup() {
    echo "========================================="
	echo " Fichier(s) de restauration"
	echo "========================================="


	# Limiter le nombre de columnnes du select
	COLUMNS=12
	PS3=$'\n'"[?] Indiquez votre choix: "

	select FILE in ${BACKUPS[@]}
	do
		if [ ! -z $FILE ]; then
			read -p "[y/n] Êtes-vous sûr de vouloir continuer? " -n 1 -r
			echo
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				break
			else
				exit 1;
			fi
		else
			echo "Votre choix n'existe pas!"
		fi
	done
}

# Télécharger le backup sur le serveur
function download_backup() {
	# Creer le dossier temporaire
	mkdir $TMP_DIR

	# Télécharger la sauvegarde dans le dossier temporaire
	echo -ne "📥  Téléchargement du backup..."
	./dropbox_uploader.sh download ./$FILE $TMP_DIR > /dev/null
	echo " ✔️"

	# Si le téléchargement a échoué
	if [ ! -f $TMP_DIR$FILE ]; then
		# Supprimer le dossier temporaire
		rm -rf $TMP_DIR
		echo "⚠️  Une erreur est survenue lors de la restauration..."
		exit 1;
	fi
}

# Extraire le backup
function extract_backup() {
	# Supprimer le contenu dans le dossier de WP
	rm -rf $WP_DIR{*,.[^.]*}

	# Extraire le backup dans le dossier de WP
	echo -ne "🎁  Extraction du backup..."
	unzip $TMP_DIR$FILE -d $WP_DIR > /dev/null
	echo " ✔️"

	# Supprimer le dossier temporaire
	rm -rf $TMP_DIR
}

# Importer la BDD
function import_db() {
	echo -ne "🔢  Importation de la base de données..."
	cd $WP_DIR && wp db import database.sql > /dev/null
	echo " ✔️"

	# Supprimer le fichier .sql
	rm database.sql
}

function restore() {
	get_backups
	select_backup
	download_backup
	extract_backup
	import_db
}

restore
echo "🎉  Restauration terminée!"
