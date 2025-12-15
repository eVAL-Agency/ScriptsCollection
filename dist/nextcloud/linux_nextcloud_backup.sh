#!/bin/bash
#
# Backup Nextcloud Server [Linux]
#
# Backup Nextcloud configuration, database, and local files.
#
# Syntax:
#   --base=<str> - Location where Nextcloud is installed DEFAULT=/var/www/nextcloud
#   --exclude-db  - Exclude database from backup
#   --exclude-files  - Exclude local files from backup
#   --exclude-config  - Exclude configuration from backup
#   --www-user=<str> - Web server user DEFAULT=www-data
#   --db-name=<str> - Database name DEFAULT=nextcloud
#   --db-user=<str> - Database user DEFAULT=nextcloud
#   --db-pass=<str> - Database password DEFAULT=nextcloud
#   --db-prefix=<str> - Database prefix DEFAULT=oc_
#   --dest=<str> - Destination directory for backup DEFAULT=/backups
#   --sftp-host=<str> - SFTP host to upload backups to (optional unless DEST=SFTP)
#   --sftp-user=<str> - SFTP user to upload backups to (optional unless DEST=SFTP)
#   --sftp-port=<int> - SFTP port to upload backups to (if DEST=SFTP) DEFAULT=22
#   --sftp-dir=<str> - SFTP directory to upload backups to (if DEST=SFTP) DEFAULT=/backups
#
# Supports:
#   Linux-All
#
# @LICENSE AGPLv3
# @AUTHOR  Charlie Powell <cdp1337@veraciousnetwork.com>
# @CATEGORY Backup
# @TRMM-TIMEOUT 600

##
# Simple check to enforce the script to be run as root
if [ $(id -u) -ne 0 ]; then
	echo "This script must be run as root or with sudo!" >&2
	exit 1
fi
function usage() {
  cat >&2 <<EOD
Usage: $0 [options]

Options:
    --base=<str> - Location where Nextcloud is installed DEFAULT=/var/www/nextcloud
    --exclude-db  - Exclude database from backup
    --exclude-files  - Exclude local files from backup
    --exclude-config  - Exclude configuration from backup
    --www-user=<str> - Web server user DEFAULT=www-data
    --db-name=<str> - Database name DEFAULT=nextcloud
    --db-user=<str> - Database user DEFAULT=nextcloud
    --db-pass=<str> - Database password DEFAULT=nextcloud
    --db-prefix=<str> - Database prefix DEFAULT=oc_
    --dest=<str> - Destination directory for backup DEFAULT=/backups
    --sftp-host=<str> - SFTP host to upload backups to (optional unless DEST=SFTP)
    --sftp-user=<str> - SFTP user to upload backups to (optional unless DEST=SFTP)
    --sftp-port=<int> - SFTP port to upload backups to (if DEST=SFTP) DEFAULT=22
    --sftp-dir=<str> - SFTP directory to upload backups to (if DEST=SFTP) DEFAULT=/backups

Backup Nextcloud configuration, database, and local files.
EOD
  exit 1
}

