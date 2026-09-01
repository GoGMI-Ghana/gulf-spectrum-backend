# Gulf Spectrum Backend

Supabase backend for [Gulf Spectrum Journal](https://github.com/GoGMI-Ghana/Gulf-spectrum-journal) — the Postgres schema and seed data. Live: self-hosted on GoGMI's Hostinger VPS (see [`self-hosting/`](self-hosting/)), applied and verified against the real running instance, not just written and hoped for.

## What's here

```
supabase/
  migrations/
    20260826000000_init_schema.sql   Core schema: topics, authors, issues,
                                      articles, article_authors, bookmarks,
                                      article_events (+ article_stats view),
                                      donations, profiles, and the RLS
                                      policies governing all of it.
    ...later migrations             article_daily_stats view, notifications
                                      (+ publish-fanout triggers), direct
                                      messages (conversations/messages,
                                      member directory, realtime), account
                                      deletion support, and dropping the
                                      memberships table (GoGMI
                                      membership/dues were removed from the
                                      site — donations on individual
                                      articles are the one payment flow).
  seed.sql                           Real INSERT statements for Issue No. 1's
                                      content — applied to the live database,
                                      not just shipped as frontend fallback
                                      data.
  config.toml                        Supabase CLI project config.
```

There's no `supabase/functions/` here anymore — the Paystack webhook lives
in the **frontend** repo instead (`app/api/paystack-webhook`), not as a
Supabase Edge Function. Reason: the self-hosted stack's function gateway
requires an `apikey` header on every request (confirmed directly against
the live instance), and Paystack's webhook configuration has no way to
send custom headers — it's just a URL. A Next.js Route Handler on Vercel
has no such gate.

## Choosing where Postgres actually runs

Two options, same schema and seed either way — see
[`self-hosting/`](self-hosting/) for the one actually in use:

- **Self-hosted on GoGMI's Hostinger VPS** — the live path. `deploy.sh`
  stands up the official Supabase Docker stack; `apply-schema.sh` loads
  this repo's migrations + seed into it.
- **Supabase Cloud** — a project exists there too ("GoGMI-Ghana's
  Project") but isn't what's actually deployed. Follow "Connecting a real
  Supabase project" below if that ever changes.

## Prerequisites

- Node.js (the Supabase CLI is installed as a local dev dependency, not
  globally — everything below runs through `npm run`).
- **Docker Desktop**, only if you want to run this against a local
  Postgres instance (`supabase start`) for local development. Not needed
  to apply migrations to the self-hosted VPS or a real hosted project —
  both of those talk to a remote database directly.

## Local development (needs Docker)

```bash
npm install
npm run db:start   # spins up local Postgres + Studio in Docker,
                    # applies migrations, then seed.sql automatically
```

`supabase start` prints a local Studio URL (usually http://localhost:54323)
where you can browse the tables, and an API URL + anon key you can point
the frontend's `.env.local` at for fully local end-to-end testing.

```bash
npm run db:stop    # tear down the local containers
npm run db:reset   # re-apply migrations + seed against the local DB
                    # (useful after editing a migration)
```

## Applying a new migration to the self-hosted VPS

This is how every migration in this repo has actually been applied and
verified — not `supabase db push` (that targets Supabase Cloud
specifically):

```bash
scp supabase/migrations/<new-file>.sql root@<vps-ip>:~/gulf-spectrum-backend/supabase/migrations/
ssh root@<vps-ip> '
  cd ~/gulf-spectrum-backend/self-hosting/supabase-project/docker
  docker compose exec -T db psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f - \
    < ~/gulf-spectrum-backend/supabase/migrations/<new-file>.sql
'
```

`-v ON_ERROR_STOP=1` matters: without it, psql keeps going after a failed
statement instead of stopping, which can leave a migration half-applied.
If a migration fails partway through, the objects it did create before
failing need to be dropped by hand before re-running the corrected file —
`CREATE TABLE`/`CREATE POLICY`/etc. aren't idempotent, so re-running as-is
errors on "already exists" instead of resuming.

## Connecting a real Supabase Cloud project

Only relevant if you move off self-hosting:

1. Create a project at [supabase.com](https://supabase.com/dashboard).
2. Authenticate the CLI: `npx supabase login`
3. Link this repo to that project:
   ```bash
   npx supabase link --project-ref <your-project-ref>
   ```
4. Push the schema: `npm run db:push`
5. Seed it — the CLI doesn't run `seed.sql` against a remote project
   automatically, so run it directly:
   ```bash
   psql "$(npx supabase status -o env | grep DB_URL | cut -d= -f2)" -f supabase/seed.sql
   ```
6. Copy the project's URL and anon key (Settings -> API) into the
   **frontend** repo's `.env.local`.

## Editing the schema

Don't hand-edit `20260826000000_init_schema.sql` (or any migration)
after it's been applied anywhere real. Instead, make a new migration:

```bash
npx supabase migration new <description>
# edit the new file in supabase/migrations/
npm run db:reset    # re-applies everything locally to check it, if Docker's available
```

Then apply it to the VPS the same way as above.

## Paystack

Donations (the one payment flow — GoGMI membership/dues were removed)
use Paystack's hosted checkout. Both the checkout-initiation call and the
webhook that confirms payment live in the **frontend** repo now (see the
note under "What's here" above for why) — `app/api/donations/initiate`
and `app/api/paystack-webhook`. This repo just owns the `donations` table
and its RLS (`for insert with check (true)` — anyone can start a pending
donation; only editors can read the list back).
