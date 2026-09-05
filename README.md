# Storagecloud on this Ubuntu host

Nextcloud handles files and sharing; Immich handles photo/video backup. One Cloudflare Tunnel publishes both apps. Docker Engine is installed from Docker's Ubuntu repository; the previous Docker snap is disabled.

## Locations

- Configuration: `/home/gasper/storagecloud`
- Private settings: `.env` (mode 0600; never commit)
- Nextcloud application/configuration: `/srv/storagecloud/nextcloud/app`
- Nextcloud files: `/srv/storagecloud/nextcloud/data`
- Immich media: `/srv/storagecloud/immich/library` mounted at `/data`
- Separate databases: `/srv/storagecloud/databases/{nextcloud,immich}`
- Local database/configuration backups: `/srv/storagecloud/backups`
- Downloaded machine-learning models: Docker volume `storagecloud_immich_model_cache`

The data directories belong to container service accounts. Do not recursively change their ownership or edit application-managed media directly.

## Access

- Nextcloud: https://cloud.storagecloud.download — user `admin`, email `admin@gmail.com`, existing password in `.env`.
- Immich: https://photos.storagecloud.download — `admin@gmail.com`, generated password in `/home/gasper/.local/share/storagecloud/immich-admin.json` (mode 0600).


Cloudflare routes must point to `http://nextcloud:80` and `http://immich-server:2283`, using the public hostnames in `.env`. `IMMICH_DOMAIN` documents the route; it does not configure Cloudflare DNS or routing.

Local troubleshooting: `http://127.0.0.1:8080/status.php` and `http://127.0.0.1:2283`. Application troubleshooting ports bind only to localhost. Local HTTPS is published on the `LAN_IP` address, port 443. Databases have no published ports. No router port forwarding is needed for the tunnel. Nextcloud uses its public HTTPS URL.

The tunnel connects to Caddy on an isolated frontend network. Caddy forwards to the web apps on a separate backend network. Nextcloud trusts only Caddy's backend address, `172.30.80.4`. Caddy trusts forwarded client addresses only from the tunnel connector at `172.30.81.3`. Machine learning has outbound connectivity for model downloads. TURN is not installed; add it separately if Nextcloud Talk calls are needed.

Cloudflare's request-body limits can prevent large video uploads. Use the local HTTPS route below for bulk transfers on home Wi-Fi; Cloudflare upload limits do not apply when DNS resolves directly to the PC. Avoid putting an interactive Cloudflare Access login in front of mobile app/API endpoints without checking client compatibility.

## Operations

```bash
cd /home/gasper/storagecloud
sudo docker compose ps
sudo docker compose logs --tail=100 nextcloud immich-server
sudo docker compose up -d
sudo docker compose stop
```

Docker starts at boot and services restart automatically unless explicitly stopped. Log rotation and per-service resource limits are configured. Sleep targets are masked for server operation. The lid configuration takes effect after logind reload/reboot; no desktop session is terminated during setup.

Membership in the Docker group takes effect after logging out and back in. Until then use `sudo docker`.

## Backups

`storagecloud-backup.timer` runs nightly around 03:30 local time, keeping 14 successful snapshots. Run it manually:

```bash
sudo systemctl start storagecloud-backup.service
sudo systemctl status storagecloud-backup.service
sudo systemctl list-timers storagecloud-backup.timer
```

These snapshots contain consistent individual PostgreSQL dumps, Nextcloud configuration, Compose configuration, and credentials. They do **not** include uploaded media and are on the same SSD. A complete disaster-recovery backup must copy both applications' media, databases, configuration, and credentials to another disk or remote destination. Coordinate backups with paused writes/maintenance mode for database-to-media consistency. Protect backups as secrets.

Restore into empty, version-compatible databases using `pg_restore`; restore the matching media and Nextcloud application/configuration before starting services. Changing database passwords in `.env` does not rotate an existing database's password.

## Updates

Nextcloud, Immich, and cloudflared release versions are pinned; PostgreSQL and Redis follow their selected major versions when explicitly pulled. Before updating, make an off-machine backup and review upstream migration instructions. Keep the Nextcloud web and cron images identical. Update Immich server and machine-learning together, using the database image and mount paths from the matching official release Compose file. Validate with `docker compose config --quiet`, pull explicitly, and verify health and login after recreation.

Do not run `docker compose down -v` or delete storage directories as routine maintenance.

