#!/bin/sh
#
# Applies this repo's migration + seed SQL to the self-hosted Postgres
# started by deploy.sh, by piping them into the running `db` container
# (no local psql client required).
#
# Usage:
#   sh apply-schema.sh              # migration + seed
#   sh apply-schema.sh --no-seed    # migration only (e.g. re-applying to
#                                    # a database that already has real data)
#

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DOCKER_DIR="$SCRIPT_DIR/supabase-project/docker"
BACKEND_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
MIGRATIONS_DIR="$BACKEND_DIR/supabase/migrations"
SEED_FILE="$BACKEND_DIR/supabase/seed.sql"

if [ ! -d "$DOCKER_DIR" ]; then
    echo "Error: $DOCKER_DIR not found. Run deploy.sh first."
    exit 1
fi

cd "$DOCKER_DIR"

if ! docker compose ps db --status running >/dev/null 2>&1 || [ -z "$(docker compose ps db --status running -q 2>/dev/null)" ]; then
    echo "Error: the 'db' container isn't running. Run 'docker compose up -d' in $DOCKER_DIR first."
    exit 1
fi

run_sql_file() {
    file="$1"
    echo "-- applying $(basename "$file")"
    docker compose exec -T db psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f - < "$file"
}

echo "== Applying migrations =="
for f in "$MIGRATIONS_DIR"/*.sql; do
    run_sql_file "$f"
done

if [ "$1" != "--no-seed" ]; then
    echo ""
    echo "== Applying seed data =="
    run_sql_file "$SEED_FILE"
else
    echo "Skipping seed data (--no-seed)."
fi

echo ""
echo "Done. Browse the data in Studio (see SUPABASE_PUBLIC_URL in docker/.env)."
echo "Grab the ANON_KEY from docker/.env for the frontend's NEXT_PUBLIC_SUPABASE_ANON_KEY."
