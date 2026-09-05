#!/usr/bin/env bash
# Local recovery copies only. Copy media and these backups off this SSD separately.
set -euo pipefail
umask 077
cd /home/gasper/storagecloud
exec 9>/run/lock/storagecloud-backup.lock
flock -n 9 || exit 0
backup_root=/srv/storagecloud/backups
install -d -m 0700 "$backup_root"
backup_dir=$(mktemp -d "$backup_root/.incomplete-XXXXXXXX")
trap 'echo "Backup failed; incomplete files retained at $backup_dir" >&2' ERR
docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$backup_dir/nextcloud.dump"
docker compose exec -T immich-database sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$backup_dir/immich.dump"
cp .env docker-compose.yml "$backup_dir/"
cp -a config scripts "$backup_dir/"
tar -czf "$backup_dir/nextcloud-config.tar.gz" -C /srv/storagecloud/nextcloud/app config
mv "$backup_dir" "$backup_root/$(date -u +%Y%m%dT%H%M%SZ)"
# Retain 14 successful local snapshots; incomplete backups are never auto-deleted.
python3 - "$backup_root" <<'PY'
import pathlib,re,shutil,sys
root=pathlib.Path(sys.argv[1])
backups=sorted(p for p in root.iterdir() if p.is_dir() and re.fullmatch(r'\d{8}T\d{6}Z',p.name))
for p in backups[:-14]: shutil.rmtree(p)
PY