# Parse arguments
NEXTCLOUD_DIR="/var/www/nextcloud"
EXCLUDE_DB=0
EXCLUDE_FILES=0
EXCLUDE_CONFIG=0
WWW_USER="www-data"
DB_NAME="nextcloud"
DB_USER="nextcloud"
DB_PASS="nextcloud"
DB_PREFIX="oc_"
DEST="/backups"
SFTP_HOST=""
SFTP_USER=""
SFTP_PORT="22"
SFTP_DIR="/backups"
while [ "$#" -gt 0 ]; do
	case "$1" in
		--base=*)
			NEXTCLOUD_DIR="${1#*=}";
			[ "${NEXTCLOUD_DIR:0:1}" == "'" ] && [ "${NEXTCLOUD_DIR:0-1}" == "'" ] && NEXTCLOUD_DIR="${NEXTCLOUD_DIR:1:-1}"
			[ "${NEXTCLOUD_DIR:0:1}" == '"' ] && [ "${NEXTCLOUD_DIR:0-1}" == '"' ] && NEXTCLOUD_DIR="${NEXTCLOUD_DIR:1:-1}"
			shift 1;;
		--exclude-db) EXCLUDE_DB=1; shift 1;;
		--exclude-files) EXCLUDE_FILES=1; shift 1;;
		--exclude-config) EXCLUDE_CONFIG=1; shift 1;;
		--www-user=*)
			WWW_USER="${1#*=}";
			[ "${WWW_USER:0:1}" == "'" ] && [ "${WWW_USER:0-1}" == "'" ] && WWW_USER="${WWW_USER:1:-1}"
			[ "${WWW_USER:0:1}" == '"' ] && [ "${WWW_USER:0-1}" == '"' ] && WWW_USER="${WWW_USER:1:-1}"
			shift 1;;
		--db-name=*)
			DB_NAME="${1#*=}";
			[ "${DB_NAME:0:1}" == "'" ] && [ "${DB_NAME:0-1}" == "'" ] && DB_NAME="${DB_NAME:1:-1}"
			[ "${DB_NAME:0:1}" == '"' ] && [ "${DB_NAME:0-1}" == '"' ] && DB_NAME="${DB_NAME:1:-1}"
			shift 1;;
		--db-user=*)
			DB_USER="${1#*=}";
			[ "${DB_USER:0:1}" == "'" ] && [ "${DB_USER:0-1}" == "'" ] && DB_USER="${DB_USER:1:-1}"
			[ "${DB_USER:0:1}" == '"' ] && [ "${DB_USER:0-1}" == '"' ] && DB_USER="${DB_USER:1:-1}"
			shift 1;;
		--db-pass=*)
			DB_PASS="${1#*=}";
			[ "${DB_PASS:0:1}" == "'" ] && [ "${DB_PASS:0-1}" == "'" ] && DB_PASS="${DB_PASS:1:-1}"
			[ "${DB_PASS:0:1}" == '"' ] && [ "${DB_PASS:0-1}" == '"' ] && DB_PASS="${DB_PASS:1:-1}"
			shift 1;;
		--db-prefix=*)
			DB_PREFIX="${1#*=}";
			[ "${DB_PREFIX:0:1}" == "'" ] && [ "${DB_PREFIX:0-1}" == "'" ] && DB_PREFIX="${DB_PREFIX:1:-1}"
			[ "${DB_PREFIX:0:1}" == '"' ] && [ "${DB_PREFIX:0-1}" == '"' ] && DB_PREFIX="${DB_PREFIX:1:-1}"
			shift 1;;
		--dest=*)
			DEST="${1#*=}";
			[ "${DEST:0:1}" == "'" ] && [ "${DEST:0-1}" == "'" ] && DEST="${DEST:1:-1}"
			[ "${DEST:0:1}" == '"' ] && [ "${DEST:0-1}" == '"' ] && DEST="${DEST:1:-1}"
			shift 1;;
		--sftp-host=*)
			SFTP_HOST="${1#*=}";
			[ "${SFTP_HOST:0:1}" == "'" ] && [ "${SFTP_HOST:0-1}" == "'" ] && SFTP_HOST="${SFTP_HOST:1:-1}"
			[ "${SFTP_HOST:0:1}" == '"' ] && [ "${SFTP_HOST:0-1}" == '"' ] && SFTP_HOST="${SFTP_HOST:1:-1}"
			shift 1;;
		--sftp-user=*)
			SFTP_USER="${1#*=}";
			[ "${SFTP_USER:0:1}" == "'" ] && [ "${SFTP_USER:0-1}" == "'" ] && SFTP_USER="${SFTP_USER:1:-1}"
			[ "${SFTP_USER:0:1}" == '"' ] && [ "${SFTP_USER:0-1}" == '"' ] && SFTP_USER="${SFTP_USER:1:-1}"
			shift 1;;
		--sftp-port=*)
			SFTP_PORT="${1#*=}";
			[ "${SFTP_PORT:0:1}" == "'" ] && [ "${SFTP_PORT:0-1}" == "'" ] && SFTP_PORT="${SFTP_PORT:1:-1}"
			[ "${SFTP_PORT:0:1}" == '"' ] && [ "${SFTP_PORT:0-1}" == '"' ] && SFTP_PORT="${SFTP_PORT:1:-1}"
			shift 1;;
		--sftp-dir=*)
			SFTP_DIR="${1#*=}";
			[ "${SFTP_DIR:0:1}" == "'" ] && [ "${SFTP_DIR:0-1}" == "'" ] && SFTP_DIR="${SFTP_DIR:1:-1}"
			[ "${SFTP_DIR:0:1}" == '"' ] && [ "${SFTP_DIR:0-1}" == '"' ] && SFTP_DIR="${SFTP_DIR:1:-1}"
			shift 1;;
		-h|--help) usage;;
	esac
done


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
