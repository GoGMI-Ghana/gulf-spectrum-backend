-- Security fix: signed-in members could change their own profiles.role
-- (to 'admin'), board_title and author_id.
--
-- The earlier migrations tried to prevent that with
--   revoke update (role, author_id) on profiles from authenticated, anon;
--   revoke update (board_title) on profiles from authenticated, anon;
-- but in Postgres a column-level REVOKE does nothing while the role still
-- holds the table-level UPDATE privilege (which Supabase grants to
-- authenticated/anon on every public table by default). The table-level
-- grant kept covering every column, so with the "users update their own
-- profile" RLS policy — which restricts the row, not the columns — any
-- member could PATCH their own role. Verified on the live database:
--   select has_column_privilege('authenticated', 'public.profiles', 'role', 'UPDATE');  -- was true
--
-- The fix inverts it into an allowlist: drop the table-level UPDATE, then
-- grant UPDATE only on the columns a member legitimately edits from the
-- browser (their name in the Profile page, the new-issue email preference
-- in Account Settings). role, board_title and author_id are only ever
-- written by the frontend's admin API routes through service_role, which
-- has its own grants and is unaffected. A column added to profiles later
-- is not member-writable unless it is added here on purpose.

revoke update on profiles from authenticated, anon;
grant update (full_name, email_notifications) on profiles to authenticated;
