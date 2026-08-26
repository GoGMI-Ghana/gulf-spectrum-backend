-- Gulf Spectrum Journal — Postgres schema (Supabase)
--
-- Mirrors the shape of lib/content.ts exactly, so migrating that file from
-- static arrays to real queries is a mechanical rewrite, not a redesign.
-- Run this in the Supabase SQL editor (or via `supabase db push`) on a
-- fresh project. Safe to run once; re-running will error on existing
-- objects rather than silently duplicating them.

-- ---------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------
create extension if not exists "pgcrypto"; -- gen_random_uuid()

-- ---------------------------------------------------------------------
-- Roles & profiles
-- ---------------------------------------------------------------------
-- Extends Supabase's built-in auth.users with the fields the site needs.
-- A row is created automatically by the trigger below whenever someone
-- signs up (matches the "Create Author Account" flow in the UI).

create type user_role as enum ('reader', 'author', 'editor', 'admin');

create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  role user_role not null default 'reader',
  author_id uuid, -- set once a reader is linked to an authors row (see below)
  created_at timestamptz not null default now()
);

create function handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data ->> 'full_name');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();

-- ---------------------------------------------------------------------
-- Core content
-- ---------------------------------------------------------------------

create table topics (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  label text not null,
  description text not null
);

create table authors (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  credentials text,
  affiliation text,
  bio text,
  photo_url text,
  user_id uuid references profiles (id) on delete set null, -- claimed account, if any
  created_at timestamptz not null default now()
);

alter table profiles
  add constraint profiles_author_id_fkey foreign key (author_id) references authors (id) on delete set null;

create type content_status as enum ('draft', 'in_review', 'published');

create table issues (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  number int not null,
  volume int not null,
  year int not null,
  cover_image text,
  status content_status not null default 'draft',
  theme text not null,
  published_date text, -- display string, e.g. "November 2025"
  about_this_volume text,
  editorial_board jsonb not null default '[]', -- [{ name, role }]
  created_by uuid references profiles (id),
  created_at timestamptz not null default now()
);

create table articles (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  issue_id uuid not null references issues (id) on delete cascade,
  topic_id uuid references topics (id),
  title text not null,
  abstract text not null,
  keywords text[] not null default '{}',
  sections jsonb not null default '[]', -- [{ heading, body }]
  conclusion text,
  "references" text[] not null default '{}',
  status content_status not null default 'draft', -- matches the brief's draft -> review -> published workflow
  created_by uuid references profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table article_authors (
  article_id uuid not null references articles (id) on delete cascade,
  author_id uuid not null references authors (id) on delete cascade,
  position int not null default 0, -- author order on the article
  primary key (article_id, author_id)
);

-- ---------------------------------------------------------------------
-- Reader features
-- ---------------------------------------------------------------------

create table bookmarks (
  user_id uuid not null references profiles (id) on delete cascade,
  article_id uuid not null references articles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, article_id)
);

-- Raw events, not counters — avoids increment race conditions and keeps
-- the door open for real time-series analytics later. article_stats below
-- is the aggregated view the /analytics page actually reads.
create type article_event_type as enum ('view', 'download');

create table article_events (
  id bigint generated always as identity primary key,
  article_id uuid not null references articles (id) on delete cascade,
  event_type article_event_type not null,
  created_at timestamptz not null default now()
);

create view article_stats as
select
  article_id,
  count(*) filter (where event_type = 'view') as views,
  count(*) filter (where event_type = 'download') as downloads
from article_events
group by article_id;

