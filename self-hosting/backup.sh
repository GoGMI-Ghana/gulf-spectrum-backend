#!/bin/sh
#
# Takes one backup of the Gulf Spectrum Journal backend and stores it on
# this server as a single dated archive. Scheduled daily by
# setup-backups.sh; safe to run by hand at any time (e.g. just before
# applying a migration):
#
#   sh backup.sh
#
# Each archive (gulf-spectrum-YYYYMMDD-HHMMSS.tar.gz) holds everything
# needed to rebuild the backend on a fresh server:
#
#   db.dump         The whole Postgres database (accounts, articles,
#                   issues, donations, messages…) in pg_dump's custom
#                   format, restorable with pg_restore.
#   storage.tar.gz  Uploaded files (author photos, issue covers, article
#                   images) from Supabase Storage.
#   env.backup      The stack's .env — the JWT secret, database password
#                   and API keys. Without the SAME secrets, a restored
#                   database's sessions and keys don't work.
#
# Because of env.backup, an archive is as sensitive as the server itself:
# the backup folder is root-only, and anything copied off the server
# should be encrypted (see OFF-SERVER COPIES below).
#
# Settings (all optional) are read from /etc/gulf-spectrum-backup.conf:
#
#   BACKUP_DIR=/var/backups/gulf-spectrum   where archives are kept
#   KEEP=14                                 how many archives to keep
#
# OFF-SERVER COPIES — a backup that lives only on this server does not
# survive losing the server. To also copy each archive elsewhere, install
# rclone, configure a remote (`rclone config`), and set:
#
#   RCLONE_REMOTE=myremote:gulf-spectrum-backups
#   PASSPHRASE_FILE=/root/.gulf-spectrum-backup-passphrase
#
# With PASSPHRASE_FILE set, the copy sent off-server is encrypted with gpg
# (AES-256) using the passphrase in that file. Keep that passphrase
# somewhere other than this server too — without it the copies are
# unreadable. RCLONE_REMOTE without PASSPHRASE_FILE is refused, on purpose.

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DOCKER_DIR="$SCRIPT_DIR/supabase-project/docker"
CONF=/etc/gulf-spectrum-backup.conf

BACKUP_DIR=/var/backups/gulf-spectrum
KEEP=14
RCLONE_REMOTE=
PASSPHRASE_FILE=
if [ -f "$CONF" ]; then
    # shellcheck disable=SC1090
    . "$CONF"
fi

log() { echo "$(date -u '+%Y-%m-%d %H:%M:%S') UTC  $*"; }
fail() { log "BACKUP FAILED: $*"; exit 1; }

[ -d "$DOCKER_DIR" ] || fail "$DOCKER_DIR not found — is this the server the stack runs on?"
cd "$DOCKER_DIR"
[ -n "$(docker compose ps db --status running -q 2>/dev/null)" ] || fail "the 'db' container isn't running"

umask 077
mkdir -p "$BACKUP_DIR"
STAMP=$(date -u +%Y%m%d-%H%M%S)
WORK="$BACKUP_DIR/.work-$STAMP"
ARCHIVE="$BACKUP_DIR/gulf-spectrum-$STAMP.tar.gz"
mkdir "$WORK"
# Never leave a half-written backup looking like a good one.
trap 'rm -rf "$WORK"' EXIT

# --- Database --------------------------------------------------------------
# supabase_admin is the stack's superuser and can read every schema (auth,
# storage, public). Older images only have `postgres` with those rights.
DB_USER=supabase_admin
docker compose exec -T db psql -U "$DB_USER" -d postgres -c 'select 1' >/dev/null 2>&1 || DB_USER=postgres

log "Dumping the database (as $DB_USER)…"
docker compose exec -T db pg_dump -U "$DB_USER" -d postgres -Fc > "$WORK/db.dump" \
    || fail "pg_dump reported an error"
[ -s "$WORK/db.dump" ] || fail "pg_dump produced an empty file"
# Reading the dump's table of contents back catches a truncated or corrupt
# file now, rather than on the day it's needed.
docker compose exec -T db pg_restore --list < "$WORK/db.dump" >/dev/null \
    || fail "the dump could not be read back by pg_restore"

# --- Uploaded files --------------------------------------------------------
if [ -d "$DOCKER_DIR/volumes/storage" ]; then
    log "Archiving uploaded files…"
    tar -czf "$WORK/storage.tar.gz" -C "$DOCKER_DIR/volumes" storage \
        || fail "could not archive volumes/storage"
else
    log "No volumes/storage folder — skipping uploaded files."
fi

# --- Secrets ---------------------------------------------------------------
cp "$DOCKER_DIR/.env" "$WORK/env.backup" || fail "could not copy .env"

# --- One archive -----------------------------------------------------------
tar -czf "$ARCHIVE.partial" -C "$WORK" . || fail "could not write the archive"
mv "$ARCHIVE.partial" "$ARCHIVE"
SIZE=$(du -h "$ARCHIVE" | cut -f1)
log "Wrote $ARCHIVE ($SIZE)"

# --- Off-server copy (optional) ---------------------------------------------
if [ -n "$RCLONE_REMOTE" ]; then
    command -v rclone >/dev/null 2>&1 || fail "RCLONE_REMOTE is set but rclone isn't installed"
    command -v gpg >/dev/null 2>&1 || fail "RCLONE_REMOTE is set but gpg isn't installed"
    [ -n "$PASSPHRASE_FILE" ] && [ -s "$PASSPHRASE_FILE" ] \
        || fail "RCLONE_REMOTE is set without a PASSPHRASE_FILE — refusing to send an unencrypted archive off-server"
    log "Encrypting and copying to $RCLONE_REMOTE…"
    gpg --batch --yes --symmetric --cipher-algo AES256 --passphrase-file "$PASSPHRASE_FILE" \
        -o "$WORK/$(basename "$ARCHIVE").gpg" "$ARCHIVE" || fail "encryption failed"
    rclone copy "$WORK/$(basename "$ARCHIVE").gpg" "$RCLONE_REMOTE" || fail "the off-server copy failed (the local archive is fine)"
    log "Off-server copy done."
else
    log "NOTE: no off-server copy configured — this archive exists only on this server."
fi

# --- Keep the newest $KEEP ---------------------------------------------------
# shellcheck disable=SC2012
ls -1t "$BACKUP_DIR"/gulf-spectrum-*.tar.gz 2>/dev/null | tail -n +"$((KEEP + 1))" | while read -r old; do
    rm -f "$old"
    log "Removed old backup $(basename "$old")"
done

log "Backup complete."
