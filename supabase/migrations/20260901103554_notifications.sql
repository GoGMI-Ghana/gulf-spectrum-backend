-- Real, read-only notifications feed — generated server-side from actual
-- publishing events, not fabricated activity. Two kinds, both fanned out
-- by a trigger the moment an issue/article's status becomes 'published':
--   - new_issue: every reader gets one.
--   - new_article_in_topic: readers who've bookmarked ANYTHING in that
--     article's topic get one — the only personalization here, and it's
--     derived from data that already exists (bookmarks), not a new
--     preferences system.
-- No general messaging (reader<->editor correspondence) is included —
-- that needs an editorial-side UI to send anything, which doesn't exist
-- yet. This is deliberately narrower: the site notifying a reader about
-- its own real content.

create type notification_type as enum ('new_issue', 'new_article_in_topic');

create table notifications (
  id bigint generated always as identity primary key,
  user_id uuid not null references profiles (id) on delete cascade,
  type notification_type not null,
  article_id uuid references articles (id) on delete cascade,
  issue_id uuid references issues (id) on delete cascade,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index notifications_user_id_created_at_idx on notifications (user_id, created_at desc);

alter table notifications enable row level security;

-- No insert policy for anon/authenticated on purpose — rows only ever
-- come from the security-definer trigger functions below (or a trusted
-- service-role script later). A user inserting notifications for
-- *themselves* would be harmless, but there's no reason to allow it, and
-- no policy is the simplest way to make sure nobody can insert one for
-- someone else.
create policy "users read their own notifications" on notifications
  for select using (user_id = auth.uid());

create policy "users mark their own notifications read" on notifications
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- Fan-out triggers
-- ---------------------------------------------------------------------
-- Both fire on insert (an issue/article created already-published) or on
-- an update that actually changes status to 'published' — not on every
-- edit to an already-published row.

create function notify_new_issue()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into notifications (user_id, type, issue_id)
  select id, 'new_issue'::notification_type, new.id from profiles;
  return new;
end;
$$;

-- A trigger's WHEN clause can only reference NEW/OLD row values, not
-- TG_OP — INSERT and UPDATE need separate triggers (OLD doesn't exist
-- for an INSERT, so its WHEN can't reference old.status at all).
create trigger on_issue_inserted_published
  after insert on issues
  for each row
  when (new.status = 'published')
  execute procedure notify_new_issue();

create trigger on_issue_updated_published
  after update of status on issues
  for each row
  when (new.status = 'published' and old.status is distinct from new.status)
  execute procedure notify_new_issue();

create function notify_new_article_in_topic()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.topic_id is not null then
    insert into notifications (user_id, type, article_id)
    select distinct b.user_id, 'new_article_in_topic'::notification_type, new.id
    from bookmarks b
    join articles a on a.id = b.article_id
    where a.topic_id = new.topic_id
      and a.id <> new.id;
  end if;
  return new;
end;
$$;

create trigger on_article_inserted_published
  after insert on articles
  for each row
  when (new.status = 'published')
  execute procedure notify_new_article_in_topic();

create trigger on_article_updated_published
  after update of status on articles
  for each row
  when (new.status = 'published' and old.status is distinct from new.status)
  execute procedure notify_new_article_in_topic();
