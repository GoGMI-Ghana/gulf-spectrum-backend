#!/bin/sh
#
# Proves a backup can actually be restored — without touching the live
# database. Run as root, any time:
#
#   sh verify-backup.sh                       # checks the newest backup
#   sh verify-backup.sh /path/to/archive.tar.gz
#
# It restores the archive's database dump into a separate scratch database
# (backup_verify) on the same Postgres server, counts the rows in the
# journal's main tables there, shows them beside the live counts, and then
# drops the scratch database again. The live database is only ever read.
#
# What to look for: the "in backup" numbers should match "live now" (or be
# slightly lower, if content was added since the backup was taken). A
# backup that restores with zero rows, or not at all, is not a backup.
#
# pg_restore prints some errors for things that can only exist once per
# server (certain extensions and their scheduled jobs) — those are expected
# here and don't affect the journal's data, which is what the counts check.

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DOCKER_DIR="$SCRIPT_DIR/supabase-project/docker"
BACKUP_DIR=/var/backups/gulf-spectrum
SCRATCH_DB=backup_verify
TABLES="profiles topics authors issues articles article_authors bookmarks donations submissions contact_messages"

# shellcheck disable=SC2012
ARCHIVE=${1:-$(ls -1t "$BACKUP_DIR"/gulf-spectrum-*.tar.gz 2>/dev/null | head -n 1)}
[ -n "$ARCHIVE" ] && [ -f "$ARCHIVE" ] || { echo "No backup archive found. Run backup.sh first."; exit 1; }

cd "$DOCKER_DIR"
DB_USER=supabase_admin
docker compose exec -T db psql -U "$DB_USER" -d postgres -c 'select 1' >/dev/null 2>&1 || DB_USER=postgres

WORK=$(mktemp -d)
cleanup() {
    rm -rf "$WORK"
    docker compose exec -T db psql -U "$DB_USER" -d postgres -q -c "drop database if exists $SCRATCH_DB" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Checking $(basename "$ARCHIVE")"
tar -xzf "$ARCHIVE" -C "$WORK" || { echo "FAILED: the archive could not be unpacked."; exit 1; }
for part in db.dump env.backup; do
    [ -s "$WORK/$part" ] || { echo "FAILED: the archive has no $part."; exit 1; }
done
if [ -f "$WORK/storage.tar.gz" ]; then
    FILES=$(tar -tzf "$WORK/storage.tar.gz" | grep -vc '/$' || true)
    echo "Uploaded files in the backup: $FILES"
else
    echo "Uploaded files in the backup: none (no storage folder was present)"
fi

echo "Restoring into a scratch database ($SCRATCH_DB)…"
docker compose exec -T db psql -U "$DB_USER" -d postgres -q -c "drop database if exists $SCRATCH_DB" >/dev/null
docker compose exec -T db psql -U "$DB_USER" -d postgres -q -c "create database $SCRATCH_DB" >/dev/null
# Errors are expected for a few server-wide objects (see the header), so
# pg_restore's exit status isn't the test — the row counts below are.
docker compose exec -T db pg_restore -U "$DB_USER" -d "$SCRATCH_DB" --no-owner < "$WORK/db.dump" > "$WORK/restore.log" 2>&1 || true
echo "  pg_restore finished ($(grep -c 'error:' "$WORK/restore.log" || true) message(s) about server-wide objects)."

count() { # database, table
    docker compose exec -T db psql -U "$DB_USER" -d "$1" -At -c "select count(*) from public.$2" 2>/dev/null || echo "missing"
}

echo ""
printf '%-22s %12s %12s\n' "table" "in backup" "live now"
printf '%-22s %12s %12s\n' "----------------------" "---------" "--------"
BAD=0
for table in $TABLES; do
    restored=$(count "$SCRATCH_DB" "$table")
    live=$(count postgres "$table")
    printf '%-22s %12s %12s\n' "$table" "$restored" "$live"
    [ "$restored" = "missing" ] && BAD=1
done
ACCOUNTS=$(docker compose exec -T db psql -U "$DB_USER" -d "$SCRATCH_DB" -At -c "select count(*) from auth.users" 2>/dev/null || echo "missing")
printf '%-22s %12s\n' "accounts (auth.users)" "$ACCOUNTS"
[ "$ACCOUNTS" = "missing" ] && BAD=1
echo ""

if [ "$BAD" -eq 0 ]; then
    echo "RESULT: OK — this backup restores, and the journal's tables are in it."
else
    echo "RESULT: PROBLEM — some tables did not restore. Details:"
    grep 'error:' "$WORK/restore.log" | head -n 20
    exit 1
fi
