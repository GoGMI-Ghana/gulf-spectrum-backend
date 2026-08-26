-- Gulf Spectrum Journal — seed data
--
-- Mirrors the placeholder content in the frontend's lib/content.ts exactly
-- (same slugs, same text), so once the frontend is switched over to query
-- this database instead of its static arrays, the site shows the same
-- content it does today. Run after the initial migration:
--   supabase db reset        (local: re-runs migrations, then this file)
--   psql <connection> -f supabase/seed.sql   (against a remote project)
--
-- Uses slug-based subqueries to resolve foreign keys instead of hardcoded
-- UUIDs, so this stays readable and safe to re-run against a fresh
-- database (it is NOT idempotent against a database that already has this
-- data — re-running will violate the unique slug constraints by design,
-- so you notice rather than silently duplicating rows).

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

-- ---------------------------------------------------------------------
-- Authors
-- ---------------------------------------------------------------------
insert into authors (slug, name, credentials, affiliation, bio) values
  ('kwabena-owusu', 'Lt. Cdr. Kwabena Owusu', 'Ghana Navy', 'Ghana Navy, Fleet Operations', 'Lt. Cdr. Owusu serves in fleet operations with the Ghana Navy, with a focus on maritime domain awareness and interagency coordination in the Gulf of Guinea.'),
  ('ama-serwaa-boateng', 'Dr. Ama Serwaa Boateng', 'PhD, International Relations', 'University of Ghana, Legon', 'Dr. Boateng researches regional security cooperation in West Africa, with recent work on Gulf of Guinea governance frameworks.'),
  ('yaw-antwi-danso', 'Cdr. Yaw Antwi-Danso', 'Ghana Navy', 'Ghana Navy, Coast Guard Command', 'Cdr. Antwi-Danso leads coast guard coordination initiatives and has represented Ghana in regional maritime security exercises.'),
  ('efua-mensah', 'Sub-Lt. Efua Mensah', 'Ghana Navy', 'Ghana Navy, Coast Guard Command', 'Sub-Lt. Mensah works on interagency coordination between naval and civilian maritime authorities.'),
  ('nana-akosua-frimpong', 'Nana Akosua Frimpong', 'Barrister-at-Law', 'Maritime & Admiralty Law Chambers, Accra', 'Nana Akosua Frimpong practices maritime and admiralty law, with a focus on the prosecution of piracy and armed robbery at sea under domestic and regional frameworks.'),
  ('kojo-adjei', 'Dr. Kojo Adjei', 'PhD, Law', 'University of Cape Coast', 'Dr. Adjei teaches and researches maritime law, focusing on jurisdictional questions in Gulf of Guinea piracy prosecutions.'),
  ('comfort-adjei-mensah', 'Dr. Comfort Adjei-Mensah', 'PhD, Security Studies', 'Institute for Security Studies', 'Dr. Adjei-Mensah studies the balance between external naval partnerships and regional ownership of maritime security in West Africa.'),
  ('effiong-bassey', 'Lt. Cdr. Effiong Bassey', 'Nigerian Navy', 'Nigerian Navy, Maritime Security Operations', 'Lt. Cdr. Bassey has served in multiple regional maritime security operations across the Gulf of Guinea.'),
  ('patricia-nyarko', 'Cdr. Patricia Nyarko', 'Ghana Navy', 'Ghana Navy, Information Fusion Centre', 'Cdr. Nyarko works on maritime information-sharing systems, including the Yaoundé Architecture for regional coordination.'),
  ('ibrahim-diallo', 'Capt. Ibrahim Diallo', 'PhD, Maritime Studies', 'Regional Maritime University', 'Capt. Diallo is a member of the journal''s editorial board and researches regional information-sharing architectures for maritime security.');

