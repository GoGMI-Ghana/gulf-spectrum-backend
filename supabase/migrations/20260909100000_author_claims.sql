-- Author self-service claiming: a registered reader can say "this author
-- page is me" and have an editor confirm it, rather than an editor being
-- the only path to linking authors.user_id (the admin Authors form still
-- works too -- this adds a second, reader-initiated path to the same
-- link). Reuses application_status from the editorial-board migration
-- (pending/approved/declined) -- same shape, no reason for a second enum.

create table author_claims (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  author_id uuid not null references authors (id) on delete cascade,
  message text,
  status application_status not null default 'pending',
  reviewed_by uuid references profiles (id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

-- Same reasoning as one_pending_application_per_user: stops someone
-- spamming claims while a decision is outstanding. A decline doesn't
-- block trying again (for the same or a different author) since it's a
-- new row, not an update to the old one.
create unique index one_pending_claim_per_user on author_claims (user_id)
  where status = 'pending';

alter table author_claims enable row level security;

create policy "users claim an author profile" on author_claims
  for insert with check (user_id = auth.uid());
create policy "users read their own claims" on author_claims
  for select using (user_id = auth.uid());

-- Editor-reviewable, not admin-only like editorial board applications --
-- editors already have full unrestricted write access to the authors
-- table directly (see "editors manage authors" below), so gating claim
-- review to admins specifically would just be a narrower door to
-- something they can already do the long way around.
create policy "editors manage author claims" on author_claims
  for all using (is_editor(auth.uid())) with check (is_editor(auth.uid()));

-- What claiming is actually FOR: once linked, the account holder can
-- maintain their own bio/photo/credentials directly, instead of asking
-- an editor for every small update. Deliberately not column-restricted
-- (e.g. a claimed author could also change their own slug, which would
-- break existing links to it) -- an accepted simplicity tradeoff, same
-- as how "users update their own profile" is a full-row policy too.
create policy "claimed authors edit their own record" on authors
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());
