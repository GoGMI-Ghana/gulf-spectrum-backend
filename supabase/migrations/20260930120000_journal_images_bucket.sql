-- Image uploads for author photos and issue covers, replacing "paste a
-- hosted URL" in the admin panel.
--
-- A public bucket: anyone can read through the /storage/v1/object/public/
-- endpoint (the images are shown on public pages anyway), so no SELECT
-- policy is needed for readers. Writes are editor/admin only, via the
-- same is_editor() helper every content table's RLS uses. The admin panel
-- uploads straight from the browser with the editor's own session, so
-- these policies are the real permission check — not the UI.
--
-- 5 MB limit and a raster-image allowlist are enforced by Storage itself,
-- not just the admin form. SVG is deliberately excluded: it can carry
-- script, and these files are served from the API's own origin.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'journal-images',
  'journal-images',
  true,
  5 * 1024 * 1024,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- Storage's upload path reads the new row back after inserting it, so
-- editors need SELECT alongside INSERT (readers don't — see above).
create policy "editors read journal images" on storage.objects
  for select to authenticated
  using (bucket_id = 'journal-images' and public.is_editor(auth.uid()));

create policy "editors upload journal images" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'journal-images' and public.is_editor(auth.uid()));

create policy "editors update journal images" on storage.objects
  for update to authenticated
  using (bucket_id = 'journal-images' and public.is_editor(auth.uid()))
  with check (bucket_id = 'journal-images' and public.is_editor(auth.uid()));

create policy "editors delete journal images" on storage.objects
  for delete to authenticated
  using (bucket_id = 'journal-images' and public.is_editor(auth.uid()));
