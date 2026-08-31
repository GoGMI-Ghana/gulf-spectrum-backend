# Self-hosting Supabase on the Hostinger VPS

This is the alternative to using Supabase Cloud: run the same Supabase
stack (Postgres, Auth, PostgREST, Realtime, Storage, Studio, Edge
Functions) yourself, in Docker, on GoGMI's own VPS. The schema and seed
data in `../supabase/` are identical either way — only where Postgres
lives changes.

Nothing here vendors copies of Supabase's own config files (docker-compose,
`.env.example`, key-generation logic). `deploy.sh` clones the official
[`supabase/supabase`](https://github.com/supabase/supabase) repo's `docker/`
folder fresh and runs *their* scripts — hand-copying ~15 interdependent
service configs into this repo would only risk drifting out of date or
transcribing something wrong.

## What you need before starting

- SSH access to the VPS (you said you have this).
- The VPS's RAM/CPU — the full stack (Postgres, Auth, REST, Realtime,
  Storage, Studio, imgproxy, connection pooler, Edge Functions) is
  Postgres-plus-nine-services. It'll run on 2 GB RAM but 4 GB+ is more
  comfortable, especially once real traffic hits it.
- Docker + the Compose plugin on the VPS (`deploy.sh` tells you the install
  command if it's missing — Hostinger's Ubuntu templates don't ship it by
  default).
- Optional but recommended for production: a domain or subdomain (e.g.
  `api.gulfspectrumjournal.com`) with its DNS A record pointed at the
  VPS's IP, so it can get a real TLS certificate. Without this the stack
  is only reachable over plain HTTP, which a browser will refuse to talk
  to from an HTTPS frontend (mixed content).
- Check what's already listening on ports 80/443 before assuming either
  HTTPS script applies (`ss -ltnp | grep -E ':80 |:443 '`). GoGMI's shared
  VPS already runs nginx + certbot for its other projects
  (`api.intranet.gogmi.org.gh`, `api.lms.gogmi.org.gh`) — on that box, use
  `setup-https-nginx.sh`, not `setup-https.sh` (which installs Caddy and
  would fight the existing nginx for those ports).

## Steps

Run these **on the VPS**, over your own SSH session — this assistant
doesn't hold VPS credentials and won't run destructive/root-level commands
against your infrastructure on your behalf. Everything below is copy-paste.

```bash
git clone https://github.com/GoGMI-Ghana/gulf-spectrum-backend.git
cd gulf-spectrum-backend/self-hosting
sh deploy.sh
```

`deploy.sh` will:
1. Check Docker is installed and running.
2. Clone `supabase/supabase`'s `docker/` folder into `./supabase-project`.
3. Copy `.env.example` → `.env` and run Supabase's own
   `utils/generate-keys.sh` + `utils/add-new-auth-keys.sh` to fill in every
   secret (JWT secret, anon/service-role keys, Postgres password, Studio
   dashboard password, encryption keys — see the script comments for the
   full list). Nothing here hand-rolls JWT signing.
4. Pause so you can edit `supabase-project/docker/.env` and set
   `SUPABASE_PUBLIC_URL` / `API_EXTERNAL_URL` (same host, with `/auth/v1`
   appended) / `SITE_URL` / dashboard credentials.
5. Check whether something outside Docker is already using the Postgres
   port and remap the pooler's published port if so (see "Known gotcha"
   below).
6. `docker compose up -d`.

Then load the journal's schema and seed data:

```bash
sh apply-schema.sh
```

That pipes `../supabase/migrations/*.sql` and `../supabase/seed.sql` into
the running `db` container — no local `psql` needed.

If you have a domain pointed at the VPS, turn on HTTPS. Check what's
already on ports 80/443 first (see above) to pick the right script:

```bash
# nginx already running on this VPS for other GoGMI projects — this is
# the one that applies on GoGMI's shared VPS:
sh setup-https-nginx.sh api.gulfspectrumjournal.com you@example.com

# nothing on 80/443 yet (a bare VPS) — installs Caddy instead:
sh setup-https.sh api.gulfspectrumjournal.com
```

## After the stack is running

- Studio (the Supabase dashboard) is at whatever you set
  `SUPABASE_PUBLIC_URL` to — log in with `DASHBOARD_USERNAME` /
  `DASHBOARD_PASSWORD` from `supabase-project/docker/.env`.
- Grab `ANON_KEY` (or `SUPABASE_PUBLISHABLE_KEY`, the newer opaque
  equivalent) from that same `.env` for the **frontend** repo's
  `.env.local` — see its README's "Turning this into a real backend"
  section.
