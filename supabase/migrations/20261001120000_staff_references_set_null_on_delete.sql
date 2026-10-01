-- Lets editors/admins delete their own account (Account Settings ->
-- Delete Account) after they've reviewed or created something.
--
-- These columns record WHICH staff member did something (reviewed a
-- submission / board application / author claim, created an issue or
-- article). They referenced profiles(id) with no ON DELETE action, so
-- deleting that person's account failed with a foreign-key violation —
-- surfaced to them only as "Failed to delete account".
--
-- SET NULL keeps the record itself (the decision, its timestamp, the
-- article) and just drops the link to the now-deleted account. Every one
-- of these columns is already nullable.

alter table submissions
  drop constraint submissions_reviewed_by_fkey,
  add constraint submissions_reviewed_by_fkey
    foreign key (reviewed_by) references profiles (id) on delete set null;

alter table editorial_board_applications
  drop constraint editorial_board_applications_reviewed_by_fkey,
  add constraint editorial_board_applications_reviewed_by_fkey
    foreign key (reviewed_by) references profiles (id) on delete set null;

alter table author_claims
  drop constraint author_claims_reviewed_by_fkey,
  add constraint author_claims_reviewed_by_fkey
    foreign key (reviewed_by) references profiles (id) on delete set null;

alter table issues
  drop constraint issues_created_by_fkey,
  add constraint issues_created_by_fkey
    foreign key (created_by) references profiles (id) on delete set null;

alter table articles
  drop constraint articles_created_by_fkey,
  add constraint articles_created_by_fkey
    foreign key (created_by) references profiles (id) on delete set null;
