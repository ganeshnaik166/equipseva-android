-- Round 3684: Own-Warehouse GDP Temperature / Humidity Storage-Compliance Board
-- OWN spare-parts/device warehouse GDP storage-condition compliance — temp/humidity mapping, logger calibration, excursion handling × CAPA

-- =============================================================================
-- TABLE 1: warehouse_gdp_r3684 — per-zone monthly GDP storage-condition record
-- =============================================================================
create table if not exists public.warehouse_gdp_r3684 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  warehouse_name text not null,
  zone_code text not null,
  storage_zone text not null,
  period_month date not null,
  target_temp_range text not null,
  avg_temp_c numeric(5,2),
  temp_excursions int not null default 0,
  excursion_minutes int not null default 0,
  avg_humidity_pct numeric(5,2),
  loggers_deployed int not null,
  loggers_calibrated_pct numeric(5,2),
  mapping_study_current boolean not null,
  quarantine_events int not null default 0,
  zone_class text not null check (zone_class in (
    'ambient_general','controlled_15_25','cold_2_8','dehumidified','flammable_store'
  )),
  gdp_status text not null check (gdp_status in (
    'compliant','excursion_managed','mapping_due','logger_gap','non_compliant'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.warehouse_gdp_r3684 enable row level security;

create index if not exists idx_warehouse_gdp_r3684_org on public.warehouse_gdp_r3684(organization_id);
create index if not exists idx_warehouse_gdp_r3684_month on public.warehouse_gdp_r3684(period_month);
create index if not exists idx_warehouse_gdp_r3684_status on public.warehouse_gdp_r3684(gdp_status);

-- =============================================================================
-- TABLE 2: warehouse_gdp_capa_actions_r3684 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.warehouse_gdp_capa_actions_r3684 (
  id uuid primary key default gen_random_uuid(),
  gdp_record_id uuid not null references public.warehouse_gdp_r3684(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'hvac_ahu_failure','roof_insulation_degraded','logger_calibration_lapse',
    'door_left_open_loading','compressor_breakdown','mapping_study_expired',
    'power_outage_dg_delay','dehumidifier_undersized','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'repair_hvac_ahu','recalibrate_loggers','replace_logger_fleet',
    'requalify_mapping_study','install_door_interlock_alarm','service_compressor',
    'add_dehumidifier_capacity','improve_roof_insulation','retrain_warehouse_staff','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  stock_value_at_risk_rupees numeric(12,2),
  capa_owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.warehouse_gdp_capa_actions_r3684 enable row level security;

create index if not exists idx_warehouse_gdp_capa_r3684_rec on public.warehouse_gdp_capa_actions_r3684(gdp_record_id);
create index if not exists idx_warehouse_gdp_capa_r3684_status on public.warehouse_gdp_capa_actions_r3684(capa_status);

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

  -- 16 zone-month GDP records
  insert into public.warehouse_gdp_r3684 (
    organization_id, warehouse_name, zone_code, storage_zone, period_month,
    target_temp_range, avg_temp_c, temp_excursions, excursion_minutes, avg_humidity_pct,
    loggers_deployed, loggers_calibrated_pct, mapping_study_current, quarantine_events,
    zone_class, gdp_status, trend_dir, notes
  )
  select v_org_id, q.wh, q.zcode, q.szone, q.pmon::date,
    q.trange, q.avgt, q.exc, q.excmin, q.avgh,
    q.lgd, q.lgc, q.mapc, q.qevt,
    q.zcls, q.gst, q.tdir, q.nt
  from (values
    ('Mumbai HQ Warehouse','MUM-AMB-01','Ambient racking hall A','2026-07-01',
     '15-30 C',26.8,0,0,58.4,12,100.0,true,0,'ambient_general','compliant','stable',
     'Ambient hall within band all month; monsoon RH watched'),
    ('Mumbai HQ Warehouse','MUM-CTRL-02','Controlled store mezzanine','2026-07-01',
     '15-25 C',23.9,3,145,55.0,8,100.0,true,0,'controlled_15_25','excursion_managed','improving',
     'Monsoon-linked spikes; AHU chilled-water valve replaced mid-month'),
    ('Mumbai HQ Warehouse','MUM-COLD-03','Cold room reagents & batteries','2026-07-01',
     '2-8 C',5.6,1,35,45.2,6,83.3,true,1,'cold_2_8','logger_gap','worsening',
     'One cold-room logger past calibration due date; sent to NABL lab'),
    ('Mumbai HQ Warehouse','MUM-FLAM-04','Flammable solvent cage','2026-07-01',
     '15-30 C',27.2,0,0,52.1,4,100.0,true,0,'flammable_store','compliant','stable',
     'Solvent cage stable; ventilation logs clean'),
    ('Chennai Branch Warehouse','CHE-AMB-01','Ambient spares bay','2026-07-01',
     '15-30 C',29.1,6,420,68.5,10,90.0,false,1,'ambient_general','non_compliant','worsening',
     'Roof insulation degraded; afternoon peaks above 30 C, one lot quarantined'),
    ('Chennai Branch Warehouse','CHE-CTRL-02','Controlled consumables room','2026-07-01',
     '15-25 C',24.6,2,90,60.2,6,100.0,true,0,'controlled_15_25','excursion_managed','stable',
     'Two brief excursions during dock-door loading windows'),
    ('Chennai Branch Warehouse','CHE-DHM-03','Dehumidified electronics store','2026-07-01',
     '15-25 C / RH<40',22.8,0,0,38.9,5,100.0,false,0,'dehumidified','mapping_due','stable',
     'Mapping study lapsed in June; requalification scheduled with vendor'),
    ('Delhi Warehouse','DEL-AMB-01','Ambient bulk racking','2026-07-01',
     '15-30 C',28.4,4,260,41.3,14,92.9,true,0,'ambient_general','excursion_managed','improving',
     'Dock-door interlock alarm installed; excursion minutes dropping'),
    ('Delhi Warehouse','DEL-COLD-02','Cold chain staging room','2026-07-01',
     '2-8 C',6.9,5,310,48.0,8,75.0,true,2,'cold_2_8','non_compliant','worsening',
     'Compressor trips twice; two consignments quarantined pending QA disposition'),
    ('Delhi Warehouse','DEL-DHM-03','Dehumidified sensor store','2026-07-01',
     'RH<40',24.1,0,0,36.7,4,100.0,true,0,'dehumidified','compliant','improving',
     'New dehumidifier holding RH under 38 percent'),
    ('Bengaluru Refurb Center','BLR-AMB-01','Ambient refurb staging','2026-07-01',
     '15-30 C',24.3,0,0,54.6,9,88.9,true,0,'ambient_general','logger_gap','stable',
     'One logger awaiting NABL calibration slot; spare deployed uncalibrated'),
    ('Bengaluru Refurb Center','BLR-CTRL-02','Controlled QC hold room','2026-07-01',
     '15-25 C',22.1,1,40,51.0,6,100.0,true,1,'controlled_15_25','excursion_managed','stable',
     'Single short excursion during power changeover; DG pickup verified'),
    ('Bengaluru Refurb Center','BLR-FLAM-03','Flammable paint & IPA store','2026-07-01',
     '15-30 C',25.9,0,0,49.8,3,100.0,false,0,'flammable_store','mapping_due','worsening',
     'Flammable store mapping requalification past due; vendor slot delayed'),
    ('Mumbai HQ Warehouse','MUM-CTRL-02-JUN','Controlled store mezzanine','2026-06-01',
     '15-25 C',24.8,5,260,57.3,8,100.0,true,0,'controlled_15_25','excursion_managed','stable',
     'Pre-monsoon excursions before AHU valve replacement'),
    ('Chennai Branch Warehouse','CHE-AMB-01-JUN','Ambient spares bay','2026-06-01',
     '15-30 C',29.8,8,540,66.0,10,90.0,false,1,'ambient_general','non_compliant','worsening',
     'June heat load; roof insulation issue first flagged'),
    ('Delhi Warehouse','DEL-COLD-02-JUN','Cold chain staging room','2026-06-01',
     '2-8 C',6.2,3,180,47.1,8,87.5,true,1,'cold_2_8','excursion_managed','stable',
     'Early compressor instability; service call raised end of June')
  ) as q(wh, zcode, szone, pmon, trange, avgt, exc, excmin, avgh, lgd, lgc, mapc, qevt, zcls, gst, tdir, nt);

  -- CAPA seed — attach to specific zone records via zone_code
  insert into public.warehouse_gdp_capa_actions_r3684 (
    gdp_record_id, root_cause, corrective_action, capa_status,
    stock_value_at_risk_rupees, capa_owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.sval, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('CHE-AMB-01','roof_insulation_degraded','improve_roof_insulation','in_progress',
     1850000.00,'Suresh Menon','2026-08-20',null,'Roof-sheet insulation retrofit underway; PO released to contractor'),
    ('DEL-COLD-02','compressor_breakdown','service_compressor','escalated',
     2400000.00,'Priya Nair','2026-07-25',null,'Repeated compressor trips; OEM service escalated, quarantined stock pending QA disposition'),
    ('MUM-COLD-03','logger_calibration_lapse','recalibrate_loggers','open',
     320000.00,'Amit Deshpande','2026-08-12',null,'Cold-room logger sent to NABL lab; interim manual twice-daily reads'),
    ('CHE-DHM-03','mapping_study_expired','requalify_mapping_study','in_progress',
     540000.00,'Kavitha Raman','2026-08-30',null,'Temperature-RH mapping requalification scheduled with validation vendor'),
    ('BLR-AMB-01','logger_calibration_lapse','recalibrate_loggers','verification_pending',
     150000.00,'Rohit Kulkarni','2026-08-05',null,'Logger back from calibration; 7-day verification trend running'),
    ('BLR-FLAM-03','mapping_study_expired','requalify_mapping_study','overdue',
     210000.00,'Rohit Kulkarni','2026-07-31',null,'Flammable store mapping requal past target date; vendor slot delayed'),
    ('MUM-CTRL-02','hvac_ahu_failure','repair_hvac_ahu','closed',
     680000.00,'Amit Deshpande','2026-07-15','2026-07-11','AHU chilled-water valve replaced; excursions ceased post-fix'),
    ('DEL-AMB-01','door_left_open_loading','install_door_interlock_alarm','closed',
     95000.00,'Priya Nair','2026-07-10','2026-07-08','Dock-door interlock alarm installed; loading SOP retraining done')
  ) as q(zcode, rc, ca, cst, sval, ownr, tcd, acd, nt)
  join public.warehouse_gdp_r3684 e
    on e.organization_id = v_org_id and e.zone_code = q.zcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) GDP status distribution
create or replace function public.founder_r3684_gdp_status_rollup()
returns table(gdp_status text, zones bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.warehouse_gdp_r3684)
  select l.gdp_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.warehouse_gdp_r3684 l
  group by l.gdp_status
  order by count(*) desc;
end;
$$;

-- 2) Warehouse-level GDP scorecard
create or replace function public.founder_r3684_warehouse_scorecard()
returns table(
  warehouse_name text,
  zones bigint,
  compliant bigint,
  excursion_managed bigint,
  non_compliant bigint,
  total_excursions bigint,
  total_excursion_minutes bigint,
  quarantine_events bigint,
  avg_logger_cal_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.warehouse_name,
    count(*)::bigint,
    count(*) filter (where l.gdp_status = 'compliant')::bigint,
    count(*) filter (where l.gdp_status = 'excursion_managed')::bigint,
    count(*) filter (where l.gdp_status = 'non_compliant')::bigint,
    coalesce(sum(l.temp_excursions),0)::bigint,
    coalesce(sum(l.excursion_minutes),0)::bigint,
    coalesce(sum(l.quarantine_events),0)::bigint,
    round(avg(l.loggers_calibrated_pct), 1)
  from public.warehouse_gdp_r3684 l
  group by l.warehouse_name
  order by count(*) desc;
end;
$$;

-- 3) Zone-class × GDP-status matrix
create or replace function public.founder_r3684_zone_class_status_matrix()
returns table(zone_class text, gdp_status text, zones bigint, total_excursions bigint, avg_temp_c numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.zone_class, l.gdp_status, count(*)::bigint,
    coalesce(sum(l.temp_excursions),0)::bigint,
    round(avg(l.avg_temp_c), 2)
  from public.warehouse_gdp_r3684 l
  group by l.zone_class, l.gdp_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly excursion trend
create or replace function public.founder_r3684_monthly_excursion_trend()
returns table(period_month date, zones bigint, total_excursions bigint, total_excursion_minutes bigint, quarantine_events bigint, non_compliant bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.temp_excursions),0)::bigint,
    coalesce(sum(l.excursion_minutes),0)::bigint,
    coalesce(sum(l.quarantine_events),0)::bigint,
    count(*) filter (where l.gdp_status = 'non_compliant')::bigint
  from public.warehouse_gdp_r3684 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3684_capa_status_board()
returns table(capa_status text, actions bigint, avg_stock_value_at_risk_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.stock_value_at_risk_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.warehouse_gdp_capa_actions_r3684 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3684_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_stock_value_at_risk_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.warehouse_gdp_capa_actions_r3684)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.stock_value_at_risk_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.warehouse_gdp_capa_actions_r3684 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Excursion impact digest by zone class
create or replace function public.founder_r3684_excursion_impact_digest()
returns table(zone_class text, zones bigint, total_excursions bigint, total_excursion_minutes bigint, quarantine_events bigint, avg_humidity_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.zone_class, count(*)::bigint,
    coalesce(sum(l.temp_excursions),0)::bigint,
    coalesce(sum(l.excursion_minutes),0)::bigint,
    coalesce(sum(l.quarantine_events),0)::bigint,
    round(avg(l.avg_humidity_pct), 1)
  from public.warehouse_gdp_r3684 l
  group by l.zone_class
  order by coalesce(sum(l.excursion_minutes),0) desc;
end;
$$;

-- 8) High-risk zone queue
create or replace function public.founder_r3684_high_risk_queue()
returns table(
  warehouse_name text,
  zone_code text,
  storage_zone text,
  zone_class text,
  period_month date,
  gdp_status text,
  temp_excursions int,
  excursion_minutes int,
  loggers_calibrated_pct numeric,
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
  select l.warehouse_name, l.zone_code, l.storage_zone, l.zone_class, l.period_month,
    l.gdp_status, l.temp_excursions, l.excursion_minutes, l.loggers_calibrated_pct,
    l.trend_dir, l.notes
  from public.warehouse_gdp_r3684 l
  where l.gdp_status in ('non_compliant','logger_gap')
     or l.mapping_study_current = false
     or l.trend_dir = 'worsening'
     or l.quarantine_events > 0
  order by l.period_month desc, l.warehouse_name;
end;
$$;

revoke all on function public.founder_r3684_gdp_status_rollup() from public, anon;
revoke all on function public.founder_r3684_warehouse_scorecard() from public, anon;
revoke all on function public.founder_r3684_zone_class_status_matrix() from public, anon;
revoke all on function public.founder_r3684_monthly_excursion_trend() from public, anon;
revoke all on function public.founder_r3684_capa_status_board() from public, anon;
revoke all on function public.founder_r3684_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3684_excursion_impact_digest() from public, anon;
revoke all on function public.founder_r3684_high_risk_queue() from public, anon;

grant execute on function public.founder_r3684_gdp_status_rollup() to authenticated;
grant execute on function public.founder_r3684_warehouse_scorecard() to authenticated;
grant execute on function public.founder_r3684_zone_class_status_matrix() to authenticated;
grant execute on function public.founder_r3684_monthly_excursion_trend() to authenticated;
grant execute on function public.founder_r3684_capa_status_board() to authenticated;
grant execute on function public.founder_r3684_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3684_excursion_impact_digest() to authenticated;
grant execute on function public.founder_r3684_high_risk_queue() to authenticated;
