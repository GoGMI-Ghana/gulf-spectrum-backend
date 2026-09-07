-- Editorial board membership — distinct from being an Author.
--
-- An Author (see init_schema.sql) can be credited on a published article
-- without ever holding an account on the platform — the site just needs
-- somewhere to put their name and bio. A board member is the opposite:
-- they must be a real signed-in account (there's nothing to "join" if
-- you're not on the platform), and membership is a visible, publicly
-- displayed status, not just a content-attribution record.
--
-- profiles.board_title does double duty: non-null means "this account is
-- currently on the editorial board", and its text is the title shown
-- with them (e.g. "Editor-in-Chief", "Associate Editor") — the same
-- free-text shape as issues.editorial_board's {name, role} pairs,
-- reused here as a single column instead of a jsonb array since a
-- profile only ever holds one board title at a time.
--
-- Becoming a board member also grants the 'editor' role (decided
-- deliberately, not a side effect worth hiding): a real editorial board
-- reviews and helps publish content, so the two are the same status
-- here rather than two separate things an admin has to keep in sync.
alter table profiles add column board_title text;

-- Same reasoning as the existing `revoke update (role, author_id)` a few
-- lines below in init_schema.sql: RLS restricts which *row* a user can
-- update, not which *column* — without this, "users update their own
-- profile" would let anyone grant themselves a board title (and, via
-- the application-review routes' logic, the 'editor' role that comes
-- with it). Only the service-role admin client can set this column now.
revoke update (board_title) on profiles from authenticated, anon;

-- Board members are meant to be publicly visible (that's the point of a
-- "tag that symbolizes" membership) — everyone else's profile stays
-- restricted to themselves or, per the existing directory policy, other
-- signed-in members. This is additive: it only ever widens access for
-- rows that already chose to be public by having a board_title.
create policy "board members are publicly visible" on profiles
  for select using (board_title is not null);

-- Mirrors is_editor() below it in spirit: a small named check instead
-- of repeating the subquery in every policy that needs "is this
-- specifically an admin, not just any editor".
create function is_admin(uid uuid)
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (select 1 from profiles where id = uid and role = 'admin');
$$;

create type application_status as enum ('pending', 'approved', 'declined');

create table editorial_board_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  statement text not null,
  status application_status not null default 'pending',
  reviewed_by uuid references profiles (id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

-- One pending application per person at a time — stops someone spamming
-- applications while a decision is still outstanding. They can apply
-- again after a decline (a new row, not an update to the old one, so
-- the decline stays on record).
create unique index one_pending_application_per_user on editorial_board_applications (user_id)
  where status = 'pending';

alter table editorial_board_applications enable row level security;

create policy "users apply for the board" on editorial_board_applications
  for insert with check (user_id = auth.uid());

create policy "users read their own applications" on editorial_board_applications
  for select using (user_id = auth.uid());

-- Admin-only, not "any editor": deciding an application effectively
-- grants CMS write access (see above), which is exactly the kind of
-- privilege change this app already treats as admin-only everywhere
-- else (compare Users & Roles / profiles.role).
create policy "admins manage applications" on editorial_board_applications
  for all using (is_admin(auth.uid())) with check (is_admin(auth.uid()));
