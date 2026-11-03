-- Puts Issue 1's articles in the order of the printed table of contents.
--
-- The site lists an issue's articles in the order they were added
-- (articles.created_at), and DOIs are numbered in that order too
-- (10.68864/gsj.2023.001, .002, ...). All five Issue 1 articles were loaded
-- by issue-1.sql in one transaction, so they share the same created_at and
-- their order was arbitrary. This spaces them one second apart, in the
-- printed order. Safe to run more than once.

update articles a
set created_at = i.created_at + make_interval(secs => o.position)
from (values
  ('the-evolutionary-path-of-maritime-security-initiatives-in-the', 1),
  ('local-content-development-programme-as-an-alternative-approach-to', 2),
  ('enhancing-maritime-security-in-the-gulf-of-guinea-through', 3),
  ('a-review-tackling-the-impact-of-maritime-insecurity-within', 4),
  ('challenges-to-maritime-security-capacity-building', 5)
) as o (slug, position), issues i
where a.slug = o.slug and i.id = a.issue_id and i.slug = 'issue-1';

select left(slug, 50) as article, created_at from articles order by created_at;
