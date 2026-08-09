-- Round 3699: Founder Search Zero-Results / Discovery-Gap Board
-- In-app search analytics — search category × platform surface × period month × zero-result rate × missing terms × synonyms × CTR × abandonment × catalog gaps × CAPA

-- =============================================================================
-- TABLE 1: search_gap_r3699 — per-surface monthly search zero-result / discovery-gap metrics
-- =============================================================================
create table if not exists public.search_gap_r3699 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  gap_code text not null,
  search_category text not null,
  platform_surface text not null,
  period_month date not null,
  searches_total int not null,
  zero_result_searches int not null,
  zero_result_pct numeric(5,2),
  top_missing_term text,
  synonyms_added int not null default 0,
  results_ctr_pct numeric(5,2),
  abandonment_pct numeric(5,2),
  catalog_gaps_identified int not null default 0,
  surface_class text not null check (surface_class in (
    'equipment_search','engineer_search','parts_search','kb_search','global_search'
  )),
  discovery_status text not null check (discovery_status in (
    'healthy','gap_emerging','high_zero_rate','catalog_gap','broken_relevance'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.search_gap_r3699 enable row level security;

create index if not exists idx_search_gap_r3699_org on public.search_gap_r3699(organization_id);
create index if not exists idx_search_gap_r3699_month on public.search_gap_r3699(period_month);
create index if not exists idx_search_gap_r3699_status on public.search_gap_r3699(discovery_status);

-- =============================================================================
-- TABLE 2: search_gap_capa_actions_r3699 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.search_gap_capa_actions_r3699 (
  id uuid primary key default gen_random_uuid(),
  gap_id uuid not null references public.search_gap_r3699(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'catalog_coverage_gap','synonym_dictionary_gap','tokenizer_language_issue',
    'ranking_model_regression','stale_search_index','typo_tolerance_off',
    'category_taxonomy_mismatch','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'add_synonym_mappings','onboard_missing_catalog','rebuild_search_index',
    'tune_ranking_weights','enable_fuzzy_matching','remap_category_taxonomy',
    'fix_indexer_pipeline','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  zero_searches_impacted numeric(10,2),
  action_owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.search_gap_capa_actions_r3699 enable row level security;

create index if not exists idx_search_gap_capa_r3699_gap on public.search_gap_capa_actions_r3699(gap_id);
create index if not exists idx_search_gap_capa_r3699_status on public.search_gap_capa_actions_r3699(capa_status);

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

  -- 16 search-gap metric rows
  insert into public.search_gap_r3699 (
    organization_id, gap_code, search_category, platform_surface, period_month,
    searches_total, zero_result_searches, zero_result_pct, top_missing_term,
    synonyms_added, results_ctr_pct, abandonment_pct, catalog_gaps_identified,
    surface_class, discovery_status, trend_dir, notes
  )
  select v_org_id, q.gcode, q.cat, q.surf, q.pm::date,
    q.st, q.zrs, q.zrp, q.term,
    q.syn, q.ctr, q.abd, q.cgi,
    q.scls, q.dst, q.tdir, q.nt
  from (values
    ('SGAP-001','ventilator-repair','android_marketplace','2026-07-01',
     4820,212,4.4,'drager v500 flow sensor',6,38.2,12.1,1,
     'equipment_search','healthy','stable','Ventilator repair search healthy across Mumbai and Delhi'),
    ('SGAP-002','infusion-pump-service','android_marketplace','2026-07-01',
     3610,589,16.3,'bbraun perfusor screen',2,24.6,28.4,4,
     'equipment_search','high_zero_rate','worsening','Infusion pump zero-rate climbing — Chennai brand-variant queries not matching'),
    ('SGAP-003','patient-monitor-parts','android_parts_store','2026-07-01',
     2980,742,24.9,'mindray spo2 sensor cable',1,18.9,34.7,7,
     'parts_search','catalog_gap','worsening','Parts catalog missing Mindray SpO2 cables — heavy Bengaluru demand'),
    ('SGAP-004','anesthesia-workstation-amc','web_portal','2026-07-01',
     1240,96,7.7,'ge aisys cs2 amc',3,31.4,15.2,1,
     'equipment_search','gap_emerging','stable','AMC quote search near zero-rate threshold on web portal'),
    ('SGAP-005','biomedical-engineer-hire','android_engineer_finder','2026-07-01',
     5240,167,3.2,'cath lab engineer delhi',9,42.7,9.8,0,
     'engineer_search','healthy','improving','Engineer discovery strong after July synonym pack rollout'),
    ('SGAP-006','ct-scanner-service','android_marketplace','2026-07-01',
     890,318,35.7,'siemens somatom tube swap',0,11.2,47.5,5,
     'equipment_search','broken_relevance','worsening','CT tube queries ranking unrelated cold-storage listings first — relevance broken'),
    ('SGAP-007','defibrillator-parts','android_parts_store','2026-06-01',
     2110,402,19.1,'zoll r series battery',2,22.5,30.1,4,
     'parts_search','high_zero_rate','stable','Zoll battery queries failing — taxonomy places batteries under accessories'),
    ('SGAP-008','kb-troubleshooting','android_help_center','2026-06-01',
     3320,610,18.4,'error e042 dialysis machine',4,26.8,25.9,3,
     'kb_search','gap_emerging','improving','Help-center error-code coverage thin for dialysis error families'),
    ('SGAP-009','ultrasound-probe-repair','web_portal','2026-06-01',
     1480,133,9.0,'ge 4c probe crystal',5,29.3,14.6,2,
     'equipment_search','healthy','stable','Probe repair search stable — Delhi and Mumbai vendors well covered'),
    ('SGAP-010','global-brand-lookup','android_global_search','2026-06-01',
     6150,1290,21.0,'philips efficia dfm100',1,16.4,33.8,9,
     'global_search','catalog_gap','worsening','Philips Efficia line absent from catalog — global search returning nothing'),
    ('SGAP-011','oxygen-concentrator-service','android_marketplace','2026-06-01',
     2760,138,5.0,'oxymed 10l service',7,36.9,11.4,0,
     'equipment_search','healthy','improving','Concentrator service search improved after vendor onboarding wave'),
    ('SGAP-012','icu-engineer-oncall','android_engineer_finder','2026-05-01',
     1980,462,23.3,'night shift engineer chennai',0,14.7,39.2,2,
     'engineer_search','high_zero_rate','worsening','On-call engineer queries with shift qualifiers hitting zero results'),
    ('SGAP-013','xray-parts','android_parts_store','2026-05-01',
     1720,229,13.3,'collimator bulb 100kv',3,25.1,22.6,3,
     'parts_search','gap_emerging','stable','X-ray consumable queries drifting — bulb wattage variants unmapped'),
    ('SGAP-014','kb-compliance-docs','web_portal','2026-05-01',
     940,71,7.6,'aerb license renewal checklist',2,33.5,13.9,1,
     'kb_search','healthy','stable','Compliance KB search healthy — AERB checklist most requested'),
    ('SGAP-015','dialysis-machine-repair','android_global_search','2026-05-01',
     2350,847,36.0,'fresenius 4008s hydraulics',0,9.8,51.3,6,
     'global_search','broken_relevance','worsening','Dialysis listings indexed under legacy taxonomy — global search relevance broken'),
    ('SGAP-016','endoscopy-camera-service','android_marketplace','2026-05-01',
     1130,204,18.1,'olympus cv190 processor',1,21.7,27.4,2,
     'equipment_search','gap_emerging','improving','Endoscopy service queries recovering after synonym additions')
  ) as q(gcode, cat, surf, pm, st, zrs, zrp, term, syn, ctr, abd, cgi, scls, dst, tdir, nt);

  -- CAPA seed — attach to specific gap rows via gap_code
  insert into public.search_gap_capa_actions_r3699 (
    gap_id, root_cause, corrective_action, capa_status,
    zero_searches_impacted, action_owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.zsi, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('SGAP-003','catalog_coverage_gap','onboard_missing_catalog','in_progress',742,'Catalog Ops - Ravi','2026-08-20',null,'Mindray SpO2 cable SKUs being onboarded from three Bengaluru vendors'),
    ('SGAP-006','ranking_model_regression','tune_ranking_weights','escalated',318,'Search Platform - Meera','2026-08-12',null,'CT relevance regression traced to July ranker deploy — rollback candidate'),
    ('SGAP-010','catalog_coverage_gap','onboard_missing_catalog','open',1290,'Catalog Ops - Ravi','2026-08-25',null,'Philips Efficia line absent from catalog — vendor outreach started'),
    ('SGAP-015','stale_search_index','rebuild_search_index','in_progress',847,'Search Platform - Arjun','2026-08-15',null,'Dialysis listings under legacy taxonomy — full reindex running'),
    ('SGAP-002','synonym_dictionary_gap','add_synonym_mappings','verification_pending',589,'Search Platform - Meera','2026-08-10',null,'B Braun brand-variant synonyms shipped — verifying zero-rate drop'),
    ('SGAP-012','typo_tolerance_off','enable_fuzzy_matching','closed',462,'Search Platform - Arjun','2026-07-30','2026-07-28','Fuzzy matching enabled on engineer finder — zero-rate down nine points'),
    ('SGAP-007','category_taxonomy_mismatch','remap_category_taxonomy','overdue',402,'Catalog Ops - Divya','2026-07-25',null,'Zoll batteries mapped under accessories not parts — remap pending'),
    ('SGAP-008','pending_investigation','none_required','open',610,'Support KB - Karthik','2026-08-18',null,'KB error-code coverage audit in progress for dialysis error families')
  ) as q(gcode, rc, ca, cst, zsi, ownr, tcd, acd, nt)
  join public.search_gap_r3699 e
    on e.organization_id = v_org_id and e.gap_code = q.gcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Discovery status distribution
create or replace function public.founder_r3699_discovery_status_rollup()
returns table(discovery_status text, surfaces bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.search_gap_r3699)
  select l.discovery_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.search_gap_r3699 l
  group by l.discovery_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3699_discovery_status_rollup() from public, anon;
grant execute on function public.founder_r3699_discovery_status_rollup() to authenticated;

-- 2) Platform-surface scorecard
create or replace function public.founder_r3699_surface_scorecard()
returns table(
  platform_surface text,
  gap_rows bigint,
  healthy bigint,
  gap_emerging bigint,
  high_zero_rate bigint,
  catalog_gap bigint,
  broken_relevance bigint,
  searches bigint,
  avg_zero_pct numeric,
  avg_ctr_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.platform_surface,
    count(*)::bigint,
    count(*) filter (where l.discovery_status = 'healthy')::bigint,
    count(*) filter (where l.discovery_status = 'gap_emerging')::bigint,
    count(*) filter (where l.discovery_status = 'high_zero_rate')::bigint,
    count(*) filter (where l.discovery_status = 'catalog_gap')::bigint,
    count(*) filter (where l.discovery_status = 'broken_relevance')::bigint,
    coalesce(sum(l.searches_total),0)::bigint,
    round(avg(l.zero_result_pct), 1),
    round(avg(l.results_ctr_pct), 1)
  from public.search_gap_r3699 l
  group by l.platform_surface
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3699_surface_scorecard() from public, anon;
grant execute on function public.founder_r3699_surface_scorecard() to authenticated;

-- 3) Surface-class × discovery-status matrix
create or replace function public.founder_r3699_surface_class_status_matrix()
returns table(surface_class text, discovery_status text, gap_rows bigint, searches bigint, avg_zero_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.surface_class, l.discovery_status, count(*)::bigint,
    coalesce(sum(l.searches_total),0)::bigint,
    round(avg(l.zero_result_pct), 1)
  from public.search_gap_r3699 l
  group by l.surface_class, l.discovery_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3699_surface_class_status_matrix() from public, anon;
grant execute on function public.founder_r3699_surface_class_status_matrix() to authenticated;

-- 4) Monthly zero-rate trend
create or replace function public.founder_r3699_monthly_zero_rate_trend()
returns table(period_month date, gap_rows bigint, searches bigint, zero_results bigint, avg_zero_pct numeric, avg_ctr_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.searches_total),0)::bigint,
    coalesce(sum(l.zero_result_searches),0)::bigint,
    round(avg(l.zero_result_pct), 1),
    round(avg(l.results_ctr_pct), 1)
  from public.search_gap_r3699 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3699_monthly_zero_rate_trend() from public, anon;
grant execute on function public.founder_r3699_monthly_zero_rate_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3699_capa_status_board()
returns table(capa_status text, actions bigint, avg_zero_searches_impacted numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.zero_searches_impacted)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.search_gap_capa_actions_r3699 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3699_capa_status_board() from public, anon;
grant execute on function public.founder_r3699_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3699_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_zero_searches_impacted numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.search_gap_capa_actions_r3699)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.zero_searches_impacted),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.search_gap_capa_actions_r3699 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3699_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3699_root_cause_pareto() to authenticated;

