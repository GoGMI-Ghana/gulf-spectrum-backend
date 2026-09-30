-- One-off: removes the placeholder Issue No. 1 content that seed.sql used
-- to load (1 issue, 5 articles, 10 fictional authors), ahead of real
-- articles being published. Topics are the journal's real scope areas and
-- are kept.
--
-- Run once against the live database, from the VPS:
--   cd ~/gulf-spectrum-backend/self-hosting/supabase-project/docker
--   docker compose exec -T db psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f - \
--     < ~/gulf-spectrum-backend/supabase/cleanup/remove-placeholder-content.sql
-- (or paste it into Studio's SQL editor).
--
-- Everything runs in one transaction and matches rows by their seed slugs
-- only. The checks below abort the whole thing, changing nothing, if any
-- real data has become entangled with the placeholders — e.g. a real
-- article filed under the placeholder issue, or a donation made against a
-- placeholder article (donations.article_id has no ON DELETE CASCADE, on
-- purpose: payment records shouldn't vanish as a side effect).
--
-- Deleting the articles cascades to their article_authors links,
-- bookmarks, article_events (view counts) and notifications. Deleting the
-- authors cascades to any author_claims on them and sets
-- profiles.author_id to null for anyone who had claimed one.
-- Safe to re-run: once the rows are gone it deletes nothing.

begin;

create temporary table placeholder_articles (slug text primary key) on commit drop;
insert into placeholder_articles values
  ('mapping-external-actors-gog'),
  ('coast-guard-interagency-coordination'),
  ('legal-frameworks-prosecuting-piracy'),
  ('external-naval-presence-regional-ownership'),
  ('information-sharing-yaounde-code');

create temporary table placeholder_authors (slug text primary key) on commit drop;
insert into placeholder_authors values
  ('kwabena-owusu'),
  ('ama-serwaa-boateng'),
  ('yaw-antwi-danso'),
  ('efua-mensah'),
  ('nana-akosua-frimpong'),
  ('kojo-adjei'),
  ('comfort-adjei-mensah'),
  ('effiong-bassey'),
  ('patricia-nyarko'),
  ('ibrahim-diallo');

do $$
declare
  n int;
begin
  select count(*) into n
  from articles a join issues i on i.id = a.issue_id
  where i.slug = 'issue-1' and a.slug not in (select slug from placeholder_articles);
  if n > 0 then
    raise exception 'Aborted: % non-placeholder article(s) are filed under issue-1. Deleting that issue would cascade to them. Move them to another issue first.', n;
  end if;

  select count(*) into n
  from article_authors aa
  join authors au on au.id = aa.author_id
  join articles a on a.id = aa.article_id
  where au.slug in (select slug from placeholder_authors)
    and a.slug not in (select slug from placeholder_articles);
  if n > 0 then
    raise exception 'Aborted: % placeholder author link(s) point at non-placeholder articles.', n;
  end if;

  select count(*) into n
  from donations d join articles a on a.id = d.article_id
  where a.slug in (select slug from placeholder_articles);
  if n > 0 then
    raise exception 'Aborted: % donation(s) reference placeholder articles. Review them in /admin/donations and delete them explicitly if they were only tests.', n;
  end if;
end $$;

delete from articles where slug in (select slug from placeholder_articles);
delete from issues where slug = 'issue-1';
delete from authors where slug in (select slug from placeholder_authors);

-- What's left, for a quick sanity check in the output.
select
  (select count(*) from issues) as issues_remaining,
  (select count(*) from articles) as articles_remaining,
  (select count(*) from authors) as authors_remaining,
  (select count(*) from topics) as topics_remaining;

commit;
