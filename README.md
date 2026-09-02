# Docker Nextcloud Cloud Storage

This is a self-contained Docker Compose setup for a Mega-like private cloud:

- Nextcloud
- PostgreSQL
- Redis
- Nextcloud cron
- Cloudflare Tunnel

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

## Useful Commands

Show running containers:

```powershell
docker compose ps
```

View logs:

```powershell
docker compose logs -f
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

Docker manages these volumes internally. They are not written into this project folder.

## Notes

- Keep `.env` private. It contains passwords and your Cloudflare Tunnel token.
- This setup exposes Nextcloud only through Cloudflare Tunnel. There is no host port mapping.
- For large uploads, Cloudflare plan limits may still apply even though Nextcloud allows `10G`.
