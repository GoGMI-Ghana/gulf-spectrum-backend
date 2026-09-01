-- GoGMI membership tiers/dues are removed from the site (frontend and
-- backend both) -- donations on individual articles are the one payment
-- flow going forward. Verified empty before dropping: `memberships` was
-- never wired to a real payment provider (the frontend Join form was a
-- design-prototype placeholder that never inserted a row), so this drops
-- nothing real.
drop table if exists memberships;
