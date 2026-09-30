-- Gulf Spectrum Journal — seed data
--
-- Only the journal's topics (its real scope areas) — these are
-- configuration, not content, and the frontend's topic ordering and About
-- page expect exactly these slugs. Issues, articles and authors are
-- entered by editors through the admin panel.
--
-- This file used to also load a placeholder Issue No. 1 (5 articles, 10
-- fictional authors) for development. That was removed ahead of real
-- publication; supabase/cleanup/remove-placeholder-content.sql deletes it
-- from a database that was seeded with it.
--
-- Run after the initial migration:
--   supabase db reset        (local: re-runs migrations, then this file)
--   psql <connection> -f supabase/seed.sql   (against a remote project)
--
-- NOT idempotent against a database that already has these rows —
-- re-running will violate the unique slug constraint by design, so you
-- notice rather than silently duplicating rows.

-- ---------------------------------------------------------------------
-- Topics
-- ---------------------------------------------------------------------
insert into topics (slug, label, description) values
  ('maritime-security', 'Maritime Security', 'Piracy, armed robbery at sea, naval and coast guard operations, and interventions across the Gulf of Guinea.'),
  ('blue-economy', 'Blue Economy', 'Fisheries, shipping, offshore resources, and sustainable development of the maritime economy.'),
  ('regional-governance', 'Regional Governance & Law', 'Regional cooperation frameworks, legal and regulatory questions, and maritime governance in the Gulf of Guinea.'),
  ('capacity-building', 'Capacity Building', 'Institutional and interagency capacity, including youth and women''s participation in the blue economy, linked to the WYTEC Blue programme.'),
  ('consultancy-case-studies', 'Consultancy & Case Studies', 'Applied case studies and consultancy insights suitable for public release.'),
  ('west-african-affairs', 'West African Affairs', 'Broader Gulf of Guinea and West African maritime affairs beyond a single theme or issue.');

