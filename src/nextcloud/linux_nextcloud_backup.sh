#!/bin/bash
#
# Backup Nextcloud Server [Linux]
#
# Backup Nextcloud configuration, database, and local files.
#
# Syntax:
#   NEXTCLOUD_DIR=--base=<str> - Location where Nextcloud is installed DEFAULT=/var/www/nextcloud
#   EXCLUDE_DB=--exclude-db - Exclude database from backup
#   EXCLUDE_FILES=--exclude-files - Exclude local files from backup
#   EXCLUDE_CONFIG=--exclude-config - Exclude configuration from backup
#   WWW_USER=--www-user=<str> - Web server user DEFAULT=www-data
#   DB_NAME=--db-name=<str> - Database name DEFAULT=nextcloud
#   DB_USER=--db-user=<str> - Database user DEFAULT=nextcloud
#   DB_PASS=--db-pass=<str> - Database password DEFAULT=nextcloud
#   DB_PREFIX=--db-prefix=<str> - Database prefix DEFAULT=oc_
#   DEST=--dest=<str> - Destination directory for backup DEFAULT=/backups
#   SFTP_HOST=--sftp-host=<str> - SFTP host to upload backups to (optional unless DEST=SFTP)
#   SFTP_USER=--sftp-user=<str> - SFTP user to upload backups to (optional unless DEST=SFTP)
#   SFTP_PORT=--sftp-port=<int> - SFTP port to upload backups to (if DEST=SFTP) DEFAULT=22
#   SFTP_DIR=--sftp-dir=<str> - SFTP directory to upload backups to (if DEST=SFTP) DEFAULT=/backups
#
# Supports:
#   Linux-All
#
# @LICENSE AGPLv3
# @AUTHOR  Charlie Powell <cdp1337@veraciousnetwork.com>
# @CATEGORY Backup
# @TRMM-TIMEOUT 600

# scriptlet:_common/require_root.sh
# compile:usage
# compile:argparse

if [ ! -d "$NEXTCLOUD_DIR" ]; then
	echo "ERROR - Nextcloud directory does not exist: $NEXTCLOUD_DIR" >&2
	exit 1
fi

TYPE="local"
if [ "$DEST" == "SFTP" ]; then
	if [ -z "$SFTP_HOST" ] || [ -z "$SFTP_USER" ]; then
		echo "ERROR - SFTP host and user must be specified when using DEST=SFTP" >&2
		exit 1
	fi

	TYPE="SFTP"
	DEST=$(mktemp -d /tmp/nextcloud_backup.XXXXXX)
fi

[ -d "$DEST" ] || mkdir -p "$DEST"

# Put Nextcloud into maintenance mode prior to any operations
sudo -u $WWW_USER php "$NEXTCLOUD_DIR/occ" maintenance:mode --on

if [ $EXCLUDE_DB -eq 0 ]; then
	echo "Backing up $DB_NAME database to $DEST/nextcloud_db_backup.sql.gz"
	mysqldump -u "$DB_USER" -p"$DB_PASS" --single-transaction "$DB_NAME" | gzip -c > "$DEST/nextcloud_db_backup.sql.gz"
fi

if [ $EXCLUDE_FILES -eq 0 ]; then
	# Grab a list of local storages defined in the database to now which local directories to backup
	mysql -B --disable-column-names -u "$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -e "select id from ${DB_PREFIX}storages WHERE id LIKE 'local::%';" \
	| sed 's/local:://' \
	| while read STORAGE; do
		TGZNAME="$(echo "$STORAGE" | sed 's:/:_:g')"
		# Strip leading and trialing slashes, (which are now underscores)
		TGZNAME="${TGZNAME:1:-1}"

		echo "Backing up local storage $STORAGE to $DEST/nextcloud_files_backup_$TGZNAME.tar.gz"
		if [ "$STORAGE" == "$NEXTCLOUD_DIR/data/" ]; then
			# Nextcloud stores some directories which we don't need in a backup.
			tar -czf "$DEST/nextcloud_files_backup_$TGZNAME.tar.gz" \
				--exclude="$NEXTCLOUD_DIR/data/updater-*" \
				--exclude="$NEXTCLOUD_DIR/data/appdata_*/preview" \
				"$STORAGE"
		else
			tar -czf "$DEST/nextcloud_files_backup_$TGZNAME.tar.gz" "$STORAGE"
		fi
	done
fi

if [ $EXCLUDE_CONFIG -eq 0 ]; then
	echo "Backing up Nextcloud configuration to $DEST/nextcloud_config_backup.tar.gz"
	tar -czf "$DEST/nextcloud_config_backup.tar.gz" -C "$NEXTCLOUD_DIR" config/
fi


# Disable maintenance mode after file and database operations are complete
sudo -u $WWW_USER php "$NEXTCLOUD_DIR/occ" maintenance:mode --off


if [ "$TYPE" == "SFTP" ]; then
	echo "Transferring backups to SFTP server $SFTP_HOST:$SFTP_DIR"
	scp -B -o StrictHostKeyChecking=accept-new -P "$SFTP_PORT" -r $DEST/* "$SFTP_USER@$SFTP_HOST:$SFTP_DIR/"

	if [ $? -ne 0 ]; then
		echo "ERROR - Failed to transfer backups to SFTP server $SFTP_HOST:$SFTP_DIR" >&2
		exit 1
	else
		echo "Backups successfully transferred to SFTP server $SFTP_HOST:$SFTP_DIR"
	fi

	# Cleanup local temporary directory
	rm -rf "$DEST"
else
	echo "Backups created in local directory: $DEST"
fi
