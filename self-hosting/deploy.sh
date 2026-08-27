#!/bin/sh
#
# Deploys self-hosted Supabase on this machine (meant for the Hostinger VPS,
# run over SSH as a user who can use docker — root or a member of the
# `docker` group). Safe to re-run: steps that already succeeded are skipped.
#
# What it does:
#   1. Checks for docker, docker compose, git, openssl, curl.
#   2. Clones the official supabase/supabase repo (docker/ folder only,
#      shallow) into ./supabase-project — NOT vendored/copied by hand, so
#      it can never silently drift from upstream.
#   3. Copies docker/.env.example -> docker/.env.
#   4. Runs Supabase's own key-generation scripts (generate-keys.sh,
#      add-new-auth-keys.sh) to fill in every secret correctly. We do not
#      hand-roll any JWT/crypto here — that's exactly the kind of thing
#      that's easy to get subtly wrong.
#   5. Pauses so you can edit docker/.env with your domain / site URL
#      before anything starts listening publicly.
#   6. `docker compose up -d`.
#
# After this succeeds, run ./apply-schema.sh to load the Gulf Spectrum
# Journal schema and seed data into the fresh database.
#
# Usage:
#   sh deploy.sh
#

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR="$SCRIPT_DIR/supabase-project"

echo "== Checking prerequisites =="
for cmd in git curl openssl docker; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: '$cmd' is required but not installed."
        case "$cmd" in
            docker) echo "  Install: curl -fsSL https://get.docker.com | sh" ;;
        esac
        exit 1
    fi
done
if ! docker compose version >/dev/null 2>&1; then
    echo "Error: 'docker compose' (the plugin, not the old docker-compose binary) is required."
    exit 1
fi
if ! docker info >/dev/null 2>&1; then
    echo "Error: docker daemon not reachable. Is it running, and is this user in the 'docker' group?"
    exit 1
fi
echo "OK."

echo ""
echo "== Fetching the official Supabase self-hosting stack =="
if [ -d "$PROJECT_DIR/.git" ]; then
    echo "Already cloned at $PROJECT_DIR — pulling latest."
    git -C "$PROJECT_DIR" pull --ff-only
else
    git clone --depth 1 --filter=blob:none --sparse https://github.com/supabase/supabase.git "$PROJECT_DIR"
    git -C "$PROJECT_DIR" sparse-checkout set docker
fi

DOCKER_DIR="$PROJECT_DIR/docker"
cd "$DOCKER_DIR"

echo ""
echo "== Preparing .env =="
if [ -f .env ]; then
    echo ".env already exists — leaving it as-is. Delete it first if you want to start over."
else
    cp .env.example .env
    echo "Copied .env.example -> .env"
fi

echo ""
echo "== Generating secrets (utils/generate-keys.sh) =="
if grep -q '^POSTGRES_PASSWORD=$' .env 2>/dev/null || grep -q '^POSTGRES_PASSWORD=your-super-secret' .env 2>/dev/null; then
    sh utils/generate-keys.sh --update-env
else
    echo "POSTGRES_PASSWORD already looks set — skipping (delete .env and re-run to regenerate)."
fi

echo ""
echo "== Generating asymmetric auth keys (utils/add-new-auth-keys.sh) =="
if ! grep -q '^JWT_KEYS=' .env 2>/dev/null; then
    sh utils/add-new-auth-keys.sh --update-env
else
    echo "JWT_KEYS already set — skipping."
fi

cat <<'EOF'

== Before starting the stack, edit docker/.env and set at minimum: ==

  SUPABASE_PUBLIC_URL   e.g. https://supabase.yourdomain.com  (or http://<vps-ip>:8000 for now)
  API_EXTERNAL_URL      same value as above
  SITE_URL              your frontend's URL, e.g. https://gulfspectrumjournal.com
  DASHBOARD_USERNAME    Studio login (dashboard_password was generated for you above)

If you don't have a domain pointed at this VPS yet, it's fine to start with
the plain http://<vps-ip>:8000 URLs now and switch to a real domain +
setup-https.sh later — just re-run this .env edit and `docker compose up -d`
again when you do.

Press Enter once docker/.env is edited (or Ctrl+C to stop and edit later).
EOF
read -r _

echo ""
echo "== Starting the stack =="
docker compose up -d

echo ""
echo "Done. 'docker compose ps' in $DOCKER_DIR to check status."
echo "Next: run ./apply-schema.sh from this self-hosting/ directory to load the journal's schema + seed data."