-- 7) Missing-term digest
create or replace function public.founder_r3699_missing_term_digest()
returns table(top_missing_term text, mentions bigint, zero_searches bigint, avg_zero_pct numeric, synonyms_added bigint, catalog_gaps bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.top_missing_term, count(*)::bigint,
    coalesce(sum(l.zero_result_searches),0)::bigint,
    round(avg(l.zero_result_pct), 1),
    coalesce(sum(l.synonyms_added),0)::bigint,
    coalesce(sum(l.catalog_gaps_identified),0)::bigint
  from public.search_gap_r3699 l
  where l.top_missing_term is not null
  group by l.top_missing_term
  order by coalesce(sum(l.zero_result_searches),0) desc;
end;
$$;

revoke all on function public.founder_r3699_missing_term_digest() from public, anon;
grant execute on function public.founder_r3699_missing_term_digest() to authenticated;

-- 8) High-risk discovery queue
create or replace function public.founder_r3699_high_risk_queue()
returns table(
  gap_code text,
  search_category text,
  platform_surface text,
  period_month date,
  zero_result_pct numeric,
  abandonment_pct numeric,
  top_missing_term text,
  discovery_status text,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.gap_code, l.search_category, l.platform_surface, l.period_month,
    l.zero_result_pct, l.abandonment_pct, l.top_missing_term,
    l.discovery_status, l.trend_dir, l.notes
  from public.search_gap_r3699 l
  where l.discovery_status in ('broken_relevance','high_zero_rate','catalog_gap')
     or l.trend_dir = 'worsening'
     or l.zero_result_pct >= 20.0
  order by l.zero_result_pct desc nulls last, l.gap_code;
end;
$$;

revoke all on function public.founder_r3699_high_risk_queue() from public, anon;
grant execute on function public.founder_r3699_high_risk_queue() to authenticated;
