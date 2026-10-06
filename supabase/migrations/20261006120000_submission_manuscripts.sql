-- Manuscript uploads on the public "Start Your Submission" form.
--
-- A submission can now carry one file (the author's Word/PDF manuscript).
-- The file lives in a PRIVATE Storage bucket; the submission row records
-- where, and the author's original file name for display.

alter table submissions
  add column manuscript_path text, -- object path inside the bucket
  add column manuscript_name text; -- original file name, for the admin panel

-- Private, unlike journal-images: these are unpublished manuscripts with
-- authors' personal details, so there is no public URL for them at all.
-- 15 MB and a document-type allowlist are enforced by Storage itself.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'manuscripts',
  'manuscripts',
  false,
  15 * 1024 * 1024,
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.oasis.opendocument.text',
    'application/rtf'
  ]
)
on conflict (id) do nothing;

-- Deliberately NO insert policy for anon or authenticated: the public
-- cannot write to this bucket on its own. An upload only happens through a
-- one-time signed upload URL that the frontend's /api/submissions/upload-url
-- route issues (with the service role) after checking the file's type and
-- size — so an open, anonymous form doesn't mean an open file drop.

-- Editors download manuscripts from /admin/submissions with their own
-- session (a short-lived signed URL), and may delete them.
create policy "editors read manuscripts" on storage.objects
  for select to authenticated
  using (bucket_id = 'manuscripts' and public.is_editor(auth.uid()));

create policy "editors delete manuscripts" on storage.objects
  for delete to authenticated
  using (bucket_id = 'manuscripts' and public.is_editor(auth.uid()));
