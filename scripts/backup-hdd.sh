#!/usr/bin/env bash
set -euo pipefail
umask 077
cd /home/gasper/storagecloud
mountpoint -q /mnt/storagecloud-backup || { echo 'Backup HDD is not mounted; skipping.'; exit 0; }
[[ $(findmnt -n -o MAJ:MIN -T /mnt/storagecloud-backup) != $(findmnt -n -o MAJ:MIN -T /srv/storagecloud) ]] || { echo 'Backup destination must be a separate device.' >&2; exit 1; }
exec 9>/run/lock/storagecloud-backup.lock
flock -n 9 || exit 0
export RESTIC_REPOSITORY=/mnt/storagecloud-backup/restic
export RESTIC_PASSWORD_FILE=/etc/storagecloud/restic-password
if [[ ! -f "$RESTIC_REPOSITORY/config" ]]; then restic init; fi
stage=$(mktemp -d /srv/storagecloud/backups/.hdd-stage-XXXXXXXX)
maintenance=0
paused=0
resume() {
  result=$?
  trap - EXIT
  if (( maintenance )); then docker compose exec -T -u www-data nextcloud php occ maintenance:mode --off || result=1; fi
  if (( paused )); then docker compose start cron immich-server || result=1; fi
  exit "$result"
}
trap resume EXIT
maintenance=1
docker compose exec -T -u www-data nextcloud php occ maintenance:mode --on
paused=1
docker compose stop cron immich-server
docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$stage/nextcloud.dump"
docker compose exec -T immich-database sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$stage/immich.dump"
restic backup --tag storagecloud /srv/storagecloud/nextcloud /srv/storagecloud/immich /srv/storagecloud/caddy /home/gasper/storagecloud/.env /home/gasper/storagecloud/docker-compose.yml /home/gasper/storagecloud/config /home/gasper/storagecloud/scripts "$stage"
docker compose exec -T -u www-data nextcloud php occ maintenance:mode --off
maintenance=0
docker compose start cron immich-server
paused=0
# Remove only this job's staging directory after a successful snapshot.
python3 - "$stage" <<'PY'
import pathlib,shutil,sys
p=pathlib.Path(sys.argv[1])
assert p.parent == pathlib.Path('/srv/storagecloud/backups') and p.name.startswith('.hdd-stage-')
shutil.rmtree(p)
PY
restic forget --tag storagecloud --group-by host,tags --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
restic check
