#!/bin/sh
#
# Puts the self-hosted Supabase stack behind HTTPS using an nginx +
# certbot setup that's ALREADY running on this VPS (as opposed to
# setup-https.sh, which installs Caddy — only appropriate on a VPS with
# nothing else on ports 80/443). Use this one whenever nginx already owns
# those ports, which is the case on GoGMI's shared VPS (it also serves
# api.intranet.gogmi.org.gh and api.lms.gogmi.org.gh) — check first with
# `ss -ltnp | grep -E ':80 |:443 '` before assuming either way.
#
# Adds a new nginx server block reverse-proxying to the stack's api-gw
# (localhost:8000) and gets it a certificate via certbot's nginx plugin —
# the same tool and pattern already used for the other GoGMI subdomains on
# this box. Existing sites/certs are untouched.
#
# Prerequisites:
#   - nginx and certbot already installed and running (true on this VPS).
#   - The domain's DNS A record already pointing at this VPS's IP.
#
# Usage:
#   sh setup-https-nginx.sh api.gulfspectrumjournal.com you@example.com
#

set -e

DOMAIN="$1"
CERTBOT_EMAIL="$2"
BACKEND_PORT="${3:-8000}"

if [ -z "$DOMAIN" ] || [ -z "$CERTBOT_EMAIL" ]; then
    echo "Usage: sh setup-https-nginx.sh <domain> <email-for-certbot> [backend-port]"
    exit 1
fi

for cmd in nginx certbot; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: '$cmd' not found. This script assumes nginx + certbot are already set up"
        echo "(true on GoGMI's shared VPS). For a bare VPS with nothing on 80/443, use"
        echo "setup-https.sh instead, which installs Caddy."
        exit 1
    fi
done

SITE_FILE="/etc/nginx/sites-available/${DOMAIN}"
if [ -f "$SITE_FILE" ]; then
    echo "Error: $SITE_FILE already exists — this domain looks already configured."
    echo "Delete it first (and its sites-enabled symlink) to start over."
    exit 1
fi

echo "== Writing $SITE_FILE =="
cat > "$SITE_FILE" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    client_max_body_size 20M;

    location / {
        proxy_pass http://localhost:${BACKEND_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

ln -sf "$SITE_FILE" "/etc/nginx/sites-enabled/${DOMAIN}"

echo "== Testing nginx config =="
nginx -t

echo "== Reloading nginx =="
systemctl reload nginx

echo "== Requesting certificate (certbot --nginx) =="
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$CERTBOT_EMAIL" --redirect

cat <<EOF

Done. https://${DOMAIN} now proxies to localhost:${BACKEND_PORT}.

Now update supabase-project/docker/.env:
  SUPABASE_PUBLIC_URL=https://${DOMAIN}
  API_EXTERNAL_URL=https://${DOMAIN}/auth/v1
then from supabase-project/docker: docker compose up -d (to pick up the change).
EOF