-- article_events itself is editor-only (raw per-event rows could be used
-- to infer traffic patterns), but the /analytics page is public, and
-- aggregate view/download counts aren't sensitive. Views run as their
-- owner by default (bypassing the underlying table's RLS), so this grant
-- is what actually makes the aggregate readable by anon/authenticated —
-- without it, PostgREST won't expose the view at all.
grant select on article_stats to anon, authenticated;

-- ---------------------------------------------------------------------
-- Money: donations and memberships
-- ---------------------------------------------------------------------
-- No payment provider is wired up yet (see SupportBox / Membership pages
-- in the app, which show a design-prototype disclaimer instead of
-- charging anyone). These tables are shaped for Paystack: `status` and
-- `payment_reference` map directly onto a Paystack transaction and its
-- reference, and split_platform_percent records the fee actually applied
-- at the time of a given donation (not just today's default), so past
-- donations stay accurate if GoGMI changes the rate later.

create type payment_status as enum ('pending', 'completed', 'failed');

create table donations (
  id uuid primary key default gen_random_uuid(),
  article_id uuid not null references articles (id),
  donor_name text,
  donor_email text,
  amount_minor_units bigint not null, -- store as integer minor units (pesewas/cents) to avoid float rounding
  currency text not null default 'GHS',
  platform_fee_percent numeric not null default 10,
  status payment_status not null default 'pending',
  payment_provider text, -- 'paystack' | 'flutterwave' | ...
  payment_reference text,
  created_at timestamptz not null default now()
);

create table memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles (id),
  tier_slug text not null, -- matches membershipTiers[].slug in lib/content.ts
  applicant_name text,
  applicant_email text,
  status payment_status not null default 'pending',
  payment_provider text,
  payment_reference text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------
-- Public visitors (anon key) can read published content and insert their
-- own bookmarks/donations/membership applications. Only editors/admins
-- can write content. Adjust once real editorial roles are assigned.

alter table topics enable row level security;
alter table authors enable row level security;
alter table issues enable row level security;
alter table articles enable row level security;
alter table article_authors enable row level security;
alter table bookmarks enable row level security;
alter table article_events enable row level security;
alter table donations enable row level security;
alter table memberships enable row level security;
alter table profiles enable row level security;

-- Small helper so "is this user an editor?" isn't repeated as a raw
-- subquery in every policy below. security definer + a fixed search_path
-- so it can't be tricked by a search_path set on the calling session.
create function is_editor(uid uuid)
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (select 1 from profiles where id = uid and role in ('editor', 'admin'));
$$;

create policy "topics are public" on topics for select using (true);
create policy "editors manage topics" on topics
  for all using (is_editor(auth.uid())) with check (is_editor(auth.uid()));

create policy "authors are public" on authors for select using (true);
create policy "editors manage authors" on authors
  for all using (is_editor(auth.uid())) with check (is_editor(auth.uid()));

create policy "published issues are public" on issues
  for select using (status = 'published');
create policy "editors manage issues" on issues
  for all using (is_editor(auth.uid())) with check (is_editor(auth.uid()));

create policy "published articles are public" on articles
  for select using (status = 'published');
create policy "editors manage articles" on articles
  for all using (is_editor(auth.uid())) with check (is_editor(auth.uid()));
create policy "authors manage their own drafts" on articles
  for select using (
    created_by = auth.uid()
  );

create policy "article_authors follow their article" on article_authors
  for select using (
    exists (select 1 from articles where id = article_id and status = 'published')
  );
create policy "editors manage article_authors" on article_authors
  for all using (is_editor(auth.uid())) with check (is_editor(auth.uid()));

create policy "users manage their own bookmarks" on bookmarks
  for all using (user_id = auth.uid());

create policy "anyone can log a view or download" on article_events
  for insert with check (true);
create policy "editors read events" on article_events
  for select using (is_editor(auth.uid()));

create policy "anyone can start a donation" on donations
  for insert with check (true);
create policy "editors read donations" on donations
  for select using (is_editor(auth.uid()));

create policy "anyone can apply for membership" on memberships
  for insert with check (true);
create policy "editors read memberships" on memberships
  for select using (is_editor(auth.uid()));

create policy "users read their own profile" on profiles
  for select using (id = auth.uid());
create policy "users update their own profile" on profiles
  for update using (id = auth.uid());

-- RLS restricts which *row* a user can update, not which *columns* — the
-- policy above would otherwise let a signed-in user PATCH their own role
-- straight to 'admin'. Revoke column-level UPDATE on the sensitive columns
-- from authenticated/anon so only service_role (which bypasses grants,
-- e.g. Supabase Studio or a trusted server action) can change them.
revoke update (role, author_id) on profiles from authenticated, anon;
