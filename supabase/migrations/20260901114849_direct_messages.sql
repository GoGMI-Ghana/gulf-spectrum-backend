-- Real private DMs between users — 1:1 conversations, RLS-scoped so only
-- the two participants can ever read a conversation or its messages.
-- Deliberately NOT end-to-end encrypted (no client-side key management,
-- no message-recovery story for a lost device) — private in every
-- practical sense (nobody else on the platform, including editors/admins,
-- has any RLS path to another user's DMs), but not the specific
-- mathematical guarantee E2EE gives. See the conversation that led here
-- for the tradeoffs.

-- ---------------------------------------------------------------------
-- Member directory
-- ---------------------------------------------------------------------
-- profiles was previously readable only by its own owner (see the
-- earlier "users read their own profile" policy). Needed now so someone
-- can find another user to message — nothing in profiles is actually
-- sensitive (no email; that lives in auth.users and is never exposed via
-- the API regardless), so this is the same shape as any member-directory
-- feature. Gated to authenticated (signed-in) visitors, matching that
-- messaging itself requires an account.
create policy "authenticated users can browse profiles" on profiles
  for select using (auth.role() = 'authenticated');

-- ---------------------------------------------------------------------
-- Conversations and messages
-- ---------------------------------------------------------------------
-- One row per 1:1 pair, not a participants join table — no group chats
-- requested, and this makes "is there already a conversation between
-- these two people" a plain unique constraint instead of an aggregate
-- query. user_a_id < user_b_id (enforced) canonicalizes the pair so it
-- doesn't matter who messaged whom first.

create table conversations (
  id uuid primary key default gen_random_uuid(),
  user_a_id uuid not null references profiles (id) on delete cascade,
  user_b_id uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now(),
  constraint conversations_ordered_pair check (user_a_id < user_b_id),
  constraint conversations_unique_pair unique (user_a_id, user_b_id)
);

create table messages (
  id bigint generated always as identity primary key,
  conversation_id uuid not null references conversations (id) on delete cascade,
  sender_id uuid not null references profiles (id) on delete cascade,
  body text not null check (char_length(btrim(body)) > 0 and char_length(body) <= 4000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index messages_conversation_id_created_at_idx on messages (conversation_id, created_at);

alter table conversations enable row level security;
alter table messages enable row level security;

-- No direct insert policy on conversations — the only way one gets
-- created is through get_or_create_conversation() below, so every
-- conversation is guaranteed to have exactly the two real participants
-- auth.uid() and the person it was started with.
create policy "participants can read their conversations" on conversations
  for select using (auth.uid() = user_a_id or auth.uid() = user_b_id);

create policy "participants can read their messages" on messages
  for select using (
    exists (
      select 1 from conversations c
      where c.id = conversation_id and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
  );

create policy "participants can send messages in their conversations" on messages
  for insert with check (
    sender_id = auth.uid()
    and exists (
      select 1 from conversations c
      where c.id = conversation_id and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
  );

create policy "participants can mark messages read" on messages
  for update using (
    exists (
      select 1 from conversations c
      where c.id = conversation_id and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
  )
  with check (
    exists (
      select 1 from conversations c
      where c.id = conversation_id and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
  );

-- Keeps the conversation list sortable by recency without a per-list
-- aggregate query over messages.
create function touch_conversation_last_message()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update conversations set last_message_at = new.created_at where id = new.conversation_id;
  return new;
end;
$$;

create trigger on_message_inserted
  after insert on messages
  for each row
  execute procedure touch_conversation_last_message();

-- Finds the existing 1:1 conversation with other_user_id, or creates it.
-- security definer + owned by the migration-applying superuser, so it
-- bypasses RLS on conversations internally (the same pattern
-- handle_new_user() and the notification triggers already use) — this is
-- deliberately the ONLY path that can insert a conversations row.
create function get_or_create_conversation(other_user_id uuid)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  a uuid;
  b uuid;
  conv_id uuid;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if me = other_user_id then
    raise exception 'cannot start a conversation with yourself';
  end if;
  if me < other_user_id then
    a := me; b := other_user_id;
  else
    a := other_user_id; b := me;
  end if;

  select id into conv_id from conversations where user_a_id = a and user_b_id = b;
  if conv_id is null then
    insert into conversations (user_a_id, user_b_id) values (a, b) returning id into conv_id;
  end if;
  return conv_id;
end;
$$;

revoke all on function get_or_create_conversation(uuid) from public;
grant execute on function get_or_create_conversation(uuid) to authenticated;

-- Live message delivery. supabase_realtime starts as an empty publication
-- (verified on the live instance — puballtables=false, zero tables) —
-- without this, postgres_changes subscriptions on messages never fire,
-- and the DM thread would only ever update on refetch/reload.
alter publication supabase_realtime add table messages;