-- ---------------------------------------------------------------------
-- Issue No. 1
-- ---------------------------------------------------------------------
insert into issues (slug, number, volume, year, cover_image, status, theme, published_date, about_this_volume, editorial_board) values (
  'issue-1', 1, 1, 2025, '/issue-1-cover.jpg', 'published',
  'Maritime Security Interventions in the Gulf of Guinea',
  'November 2025',
  'Issue No. 1 examines maritime security interventions in the Gulf of Guinea, with particular attention to the role of external actors alongside regional and national forces. The five articles in this volume were contributed by naval and coast guard officers, university researchers, and legal practitioners from Ghana and partner countries, and were reviewed by this volume''s editorial board prior to publication.',
  '[
    {"name": "Rear Admiral (Rtd) E. K. Ansah", "role": "Chair, Issue Editorial Board"},
    {"name": "Prof. Adjoa Mensimah Kufuor", "role": "Member"},
    {"name": "Dr. Comfort Adjei-Mensah", "role": "Member"},
    {"name": "Capt. Ibrahim Diallo", "role": "Member"}
  ]'::jsonb
);

-- ---------------------------------------------------------------------
-- Articles
-- ---------------------------------------------------------------------

insert into articles (slug, issue_id, topic_id, title, abstract, keywords, sections, conclusion, "references", status)
select
  'mapping-external-actors-gog',
  (select id from issues where slug = 'issue-1'),
  (select id from topics where slug = 'maritime-security'),
  'Maritime Security Interventions in the Gulf of Guinea: Mapping the Role of External Actors',
  'This article maps the range of external naval and institutional interventions in Gulf of Guinea maritime security since 2015, from bilateral ship visits to multinational exercises and capacity-building programmes. It argues that interventions are most effective, and most durable, when they are built around existing regional architectures such as the Yaoundé Code of Conduct rather than run in parallel to them.',
  array['Gulf of Guinea', 'maritime security', 'external actors', 'naval cooperation', 'Yaoundé Code of Conduct'],
  '[
    {"heading": "Introduction", "body": "Piracy and armed robbery at sea in the Gulf of Guinea drew sustained international naval attention through the late 2010s and early 2020s. This attention has taken varied forms: bilateral port calls and training visits, multinational task forces, and long-running capacity-building partnerships. This article surveys that landscape and asks what distinguishes interventions that strengthen regional capacity from those that risk substituting for it."},
    {"heading": "A Typology of External Engagement", "body": "We distinguish three broad categories of external engagement in the region: episodic naval presence (ship visits, joint patrols), structured capacity building (training programmes, equipment transfers), and institutional support (funding and technical assistance to regional bodies such as the Interregional Coordination Centre). Each carries different implications for regional ownership."},
    {"heading": "Alignment with Regional Architecture", "body": "Interventions anchored to the Yaoundé Code of Conduct''s reporting and coordination structures showed greater continuity after the initiating partner''s political priorities shifted, compared to bilateral programmes run outside that architecture."}
  ]'::jsonb,
  'External support remains important to Gulf of Guinea maritime security, but its long-term value depends on how well it is threaded through existing regional structures rather than run alongside them. Future interventions should be evaluated in part by their contribution to regional institutional capacity, not only by their immediate security effect.',
  array[
    'Bueger, C. (2021). Piracy Studies: Scholarly Responses to the Return of an Ancient Threat. Maritime Studies Review.',
    'Interregional Coordination Centre. (2023). Annual Report on Maritime Security in the Gulf of Guinea.',
    'Ukeje, C., & Ela, W. (2022). African Approaches to Maritime Security: The Gulf of Guinea. Institute for Security Studies.'
  ],
  'published';

