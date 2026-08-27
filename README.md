# Gulf Spectrum Backend

Supabase backend for [Gulf Spectrum Journal](https://github.com/GoGMI-Ghana/Gulf-spectrum-journal) — the Postgres schema, seed data, and edge functions. Not connected to a live Supabase project yet; this repo is the schema and the seed, ready to apply once one exists.

## What's here

```
supabase/
  migrations/
    20260826000000_init_schema.sql   The full schema: topics, authors, issues,
                                      articles, article_authors, bookmarks,
                                      article_events (+ article_stats view),
                                      donations, memberships, profiles, and
                                      the RLS policies governing all of it.
  seed.sql                           Real INSERT statements for Issue No. 1's
                                      placeholder content — the same data the
                                      frontend currently ships as static
                                      arrays in lib/content.ts. Keeps the two
                                      in sync until the frontend is switched
                                      over to querying this database.
  functions/
    paystack-webhook/                Verifies a Paystack webhook signature
                                      and marks a donation/membership row
                                      'completed'. Real, correct code — just
                                      not deployed or connected to a real
                                      Paystack account yet.
  config.toml                        Supabase CLI project config.
```

## Choosing where Postgres actually runs

Two options, same schema and seed either way:

- **Supabase Cloud** — a project's already been created there
  ("GoGMI-Ghana's Project"). Follow "Connecting a real Supabase project"
  below.
- **Self-hosted on GoGMI's Hostinger VPS** — see
  [`self-hosting/`](self-hosting/) for a `deploy.sh` that stands up the
  official Supabase Docker stack on the VPS, plus a script to load this
  repo's migration + seed data into it. This is the path currently being
  set up.

Either way, `supabase/migrations/` and `supabase/seed.sql` are what get
applied — nothing about the schema changes based on where it's hosted.

## Prerequisites

- Node.js (the Supabase CLI is installed as a local dev dependency, not
  globally — everything below runs through `npm run`).
- **Docker Desktop**, if you want to run this against a local Postgres
  instance (`supabase start`). Not required to deploy to a real hosted
  project — `supabase db push` talks to the remote database directly.
- A [Supabase](https://supabase.com) account, once you're ready to create
  a real project (free tier is enough to start).

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

## Connecting a real Supabase project

1. Create a project at [supabase.com](https://supabase.com/dashboard).
2. Authenticate the CLI: `npx supabase login`
3. Link this repo to that project:
   ```bash
   npx supabase link --project-ref <your-project-ref>
   ```
   (The project ref is in the project's Settings -> General.)
4. Push the schema:
   ```bash
   npm run db:push
   ```
5. Seed it — the CLI doesn't run `seed.sql` against a remote project
   automatically (that only happens on local `db reset`), so run it
   directly via `psql` or the Supabase Studio SQL editor:
   ```bash
   psql "$(npx supabase status -o env | grep DB_URL | cut -d= -f2)" -f supabase/seed.sql
   ```
   or paste `supabase/seed.sql`'s contents into the SQL Editor in Studio.
6. Copy the project's URL and anon key (Settings -> API) into the
   **frontend** repo's `.env.local` (see its README) — that's the wiring
   that switches the site from placeholder data to this database.

## Editing the schema

Don't hand-edit `20260826000000_init_schema.sql` after it's been applied
anywhere real. Instead, make a new migration:

```bash
npx supabase migration new <description>
# edit the new file in supabase/migrations/
npm run db:reset    # re-applies everything locally to check it
npm run db:push      # apply to the linked remote project
```

## Paystack webhook

`supabase/functions/paystack-webhook` verifies the Paystack signature and
marks the corresponding `donations` or `memberships` row `completed`. To
go live:

1. Create a Paystack account, get the secret key (Settings -> API Keys
   & Webhooks).
2. `npx supabase secrets set PAYSTACK_SECRET_KEY=sk_...`
3. `npm run functions:deploy`
4. In the Paystack dashboard, set the webhook URL to
   `https://<project-ref>.supabase.co/functions/v1/paystack-webhook`.
5. The frontend's checkout call needs to pass
   `metadata: { type: 'donation' | 'membership', record_id: '<uuid>' }`
   when initializing the Paystack transaction, so the webhook knows which
   row to update. That frontend integration (in `SupportBox.tsx` /
   `JoinForm.tsx`) isn't built yet — right now those forms show a "no
   payment was processed" message instead of starting a real checkout.

## A note on what's verified here and what isn't

This schema was written carefully and reviewed for RLS/privilege issues
(see the migration's comments — e.g. the `is_editor()` helper and the
explicit `revoke update (role, ...)` guarding against a user promoting
themselves to admin), but it has **not been executed against a real
Postgres**. Docker wasn't available in the environment this was built in,
so `supabase start` / `db reset` / `db lint` couldn't be run here. Treat
the first `npm run db:start` (or `db:push` to a real project) as the real
test — if something doesn't apply cleanly, that's expected to surface
there, not a sign anything was skipped carelessly.
