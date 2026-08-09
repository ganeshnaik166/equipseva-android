-- Round 3712: Founder Demo-Equipment Fleet / Prospect-Trial Board
-- Demo fleet ops — unit × model × placement class × days at prospect × trials completed/converted × utilization × condition × refurb flag × book value × fleet status × CAPA

-- =============================================================================
-- TABLE 1: demo_fleet_r3712 — per-demo-unit placement & trial-conversion facts
-- =============================================================================
create table if not exists public.demo_fleet_r3712 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  demo_unit_code text not null,
  equipment_model text not null,
  period_month date not null,
  current_location text not null,
  days_at_prospect int not null,
  trials_completed int not null,
  trials_converted int not null,
  conversion_pct numeric(5,1),
  utilization_pct numeric(5,1),
  condition_score numeric(4,1),
  refurb_needed boolean not null default false,
  book_value_rupees numeric(12,2),
  placement_class text not null check (placement_class in (
    'hospital_trial','exhibition_demo','training_unit','showroom','in_transit'
  )),
  fleet_status text not null check (fleet_status in (
    'deployed_active','available','idle_too_long','maintenance_due','write_down_candidate'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.demo_fleet_r3712 enable row level security;

create index if not exists idx_demo_fleet_r3712_org on public.demo_fleet_r3712(organization_id);
create index if not exists idx_demo_fleet_r3712_month on public.demo_fleet_r3712(period_month);
create index if not exists idx_demo_fleet_r3712_status on public.demo_fleet_r3712(fleet_status);

-- =============================================================================
-- TABLE 2: demo_fleet_capa_actions_r3712 — CAPA / recovery actions on fleet units
-- =============================================================================
create table if not exists public.demo_fleet_capa_actions_r3712 (
  id uuid primary key default gen_random_uuid(),
  demo_unit_id uuid not null references public.demo_fleet_r3712(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'prolonged_idle_placement','poor_prospect_qualification','unit_condition_degraded',
    'logistics_delay','missing_demo_kit_accessories','pricing_objection_unresolved',
    'rep_followup_lapse','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'recall_and_redeploy','refurbish_unit','replace_accessories','retrain_sales_rep',
    'tighten_trial_agreement','offer_buyback_conversion','write_down_and_dispose','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  book_value_at_risk_rupees numeric(12,2),
  owner_rep text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.demo_fleet_capa_actions_r3712 enable row level security;

create index if not exists idx_demo_fleet_capa_r3712_unit on public.demo_fleet_capa_actions_r3712(demo_unit_id);
create index if not exists idx_demo_fleet_capa_r3712_status on public.demo_fleet_capa_actions_r3712(capa_status);

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

  -- 16 demo-fleet unit rows
  insert into public.demo_fleet_r3712 (
    organization_id, demo_unit_code, equipment_model, period_month, current_location,
    days_at_prospect, trials_completed, trials_converted, conversion_pct, utilization_pct,
    condition_score, refurb_needed, book_value_rupees, placement_class, fleet_status,
    trend_dir, notes
  )
  select v_org_id, q.ucode, q.emodel, q.pmon::date, q.loc,
    q.dpros, q.tcomp, q.tconv, q.convp, q.utilp,
    q.cond, q.refurb, q.bval, q.pclass, q.fstat,
    q.tdir, q.nt
  from (values
    ('DEMO-VENT-01','VentMax S5','2026-07-01','Apollo Chennai ICU',
     34,3,2,66.7,82.0,8.6,false,1450000.00,'hospital_trial','deployed_active','improving','Trial converting well — PO expected from Apollo Chennai'),
    ('DEMO-VENT-02','VentMax S5','2026-07-01','Fortis Mulund Mumbai',
     58,2,0,0.0,61.0,7.9,false,1420000.00,'hospital_trial','idle_too_long','worsening','58 days at prospect with no conversion — pull-back review due'),
    ('DEMO-HFNC-01','OxyFlow HFNC-2','2026-07-01','Manipal Bengaluru NICU',
     21,2,1,50.0,74.5,9.1,false,380000.00,'hospital_trial','deployed_active','stable','HFNC trial in NICU — clinician feedback positive'),
    ('DEMO-ECG-01','CardioScan 12L ECG','2026-07-01','Medica Expo Delhi booth',
     6,4,1,25.0,55.0,8.8,false,240000.00,'exhibition_demo','deployed_active','stable','Expo demo unit — 4 leads captured, 1 converted on the spot'),
    ('DEMO-INCU-01','NeoWarm Incubator','2026-07-01','Rainbow Children Hyderabad',
     44,1,0,0.0,48.0,6.4,true,690000.00,'hospital_trial','maintenance_due','worsening','Hood latch worn during trial — service visit scheduled'),
    ('DEMO-USG-01','SonoView Portable USG','2026-07-01','Bengaluru showroom',
     12,5,3,60.0,68.0,9.4,false,860000.00,'showroom','deployed_active','improving','Showroom walk-in demos converting strongly'),
    ('DEMO-PUMP-01','InfuSafe Pump Duo','2026-07-01','KIMS Hyderabad wards',
     29,3,2,66.7,77.0,8.2,false,155000.00,'hospital_trial','deployed_active','stable','Ward trial across 3 units — 2 POs raised'),
    ('DEMO-USG-02','SonoView Portable USG','2026-07-01','In transit Chennai to Pune',
     4,0,0,0.0,0.0,8.9,false,845000.00,'in_transit','available','stable','Reallocated from Chennai trial to Pune prospect'),
    ('DEMO-VENT-03','VentMax S5','2026-06-01','Sales training centre Mumbai',
     90,0,0,0.0,35.0,7.1,false,1380000.00,'training_unit','idle_too_long','worsening','Training unit 90 days without prospect placement'),
    ('DEMO-HFNC-02','OxyFlow HFNC-2','2026-06-01','AIIMS Delhi trauma ICU',
     26,2,1,50.0,71.0,8.5,false,372000.00,'hospital_trial','deployed_active','improving','Trauma-ICU trial ongoing — second unit requested'),
    ('DEMO-ECG-02','CardioScan 12L ECG','2026-06-01','Lilavati Mumbai OPD',
     63,1,0,0.0,42.0,5.8,true,210000.00,'hospital_trial','write_down_candidate','worsening','Cracked casing plus 63 idle days — write-down assessment'),
    ('DEMO-INCU-02','NeoWarm Incubator','2026-06-01','Cloudnine Bengaluru',
     18,2,2,100.0,88.0,9.2,false,705000.00,'hospital_trial','deployed_active','improving','Both trials converted — flagship NICU reference site'),
    ('DEMO-PUMP-02','InfuSafe Pump Duo','2026-06-01','Chennai showroom',
     37,2,0,0.0,30.0,7.6,false,148000.00,'showroom','available','stable','Returned from trial — awaiting next placement'),
    ('DEMO-USG-03','SonoView Portable USG','2026-05-01','MedTech Expo Chennai',
     9,6,2,33.3,64.0,8.0,false,830000.00,'exhibition_demo','deployed_active','stable','Expo circuit unit — strong lead capture'),
    ('DEMO-ECG-03','CardioScan 12L ECG','2026-05-01','Ruby Hall Pune cardiology',
     48,2,1,50.0,58.0,6.9,true,205000.00,'hospital_trial','maintenance_due','stable','Lead-set wear — refurb before next placement'),
    ('DEMO-PUMP-03','InfuSafe Pump Duo','2026-05-01','Delhi warehouse',
     110,0,0,0.0,12.0,6.1,true,142000.00,'training_unit','write_down_candidate','worsening','110 idle days, battery degraded — candidate for write-down')
  ) as q(ucode, emodel, pmon, loc, dpros, tcomp, tconv, convp, utilp, cond, refurb, bval, pclass, fstat, tdir, nt);

  -- CAPA seed — attach to specific units via demo_unit_code
  insert into public.demo_fleet_capa_actions_r3712 (
    demo_unit_id, root_cause, corrective_action, capa_status,
    book_value_at_risk_rupees, owner_rep, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.bvr, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('DEMO-VENT-02','poor_prospect_qualification','tighten_trial_agreement','in_progress',1420000.00,'Rohan Kulkarni','2026-08-20',null,'Trial extension only with signed conversion-intent letter'),
    ('DEMO-INCU-01','unit_condition_degraded','refurbish_unit','open',690000.00,'Sneha Iyer','2026-08-25',null,'Hood latch and skin-probe kit refurb before redeploy'),
    ('DEMO-VENT-03','prolonged_idle_placement','recall_and_redeploy','escalated',1380000.00,'Amit Sharma','2026-08-12',null,'90-day idle training unit — escalated to national sales head'),
    ('DEMO-ECG-02','unit_condition_degraded','write_down_and_dispose','verification_pending',210000.00,'Priya Nair','2026-08-18',null,'Write-down memo raised — finance verification pending'),
    ('DEMO-PUMP-03','prolonged_idle_placement','offer_buyback_conversion','overdue',142000.00,'Vikram Reddy','2026-07-30',null,'Discounted buyback offer to last trial prospect — past target date'),
    ('DEMO-ECG-03','missing_demo_kit_accessories','replace_accessories','closed',205000.00,'Kavitha Krishnan','2026-08-05','2026-08-02','Lead set and carry case replaced — unit back in pool'),
    ('DEMO-PUMP-02','rep_followup_lapse','retrain_sales_rep','in_progress',148000.00,'Arjun Mehta','2026-08-15',null,'Rep coached on 7-day trial follow-up cadence'),
    ('DEMO-USG-02','logistics_delay','recall_and_redeploy','open',845000.00,'Rohan Kulkarni','2026-08-14',null,'Transit delayed at Pune hub — courier escalation raised')
  ) as q(ucode, rc, ca, cst, bvr, ownr, tcd, acd, nt)
  join public.demo_fleet_r3712 e
    on e.organization_id = v_org_id and e.demo_unit_code = q.ucode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Fleet status distribution
create or replace function public.founder_r3712_fleet_status_rollup()
returns table(fleet_status text, units bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.demo_fleet_r3712)
  select l.fleet_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.demo_fleet_r3712 l
  group by l.fleet_status
  order by count(*) desc;
end;
$$;

-- 2) Equipment-model scorecard
create or replace function public.founder_r3712_equipment_model_scorecard()
returns table(
  equipment_model text,
  total_units bigint,
  deployed_active bigint,
  idle_units bigint,
  refurb_flagged bigint,
  avg_conversion_pct numeric,
  avg_utilization_pct numeric,
  avg_condition_score numeric,
  total_book_value_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_model,
    count(*)::bigint,
    count(*) filter (where l.fleet_status = 'deployed_active')::bigint,
    count(*) filter (where l.fleet_status in ('idle_too_long','available'))::bigint,
    count(*) filter (where l.refurb_needed = true)::bigint,
    round(avg(l.conversion_pct), 1),
    round(avg(l.utilization_pct), 1),
    round(avg(l.condition_score), 1),
    coalesce(sum(l.book_value_rupees),0)::numeric
  from public.demo_fleet_r3712 l
  group by l.equipment_model
  order by count(*) desc;
end;
$$;

-- 3) Placement-class × fleet-status matrix
create or replace function public.founder_r3712_placement_status_matrix()
returns table(placement_class text, fleet_status text, units bigint, avg_days_at_prospect numeric, total_book_value_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.placement_class, l.fleet_status, count(*)::bigint,
    round(avg(l.days_at_prospect)::numeric, 1),
    coalesce(sum(l.book_value_rupees),0)::numeric
  from public.demo_fleet_r3712 l
  group by l.placement_class, l.fleet_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly trial-conversion trend
create or replace function public.founder_r3712_monthly_conversion_trend()
returns table(period_month date, units bigint, trials_completed bigint, trials_converted bigint, conversion_pct numeric, avg_utilization_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.trials_completed),0)::bigint,
    coalesce(sum(l.trials_converted),0)::bigint,
    round(100.0 * coalesce(sum(l.trials_converted),0)::numeric / nullif(coalesce(sum(l.trials_completed),0),0), 1),
    round(avg(l.utilization_pct), 1)
  from public.demo_fleet_r3712 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3712_capa_status_board()
returns table(capa_status text, actions bigint, avg_value_at_risk_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.book_value_at_risk_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.demo_fleet_capa_actions_r3712 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3712_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_value_at_risk_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.demo_fleet_capa_actions_r3712)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.book_value_at_risk_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.demo_fleet_capa_actions_r3712 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Idle-unit digest
create or replace function public.founder_r3712_idle_unit_digest()
returns table(
  demo_unit_code text,
  equipment_model text,
  current_location text,
  days_at_prospect int,
  utilization_pct numeric,
  fleet_status text,
  book_value_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.demo_unit_code, l.equipment_model, l.current_location, l.days_at_prospect,
    l.utilization_pct, l.fleet_status, l.book_value_rupees, l.notes
  from public.demo_fleet_r3712 l
  where l.fleet_status in ('idle_too_long','available')
     or l.days_at_prospect > 45
     or l.utilization_pct < 40
  order by l.days_at_prospect desc, l.demo_unit_code;
end;
$$;

-- 8) High-risk fleet queue (write-down candidates & long-idle units)
create or replace function public.founder_r3712_high_risk_queue()
returns table(
  demo_unit_code text,
  equipment_model text,
  current_location text,
  period_month date,
  placement_class text,
  fleet_status text,
  condition_score numeric,
  refurb_needed boolean,
  book_value_rupees numeric,
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
  select l.demo_unit_code, l.equipment_model, l.current_location, l.period_month,
    l.placement_class, l.fleet_status, l.condition_score, l.refurb_needed,
    l.book_value_rupees, l.trend_dir, l.notes
  from public.demo_fleet_r3712 l
  where l.fleet_status in ('write_down_candidate','idle_too_long','maintenance_due')
     or l.refurb_needed = true
     or l.condition_score < 7.0
     or l.trend_dir = 'worsening'
  order by l.book_value_rupees desc nulls last, l.demo_unit_code;
end;
$$;

-- =============================================================================
-- GRANTS
-- =============================================================================
revoke all on function public.founder_r3712_fleet_status_rollup() from public, anon;
revoke all on function public.founder_r3712_equipment_model_scorecard() from public, anon;
revoke all on function public.founder_r3712_placement_status_matrix() from public, anon;
revoke all on function public.founder_r3712_monthly_conversion_trend() from public, anon;
revoke all on function public.founder_r3712_capa_status_board() from public, anon;
revoke all on function public.founder_r3712_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3712_idle_unit_digest() from public, anon;
revoke all on function public.founder_r3712_high_risk_queue() from public, anon;

grant execute on function public.founder_r3712_fleet_status_rollup() to authenticated;
grant execute on function public.founder_r3712_equipment_model_scorecard() to authenticated;
grant execute on function public.founder_r3712_placement_status_matrix() to authenticated;
grant execute on function public.founder_r3712_monthly_conversion_trend() to authenticated;
grant execute on function public.founder_r3712_capa_status_board() to authenticated;
grant execute on function public.founder_r3712_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3712_idle_unit_digest() to authenticated;
grant execute on function public.founder_r3712_high_risk_queue() to authenticated;