insert into articles (slug, issue_id, topic_id, title, abstract, keywords, sections, conclusion, "references", status)
select
  'coast-guard-interagency-coordination',
  (select id from issues where slug = 'issue-1'),
  (select id from topics where slug = 'capacity-building'),
  'Coast Guard Capacity and Interagency Coordination in Gulf of Guinea Maritime Security',
  'Drawing on operational experience within Ghana''s coast guard command structures, this article examines the practical obstacles to interagency coordination between navies, fisheries authorities, customs, and port authorities, and proposes a set of coordination practices adaptable to partner countries in the region.',
  array['coast guard', 'interagency coordination', 'maritime domain awareness', 'Ghana'],
  '[
    {"heading": "Introduction", "body": "Maritime security incidents in the Gulf of Guinea rarely fall neatly under a single agency''s mandate. Effective response depends on coordination among navies, coast guards, fisheries enforcement, customs, and port authorities — agencies that often operate on different reporting lines, equipment standards, and information systems."},
    {"heading": "Coordination Gaps in Practice", "body": "Drawing on case reviews of incident response in Ghanaian waters, this section identifies recurring points of friction: inconsistent vessel-tracking data formats, unclear first-responder protocols, and gaps in real-time communication between agencies during live incidents."},
    {"heading": "Toward a Shared Coordination Framework", "body": "We propose a lightweight, shared incident-coordination protocol built on existing regional information-sharing centres, requiring no new hardware investment and adaptable to coast guard structures across partner states."}
  ]'::jsonb,
  'Interagency coordination, not additional platforms alone, is the binding constraint on effective coast guard response in much of the Gulf of Guinea. Low-cost coordination protocols, adopted consistently, can meaningfully close this gap.',
  array[
    'Ghana Maritime Authority. (2022). National Maritime Security Strategy.',
    'International Maritime Organization. (2021). Guidelines on Interagency Cooperation in Maritime Security.'
  ],
  'published';

insert into articles (slug, issue_id, topic_id, title, abstract, keywords, sections, conclusion, "references", status)
select
  'legal-frameworks-prosecuting-piracy',
  (select id from issues where slug = 'issue-1'),
  (select id from topics where slug = 'regional-governance'),
  'Legal Frameworks for Prosecuting Piracy and Armed Robbery at Sea in the Gulf of Guinea',
  'This article reviews the domestic legal frameworks available to Gulf of Guinea states for prosecuting piracy and armed robbery at sea, identifies jurisdictional gaps that have historically allowed suspects to be released without charge, and recommends legislative and procedural reforms.',
  array['maritime law', 'piracy prosecution', 'jurisdiction', 'armed robbery at sea'],
  '[
    {"heading": "Introduction", "body": "Successful naval interdiction of piracy suspects has, in a number of documented cases, not led to prosecution — largely because of unresolved jurisdictional and evidentiary questions. This article examines the legal frameworks in Ghana and selected partner states against that pattern."},
    {"heading": "Jurisdictional Gaps", "body": "Several states in the region have not fully domesticated UNCLOS provisions on piracy, creating ambiguity over which court has jurisdiction when an incident occurs outside territorial waters but the suspects are landed domestically."},
    {"heading": "Recommendations", "body": "We recommend model legislation clarifying jurisdiction for offences committed in the exclusive economic zone, alongside standardized evidence-handling protocols for naval forces conducting interdictions."}
  ]'::jsonb,
  'Without clearer domestic legal frameworks, naval interdiction efforts in the Gulf of Guinea will continue to outpace the region''s capacity to prosecute. Legal reform is as central to deterrence as naval capacity.',
  array[
    'United Nations Convention on the Law of the Sea (UNCLOS), 1982.',
    'Yaoundé Code of Conduct Concerning the Repression of Piracy, Armed Robbery against Ships, and Illicit Maritime Activity, 2013.',
    'Frimpong, N. A. (2020). Prosecuting Maritime Crime in West Africa: A Practitioner''s View. Ghana Law Journal.'
  ],
  'published';

