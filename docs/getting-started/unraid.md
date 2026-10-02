# Running Prism on Unraid

Prism runs as three containers (app, Postgres, Redis). The Unraid compose file
bundles them with data under `/mnt/user/appdata/prism`.

## Image

The stack builds the image on your Unraid server directly from the git repo in
`PRISM_BUILD_CONTEXT` (default: your fork's `unraid-support` branch). The first
**Compose Up** takes roughly 10-20 minutes and needs ~4 GB free RAM; later
starts reuse the built image. No GitHub Actions or registry login needed.

## Prepare the folders (once)

Docker creates missing bind-mount folders as root, but Prism runs as `99:100`
(nobody:users), so create them first. Open the Unraid terminal (top-right `>_`):

```sh
mkdir -p /mnt/user/appdata/prism/{config,uploads,backups,data,photos-cache,postgres,redis}
chown -R 99:100 /mnt/user/appdata/prism/{config,uploads,backups,data,photos-cache}
```

(Postgres and Redis manage their own folders.) If you changed `PRISM_APPDATA`
or `PUID`/`PGID`, use those values instead.

## Install

1. Install **Docker Compose Manager** from Community Apps.
2. Docker tab → **Add New Stack** → name it `prism`.
3. **Edit Stack → Compose File**: paste the contents of `docker-compose.unraid.yml`.
4. **Edit Stack → ENV File**: paste `.env.unraid.example` and set `DB_PASSWORD`,
   `APP_URL` (your Unraid IP and port) and `TZ`.
5. **Compose Up**, then open `http://<unraid-ip>:23000`.

No repo checkout, `openssl` commands, or certificates needed. The database
schema and app secrets are created on first boot.

## Updating

Rebuild from the latest code, from the stack's folder in the Unraid terminal:
`docker compose build --no-cache app && docker compose up -d`.
Migrations run automatically on start.

## Backups

- Dashboard backups (Settings → Backups) go to `appdata/prism/backups`.
- Back up the whole `appdata/prism` folder (Appdata Backup plugin works),
  especially `config/.prism_secrets`: without it, stored integration credentials
  can't be decrypted.

## Notes

- HTTPS: put Nginx Proxy Manager / SWAG / Traefik in front and point it at port 23000,
  then set `APP_URL` to the https address.
- Reaching other LAN apps (Immich, CalDAV...) needs `PRISM_ALLOWED_INTERNAL_HOSTS`.
- Files are owned by `99:100` (nobody:users) by default; change with `PUID`/`PGID`.
