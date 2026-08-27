-- Daily aggregate view for the public Analytics dashboard's engagement
-- chart and 30/60-day breakdowns.
--
-- article_stats (in the init migration) already covers all-time totals;
-- this adds a day-bucketed version so the frontend can build a real
-- trend chart instead of the seeded placeholder it used before real
-- event logging existed. Like article_stats, this view runs as its
-- owner (not security_invoker), so it bypasses article_events' RLS
-- (editor-only) on its own — the explicit grant below is what actually
-- exposes it to anon/authenticated. Day-bucketed counts are coarse
-- enough that this carries the same exposure level as the all-time
-- totals already public via article_stats, not the raw per-event rows.
create view article_daily_stats as
select
  article_id,
  date_trunc('day', created_at)::date as day,
  count(*) filter (where event_type = 'view') as views,
  count(*) filter (where event_type = 'download') as downloads
from article_events
group by article_id, date_trunc('day', created_at);

grant select on article_daily_stats to anon, authenticated;
