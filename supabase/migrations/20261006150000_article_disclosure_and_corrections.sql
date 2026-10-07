-- Two optional pieces of editorial text per article, both promised on the
-- journal's About page ("Content Standards & Trust Signals") but with
-- nowhere to enter them until now:
--
--   disclosure       A funding and/or conflict-of-interest statement,
--                    shown with the article and in its PDF.
--   correction_note  A dated notice describing what was corrected after
--                    publication (or why an article was retracted), shown
--                    prominently on the article and in its PDF — see the
--                    journal's Correction Policy page.
--
-- Plain text, null when there is nothing to say. Covered by the existing
-- articles policies: readable with the published article, writable by
-- editors.

alter table articles
  add column disclosure text,
  add column correction_note text;
