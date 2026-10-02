# Running Prism on Unraid

Prism runs as three containers (app, Postgres, Redis). The Unraid compose file
bundles them with data under `/mnt/user/appdata/prism`.

## Image

The compose file needs an image built from *this* repo (it includes the
self-bootstrapping entrypoint). Publish one by running the **Build & Publish
Docker Image** workflow on your fork, then set `PRISM_IMAGE=ghcr.io/<you>/prism`
in the env file (make the package public, or `docker login ghcr.io` on Unraid).

## Install

1. Install **Docker Compose Manager** from Community Apps.
2. Docker tab → **Add New Stack** → name it `prism`.
3. **Edit Stack → Compose File**: paste the contents of `docker-compose.unraid.yml`.
4. **Edit Stack → ENV File**: paste `.env.unraid.example` and set `DB_PASSWORD`,
   `APP_URL` (your Unraid IP and port) and `TZ`.
5. **Compose Up**, then open `http://<unraid-ip>:3000`.

No repo checkout, `openssl` commands, or certificates needed. The database
schema and app secrets are created on first boot.

## Updating

Compose Manager → **Update Stack** (or `docker compose pull && docker compose up -d`).
Migrations run automatically on start.

## Backups

- Dashboard backups (Settings → Backups) go to `appdata/prism/backups`.
- Back up the whole `appdata/prism` folder (Appdata Backup plugin works),
  especially `config/.prism_secrets`: without it, stored integration credentials
  can't be decrypted.

## Notes

- HTTPS: put Nginx Proxy Manager / SWAG / Traefik in front and point it at port 3000,
  then set `APP_URL` to the https address.
- Reaching other LAN apps (Immich, CalDAV...) needs `PRISM_ALLOWED_INTERNAL_HOSTS`.
- Files are owned by `99:100` (nobody:users) by default; change with `PUID`/`PGID`.
