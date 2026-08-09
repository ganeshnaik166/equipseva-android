-- Round 3706: Founder Marketplace SKU-Catalog Completeness / Listing-Quality Board
-- Platform catalog QA — catalog section × category × photo coverage × spec coverage × pricing coverage × duplicates × staleness × completeness score × CAPA

-- =============================================================================
-- TABLE 1: sku_catalog_r3706 — per-section monthly catalog completeness snapshots
-- =============================================================================
create table if not exists public.sku_catalog_r3706 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  section_ref text not null,
  catalog_section text not null,
  category text not null,
  period_month date not null,
  skus_total int not null,
  skus_with_photos int not null,
  photo_pct numeric(5,1) not null,
  skus_with_specs int not null,
  spec_pct numeric(5,1) not null,
  skus_priced int not null,
  pricing_pct numeric(5,1) not null,
  duplicate_listings int not null default 0,
  stale_listings int not null default 0,
  completeness_score numeric(5,1) not null,
  section_class text not null check (section_class in (
    'equipment_sale','spare_parts','service_offerings','consumables','refurbished'
  )),
  catalog_status text not null check (catalog_status in (
    'complete','minor_gaps','photo_gaps','spec_gaps','poor_quality'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.sku_catalog_r3706 enable row level security;

create index if not exists idx_sku_catalog_r3706_org on public.sku_catalog_r3706(organization_id);
create index if not exists idx_sku_catalog_r3706_month on public.sku_catalog_r3706(period_month);
create index if not exists idx_sku_catalog_r3706_status on public.sku_catalog_r3706(catalog_status);

-- =============================================================================
-- TABLE 2: sku_catalog_capa_actions_r3706 — catalog-quality CAPA actions
-- =============================================================================
create table if not exists public.sku_catalog_capa_actions_r3706 (
  id uuid primary key default gen_random_uuid(),
  catalog_row_id uuid not null references public.sku_catalog_r3706(id) on delete cascade,
  raised_at timestamptz not null default now(),
  gap_category text not null check (gap_category in (
    'photo_coverage_gap','spec_sheet_missing','pricing_missing','duplicate_listings',
    'stale_listing_backlog','image_quality_poor','description_thin','category_misclassification'
  )),
  root_cause text not null check (root_cause in (
    'seller_onboarding_rushed','photo_upload_tooling_gap','spec_template_missing',
    'bulk_import_mapping_error','pricing_approval_backlog','seller_unresponsive',
    'catalog_team_bandwidth','legacy_migration_debt','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'professional_photo_shoot','spec_template_rollout','bulk_enrichment_sprint',
    'dedupe_merge_run','delist_stale_skus','seller_outreach_campaign',
    'pricing_desk_escalation','catalog_qa_checklist_update','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  skus_impacted numeric(8,0) not null default 0,
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.sku_catalog_capa_actions_r3706 enable row level security;

create index if not exists idx_sku_catalog_capa_r3706_row on public.sku_catalog_capa_actions_r3706(catalog_row_id);
create index if not exists idx_sku_catalog_capa_r3706_status on public.sku_catalog_capa_actions_r3706(capa_status);

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

  -- 16 catalog-section snapshot rows
  insert into public.sku_catalog_r3706 (
    organization_id, section_ref, catalog_section, category, period_month,
    skus_total, skus_with_photos, photo_pct, skus_with_specs, spec_pct,
    skus_priced, pricing_pct, duplicate_listings, stale_listings,
    completeness_score, section_class, catalog_status, trend_dir, notes
  )
  select v_org_id, q.sref, q.csec, q.cat, q.pm::date,
    q.tot, q.wph, q.phpct, q.wsp, q.sppct,
    q.prc, q.prpct, q.dup, q.stl,
    q.comp, q.scls, q.cst, q.trd, q.nt
  from (values
    ('SEC-EQ-VENT','Ventilators — ICU & Transport','Critical Care','2026-07-01',
     148,141,95.3,139,93.9,145,98.0,2,4,94.1,'equipment_sale','complete','stable','Flagship section — near-full enrichment held after Q2 sprint'),
    ('SEC-EQ-MON','Patient Monitors — Multipara','Critical Care','2026-07-01',
     212,190,89.6,171,80.7,205,96.7,5,9,88.2,'equipment_sale','minor_gaps','improving','Spec template v2 adoption lifting coverage month over month'),
    ('SEC-EQ-XRAY','Portable X-Ray & C-Arm','Imaging','2026-07-01',
     96,61,63.5,79,82.3,90,93.8,3,7,76.4,'equipment_sale','photo_gaps','improving','C-arm sellers slow to upload photos — outreach campaign closed the worst gaps'),
    ('SEC-EQ-USG','Ultrasound & Doppler','Imaging','2026-07-01',
     124,118,95.2,84,67.7,117,94.4,4,6,82.9,'equipment_sale','spec_gaps','stable','Doppler probe spec sheets missing on a third of listings'),
    ('SEC-EQ-LAB','Lab Analyzers — Biochem & Hematology','Lab & Diagnostics','2026-07-01',
     167,132,79.0,121,72.5,149,89.2,8,15,74.8,'equipment_sale','spec_gaps','worsening','Analyzer spec coverage slipping as new sellers list without templates'),
    ('SEC-SP-VENT','Spares — Ventilator Circuits & Valves','Spare Parts','2026-07-01',
     321,214,66.7,246,76.6,298,92.8,12,28,71.3,'spare_parts','photo_gaps','stable','High-volume spares section — photo backlog concentrated in valve SKUs'),
    ('SEC-SP-MON','Spares — Monitor Probes & Cables','Spare Parts','2026-07-01',
     284,201,70.8,192,67.6,251,88.4,18,34,66.9,'spare_parts','poor_quality','worsening','Worst section — duplicates plus stale probes dragging quality score'),
    ('SEC-SP-IMG','Spares — Imaging Tubes & Detectors','Spare Parts','2026-07-01',
     88,74,84.1,71,80.7,79,89.8,2,5,83.6,'spare_parts','minor_gaps','improving','Tube/detector listings enriched during July catalog QA pass'),
    ('SEC-SV-AMC','Service — AMC & CMC Plans','Services','2026-07-01',
     64,58,90.6,61,95.3,62,96.9,1,2,93.4,'service_offerings','complete','stable','Service plan listings well structured — pricing bands published'),
    ('SEC-SV-INST','Service — Installation & Calibration','Services','2026-07-01',
     52,41,78.8,44,84.6,47,90.4,2,6,81.7,'service_offerings','minor_gaps','stable','Calibration offerings need city-coverage notes on older listings'),
    ('SEC-CN-ECG','Consumables — ECG Electrodes & Gels','Consumables','2026-07-01',
     196,157,80.1,148,75.5,183,93.4,9,21,77.2,'consumables','minor_gaps','improving','Electrode brand pages consolidated — stale count trending down'),
    ('SEC-CN-VENT','Consumables — Breathing Circuits & Filters','Consumables','2026-07-01',
     173,121,69.9,109,63.0,152,87.9,11,26,68.5,'consumables','spec_gaps','worsening','Bulk import dropped spec fields for circuit SKUs — remap under way'),
    ('SEC-RF-MON','Refurbished — Patient Monitors','Refurbished','2026-07-01',
     77,49,63.6,42,54.5,66,85.7,6,12,61.8,'refurbished','poor_quality','worsening','Refurb monitors listed with stock images and thin condition reports'),
    ('SEC-RF-USG','Refurbished — Ultrasound Systems','Refurbished','2026-07-01',
     41,36,87.8,33,80.5,39,95.1,1,3,86.2,'refurbished','minor_gaps','improving','Refurb ultrasound listings carry inspection certificates — good shape'),
    ('SEC-EQ-MON-JUN','Patient Monitors — Multipara (Jun)','Critical Care','2026-06-01',
     204,175,85.8,158,77.5,193,94.6,7,12,84.1,'equipment_sale','minor_gaps','stable','June baseline snapshot before spec template v2 rollout'),
    ('SEC-SP-MON-JUN','Spares — Monitor Probes & Cables (Jun)','Spare Parts','2026-06-01',
     271,183,67.5,178,65.7,236,87.1,15,29,64.4,'spare_parts','poor_quality','stable','June baseline — duplicate probe listings already flagged')
  ) as q(sref, csec, cat, pm, tot, wph, phpct, wsp, sppct, prc, prpct, dup, stl, comp, scls, cst, trd, nt);

  -- CAPA seed — attach to specific sections via section_ref
  insert into public.sku_catalog_capa_actions_r3706 (
    catalog_row_id, gap_category, root_cause, corrective_action,
    capa_status, skus_impacted, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.gc, q.rc, q.ca,
    q.cst, q.ski, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('SEC-SP-MON','photo_coverage_gap','photo_upload_tooling_gap','bulk_enrichment_sprint','in_progress',83,'Meera Krishnan','2026-07-20',null,'Probe/cable photo backlog — enrichment sprint week 2 of 3'),
    ('SEC-RF-MON','image_quality_poor','seller_onboarding_rushed','professional_photo_shoot','open',28,'Arjun Nair','2026-07-25',null,'Refurb monitor listings using stock images — studio shoot booked in Pune'),
    ('SEC-EQ-LAB','spec_sheet_missing','spec_template_missing','spec_template_rollout','in_progress',46,'Divya Menon','2026-07-18',null,'Biochem analyzer spec template v2 rolled to 60 percent of listings'),
    ('SEC-CN-VENT','spec_sheet_missing','bulk_import_mapping_error','bulk_enrichment_sprint','escalated',64,'Rohit Sharma','2026-07-10',null,'Bulk import dropped spec fields for circuit SKUs — remap escalated to platform team'),
    ('SEC-SP-VENT','stale_listing_backlog','seller_unresponsive','delist_stale_skus','verification_pending',28,'Meera Krishnan','2026-07-12',null,'28 stale valve SKUs delisted — awaiting search-index verification'),
    ('SEC-SP-MON','duplicate_listings','legacy_migration_debt','dedupe_merge_run','open',18,'Arjun Nair','2026-07-22',null,'Duplicate probe listings from legacy catalog migration queued for merge'),
    ('SEC-EQ-XRAY','photo_coverage_gap','seller_unresponsive','seller_outreach_campaign','closed',35,'Divya Menon','2026-07-05','2026-07-03','C-arm sellers uploaded photos after outreach — photo coverage up 9 points'),
    ('SEC-EQ-USG','spec_sheet_missing','catalog_team_bandwidth','spec_template_rollout','overdue',40,'Rohit Sharma','2026-06-30',null,'Doppler spec backlog past target — catalog pod hiring in progress')
  ) as q(sref, gc, rc, ca, cst, ski, ownr, tcd, acd, nt)
  join public.sku_catalog_r3706 e
    on e.organization_id = v_org_id and e.section_ref = q.sref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Catalog status distribution
create or replace function public.founder_r3706_catalog_status_rollup()
returns table(catalog_status text, sections bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.sku_catalog_r3706)
  select l.catalog_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.sku_catalog_r3706 l
  group by l.catalog_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3706_catalog_status_rollup() from public, anon;
grant execute on function public.founder_r3706_catalog_status_rollup() to authenticated;

-- 2) Category-level completeness scorecard
create or replace function public.founder_r3706_category_scorecard()
returns table(
  category text,
  sections bigint,
  skus bigint,
  complete_sections bigint,
  poor_quality_sections bigint,
  avg_photo_pct numeric,
  avg_spec_pct numeric,
  avg_pricing_pct numeric,
  avg_completeness numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category,
    count(*)::bigint,
    coalesce(sum(l.skus_total),0)::bigint,
    count(*) filter (where l.catalog_status = 'complete')::bigint,
    count(*) filter (where l.catalog_status = 'poor_quality')::bigint,
    round(avg(l.photo_pct), 1),
    round(avg(l.spec_pct), 1),
    round(avg(l.pricing_pct), 1),
    round(avg(l.completeness_score), 1)
  from public.sku_catalog_r3706 l
  group by l.category
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3706_category_scorecard() from public, anon;
grant execute on function public.founder_r3706_category_scorecard() to authenticated;

-- 3) Section-class × catalog-status matrix
create or replace function public.founder_r3706_section_class_status_matrix()
returns table(section_class text, catalog_status text, sections bigint, skus bigint, avg_completeness numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.section_class, l.catalog_status, count(*)::bigint,
    coalesce(sum(l.skus_total),0)::bigint,
    round(avg(l.completeness_score), 1)
  from public.sku_catalog_r3706 l
  group by l.section_class, l.catalog_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3706_section_class_status_matrix() from public, anon;
grant execute on function public.founder_r3706_section_class_status_matrix() to authenticated;

-- 4) Monthly completeness trend
create or replace function public.founder_r3706_monthly_completeness_trend()
returns table(
  period_month date,
  sections bigint,
  avg_photo_pct numeric,
  avg_spec_pct numeric,
  avg_pricing_pct numeric,
  avg_completeness numeric,
  duplicate_listings bigint,
  stale_listings bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.photo_pct), 1),
    round(avg(l.spec_pct), 1),
    round(avg(l.pricing_pct), 1),
    round(avg(l.completeness_score), 1),
    coalesce(sum(l.duplicate_listings),0)::bigint,
    coalesce(sum(l.stale_listings),0)::bigint
  from public.sku_catalog_r3706 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3706_monthly_completeness_trend() from public, anon;
grant execute on function public.founder_r3706_monthly_completeness_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3706_capa_status_board()
returns table(capa_status text, actions bigint, skus_impacted numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    coalesce(sum(c.skus_impacted),0)::numeric,
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.sku_catalog_capa_actions_r3706 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3706_capa_status_board() from public, anon;
grant execute on function public.founder_r3706_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3706_root_cause_pareto()
returns table(root_cause text, occurrences bigint, skus_impacted numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.sku_catalog_capa_actions_r3706)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.skus_impacted),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.sku_catalog_capa_actions_r3706 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3706_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3706_root_cause_pareto() to authenticated;

-- 7) Gap-category digest
create or replace function public.founder_r3706_gap_digest()
returns table(gap_category text, actions bigint, open_actions bigint, skus_impacted numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.gap_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','escalated','overdue'))::bigint,
    coalesce(sum(c.skus_impacted),0)::numeric
  from public.sku_catalog_capa_actions_r3706 c
  group by c.gap_category
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3706_gap_digest() from public, anon;
grant execute on function public.founder_r3706_gap_digest() to authenticated;

-- 8) High-risk section queue (poor quality / spec gaps / worsening)
create or replace function public.founder_r3706_high_risk_queue()
returns table(
  section_ref text,
  catalog_section text,
  category text,
  period_month date,
  catalog_status text,
  trend_dir text,
  completeness_score numeric,
  duplicate_listings int,
  stale_listings int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.section_ref, l.catalog_section, l.category, l.period_month,
    l.catalog_status, l.trend_dir, l.completeness_score,
    l.duplicate_listings, l.stale_listings, l.notes
  from public.sku_catalog_r3706 l
  where l.catalog_status in ('poor_quality','spec_gaps')
     or l.trend_dir = 'worsening'
     or l.completeness_score < 70
     or l.duplicate_listings >= 10
     or l.stale_listings >= 20
  order by l.completeness_score asc, l.period_month desc;
end;
$$;

revoke all on function public.founder_r3706_high_risk_queue() from public, anon;
grant execute on function public.founder_r3706_high_risk_queue() to authenticated;
