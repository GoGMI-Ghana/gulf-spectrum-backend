-- Real backends for the Contact and Submission Guidelines pages, both of
-- which have been pure frontend prototypes until now (ContactForm.tsx /
-- SubmissionForm.tsx literally told the visitor "no message was sent").
-- Both are open to anonymous visitors on purpose — neither page has ever
-- required an account, and requiring one now would be a bigger, separate
-- product change than "give this form a backend".

create table contact_messages (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null,
  subject text not null,
  message text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

alter table contact_messages enable row level security;

create policy "anyone can send a contact message" on contact_messages
  for insert with check (true);
create policy "editors read contact messages" on contact_messages
  for select using (is_editor(auth.uid()));
create policy "editors mark contact messages read" on contact_messages
  for update using (is_editor(auth.uid())) with check (is_editor(auth.uid()));

-- Deliberately a simpler status set than articles' content_status
-- (draft/in_review/published) -- a submission isn't an article yet, it's
-- a proposal an editor is triaging, so "accepted" here means "worth
-- pursuing", not "published". Turning an accepted submission into an
-- actual article is still a manual step in /admin/articles for now.
create type submission_status as enum ('new', 'in_review', 'accepted', 'declined');

create table submissions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null,
  title text not null,
  abstract text,
  status submission_status not null default 'new',
  editor_notes text,
  reviewed_by uuid references profiles (id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table submissions enable row level security;

create policy "anyone can submit an article proposal" on submissions
  for insert with check (true);
create policy "editors manage submissions" on submissions
  for all using (is_editor(auth.uid())) with check (is_editor(auth.uid()));