insert into articles (slug, issue_id, topic_id, title, abstract, keywords, sections, conclusion, "references", status)
select
  'external-naval-presence-regional-ownership',
  (select id from issues where slug = 'issue-1'),
  (select id from topics where slug = 'regional-governance'),
  'External Naval Presence and Regional Ownership: Balancing Partnership and Sovereignty in Gulf of Guinea Security',
  'This article examines the tension between welcoming external naval partnership and preserving regional ownership of maritime security outcomes in the Gulf of Guinea, drawing on interviews with regional naval officers and policy documents from partner-country deployments.',
  array['naval partnership', 'sovereignty', 'regional ownership', 'security cooperation'],
  '[
    {"heading": "Introduction", "body": "External naval deployments to the Gulf of Guinea are generally welcomed by regional states, but officers interviewed for this study consistently raised concerns about long-term dependency and the risk that regional navies are positioned as junior partners in operations conducted in their own waters."},
    {"heading": "Perspectives from Regional Officers", "body": "Interviews with serving officers highlight a preference for partnership models that transfer operational leadership to regional forces over time, rather than open-ended external presence."},
    {"heading": "Principles for Balanced Partnership", "body": "We propose a set of principles for structuring external naval partnerships so that they build, rather than substitute for, regional operational leadership."}
  ]'::jsonb,
  'Sustainable maritime security in the Gulf of Guinea requires external partners to explicitly design for their own reduced role over time. Regional ownership should be a stated objective of partnership programmes, not an assumed byproduct.',
  array[
    'Ukeje, C. (2019). Whose Security? External Actors in Gulf of Guinea Maritime Governance.',
    'African Union. (2050). Africa''s Integrated Maritime Strategy (2050 AIM Strategy).'
  ],
  'published';

insert into articles (slug, issue_id, topic_id, title, abstract, keywords, sections, conclusion, "references", status)
select
  'information-sharing-yaounde-code',
  (select id from issues where slug = 'issue-1'),
  (select id from topics where slug = 'maritime-security'),
  'Information Sharing Architectures and the Yaoundé Code of Conduct: Progress and Gaps',
  'This article assesses progress in maritime information-sharing across Gulf of Guinea states under the Yaoundé Architecture, identifying which regional centres are receiving consistent reporting and where gaps remain, and offers recommendations for closing them.',
  array['information sharing', 'Yaoundé Architecture', 'maritime domain awareness', 'regional cooperation'],
  '[
    {"heading": "Introduction", "body": "The Yaoundé Architecture established a network of regional and zonal maritime information-sharing centres. A decade on, reporting consistency varies significantly across member states and zones."},
    {"heading": "Reporting Consistency Across Zones", "body": "Drawing on centre-level reporting data, this section identifies zones with strong reporting discipline and those where reporting has lapsed, along with plausible institutional and resourcing explanations for the gap."},
    {"heading": "Closing the Gaps", "body": "We recommend standardized minimum reporting requirements tied to continued regional and international funding eligibility, alongside shared technical infrastructure to lower the reporting burden on smaller navies."}
  ]'::jsonb,
  'The Yaoundé Architecture''s information-sharing promise is only partly realized. Consistent reporting, not additional centres, is the priority for the next phase of regional maritime domain awareness.',
  array[
    'Interregional Coordination Centre. (2023). Annual Report on Maritime Security in the Gulf of Guinea.',
    'Nyarko, P. (2021). Information Fusion in West African Maritime Security. Gulf Review.'
  ],
  'published';

-- ---------------------------------------------------------------------
-- Article <-> Author links (order matches authorSlugs in lib/content.ts)
-- ---------------------------------------------------------------------
insert into article_authors (article_id, author_id, position)
select a.id, au.id, x.position
from (values
  ('mapping-external-actors-gog', 'kwabena-owusu', 0),
  ('mapping-external-actors-gog', 'ama-serwaa-boateng', 1),
  ('coast-guard-interagency-coordination', 'yaw-antwi-danso', 0),
  ('coast-guard-interagency-coordination', 'efua-mensah', 1),
  ('legal-frameworks-prosecuting-piracy', 'nana-akosua-frimpong', 0),
  ('legal-frameworks-prosecuting-piracy', 'kojo-adjei', 1),
  ('external-naval-presence-regional-ownership', 'comfort-adjei-mensah', 0),
  ('external-naval-presence-regional-ownership', 'effiong-bassey', 1),
  ('information-sharing-yaounde-code', 'patricia-nyarko', 0),
  ('information-sharing-yaounde-code', 'ibrahim-diallo', 1)
) as x(article_slug, author_slug, position)
join articles a on a.slug = x.article_slug
join authors au on au.slug = x.author_slug;
