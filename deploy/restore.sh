#!/usr/bin/env bash
# Puts back a backup made by backup.sh : the databases it contains and the photos of GardenFlow.
# ⚠️  What changed since the backup is lost. Guide : deploy/README.md
#   bash deploy/restore.sh deploy/backups/2026-10-12_0300
set -euo pipefail

BACKUP=$(cd "${1:?usage : bash deploy/restore.sh <folder of a backup>}" && pwd)
cd "$(dirname "$0")"

for file in mysql.sql.gz gardenflow-uploads.tar.gz; do
  [ -f "$BACKUP/$file" ] || { echo "❌ $BACKUP/$file not found" >&2; exit 1; }
done

read -r -p "Replace the databases and the photos of the server by the backup $BACKUP ? Type yes : " answer
[ "$answer" = "yes" ] || { echo "Cancelled"; exit 1; }

# no request during the restore
docker compose stop gardenflow-api

# the dump drops and recreates each table of the databases it contains
gzip -dc "$BACKUP/mysql.sql.gz" \
  | docker compose exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -uroot'

# the photos : the folder is emptied first (photos added after the backup are removed)
docker compose run --rm --no-deps -T --entrypoint sh gardenflow-api \
  -c 'rm -rf /data/uploads/* && tar -xzf - -C /data' < "$BACKUP/gardenflow-uploads.tar.gz"

docker compose start gardenflow-api
echo "✅ Restored from $BACKUP"
