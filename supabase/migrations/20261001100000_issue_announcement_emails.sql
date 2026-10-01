-- Email announcement when a new issue is published, alongside the
-- existing in-site notification (see the notifications migration).
--
-- The email itself is sent by the frontend (POST
-- /api/admin/issues/[id]/announce, through Microsoft Graph), not from a
-- database trigger: an editor confirms it in the admin panel, since unlike
-- an in-site notification an email can't be taken back.

-- When the announcement email went out — null until then. The announce
-- route claims this with a conditional update (`... where
-- announcement_sent_at is null`) before sending anything, which is what
-- guarantees an issue is only ever announced once, even if two editors
-- click at the same moment or an issue is unpublished and republished.
alter table issues add column announcement_sent_at timestamptz;

-- Per-member opt-out, on by default. Covered by the existing "users
-- update their own profile" policy, so members can change it themselves
-- from Account Settings; the announce route only emails rows where this
-- is true.
alter table profiles add column email_notifications boolean not null default true;
