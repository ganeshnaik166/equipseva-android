-- Round 3690: Founder Office Drinking-Water / RO / Tank-Hygiene Board
-- Own-premises drinking-water hygiene — tank cleaning × RO service × TDS/potability tests × complaints per site/water point × CAPA

-- =============================================================================
-- TABLE 1: water_hygiene_r3690 — per-water-point monthly hygiene checks
-- =============================================================================
create table if not exists public.water_hygiene_r3690 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  site_name text not null,
  water_point text not null,
  period_month date not null,
  tanks_count int,
  tanks_cleaned_on_schedule int,
  cleaning_current_pct numeric,
  last_cleaning_date date,
  ro_units int,
  ro_serviced_pct numeric,
  tds_ppm numeric,
  tds_limit_ppm numeric,
  potability_test_passed boolean not null,
  complaints int,
  point_class text not null check (point_class in (
    'overhead_tank','underground_sump','ro_unit','water_cooler','pantry_tap'
  )),
  hygiene_status text not null check (hygiene_status in (
    'compliant','cleaning_due','service_due','tds_high','test_failed'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.water_hygiene_r3690 enable row level security;

create index if not exists idx_water_hygiene_r3690_org on public.water_hygiene_r3690(organization_id);
create index if not exists idx_water_hygiene_r3690_month on public.water_hygiene_r3690(period_month);
create index if not exists idx_water_hygiene_r3690_status on public.water_hygiene_r3690(hygiene_status);

-- =============================================================================
-- TABLE 2: water_hygiene_capa_actions_r3690 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.water_hygiene_capa_actions_r3690 (
  id uuid primary key default gen_random_uuid(),
  water_log_id uuid not null references public.water_hygiene_r3690(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'tank_cleaning_vendor_delay','ro_membrane_fouled','uv_lamp_expired',
    'filter_cartridge_overdue','municipal_input_tds_spike','sump_seepage_ingress',
    'pipeline_biofilm_contamination','vendor_contract_lapsed','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'emergency_tank_cleaning','replace_ro_membrane','replace_uv_lamp',
    'replace_filter_cartridge','install_pretreatment_softener','flush_and_chlorinate_line',
    'repair_sump_lining','renew_vendor_amc','retest_water_sample','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  estimated_cost_rupees numeric(12,2),
  action_owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.water_hygiene_capa_actions_r3690 enable row level security;

create index if not exists idx_water_hygiene_capa_r3690_log on public.water_hygiene_capa_actions_r3690(water_log_id);
create index if not exists idx_water_hygiene_capa_r3690_status on public.water_hygiene_capa_actions_r3690(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Hygiene status distribution
create or replace function public.founder_r3690_hygiene_status_rollup()
returns table(hygiene_status text, points bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.water_hygiene_r3690)
  select l.hygiene_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.water_hygiene_r3690 l
  group by l.hygiene_status
  order by count(*) desc;
end;
$$;

-- 2) Site-level hygiene scorecard
create or replace function public.founder_r3690_site_scorecard()
returns table(
  site_name text,
  total_points bigint,
  compliant bigint,
  cleaning_due bigint,
  service_due bigint,
  tds_high bigint,
  test_failed bigint,
  total_complaints bigint,
  avg_tds_ppm numeric,
  compliant_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name,
    count(*)::bigint,
    count(*) filter (where l.hygiene_status = 'compliant')::bigint,
    count(*) filter (where l.hygiene_status = 'cleaning_due')::bigint,
    count(*) filter (where l.hygiene_status = 'service_due')::bigint,
    count(*) filter (where l.hygiene_status = 'tds_high')::bigint,
    count(*) filter (where l.hygiene_status = 'test_failed')::bigint,
    coalesce(sum(l.complaints),0)::bigint,
    round(avg(l.tds_ppm), 1),
    round(100.0 * count(*) filter (where l.hygiene_status = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.water_hygiene_r3690 l
  group by l.site_name
  order by count(*) desc;
end;
$$;

-- 3) Point-class × hygiene-status matrix
create or replace function public.founder_r3690_point_class_status_matrix()
returns table(point_class text, hygiene_status text, points bigint, avg_tds_ppm numeric, total_complaints bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.point_class, l.hygiene_status, count(*)::bigint,
    round(avg(l.tds_ppm), 1),
    coalesce(sum(l.complaints),0)::bigint
  from public.water_hygiene_r3690 l
  group by l.point_class, l.hygiene_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly potability test trend
create or replace function public.founder_r3690_monthly_test_trend()
returns table(
  period_month date,
  points bigint,
  potability_passed bigint,
  potability_failed bigint,
  avg_tds_ppm numeric,
  avg_cleaning_current_pct numeric,
  total_complaints bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.potability_test_passed = true)::bigint,
    count(*) filter (where l.potability_test_passed = false)::bigint,
    round(avg(l.tds_ppm), 1),
    round(avg(l.cleaning_current_pct), 1),
    coalesce(sum(l.complaints),0)::bigint
  from public.water_hygiene_r3690 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3690_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.water_hygiene_capa_actions_r3690 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3690_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.water_hygiene_capa_actions_r3690)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.water_hygiene_capa_actions_r3690 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) TDS / complaint digest by site
create or replace function public.founder_r3690_tds_complaint_digest()
returns table(
  site_name text,
  points bigint,
  avg_tds_ppm numeric,
  max_tds_ppm numeric,
  tds_over_limit_points bigint,
  potability_fail_points bigint,
  total_complaints bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name,
    count(*)::bigint,
    round(avg(l.tds_ppm), 1),
    max(l.tds_ppm),
    count(*) filter (where l.tds_ppm > l.tds_limit_ppm)::bigint,
    count(*) filter (where l.potability_test_passed = false)::bigint,
    coalesce(sum(l.complaints),0)::bigint
  from public.water_hygiene_r3690 l
  group by l.site_name
  order by count(*) desc;
end;
$$;

-- 8) High-risk queue (test_failed / tds_high / worsening)
create or replace function public.founder_r3690_high_risk_queue()
returns table(
  site_name text,
  water_point text,
  point_class text,
  period_month date,
  hygiene_status text,
  trend_dir text,
  tds_ppm numeric,
  tds_limit_ppm numeric,
  potability_test_passed boolean,
  complaints int,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name, l.water_point, l.point_class, l.period_month,
    l.hygiene_status, l.trend_dir, l.tds_ppm, l.tds_limit_ppm,
    l.potability_test_passed, l.complaints, l.notes
  from public.water_hygiene_r3690 l
  where l.hygiene_status in ('test_failed','tds_high')
     or l.potability_test_passed = false
     or l.tds_ppm > l.tds_limit_ppm
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.site_name;
end;
$$;

-- =============================================================================
-- Grants
-- =============================================================================
revoke all on function public.founder_r3690_hygiene_status_rollup() from public, anon;
revoke all on function public.founder_r3690_site_scorecard() from public, anon;
revoke all on function public.founder_r3690_point_class_status_matrix() from public, anon;
revoke all on function public.founder_r3690_monthly_test_trend() from public, anon;
revoke all on function public.founder_r3690_capa_status_board() from public, anon;
revoke all on function public.founder_r3690_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3690_tds_complaint_digest() from public, anon;
revoke all on function public.founder_r3690_high_risk_queue() from public, anon;

grant execute on function public.founder_r3690_hygiene_status_rollup() to authenticated;
grant execute on function public.founder_r3690_site_scorecard() to authenticated;
grant execute on function public.founder_r3690_point_class_status_matrix() to authenticated;
grant execute on function public.founder_r3690_monthly_test_trend() to authenticated;
grant execute on function public.founder_r3690_capa_status_board() to authenticated;
grant execute on function public.founder_r3690_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3690_tds_complaint_digest() to authenticated;
grant execute on function public.founder_r3690_high_risk_queue() to authenticated;

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

  -- 16 water-point hygiene rows
  insert into public.water_hygiene_r3690 (
    organization_id, site_name, water_point, period_month,
    tanks_count, tanks_cleaned_on_schedule, cleaning_current_pct, last_cleaning_date,
    ro_units, ro_serviced_pct, tds_ppm, tds_limit_ppm,
    potability_test_passed, complaints, point_class, hygiene_status, trend_dir, notes
  )
  select v_org_id, q.site, q.wp, q.pm::date,
    q.tks, q.tcs, q.ccp::numeric, q.lcd::date,
    q.rou, q.rsp::numeric, q.tds::numeric, q.tlim::numeric,
    q.pot, q.cmp, q.pcls, q.hst, q.tdir, q.nt
  from (values
    ('Mumbai HQ','OHT-MUM-01','2026-07-01',2,2,100,'2026-06-20',0,null,180,500,
     true,0,'overhead_tank','compliant','stable','Twin overhead tanks cleaned by AquaShine on schedule'),
    ('Mumbai HQ','RO-MUM-02','2026-07-01',0,0,null,null,3,100,45,50,
     true,0,'ro_unit','compliant','improving','Three-stage RO bank serviced by Eureka Forbes AMC in June'),
    ('Mumbai HQ','WC-MUM-03','2026-06-01',0,0,null,null,1,0,62,50,
     true,1,'water_cooler','service_due','worsening','Cafeteria water cooler RO cartridge service overdue by 3 weeks'),
    ('Mumbai HQ','UGS-MUM-04','2026-07-01',1,0,0,'2026-03-15',0,null,410,500,
     true,0,'underground_sump','cleaning_due','worsening','Underground sump last cleaned in March — vendor slot pending'),
    ('Chennai Branch','OHT-CHE-01','2026-06-01',1,1,100,'2026-06-12',0,null,320,500,
     true,0,'overhead_tank','compliant','stable','Terrace tank cleaned and chlorinated by CityCare vendor'),
    ('Chennai Branch','RO-CHE-02','2026-07-01',0,0,null,null,2,50,88,50,
     false,3,'ro_unit','test_failed','worsening','RO output TDS 88 ppm and potability sample failed after metro input spike'),
    ('Chennai Branch','PT-CHE-03','2026-07-01',0,0,null,null,0,null,540,500,
     true,2,'pantry_tap','tds_high','worsening','Pantry tap on raw metro line reading 540 ppm — above 500 ppm limit'),
    ('Chennai Branch','WC-CHE-04','2026-05-01',0,0,null,null,1,100,40,50,
     true,0,'water_cooler','compliant','improving','Reception cooler cartridge replaced during May AMC visit'),
    ('Delhi Warehouse','UGS-DEL-01','2026-06-01',1,1,100,'2026-06-25',0,null,380,500,
     true,0,'underground_sump','compliant','stable','Sump dewatered and scrubbed by Kent AMC crew'),
    ('Delhi Warehouse','OHT-DEL-02','2026-07-01',2,1,50,'2026-05-10',0,null,395,500,
     true,1,'overhead_tank','cleaning_due','stable','One of two rooftop tanks missed the June cleaning window'),
    ('Delhi Warehouse','RO-DEL-03','2026-05-01',0,0,null,null,1,100,120,150,
     true,0,'ro_unit','compliant','stable','Warehouse RO within borewell-adjusted 150 ppm limit'),
    ('Delhi Warehouse','WC-DEL-04','2026-07-01',0,0,null,null,2,50,165,150,
     true,4,'water_cooler','tds_high','worsening','Dock-side coolers at 165 ppm — membrane fouling suspected'),
    ('Bengaluru Refurb Center','OHT-BLR-01','2026-06-01',1,1,100,'2026-06-18',0,null,210,500,
     true,0,'overhead_tank','compliant','improving','Tank cleaned and epoxy re-lining completed in June'),
    ('Bengaluru Refurb Center','RO-BLR-02','2026-05-01',0,0,null,null,2,100,35,50,
     true,0,'ro_unit','compliant','stable','Refurb center RO bank UV lamp replaced during AMC'),
    ('Bengaluru Refurb Center','PT-BLR-03','2026-07-01',0,0,null,null,0,null,470,500,
     false,2,'pantry_tap','test_failed','worsening','Pantry tap coliform positive in July sample — line flush ordered'),
    ('Bengaluru Refurb Center','UGS-BLR-04','2026-07-01',1,0,0,'2026-02-28',0,null,330,500,
     true,1,'underground_sump','cleaning_due','stable','Sump cleaning overdue since February — tanker silt ingress noted')
  ) as q(site, wp, pm, tks, tcs, ccp, lcd, rou, rsp, tds, tlim, pot, cmp, pcls, hst, tdir, nt);

  -- CAPA seed — attach to specific water points via water_point code
  insert into public.water_hygiene_capa_actions_r3690 (
    water_log_id, root_cause, corrective_action, capa_status,
    estimated_cost_rupees, action_owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.cost, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('RO-CHE-02','municipal_input_tds_spike','install_pretreatment_softener','in_progress',52000.00,'Admin - Chennai','2026-07-20',null,'Softener quote approved; potability retest after install'),
    ('PT-CHE-03','municipal_input_tds_spike','install_pretreatment_softener','open',18000.00,'Admin - Chennai','2026-07-25',null,'Pantry line to be moved onto RO loop after softener install'),
    ('WC-MUM-03','filter_cartridge_overdue','replace_filter_cartridge','closed',3200.00,'Facilities - Mumbai','2026-07-10','2026-07-08','Cartridge replaced; cooler TDS back to 38 ppm'),
    ('UGS-MUM-04','tank_cleaning_vendor_delay','emergency_tank_cleaning','escalated',12500.00,'Facilities - Mumbai','2026-07-12',null,'Vendor no-show twice — escalated and AMC renewal with new agency'),
    ('OHT-DEL-02','tank_cleaning_vendor_delay','emergency_tank_cleaning','overdue',9000.00,'Warehouse Admin - Delhi','2026-07-05',null,'Second rooftop tank still pending — beyond target date'),
    ('WC-DEL-04','ro_membrane_fouled','replace_ro_membrane','in_progress',14800.00,'Warehouse Admin - Delhi','2026-07-18',null,'Membranes ordered for both dock coolers'),
    ('PT-BLR-03','pipeline_biofilm_contamination','flush_and_chlorinate_line','verification_pending',6500.00,'Facilities - Bengaluru','2026-07-15',null,'Line flushed and shock-chlorinated — lab retest sample sent'),
    ('UGS-BLR-04','sump_seepage_ingress','repair_sump_lining','open',38000.00,'Facilities - Bengaluru','2026-08-01',null,'Silt ingress via cracked lining — civil repair quote in review')
  ) as q(wp, rc, ca, cst, cost, own, tcd, acd, nt)
  join public.water_hygiene_r3690 e
    on e.organization_id = v_org_id and e.water_point = q.wp;
end;
$seed$;
