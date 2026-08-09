-- Round 3685: Own-Fleet Vehicle Statutory-Compliance Board
-- Own service-van/vehicle statutory documents — insurance × PUC × fitness × permit × road tax × challans × CAPA

-- =============================================================================
-- TABLE 1: fleet_statutory_r3685 — per-vehicle monthly statutory-document snapshot
-- =============================================================================
create table if not exists public.fleet_statutory_r3685 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  vehicle_reg_no text not null,
  home_region text not null,
  period_month date not null,
  insurance_expiry date,
  puc_expiry date,
  fitness_expiry date,
  permit_expiry date,
  road_tax_paid_till date,
  nearest_expiry_days int,
  docs_current_pct numeric(5,2),
  open_challans int not null default 0,
  challan_amount_rupees numeric(12,2) not null default 0,
  vehicle_class text not null check (vehicle_class in (
    'service_van','delivery_truck','two_wheeler','car_pool','forklift_registered'
  )),
  compliance_status text not null check (compliance_status in (
    'all_current','renewal_due','doc_lapsed','challan_pending','off_road_risk'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fleet_statutory_r3685 enable row level security;

create index if not exists idx_fleet_statutory_r3685_org on public.fleet_statutory_r3685(organization_id);
create index if not exists idx_fleet_statutory_r3685_month on public.fleet_statutory_r3685(period_month);
create index if not exists idx_fleet_statutory_r3685_status on public.fleet_statutory_r3685(compliance_status);

-- =============================================================================
-- TABLE 2: fleet_statutory_capa_actions_r3685 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.fleet_statutory_capa_actions_r3685 (
  id uuid primary key default gen_random_uuid(),
  vehicle_log_id uuid not null references public.fleet_statutory_r3685(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'insurance_lapsed','puc_lapsed','fitness_expired','permit_expired',
    'road_tax_overdue','challan_backlog','renewal_window_missed','document_missing_in_vehicle'
  )),
  root_cause text not null check (root_cause in (
    'renewal_reminder_missed','agent_delay','budget_hold','rto_backlog',
    'driver_unaware','vendor_policy_dispute','challan_contest_pending','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'renew_insurance_policy','book_puc_test','schedule_fitness_test','apply_permit_renewal',
    'pay_road_tax','pay_and_close_challans','contest_challan_in_court',
    'ground_vehicle_till_compliant','setup_renewal_tracker','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  exposure_amount_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fleet_statutory_capa_actions_r3685 enable row level security;

create index if not exists idx_fleet_statutory_capa_r3685_log on public.fleet_statutory_capa_actions_r3685(vehicle_log_id);
create index if not exists idx_fleet_statutory_capa_r3685_status on public.fleet_statutory_capa_actions_r3685(capa_status);

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

  -- 16 vehicle statutory snapshot rows
  insert into public.fleet_statutory_r3685 (
    organization_id, vehicle_reg_no, home_region, period_month,
    insurance_expiry, puc_expiry, fitness_expiry, permit_expiry, road_tax_paid_till,
    nearest_expiry_days, docs_current_pct, open_challans, challan_amount_rupees,
    vehicle_class, compliance_status, trend_dir, notes
  )
  select v_org_id, q.reg, q.region, q.pm::date,
    q.ins::date, q.puc::date, q.fit::date, q.perm::date, q.rtax::date,
    q.ned, q.dcp, q.oc, q.camt,
    q.vcls, q.cst, q.tdir, q.nt
  from (values
    ('MH01AB1234','Mumbai HQ','2026-07-01',
     '2027-03-14','2026-11-20','2028-01-10','2027-06-30','2027-03-31',
     104,100.00,0,0,'service_van','all_current','stable','All five documents current — next action PUC in Nov'),
    ('MH01CD5678','Mumbai HQ','2026-07-01',
     '2027-01-22','2026-08-18','2027-09-15','2027-02-28','2027-03-31',
     10,100.00,0,0,'service_van','renewal_due','worsening','PUC expires in 10 days — renewal window missed once already'),
    ('MH02EF9012','Mumbai HQ','2026-07-01',
     '2026-12-05','2026-10-11','2027-04-20','2026-11-30','2026-12-31',
     64,100.00,3,4700,'delivery_truck','challan_pending','worsening','3 e-challans pending — 2 speed camera, 1 no-parking at Andheri'),
    ('MH01GH3456','Mumbai HQ','2026-07-01',
     '2027-05-09','2026-12-02','2029-03-18','2028-01-15','2028-03-31',
     116,100.00,0,0,'two_wheeler','all_current','stable','Courier two-wheeler fully compliant'),
    ('MH01JK7890','Mumbai HQ','2026-07-01',
     '2026-07-28','2026-09-14','2027-08-05','2027-01-20','2026-12-31',
     -12,80.00,0,0,'car_pool','doc_lapsed','worsening','Insurance lapsed 28-Jul — vehicle held at HQ pending renewal'),
    ('TN09AB2345','Chennai Branch','2026-07-01',
     '2027-02-17','2026-10-25','2027-11-08','2027-04-12','2027-03-31',
     78,100.00,0,0,'service_van','all_current','improving','Renewed insurance early via new broker — clean record'),
    ('TN09CD6789','Chennai Branch','2026-07-01',
     '2026-11-30','2026-09-22','2026-09-02','2026-12-15','2026-12-31',
     24,100.00,0,0,'service_van','renewal_due','stable','Fitness test due 02-Sep — slot booked at Ambattur RTO'),
    ('TN10EF1122','Chennai Branch','2026-07-01',
     '2026-10-19','2026-08-30','2026-07-14','2026-06-30','2026-09-30',
     -25,60.00,0,0,'delivery_truck','off_road_risk','worsening','Fitness and permit both lapsed — truck grounded at branch yard'),
    ('TN09GH3344','Chennai Branch','2026-07-01',
     '2027-01-11','2026-11-05','2028-06-22','2027-05-31','2027-03-31',
     87,100.00,1,500,'two_wheeler','challan_pending','stable','One helmet-cam challan under contest'),
    ('DL01AB4455','Delhi Warehouse','2026-06-01',
     '2027-04-02','2026-12-18','2027-10-30','2027-03-25','2027-03-31',
     122,100.00,0,0,'delivery_truck','all_current','stable','Warehouse shuttle truck fully compliant'),
    ('DL01CD5566','Delhi Warehouse','2026-06-01',
     '2026-12-14','2026-06-20','2027-07-19','2027-02-10','2026-12-31',
     -18,80.00,0,0,'service_van','doc_lapsed','stable','PUC lapsed 20-Jun — agent booked, test pending'),
    ('DL01EF6677','Delhi Warehouse','2026-06-01',
     '2027-03-08',null,'2027-05-27',null,'2026-08-31',
     22,100.00,0,0,'forklift_registered','renewal_due','stable','Registered forklift — road tax paid only till 31-Aug'),
    ('DL01GH7788','Delhi Warehouse','2026-06-01',
     '2027-06-15','2026-11-28','2028-02-14','2027-08-31','2027-03-31',
     101,100.00,0,0,'car_pool','all_current','improving','Staff car-pool sedan — all documents digitised in vault'),
    ('KA05AB8899','Bengaluru Refurb Center','2026-06-01',
     '2026-08-25','2026-10-07','2027-12-03','2027-01-18','2026-12-31',
     17,100.00,0,0,'service_van','renewal_due','stable','Insurance renewal quote received — approval in finance queue'),
    ('KA05CD9900','Bengaluru Refurb Center','2026-06-01',
     '2026-09-10','2026-07-05','2026-11-26','2026-05-31','2026-09-30',
     -36,60.00,2,11500,'delivery_truck','off_road_risk','worsening','Permit lapsed May, PUC lapsed Jul, 2 overloading challans — grounded'),
    ('KA05EF1010','Bengaluru Refurb Center','2026-06-01',
     '2027-02-28','2026-12-09','2029-01-07','2028-04-30','2028-03-31',
     134,100.00,0,0,'two_wheeler','all_current','stable','Spares-runner two-wheeler fully compliant')
  ) as q(reg, region, pm, ins, puc, fit, perm, rtax, ned, dcp, oc, camt, vcls, cst, tdir, nt);

  -- CAPA seed — attach to specific vehicles via vehicle_reg_no
  insert into public.fleet_statutory_capa_actions_r3685 (
    vehicle_log_id, finding_category, root_cause, corrective_action,
    capa_status, exposure_amount_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.amt, q.own,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('MH01JK7890','insurance_lapsed','renewal_reminder_missed','renew_insurance_policy','in_progress',18500.00,'Fleet Admin — Mumbai HQ','2026-08-14',null,'Comprehensive policy quote approved — payment in process'),
    ('MH02EF9012','challan_backlog','driver_unaware','pay_and_close_challans','open',4700.00,'Regional Ops — Mumbai','2026-08-20',null,'Driver counselled; challans queued on Parivahan portal'),
    ('TN10EF1122','fitness_expired','rto_backlog','ground_vehicle_till_compliant','escalated',42000.00,'Branch Manager — Chennai','2026-08-12',null,'RTO fitness slot backlog 3 weeks — escalated to state transport agent'),
    ('TN09GH3344','challan_backlog','challan_contest_pending','contest_challan_in_court','verification_pending',500.00,'Fleet Admin — Chennai','2026-08-25',null,'Helmet-cam challan contested with rider footage — awaiting lok adalat date'),
    ('DL01CD5566','puc_lapsed','agent_delay','book_puc_test','closed',350.00,'Warehouse Ops — Delhi','2026-08-05','2026-08-02','PUC test done at authorised centre — certificate uploaded to vault'),
    ('DL01EF6677','road_tax_overdue','budget_hold','pay_road_tax','open',26000.00,'Finance — Delhi Warehouse','2026-08-28',null,'Annual road tax for registered forklift held in Q2 budget freeze — released'),
    ('KA05CD9900','permit_expired','vendor_policy_dispute','apply_permit_renewal','overdue',15800.00,'Refurb Center Lead — Bengaluru','2026-08-01',null,'Permit agent dispute over goods-carriage category — past target date'),
    ('MH01CD5678','renewal_window_missed','renewal_reminder_missed','setup_renewal_tracker','in_progress',0.00,'Fleet Admin — Mumbai HQ','2026-08-18',null,'60/30/7-day expiry alerts being configured for entire Mumbai fleet')
  ) as q(reg, fc, rc, ca, cst, amt, own, tcd, acd, nt)
  join public.fleet_statutory_r3685 e
    on e.organization_id = v_org_id and e.vehicle_reg_no = q.reg;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance status distribution
create or replace function public.founder_r3685_compliance_status_rollup()
returns table(compliance_status text, vehicles bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fleet_statutory_r3685)
  select l.compliance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.fleet_statutory_r3685 l
  group by l.compliance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3685_compliance_status_rollup() from public, anon;
grant execute on function public.founder_r3685_compliance_status_rollup() to authenticated;

-- 2) Region-level compliance scorecard
create or replace function public.founder_r3685_region_scorecard()
returns table(
  home_region text,
  total_vehicles bigint,
  fully_current bigint,
  renewal_due bigint,
  lapsed_or_off_road bigint,
  challan_pending bigint,
  total_open_challans bigint,
  total_challan_amount_rupees numeric,
  avg_docs_current_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.home_region,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'all_current')::bigint,
    count(*) filter (where l.compliance_status = 'renewal_due')::bigint,
    count(*) filter (where l.compliance_status in ('doc_lapsed','off_road_risk'))::bigint,
    count(*) filter (where l.compliance_status = 'challan_pending')::bigint,
    coalesce(sum(l.open_challans),0)::bigint,
    coalesce(sum(l.challan_amount_rupees),0)::numeric,
    round(avg(l.docs_current_pct), 1)
  from public.fleet_statutory_r3685 l
  group by l.home_region
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3685_region_scorecard() from public, anon;
grant execute on function public.founder_r3685_region_scorecard() to authenticated;

-- 3) Vehicle class × compliance status matrix
create or replace function public.founder_r3685_class_status_matrix()
returns table(vehicle_class text, compliance_status text, vehicles bigint, avg_docs_current_pct numeric, total_challan_amount_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.vehicle_class, l.compliance_status, count(*)::bigint,
    round(avg(l.docs_current_pct), 1),
    coalesce(sum(l.challan_amount_rupees),0)::numeric
  from public.fleet_statutory_r3685 l
  group by l.vehicle_class, l.compliance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3685_class_status_matrix() from public, anon;
grant execute on function public.founder_r3685_class_status_matrix() to authenticated;

-- 4) Monthly expiry trend
create or replace function public.founder_r3685_monthly_expiry_trend()
returns table(period_month date, vehicles bigint, renewal_due bigint, doc_lapsed bigint, off_road_risk bigint, avg_nearest_expiry_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'renewal_due')::bigint,
    count(*) filter (where l.compliance_status = 'doc_lapsed')::bigint,
    count(*) filter (where l.compliance_status = 'off_road_risk')::bigint,
    round(avg(l.nearest_expiry_days), 1)
  from public.fleet_statutory_r3685 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3685_monthly_expiry_trend() from public, anon;
grant execute on function public.founder_r3685_monthly_expiry_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3685_capa_status_board()
returns table(capa_status text, actions bigint, avg_exposure_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.exposure_amount_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.fleet_statutory_capa_actions_r3685 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3685_capa_status_board() from public, anon;
grant execute on function public.founder_r3685_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3685_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_exposure_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fleet_statutory_capa_actions_r3685)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.exposure_amount_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.fleet_statutory_capa_actions_r3685 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3685_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3685_root_cause_pareto() to authenticated;

-- 7) Challan exposure digest by vehicle class
create or replace function public.founder_r3685_challan_exposure_digest()
returns table(
  vehicle_class text,
  vehicles bigint,
  vehicles_with_challans bigint,
  total_open_challans bigint,
  total_challan_amount_rupees numeric,
  max_single_vehicle_amount_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.vehicle_class, count(*)::bigint,
    count(*) filter (where l.open_challans > 0)::bigint,
    coalesce(sum(l.open_challans),0)::bigint,
    coalesce(sum(l.challan_amount_rupees),0)::numeric,
    coalesce(max(l.challan_amount_rupees),0)::numeric
  from public.fleet_statutory_r3685 l
  group by l.vehicle_class
  order by coalesce(sum(l.challan_amount_rupees),0) desc;
end;
$$;

revoke all on function public.founder_r3685_challan_exposure_digest() from public, anon;
grant execute on function public.founder_r3685_challan_exposure_digest() to authenticated;

-- 8) High-risk vehicle queue (off-road risk / lapsed docs / challans / imminent expiry)
create or replace function public.founder_r3685_high_risk_queue()
returns table(
  vehicle_reg_no text,
  home_region text,
  vehicle_class text,
  period_month date,
  compliance_status text,
  nearest_expiry_days int,
  open_challans int,
  challan_amount_rupees numeric,
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
  select l.vehicle_reg_no, l.home_region, l.vehicle_class, l.period_month,
    l.compliance_status, l.nearest_expiry_days, l.open_challans,
    l.challan_amount_rupees, l.trend_dir, l.notes
  from public.fleet_statutory_r3685 l
  where l.compliance_status in ('off_road_risk','doc_lapsed','challan_pending')
     or l.nearest_expiry_days <= 15
     or l.open_challans > 0
     or l.trend_dir = 'worsening'
  order by l.nearest_expiry_days asc, l.challan_amount_rupees desc;
end;
$$;

revoke all on function public.founder_r3685_high_risk_queue() from public, anon;
grant execute on function public.founder_r3685_high_risk_queue() to authenticated;
