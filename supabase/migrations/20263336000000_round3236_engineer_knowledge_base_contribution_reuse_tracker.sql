-- Round 3236: Engineer Knowledge-Base Contribution & Fix-Documentation Reuse Tracker
-- Engineer KB log — article type × equipment category × views 30d × reuse-in-jobs × peer rating × freshness × gap-topic flag × CAPA

-- =============================================================================
-- TABLE 1: kb_contribution_r3236 — individual KB article contributions
-- =============================================================================
create table if not exists public.kb_contribution_r3236 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  engineer_name text not null,
  article_code text not null,
  article_title text not null,
  article_type text not null check (article_type in (
    'fix_guide','error_code_reference','part_cross_reference','video_walkthrough',
    'troubleshooting_flowchart','pm_checklist','installation_note','firmware_update_guide'
  )),
  equipment_category text not null check (equipment_category in (
    'dialysis_machine','ventilator','ct_scanner','mri_scanner','defibrillator',
    'patient_monitor','infusion_pump','xray_machine','ultrasound_scanner','autoclave_sterilizer','infant_warmer'
  )),
  published_date date not null,
  views_30d int not null default 0,
  reuse_in_jobs_count int not null default 0,
  peer_rating numeric(3,2),
  peer_review_status text not null check (peer_review_status in (
    'peer_verified','pending_review','needs_revision','not_reviewed'
  )),
  freshness_days int not null default 0,
  gap_topic_flagged boolean not null default false,
  kb_verdict text not null check (kb_verdict in (
    'exemplary','high_reuse','healthy','stale_needs_refresh',
    'low_quality_flagged','duplicate_merge_needed','archived'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.kb_contribution_r3236 enable row level security;

create index if not exists idx_kb_contribution_r3236_org on public.kb_contribution_r3236(organization_id);
create index if not exists idx_kb_contribution_r3236_verdict on public.kb_contribution_r3236(kb_verdict);
create index if not exists idx_kb_contribution_r3236_type on public.kb_contribution_r3236(article_type);

-- =============================================================================
-- TABLE 2: kb_contribution_capa_actions_r3236 — CAPA & documentation-quality actions
-- =============================================================================
create table if not exists public.kb_contribution_capa_actions_r3236 (
  id uuid primary key default gen_random_uuid(),
  kb_contribution_id uuid not null references public.kb_contribution_r3236(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'stale_content','incorrect_procedure','missing_safety_warning','duplicate_article',
    'low_peer_rating','gap_topic_unfilled','broken_media_link','outdated_part_number'
  )),
  root_cause text not null check (root_cause in (
    'firmware_changed','part_superseded','author_left_org','no_review_cycle',
    'rushed_documentation','equipment_model_discontinued','taxonomy_mismatch','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'rewrite_article','merge_duplicates','assign_peer_reviewer','add_safety_warning',
    'update_part_cross_reference','record_new_video','schedule_review_cycle',
    'archive_article','commission_gap_article','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.kb_contribution_capa_actions_r3236 enable row level security;

create index if not exists idx_kb_capa_r3236_contribution on public.kb_contribution_capa_actions_r3236(kb_contribution_id);
create index if not exists idx_kb_capa_r3236_status on public.kb_contribution_capa_actions_r3236(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 14 KB contribution rows
  insert into public.kb_contribution_r3236 (
    organization_id, hospital_name, engineer_name, article_code, article_title,
    article_type, equipment_category, published_date,
    views_30d, reuse_in_jobs_count, peer_rating, peer_review_status,
    freshness_days, gap_topic_flagged, kb_verdict, notes
  )
  select v_org_id, q.hosp, q.eng, q.code, q.title,
    q.atype, q.ecat, q.pub::date,
    q.v30, q.reuse, q.rating, q.prs,
    q.fresh, q.gap, q.verdict, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','Ramesh Kulkarni','KB-3236-001','Fresenius 4008S conductivity error E07 fix guide',
     'fix_guide','dialysis_machine','2026-05-12',342,19,4.70,'peer_verified',36,false,'exemplary','Most reused dialysis article this quarter'),
    ('Apollo Hyderabad Jubilee Hills','Ramesh Kulkarni','KB-3236-002','Drager Savina 300 alarm code cross-map table',
     'error_code_reference','ventilator','2026-03-02',118,7,4.20,'peer_verified',107,false,'healthy','Covers full E-series alarm catalogue'),
    ('Fortis Bannerghatta Bengaluru','Anita Deshmukh','KB-3236-003','GE Revolution CT tube warmup fault walkthrough video',
     'video_walkthrough','ct_scanner','2025-11-20',25,1,3.10,'needs_revision',210,false,'stale_needs_refresh','Procedure changed in firmware 4.2 — video outdated'),
    ('Fortis Bannerghatta Bengaluru','Anita Deshmukh','KB-3236-004','Mindray uMEC SpO2 sensor part cross-reference',
     'part_cross_reference','patient_monitor','2026-06-18',96,11,4.50,'peer_verified',30,false,'high_reuse','Masimo vs Nellcor compatibility matrix included'),
    ('Manipal Whitefield Bengaluru','Suresh Iyer','KB-3236-005','Philips MX450 boot-loop troubleshooting flowchart',
     'troubleshooting_flowchart','patient_monitor','2026-01-15',44,3,2.40,'needs_revision',154,false,'low_quality_flagged','Ambiguous decision branches — two engineers misled on site'),
    ('Manipal Whitefield Bengaluru','Suresh Iyer','KB-3236-006','Infusion pump occlusion alarm error code list',
     'error_code_reference','infusion_pump','2026-06-25',210,14,4.60,'peer_verified',23,false,'high_reuse','Covers BBraun, Fresenius and Smiths models'),
    ('AIIMS New Delhi Ansari Nagar','Priya Nair','KB-3236-007','Siemens Magnetom helium level PM checklist',
     'pm_checklist','mri_scanner','2025-09-10',12,0,3.50,'not_reviewed',281,true,'stale_needs_refresh','No review cycle since publication — cryogen SOP revised twice since'),
    ('AIIMS New Delhi Ansari Nagar','Priya Nair','KB-3236-008','Nihon Kohden defibrillator battery cross-reference',
     'part_cross_reference','defibrillator','2026-04-08',77,9,4.30,'peer_verified',71,false,'healthy','Includes OEM vs compatible cell cycle-life data'),
    ('KIMS Secunderabad','Vikram Rao','KB-3236-009','Autoclave vacuum leak test error E22 fix guide',
     'fix_guide','autoclave_sterilizer','2026-02-14',59,6,4.00,'peer_verified',124,false,'healthy','Door gasket and pump seal diagnosis tree'),
    ('KIMS Secunderabad','Vikram Rao','KB-3236-010','Dialysis E07 conductivity quick fix (duplicate)',
     'fix_guide','dialysis_machine','2026-05-30',15,1,3.20,'pending_review',49,false,'duplicate_merge_needed','Overlaps KB-3236-001 — flagged for merge'),
    ('Care Hospitals Banjara Hills','Farhan Sheikh','KB-3236-011','X-ray generator kV calibration firmware update guide',
     'firmware_update_guide','xray_machine','2026-06-05',88,8,4.40,'peer_verified',43,true,'high_reuse','Fills flagged gap topic on post-update calibration'),
    ('Yashoda Somajiguda Hyderabad','Lakshmi Menon','KB-3236-012','Ultrasound probe crystal fault installation note',
     'installation_note','ultrasound_scanner','2025-12-01',8,0,2.10,'not_reviewed',199,true,'archived','Probe model discontinued — replacement article commissioned'),
    ('St John''s Bengaluru','Deepak Verma','KB-3236-013','CT couch motor jam fix guide with video',
     'video_walkthrough','ct_scanner','2026-07-02',156,12,4.80,'peer_verified',16,false,'exemplary','Reused in three field jobs within first fortnight'),
    ('Rainbow Children''s Hyderabad','Meera Pillai','KB-3236-014','Infant warmer temperature probe error code table',
     'error_code_reference','infant_warmer','2026-06-20',61,4,3.90,'pending_review',28,true,'healthy','Gap topic raised in NABH mock audit — first coverage')
  ) as q(hosp, eng, code, title, atype, ecat, pub, v30, reuse, rating, prs, fresh, gap, verdict, nt);

  -- 6 CAPA rows — attach by article code
  insert into public.kb_contribution_capa_actions_r3236 (
    kb_contribution_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.tcd::date, q.acd::date, q.cst, q.ri,
    q.cost, q.nt
  from (values
    ('KB-3236-003','stale_content','firmware_changed','record_new_video','2026-07-20',null,'in_progress','internal_only',18000.00,'CT warmup procedure changed in FW 4.2 — video re-shoot assigned'),
    ('KB-3236-005','low_peer_rating','rushed_documentation','rewrite_article','2026-07-15',null,'open','internal_only',5000.00,'Flowchart branches ambiguous — rewrite with reviewer pairing'),
    ('KB-3236-007','stale_content','no_review_cycle','schedule_review_cycle','2026-07-10','2026-07-08','closed','iso_13485_deviation',2500.00,'Helium PM checklist now on quarterly review cadence'),
    ('KB-3236-010','duplicate_article','taxonomy_mismatch','merge_duplicates','2026-07-12',null,'verification_pending','none',0.00,'Merging into KB-3236-001 canonical article'),
    ('KB-3236-012','missing_safety_warning','part_superseded','archive_article','2026-06-28',null,'overdue','patient_safety_alert',7500.00,'Probe part discontinued — archive and commission replacement'),
    ('KB-3236-014','gap_topic_unfilled','author_left_org','commission_gap_article','2026-07-25',null,'escalated','nabh_finding',12000.00,'Infant warmer coverage gap escalated after NABH mock audit')
  ) as q(code, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.kb_contribution_r3236 e
    on e.organization_id = v_org_id and e.article_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) KB verdict distribution
create or replace function public.founder_r3236_verdict_rollup()
returns table(kb_verdict text, articles bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.kb_contribution_r3236)
  select l.kb_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.kb_contribution_r3236 l
  group by l.kb_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3236_verdict_rollup() from public, anon;
grant execute on function public.founder_r3236_verdict_rollup() to authenticated;

-- 2) Engineer contribution scorecard
create or replace function public.founder_r3236_engineer_scorecard()
returns table(
  engineer_name text,
  articles bigint,
  total_views_30d bigint,
  total_reuse_jobs bigint,
  avg_peer_rating numeric,
  peer_verified bigint,
  gap_topics_covered bigint,
  flagged_articles bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name,
    count(*)::bigint,
    coalesce(sum(l.views_30d),0)::bigint,
    coalesce(sum(l.reuse_in_jobs_count),0)::bigint,
    round(avg(l.peer_rating), 2),
    count(*) filter (where l.peer_review_status = 'peer_verified')::bigint,
    count(*) filter (where l.gap_topic_flagged)::bigint,
    count(*) filter (where l.kb_verdict in ('low_quality_flagged','stale_needs_refresh','duplicate_merge_needed'))::bigint
  from public.kb_contribution_r3236 l
  group by l.engineer_name
  order by coalesce(sum(l.reuse_in_jobs_count),0) desc;
end;
$$;

revoke execute on function public.founder_r3236_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3236_engineer_scorecard() to authenticated;

-- 3) Article type × equipment category matrix
create or replace function public.founder_r3236_type_category_matrix()
returns table(article_type text, equipment_category text, articles bigint, total_reuse_jobs bigint, avg_peer_rating numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.article_type, l.equipment_category, count(*)::bigint,
    coalesce(sum(l.reuse_in_jobs_count),0)::bigint,
    round(avg(l.peer_rating), 2)
  from public.kb_contribution_r3236 l
  group by l.article_type, l.equipment_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3236_type_category_matrix() from public, anon;
grant execute on function public.founder_r3236_type_category_matrix() to authenticated;

-- 4) Monthly publication trend
create or replace function public.founder_r3236_monthly_publish_trend()
returns table(publish_month date, articles bigint, avg_views_30d numeric, avg_peer_rating numeric, gap_topics bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.published_date)::date,
    count(*)::bigint,
    round(avg(l.views_30d), 1),
    round(avg(l.peer_rating), 2),
    count(*) filter (where l.gap_topic_flagged)::bigint
  from public.kb_contribution_r3236 l
  group by date_trunc('month', l.published_date)::date
  order by date_trunc('month', l.published_date)::date desc;
end;
$$;

revoke execute on function public.founder_r3236_monthly_publish_trend() from public, anon;
grant execute on function public.founder_r3236_monthly_publish_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3236_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.kb_contribution_capa_actions_r3236 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3236_capa_status_board() from public, anon;
grant execute on function public.founder_r3236_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3236_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.kb_contribution_capa_actions_r3236)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.kb_contribution_capa_actions_r3236 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3236_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3236_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3236_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.kb_contribution_capa_actions_r3236 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3236_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3236_regulatory_impact_digest() to authenticated;

-- 8) Stale / gap / low-quality priority queue
create or replace function public.founder_r3236_stale_gap_priority_queue()
returns table(
  hospital_name text,
  engineer_name text,
  article_code text,
  article_title text,
  article_type text,
  kb_verdict text,
  freshness_days int,
  peer_rating numeric,
  gap_topic_flagged boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.article_code, l.article_title,
    l.article_type, l.kb_verdict, l.freshness_days, l.peer_rating, l.gap_topic_flagged, l.notes
  from public.kb_contribution_r3236 l
  where l.kb_verdict in ('stale_needs_refresh','low_quality_flagged','duplicate_merge_needed','archived')
     or l.gap_topic_flagged
     or l.freshness_days > 180
     or l.peer_rating < 3.0
  order by l.freshness_days desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3236_stale_gap_priority_queue() from public, anon;
grant execute on function public.founder_r3236_stale_gap_priority_queue() to authenticated;
