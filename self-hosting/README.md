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
   `SUPABASE_PUBLIC_URL` / `API_EXTERNAL_URL` / `SITE_URL` / dashboard
   credentials.
5. `docker compose up -d`.

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

## Updating later

`deploy.sh` is safe to re-run — it skips steps that already succeeded
(existing `.env`, already-set secrets). To pull a newer Supabase release,
`git -C supabase-project pull` and `docker compose up -d` again from
`supabase-project/docker`.

## What's not verified here

Same caveat as the rest of this repo: this was put together carefully by
reading Supabase's actual current `docker-compose.yml` and `.env.example`
(not from memory — the API gateway is Envoy now, not Kong, which is a
recent change), but it has not been run end-to-end against your VPS yet.
Treat the first `sh deploy.sh` as the real test.