- The Paystack webhook Edge Function in `../supabase/functions/` deploys
  the same way either way: `supabase functions deploy` needs the CLI
  linked to *this* project. For a self-hosted stack that means running the
  CLI against `--db-url`/the local API URL rather than `supabase link` (which
  targets Supabase Cloud specifically) — worth revisiting once the stack is
  up and reachable, since the exact CLI flags for self-hosted Edge Function
  deploys are easiest to confirm against the running instance rather than
  guessed here.

## Known gotcha: `SITE_URL` has to match wherever the frontend actually is

`docker/.env`'s `SITE_URL` (and `ADDITIONAL_REDIRECT_URLS`, a comma-separated
allow-list) control which `redirect_to` values GoTrue will actually honor
after a sign-in — OAuth (Google, etc.) included. Anything not in that list
gets silently swapped for `SITE_URL` itself, with no error surfaced to the
frontend. `deploy.sh`'s .env-editing pause mentions this, but it's easy to
leave at the `.env.example` default (`http://localhost:3000`) since nothing
breaks loudly until someone actually tries an OAuth sign-in — the failure
mode is a mysterious redirect to `localhost:3000` from a production site,
not an obvious error. Hit this exact thing once already: `SITE_URL` never
got updated off the default when the stack was first stood up, and Google
sign-in silently bounced everyone's browser to `localhost:3000` until caught.

Update both whenever the frontend's deployed URL changes (a new Vercel
preview, a custom domain replacing the current one, etc.):

```bash
# in supabase-project/docker/
sed -i \
  -e 's|^SITE_URL=.*|SITE_URL=https://your-real-frontend-url|' \
  -e 's|^ADDITIONAL_REDIRECT_URLS=.*|ADDITIONAL_REDIRECT_URLS=http://localhost:3000/auth/callback|' \
  .env
docker compose up -d auth
```

## Known gotcha: a pre-existing Postgres on the host

If port 5432 (or whatever `POSTGRES_PORT` is set to) is already bound by
something outside Docker — a natively-installed Postgres, for instance —
the `supavisor` (connection pooler) container will crash-loop on startup.
The failure is misleading: its logs just show

```
Setting RLIMIT_NOFILE to 100000
hostname: Temporary failure in name resolution
```

repeated on every restart, which looks like a DNS problem but isn't one —
it's the container failing to bind the host port it's told to publish.
`deploy.sh` checks for this and remaps the pooler's *published* port
automatically (internal container-to-container traffic is unaffected
either way, since that goes over the Docker network to `db:5432`
regardless of what's exposed to the host). If you ever hit this manually:
`docker logs supabase-pooler`, then check `ss -ltnp | grep :5432` for
what's already listening, and edit the `supavisor` service's `ports:`
entry in `docker-compose.yml` to publish a free host port instead of
touching whatever else is already using 5432 — don't stop or reconfigure
an existing service you didn't set up without checking what it is and
whether anything depends on it first.

## Known gotcha: ports 80/443 already owned by another project's nginx

GoGMI's Hostinger VPS isn't dedicated to this project — it already runs
an intranet/LMS stack (native Postgres, nginx, certbot-managed certs for
`api.intranet.gogmi.org.gh` and `api.lms.gogmi.org.gh`) from before this
deployment. Nothing here touches that: `setup-https-nginx.sh` only adds a
*new* nginx server block and requests a *new* certificate for our own
domain, alongside the existing ones. If you're setting this up on a
*different*, genuinely bare VPS, `setup-https.sh` (Caddy) is the simpler
option — just confirm with `ss -ltnp` that nothing else owns those ports
first.

## Updating later

`deploy.sh` is safe to re-run — it skips steps that already succeeded
(existing `.env`, already-set secrets). To pull a newer Supabase release,
`git -C supabase-project pull` and `docker compose up -d` again from
`supabase-project/docker`.

## Status

Deployed and verified end-to-end on the GoGMI Hostinger VPS
(`srv1275242.hstgr.cloud`, Ubuntu 24.04): all 11 services healthy, the
`gulf-spectrum-backend` migration and seed applied cleanly, and
`https://api.gulfspectrumjournal.com/rest/v1/topics` confirmed returning
real seeded rows over the public gateway (certificate via certbot,
auto-renewing). The frontend's `.env.local` points at the HTTPS URL.

Not yet done: the pre-existing native Postgres and nginx setup for
GoGMI's other projects on this VPS (see the two "Known gotcha" sections
above) haven't been investigated further than confirming they're
unaffected — they predate this deployment and weren't touched.
