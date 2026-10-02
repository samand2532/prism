#!/bin/sh
set -e

# --- Secrets -----------------------------------------------------------------
# If SESSION_SECRET / PIN_ENCRYPTION_KEY / ENCRYPTION_KEY aren't supplied, generate
# them once and persist them in /app/config so they survive restarts and updates.
# Supplying them via .env still wins. Losing /app/config (without .env values)
# means stored integration credentials can no longer be decrypted.
SECRETS_FILE=/app/config/.prism_secrets
if [ -z "$SESSION_SECRET" ] || [ -z "$PIN_ENCRYPTION_KEY" ] || [ -z "$ENCRYPTION_KEY" ]; then
  if [ ! -f "$SECRETS_FILE" ]; then
    echo "[entrypoint] Generating app secrets at $SECRETS_FILE (first boot)"
    mkdir -p /app/config
    {
      echo "SESSION_SECRET=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
      echo "PIN_ENCRYPTION_KEY=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
      echo "ENCRYPTION_KEY=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    } > "$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
  fi
  # shellcheck disable=SC1090
  . "$SECRETS_FILE"
  : "${SESSION_SECRET:?}" "${PIN_ENCRYPTION_KEY:?}" "${ENCRYPTION_KEY:?}"
  export SESSION_SECRET PIN_ENCRYPTION_KEY ENCRYPTION_KEY
fi

# --- Base schema -------------------------------------------------------------
# 02-schema.sql is not idempotent, so apply it only to an empty database. The
# stock compose already applies it via initdb (which creates __prism_migrations),
# making this a no-op there; elsewhere (Unraid) it bootstraps a fresh DB.
# Wait for Postgres first: psql failing must not be mistaken for "empty DB".
if [ -d /app/db-init ] && [ -n "$DATABASE_URL" ]; then
  i=0
  until pg_isready -d "$DATABASE_URL" >/dev/null 2>&1; do
    i=$((i+1)); [ "$i" -ge 30 ] && break
    sleep 2
  done
  PRESENT="$(psql "$DATABASE_URL" -tAc "SELECT to_regclass('public.__prism_migrations') IS NOT NULL" 2>/dev/null || echo err)"
  if [ "$PRESENT" = "f" ]; then
    echo "[entrypoint] Fresh database - applying base schema..."
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f /app/db-init/01-init.sql
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f /app/db-init/02-schema.sql
  fi
fi

echo "[entrypoint] Running database migrations..."
node /app/scripts/migrate.js

echo "[entrypoint] Starting Prism..."
exec node /app/server.js
