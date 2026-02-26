#!/bin/sh
# docker-entrypoint.sh
# Wait for PostgreSQL to be ready, then run DB migrations, then start the API.

set -e

echo "⏳  Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT} …"
until pg_isready -h "${DB_HOST:-localhost}" -p "${DB_PORT:-5432}" -U "${DB_USER:-postgres}" > /dev/null 2>&1; do
  sleep 1
done
echo "✅  PostgreSQL is ready."

# Apply schema (idempotent — uses CREATE TABLE IF NOT EXISTS)
echo "📦  Applying DB schema …"
psql "postgresql://${DB_USER:-postgres}:${DB_PASSWORD:-postgres}@${DB_HOST:-localhost}:${DB_PORT:-5432}/${DB_NAME:-shelfscanner}" \
     -f /app/db/schema.sql
echo "✅  Schema applied."

echo "🚀  Starting ShelfScanner API …"
exec "$@"
