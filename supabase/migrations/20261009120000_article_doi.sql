-- An article's DOI (Digital Object Identifier), registered with Crossref.
--
-- Stored bare — "10.12345/gsj.2023.1.1", without the https://doi.org/
-- prefix — and null until one has been registered: the site shows "DOI:
-- pending" for those. Unique, because a DOI identifies exactly one work.
-- The format check is a guard against pasting a web address or a stray
-- word; it is not proof the DOI is registered.
--
-- Covered by the existing articles policies: readable with the published
-- article, writable by editors.

alter table articles
  add column doi text unique
  constraint articles_doi_format check (doi ~ '^10\.[0-9]{4,9}/[^[:space:]]+$');
