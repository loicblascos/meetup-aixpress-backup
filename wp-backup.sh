#!/bin/bash
#@author Loic Blascos

# Prérequis:
# Installer WP-CLI: https://wp-cli.org/fr/#installation
# Installer zip package: sudo apt install zip (Ubuntu)
# Installer pv package: sudo apt install pv (Ubuntu)
# Installer dropbox package: https://github.com/andreafabrizi/Dropbox-Uploader

# Chemin vers le dossier de WP
WP_DIR="/var/www/html/"
# Nombre max de backups
BAK_NB=10
# Date du backup
BAK_DATE=$(date +\%d-\%m-\%Y-\%T)
# Nom du fichier backup
BAK_FILE=${WP_DIR}backup-$BAK_DATE.zip

# Verifier l'existance de WordPress
if [ ! -f ${WP_DIR}wp-config.php ]; then
	echo "ERREUR: Impossible de détecter l'installation de WordPress..."
	exit 1
fi

# Exporter la base de données avec wp-cli
function export() {
    echo -ne "🔢  Exportation de la base de données..."
	cd $WP_DIR && wp db export database.sql --allow-root > /dev/null

	if [ -f ${WP_DIR}database.sql ]; then
		echo " ✔️"
	else
		echo " ❌"
		echo " Une erreur est survenue lors de l'exportation!"
		exit 1;
	fi

}

# Maintenir le nombre de backups
function remove_backup() {
	BACKUPS=($(./dropbox_uploader.sh list | awk 'NR!=1{ print $3 }'))
	LENGTH=${#BACKUPS[@]}

	if (( $LENGTH <= $BAK_NB )); then
	 	return
	fi

	echo -ne "✨  Nettoyage des backups..."
	for (( idx=0; idx<$(($LENGTH-$BAK_NB)); idx++ )); do
		./dropbox_uploader.sh delete ${BACKUPS[idx]} > /dev/null
	done
	echo " ✔️"
}

# Archiver tous les fichiers de WP
function compress() {
    echo "🎁  Compression des fichiers WP..."
	zip -r $BAK_FILE * .[^.]* 2>&1 | \
	pv -lep -s $(ls -Rl1 $WP_DIR | \
	egrep -c '^[-/]') > /dev/null

	# Supprimer le fichier .sql
	rm database.sql

	if [ ! -f $BAK_FILE ]; then
		echo " ❌"
		echo " Une erreur est survenue lors de la compression!"
		exit 1;
	fi
}

# Televerser dans Dropbox
function upload() {
	echo -ne "📥  Televersement sur Dropbox..."
	cd && ./dropbox_uploader.sh upload $BAK_FILE / > /dev/null
	echo " ✔️"
	# Supprimer le fichier .zip
	rm $BAK_FILE
}

function backup() {
	export
	compress
	upload
	remove_backup
}

backup
echo "🎉  Backup terminé!"
