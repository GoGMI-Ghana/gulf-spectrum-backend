#!/bin/sh
#
# Puts Caddy in front of the Supabase gateway (port 8000) so the stack is
# reachable over HTTPS at a real domain, with Caddy handling Let's Encrypt
# automatically. Optional — the stack works over plain http://<vps-ip>:8000
# without this, which is fine for local testing but not for a live
# frontend talking to it from a browser.
#
# Prerequisites:
#   - A domain/subdomain's DNS A record already pointing at this VPS's IP
#     (e.g. supabase.yourdomain.com -> your VPS IP). This script can't
#     verify that for you — check with `dig +short supabase.yourdomain.com`.
#   - Ports 80 and 443 free on this VPS (not used by another web server).
#
# Usage:
#   sh setup-https.sh supabase.yourdomain.com
#

set -e

DOMAIN="$1"
if [ -z "$DOMAIN" ]; then
    echo "Usage: sh setup-https.sh <domain>"
    exit 1
fi

if ! command -v caddy >/dev/null 2>&1; then
    echo "== Installing Caddy =="
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
        sudo apt-get update
        sudo apt-get install -y caddy
    else
        echo "Error: this script only automates install on apt-based systems (Ubuntu/Debian, Hostinger's usual default)."
        echo "Install Caddy manually: https://caddyserver.com/docs/install"
        exit 1
    fi
fi

CADDYFILE=/etc/caddy/Caddyfile
echo "== Writing $CADDYFILE =="
sudo tee "$CADDYFILE" >/dev/null <<EOF
$DOMAIN {
    reverse_proxy 127.0.0.1:8000
}
EOF

sudo systemctl reload caddy 2>/dev/null || sudo systemctl restart caddy

cat <<EOF

Done. Caddy will request a Let's Encrypt certificate for $DOMAIN on first
request (may take a few seconds).

Now update docker/.env in supabase-project/ and set:
  SUPABASE_PUBLIC_URL=https://$DOMAIN
  API_EXTERNAL_URL=https://$DOMAIN
then from supabase-project/docker: docker compose up -d (to pick up the change).
EOF
