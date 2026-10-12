#!/usr/bin/env bash
# Backup of the server : every MySQL database of the apps + the photos of GardenFlow.
# Kept BACKUP_KEEP_DAYS days in deploy/backups, then copied with rclone to BACKUP_REMOTE (another place than
# the server : a disk dies, a house burns). Started every night by cron, see deploy/README.md.
#   bash deploy/backup.sh
set -euo pipefail

cd "$(dirname "$0")"

# only the BACKUP_* settings are read from .env (the other values are not meant for the shell)
setting() { grep -E "^$1=" .env | tail -n 1 | cut -d= -f2- || true; }
REMOTE=$(setting BACKUP_REMOTE)
KEEP_DAYS=$(setting BACKUP_KEEP_DAYS); KEEP_DAYS=${KEEP_DAYS:-7}
REMOTE_KEEP_DAYS=$(setting BACKUP_REMOTE_KEEP_DAYS); REMOTE_KEEP_DAYS=${REMOTE_KEEP_DAYS:-30}

DIR="backups/$(date +%Y-%m-%d_%H%M)"
mkdir -p "$DIR"

# databases of the apps (not the system ones of MySQL) : a dump with their CREATE DATABASE, restorable as is
DATABASES=$(docker compose exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -uroot -N -e "
  SELECT schema_name FROM information_schema.schemata
  WHERE schema_name NOT IN (\"mysql\", \"information_schema\", \"performance_schema\", \"sys\")"')

# --single-transaction : a consistent copy without stopping the apps
docker compose exec -T mysql sh -c "MYSQL_PWD=\"\$MYSQL_ROOT_PASSWORD\" exec mysqldump -uroot --single-transaction --routines --events --databases $(echo $DATABASES)" \
  | gzip > "$DIR/mysql.sql.gz"

# photos sent by the users
docker compose exec -T gardenflow-api tar -czf - -C /data uploads > "$DIR/gardenflow-uploads.tar.gz"

# a dump cut short (MySQL stopped...) has no "Dump completed" line at its end
if ! gzip -dc "$DIR/mysql.sql.gz" | tail -n 1 | grep -q 'Dump completed'; then
  echo "❌ MySQL dump incomplete : $DIR" >&2
  exit 1
fi
echo "✅ Backup $DIR ($(du -sh "$DIR" | cut -f1)) : $(echo $DATABASES)"

find backups -mindepth 1 -maxdepth 1 -type d -mtime "+$KEEP_DAYS" -exec rm -rf {} +

if [ -n "$REMOTE" ]; then
  # copy (not sync) : a backup deleted or damaged here stays on the remote
  rclone copy backups "$REMOTE"
  rclone delete "$REMOTE" --min-age "${REMOTE_KEEP_DAYS}d"
  rclone rmdirs "$REMOTE" --leave-root
  echo "✅ Copied to $REMOTE"
fi
