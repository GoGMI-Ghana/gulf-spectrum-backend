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
  `supabase.gogmi.org.gh`) with its DNS A record pointed at the VPS's IP,
  so `setup-https.sh` can get it a real TLS certificate. Without this the
  stack is only reachable over plain HTTP, which a browser will refuse to
  talk to from an HTTPS frontend (mixed content).

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

If you have a domain pointed at the VPS, turn on HTTPS:

```bash
sh setup-https.sh supabase.gogmi.org.gh
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

## Updating later

`deploy.sh` is safe to re-run — it skips steps that already succeeded
(existing `.env`, already-set secrets). To pull a newer Supabase release,
`git -C supabase-project pull` and `docker compose up -d` again from
`supabase-project/docker`.

## Status

Deployed and verified end-to-end on the GoGMI Hostinger VPS
(`srv1275242.hstgr.cloud`, Ubuntu 24.04): all 11 services healthy, the
`gulf-spectrum-backend` migration and seed applied cleanly, and
`/rest/v1/topics` confirmed returning real seeded rows over the public
gateway. The frontend's `.env.local` points at it.

Not yet done: HTTPS (no domain pointed at the VPS yet — currently plain
`http://<vps-ip>:8000`, fine for development but not for a live frontend
requesting it from an HTTPS page), and the pre-existing native Postgres
on the VPS (see "Known gotcha" above) hasn't been investigated — it
predates this deployment and wasn't touched.
