-- Profile pictures: every signed-in member can upload one picture of
-- themselves, from the Profile page.
--
--   profiles.avatar_url   the picture's public address, or null.
--   avatars bucket        public (pictures are shown on the site), 2 MB,
--                         JPEG/PNG/WebP. Each member may only write inside
--                         a folder named after their own user id, so no
--                         one can replace or delete someone else's picture.
--
-- When the member's account is linked to an author profile, the site also
-- copies the picture to authors.photo_url (already allowed by the existing
-- "claimed authors edit their own record" policy), so it appears on their
-- articles.

alter table profiles add column avatar_url text;

-- Column privileges on profiles are explicit (see
-- 20261001110000_fix_profile_column_privileges.sql): members may update
-- only these columns of their own row. Re-granting the full list keeps
-- this migration self-explanatory.
grant update (full_name, email_notifications, avatar_url) on profiles to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  2 * 1024 * 1024,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

create policy "members upload their own avatar" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "members read their own avatar files" on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "members delete their own avatar" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