References: [Immich Compose](https://docs.immich.app/install/docker-compose/), [Nextcloud Docker](https://github.com/nextcloud/docker), [Docker Ubuntu installation](https://docs.docker.com/engine/install/ubuntu/).

## Future backup HDD (prepared, disk not yet installed)

The `storagecloud-hdd-backup.timer` runs around 04:15. Its service skips execution unless a filesystem is mounted at `/mnt/storagecloud-backup`; the script also refuses a destination on the source device. When the HDD arrives, identify and mount it persistently by UUID at that location before testing the job. No disk has been formatted or assumed to be the backup disk.

Backups use encrypted, deduplicated Restic snapshots. The password is `/etc/storagecloud/restic-password` (root only). Save a copy of that password somewhere secure off this computer before relying on the backup: it is required for restoration. Retention is 7 daily, 4 weekly, and 6 monthly snapshots. Monitor space: a 1 TB backup disk may be insufficient if the source SSD fills or files change frequently.

For consistency, the HDD job temporarily enables Nextcloud maintenance mode and stops Nextcloud cron and Immich server, takes database dumps and backs up all application files/media/configuration, then resumes services. The first backup can cause substantial downtime; later runs use deduplication. It runs `restic check` after each successful backup. Local nightly dumps remain separate.

```bash
sudo systemctl start storagecloud-hdd-backup.service
sudo journalctl -u storagecloud-hdd-backup.service
sudo env RESTIC_REPOSITORY=/mnt/storagecloud-backup/restic RESTIC_PASSWORD_FILE=/etc/storagecloud/restic-password restic snapshots
```

## Initial validation

Public HTTPS authentication works for both applications. Nextcloud WebDAV and Immich photo upload/download were tested; test assets were removed. Immich thumbnail generation and Intel Quick Sync encoding were verified. Quick Sync is enabled with the Intel `/dev/dri/renderD128` device; background video jobs are limited to one at a time. Machine learning uses CPU with two threads and unloads idle models after five minutes.

Nextcloud uses cron, Redis locking/cache, a nightly maintenance window, tuned PHP opcode cache, and eight Apache workers. HSTS is enabled. SMTP is not configured: email notifications/password-reset mail need a mail provider and credentials. External Nextcloud AppAPI deployment is not configured because this stack does not use Ex-Apps.

Nightly local backups were executed successfully and both PostgreSQL archives were validated with `pg_restore --list`; a full disaster-recovery restore has not yet been tested. The HDD service was verified to skip while the disk is absent. Nextcloud's fresh-install theming migration required initializing its `global` appdata folder through the Nextcloud API; initial errors remain in the historical log.

## Home Wi-Fi access (local HTTPS)

Caddy provides trusted HTTPS for the same public hostnames. With router DNS overrides, home devices connect directly over Wi-Fi and do not send uploads through Cloudflare. Outside the home network, public DNS still uses the tunnel. Keep using the domain names in the apps; the bare IP is not a certificate hostname.

Reserved address: **192.168.10.10**, Wi-Fi MAC **d0:c6:37:40:de:2c**, gateway **192.168.10.1**. The user confirmed that this address is already assigned to this PC in the router. `LAN_IP=192.168.10.10` is active.

Cudy router setup (the PC-side services are installed and tested; user reports the DHCP DNS change has been applied):

1. Open `http://192.168.10.1` and go to **Advanced Settings → Network → DHCP Server** (wording varies by model/firmware).
2. Keep DHCP enabled and keep the existing `.10` IP/MAC reservation.
3. Set **Preferred DNS = 192.168.10.10**. Leave **Alternate DNS empty**. A public alternate resolver can bypass the local addresses; it is not a reliable standby-only setting.
4. Save & Apply, then disconnect/reconnect home devices to Wi-Fi to renew their DHCP DNS settings.
5. Leave **Custom DNS → Override All Clients' DNS off**. Forced DNS interception can send this PC's upstream queries back to itself and cause a loop.
6. Do not configure WAN port forwards or change public Cloudflare DNS.

CoreDNS is listening on `192.168.10.10:53` (UDP and TCP). It answers both app hostnames with `.10`, returns no public AAAA/HTTPS records for them, and forwards unrelated lookups to `1.1.1.1` or `9.9.9.9`. `cudy.net` resolves to `192.168.10.1`. This avoids needing arbitrary hostname overrides in Cudy's firmware. The PC must stay on for devices using it as their DNS server. To undo, restore the previous DHCP DNS settings and reconnect clients.

Private DNS, browser Secure DNS/DoH, VPN DNS, or a separately advertised IPv6 DNS server can bypass this resolver. Configure affected devices to use the home network's DNS. Guest/client isolation must not block access to the PC. If the router relays DNS instead of advertising `.10` directly, its DNS-rebinding protection may need exceptions for these two names.

Official Cudy instructions: https://docs.cudy.com/user_guide/wireless_router/network/#dhcp-server

No DHCP reconnect is needed with the confirmed `.10` reservation. If the IP changes later, update `LAN_IP` in `.env` and recreate `lan-proxy` with `sudo docker compose up -d lan-proxy`. If this moves to Ethernet, reserve the Ethernet MAC instead.

Validate from a home device: DNS lookup of each hostname should return `.10`; visit the usual HTTPS URLs. During setup, `curl --resolve cloud.storagecloud.download:443:192.168.10.10 https://cloud.storagecloud.download/status.php` tests the local route without changing DNS.  No `-k`/certificate bypass is needed.

Caddy obtains and renews public certificates using HTTP-01 validation through the existing Cloudflare Tunnel. The tunnel destinations retain their original names/ports using aliases on the isolated frontend network. Internet access is needed for certificate renewal, but local uploads do not require an Internet round trip while the certificates remain valid. The local CoreDNS service answers these two names even during an Internet outage. Caddy certificate state is under `/srv/storagecloud/caddy` and is included in future HDD backups.

Local validation completed: UDP/TCP DNS, absence of public AAAA/HTTPS records, normal external DNS forwarding, certificate verification, direct Nextcloud file upload/download/delete, and direct Immich login. Both public tunnel endpoints still respond. These tests ran on this PC against its LAN address; another Wi-Fi device must still confirm the router DHCP/DNS settings and client-to-PC connectivity.

The host Wi-Fi profile `Cudy-076C` explicitly uses `192.168.10.10` for IPv4 DNS (`ipv4.ignore-auto-dns=yes`). Ordinary HTTPS requests from this PC were verified to connect directly to `.10` after applying that setting. Other devices must renew their Wi-Fi/DHCP lease. To revert the host DNS override: `sudo nmcli connection modify Cudy-076C ipv4.dns "" ipv4.ignore-auto-dns no` followed by `sudo nmcli device reapply wlo1`.
