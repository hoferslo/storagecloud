# Docker Nextcloud Cloud Storage

This is a self-contained Docker Compose setup for a Mega-like private cloud:

- Nextcloud
- PostgreSQL
- Redis
- Nextcloud cron
- Cloudflare Tunnel
- coturn for Nextcloud Talk calls
- Immich photo/video backup

It does not install Linux packages or edit host configuration. Data is stored in Docker named volumes.

## Requirements

- Docker Desktop on Windows, using Linux containers
- A domain in Cloudflare
- A Cloudflare Tunnel token

## Setup

1. Copy the example environment file:

   ```powershell
   Copy-Item .env.example .env
   ```

2. Edit `.env` and set:

   - `NEXTCLOUD_DOMAIN`
   - `NEXTCLOUD_ADMIN_USER`
   - `NEXTCLOUD_ADMIN_PASSWORD`
   - `POSTGRES_PASSWORD`
   - `CLOUDFLARE_TUNNEL_TOKEN`
   - `TURN_SECRET`
   - `IMMICH_DB_PASSWORD`

3. In Cloudflare Zero Trust, create a tunnel and public hostname:

   ```text
   Hostname: your domain, for example cloud.example.com
   Service:  http://nextcloud:80
   ```

   When using a token-based tunnel, Cloudflare stores the hostname routing in Zero Trust.

4. Start the stack:

   ```powershell
   docker compose up -d
   ```

5. Open:

   ```text
   https://your-domain.example
   ```

## Immich

Immich runs next to Nextcloud using its own database and cache.

Local access from this machine:

```text
http://127.0.0.1:2283
```

Cloudflare Tunnel route to add:

```text
Hostname: photos.storagecloud.download
Service:  http://immich-server:2283
```

After adding the route in Cloudflare, open:

```text
https://photos.storagecloud.download
```

## Useful Commands

Show running containers:

```powershell
docker compose ps
```

View logs:

```powershell
docker compose logs -f
```

Install or enable the Nextcloud Talk app:

```powershell
docker compose exec --user www-data nextcloud php occ app:install spreed
docker compose exec --user www-data nextcloud php occ app:enable spreed
```

Stop the stack:

```powershell
docker compose down
```

Stop and delete all stored data:

```powershell
docker compose down -v
```

## Storage

The files live in Docker named volumes:

- `storage_nextcloud`
- `storage_nextcloud_data`
- `storage_db`
- `storage_redis`
- `storage_immich_uploads`
- `storage_immich_database`
- `storage_immich_model_cache`

Docker manages these volumes internally. They are not written into this project folder.

## Notes

- Keep `.env` private. It contains passwords and your Cloudflare Tunnel token.
- This setup exposes Nextcloud through Cloudflare Tunnel and locally on `http://127.0.0.1:8080` for host-only troubleshooting.
- Nextcloud Talk media uses the `coturn` container on port `3478` TCP/UDP and UDP relay ports `49160-49200`.
- If this runs at home and callers are outside your network, forward those TURN ports on your router to this machine.
- In Nextcloud admin settings, configure Talk TURN with `storagecloud.download:3478`, protocol `UDP and TCP`, and the shared secret from `TURN_SECRET`.
- For large uploads, Cloudflare plan limits may still apply even though Nextcloud allows `10G`.

For Ubuntu laptop-server notes, including desktop toggling and battery charge limits, see [LAPTOP_SERVER.md](LAPTOP_SERVER.md).
