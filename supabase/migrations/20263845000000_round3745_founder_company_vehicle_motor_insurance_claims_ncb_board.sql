-- Round 3745: Founder Company Vehicle Motor-Insurance Claims & NCB Board
-- Company-owned fleet vehicle motor-insurance policies, claims, and no-claim-bonus (NCB)
-- tracking per vehicle — renewal, claims filed, IDV vs claim settlement, NCB erosion.
-- Distinct from any D&O insurance board, any insurance-broker-performance-scorecard page,
-- and any engineer-vehicle-fuel-log page, which is fuel not insurance.

-- =============================================================================
-- TABLE 1: motor_insurance_r3745 — per-vehicle motor-insurance policy/claim facts
-- =============================================================================
create table if not exists public.motor_insurance_r3745 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  vehicle_registration text not null,
  vehicle_type text not null,
  period_month date not null,
  policy_number text,
  policy_renewal_date date,
  idv_rupees numeric(12,2),
  premium_rupees numeric(10,2),
  claims_filed int,
  claim_amount_rupees numeric(12,2),
  ncb_pct numeric,
  ncb_eroded boolean not null,
  at_fault_accidents int,
  policy_class text not null check (policy_class in (
    'own_damage_comprehensive','third_party_only','fleet_package','zero_dep_addon','commercial_goods_carrier'
  )),
  policy_status text not null check (policy_status in (
    'active_ncb_intact','active_ncb_eroded','claim_in_process','renewal_due','lapsed'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.motor_insurance_r3745 enable row level security;

create index if not exists idx_motor_insurance_r3745_org on public.motor_insurance_r3745(organization_id);
create index if not exists idx_motor_insurance_r3745_month on public.motor_insurance_r3745(period_month);
create index if not exists idx_motor_insurance_r3745_status on public.motor_insurance_r3745(policy_status);

-- =============================================================================
-- TABLE 2: motor_insurance_capa_actions_r3745 — CAPA for claims/NCB-erosion gaps
-- =============================================================================
create table if not exists public.motor_insurance_capa_actions_r3745 (
  id uuid primary key default gen_random_uuid(),
  policy_id uuid references public.motor_insurance_r3745(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.motor_insurance_capa_actions_r3745 enable row level security;

create index if not exists idx_motor_insurance_capa_r3745_main on public.motor_insurance_capa_actions_r3745(policy_id);
create index if not exists idx_motor_insurance_capa_r3745_status on public.motor_insurance_capa_actions_r3745(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Policy-status distribution
create or replace function public.founder_r3745_policy_status_rollup()
returns table(policy_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.motor_insurance_r3745)
  select l.policy_status, count(*)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.motor_insurance_r3745 l
  group by l.policy_status
  order by count(*) desc;
end;
$$;

-- 2) Vehicle-type scorecard
create or replace function public.founder_r3745_vehicle_type_scorecard()
returns table(
  vehicle_type text,
  records bigint,
  active_ncb_intact bigint,
  active_ncb_eroded bigint,
  claim_in_process bigint,
  renewal_due bigint,
  lapsed bigint,
  claims_filed_total bigint,
  claim_amount_total numeric,
  avg_ncb_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.vehicle_type,
    count(*)::bigint,
    count(*) filter (where l.policy_status = 'active_ncb_intact')::bigint,
    count(*) filter (where l.policy_status = 'active_ncb_eroded')::bigint,
    count(*) filter (where l.policy_status = 'claim_in_process')::bigint,
    count(*) filter (where l.policy_status = 'renewal_due')::bigint,
    count(*) filter (where l.policy_status = 'lapsed')::bigint,
    coalesce(sum(l.claims_filed), 0)::bigint,
    coalesce(sum(l.claim_amount_rupees), 0)::numeric,
    round(avg(l.ncb_pct), 1)
  from public.motor_insurance_r3745 l
  group by l.vehicle_type
  order by count(*) desc;
end;
$$;

-- 3) Policy-class x policy-status matrix
create or replace function public.founder_r3745_policy_class_status_matrix()
returns table(policy_class text, policy_status text, records bigint, avg_idv_rupees numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.policy_class, l.policy_status, count(*)::bigint,
    round(avg(l.idv_rupees), 2)
  from public.motor_insurance_r3745 l
  group by l.policy_class, l.policy_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly claims trend
create or replace function public.founder_r3745_monthly_claims_trend()
returns table(
  period_month date,
  records bigint,
  claims_filed_total bigint,
  claim_amount_total numeric,
  at_fault_accidents_total bigint,
  ncb_eroded_records bigint
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
    coalesce(sum(l.claims_filed), 0)::bigint,
    coalesce(sum(l.claim_amount_rupees), 0)::numeric,
    coalesce(sum(l.at_fault_accidents), 0)::bigint,
    count(*) filter (where l.ncb_eroded)::bigint
  from public.motor_insurance_r3745 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3745_capa_status_board()
returns table(capa_status text, findings bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.motor_insurance_capa_actions_r3745 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root-cause pareto
create or replace function public.founder_r3745_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.motor_insurance_capa_actions_r3745)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot), 0) * 100.0, 1)
  from public.motor_insurance_capa_actions_r3745 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) NCB-erosion digest (vehicles that have lost accumulated no-claim bonus)
create or replace function public.founder_r3745_ncb_erosion_digest()
returns table(
  vehicle_type text,
  records bigint,
  ncb_eroded_records bigint,
  avg_ncb_pct numeric,
  at_fault_accidents_total bigint,
  claim_amount_total numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.vehicle_type,
    count(*)::bigint,
    count(*) filter (where l.ncb_eroded)::bigint,
    round(avg(l.ncb_pct), 1),
    coalesce(sum(l.at_fault_accidents), 0)::bigint,
    coalesce(sum(l.claim_amount_rupees), 0)::numeric
  from public.motor_insurance_r3745 l
  where l.ncb_eroded = true
  group by l.vehicle_type
  order by count(*) desc;
end;
$$;

-- 8) High-risk policy queue (lapsed / claim-in-process, worst first)
create or replace function public.founder_r3745_high_risk_queue()
returns table(
  vehicle_registration text,
  vehicle_type text,
  period_month date,
  policy_class text,
  policy_status text,
  policy_renewal_date date,
  claim_amount_rupees numeric,
  at_fault_accidents int,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.vehicle_registration, l.vehicle_type, l.period_month, l.policy_class,
    l.policy_status, l.policy_renewal_date, l.claim_amount_rupees, l.at_fault_accidents,
    l.notes
  from public.motor_insurance_r3745 l
  where l.policy_status in ('lapsed','claim_in_process')
  order by l.claim_amount_rupees desc nulls last, l.period_month desc
  limit 20;
end;
$$;

-- =============================================================================
-- Grants — founder-gated, authenticated-only surface
-- =============================================================================
revoke all on function public.founder_r3745_policy_status_rollup() from public, anon;
revoke all on function public.founder_r3745_vehicle_type_scorecard() from public, anon;
revoke all on function public.founder_r3745_policy_class_status_matrix() from public, anon;
revoke all on function public.founder_r3745_monthly_claims_trend() from public, anon;
revoke all on function public.founder_r3745_capa_status_board() from public, anon;
revoke all on function public.founder_r3745_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3745_ncb_erosion_digest() from public, anon;
revoke all on function public.founder_r3745_high_risk_queue() from public, anon;

grant execute on function public.founder_r3745_policy_status_rollup() to authenticated;
grant execute on function public.founder_r3745_vehicle_type_scorecard() to authenticated;
grant execute on function public.founder_r3745_policy_class_status_matrix() to authenticated;
grant execute on function public.founder_r3745_monthly_claims_trend() to authenticated;
grant execute on function public.founder_r3745_capa_status_board() to authenticated;
grant execute on function public.founder_r3745_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3745_ncb_erosion_digest() to authenticated;
grant execute on function public.founder_r3745_high_risk_queue() to authenticated;

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

  -- 16 motor-insurance policy/claim rows across vehicles, classes, statuses & months
  insert into public.motor_insurance_r3745 (
    organization_id, vehicle_registration, vehicle_type, period_month, policy_number,
    policy_renewal_date, idv_rupees, premium_rupees, claims_filed, claim_amount_rupees,
    ncb_pct, ncb_eroded, at_fault_accidents, policy_class, policy_status, trend_dir, notes
  )
  select v_org_id, q.vr, q.vt, q.pm::date, q.pn,
    q.prd::date, q.idv, q.prem, q.cf, q.cam,
    q.ncb, q.nce, q.afa, q.pc, q.ps, q.td, q.nt
  from (values
    ('KA-01-AB-1234','mini_truck','2026-07-01','POL-MI-8821','2027-01-15',850000.00,42500.00,0,0.00,35,false,0,'own_damage_comprehensive','active_ncb_intact','stable','No claims filed this policy year — NCB protected'),
    ('MH-12-CD-5678','pickup_truck','2026-07-01','POL-MI-8822','2026-09-20',620000.00,31000.00,1,185000.00,0,true,1,'third_party_only','active_ncb_eroded','worsening','Single at-fault accident wiped out accumulated 25% NCB'),
    ('TN-09-EF-9012','tempo_traveller','2026-07-01','POL-MI-8823','2026-08-05',780000.00,39500.00,1,0.00,20,false,0,'fleet_package','claim_in_process','stable','Windshield and body damage claim under survey — no fault determined yet'),
    ('DL-03-GH-3456','suv','2026-06-01','POL-MI-8824','2026-08-30',1450000.00,58000.00,0,0.00,50,false,0,'zero_dep_addon','renewal_due','stable','Renewal due in under 60 days — zero-dep rider to be continued'),
    ('GJ-05-IJ-7890','tipper_truck','2026-06-01','POL-MI-8825','2026-06-10',1650000.00,72000.00,2,410000.00,0,true,2,'commercial_goods_carrier','lapsed','worsening','Policy lapsed 20+ days after two at-fault claims — vehicle grounded pending renewal'),
    ('KA-01-KL-2345','mini_truck','2026-07-01','POL-MI-8826','2027-02-10',890000.00,44000.00,0,0.00,45,false,0,'own_damage_comprehensive','active_ncb_intact','improving','Clean claims record for third consecutive year'),
    ('MH-14-MN-6789','van','2026-07-01','POL-MI-8827','2026-10-05',560000.00,27500.00,1,92000.00,0,true,0,'third_party_only','active_ncb_eroded','worsening','Minor collision claim settled — NCB reset to zero this renewal'),
    ('TN-10-OP-0123','tractor_trailer','2026-07-01','POL-MI-8828','2026-07-25',2100000.00,95000.00,1,0.00,30,false,1,'fleet_package','claim_in_process','worsening','Highway collision claim filed — surveyor assessment pending, at-fault status contested'),
    ('DL-04-QR-4567','sedan','2026-06-01','POL-MI-8829','2026-08-12',720000.00,33000.00,0,0.00,40,false,0,'zero_dep_addon','renewal_due','stable','Renewal quote received — premium up 8% due to fleet-wide claims ratio'),
    ('GJ-06-ST-8901','tipper_truck','2026-06-01','POL-MI-8830','2026-06-01',1580000.00,69000.00,3,620000.00,0,true,3,'commercial_goods_carrier','lapsed','worsening','Third at-fault accident this year — insurer declined renewal, seeking new insurer'),
    ('KA-02-UV-2346','pickup_truck','2026-05-01','POL-MI-8831','2026-11-18',640000.00,32000.00,0,0.00,25,false,0,'own_damage_comprehensive','active_ncb_intact','stable','No incidents reported this period'),
    ('MH-15-WX-6790','tempo_traveller','2026-05-01','POL-MI-8832','2026-09-02',810000.00,40500.00,1,145000.00,0,true,1,'third_party_only','active_ncb_eroded','worsening','Rear-end collision at-fault — NCB dropped from 20% to 0%'),
    ('TN-11-YZ-0124','suv','2026-05-01','POL-MI-8833','2026-07-28',1520000.00,61000.00,1,0.00,15,false,0,'fleet_package','claim_in_process','stable','Theft-attempt damage claim lodged — awaiting police report closure'),
    ('DL-05-AB-4568','van','2026-05-01','POL-MI-8834','2026-07-10',590000.00,28500.00,0,0.00,35,false,0,'zero_dep_addon','renewal_due','improving','Renewal due shortly — driver training program has kept claims nil'),
    ('GJ-07-CD-8902','mini_truck','2026-06-01','POL-MI-8835','2026-06-05',870000.00,43000.00,2,310000.00,0,true,2,'commercial_goods_carrier','lapsed','worsening','Lapsed after repeated at-fault claims — fleet manager sourcing alternate insurer'),
    ('KA-03-EF-2347','sedan','2026-07-01','POL-MI-8836','2027-03-22',690000.00,30500.00,0,0.00,50,false,0,'own_damage_comprehensive','active_ncb_intact','improving','Maximum 50% NCB slab reached — best-in-fleet claims record')
  ) as q(vr, vt, pm, pn, prd, idv, prem, cf, cam, ncb, nce, afa, pc, ps, td, nt);

  -- 8 CAPA rows — attach to policy rows via vehicle_registration + period_month
  insert into public.motor_insurance_capa_actions_r3745 (
    policy_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('MH-12-CD-5678','2026-07-01','At-fault accident wiped out accumulated 25% NCB slab','Enroll driver in defensive-driving refresher and flag vehicle for telematics monitoring','in_progress','Fleet Risk Manager','2026-09-10',null,'Driver enrolled in refresher course; telematics installation scheduled this month'),
    ('GJ-05-IJ-7890','2026-06-01','Two at-fault accidents within policy year triggered lapse after non-renewal by insurer','Source replacement comprehensive cover from alternate insurer and suspend vehicle from active routes till bound','open','Fleet Risk Manager','2026-08-30',null,'Two insurers quoting; vehicle grounded at yard pending fresh policy binding'),
    ('MH-14-MN-6789','2026-07-01','Minor collision claim settled at fault, resetting NCB to zero','Review driver assignment history and issue written caution to assigned driver','closed','Regional Transport Supervisor','2026-07-25','2026-07-20','Caution issued; no repeat incidents since closure'),
    ('TN-10-OP-0123','2026-07-01','Highway collision claim under survey with contested at-fault determination','Submit dashcam footage and route-log evidence to surveyor to contest fault attribution','in_progress','Legal & Claims Coordinator','2026-08-15',null,'Dashcam footage submitted; surveyor review expected within two weeks'),
    ('GJ-06-ST-8901','2026-06-01','Third at-fault accident in policy year led insurer to decline renewal outright','Retire vehicle from high-risk route assignment and negotiate fresh-start cover with new insurer at higher premium','overdue','Fleet Risk Manager','2026-07-20',null,'SLA breached by three weeks; two insurers have declined, third quote pending'),
    ('MH-15-WX-6790','2026-05-01','Rear-end collision at-fault claim dropped NCB from 20% to 0%','Install reverse-parking sensors and mandate refresher training for repeat-offense drivers','in_progress','Regional Transport Supervisor','2026-08-05',null,'Sensors ordered for fleet-wide rollout; training scheduled for next batch'),
    ('GJ-07-CD-8902','2026-06-01','Repeated at-fault claims across two years led to policy lapse','Replace vehicle on high-risk city route with newer unit and reassign to low-risk depot circuit','open','Fleet Operations Head','2026-09-05',null,'Alternate depot assignment approved; new insurer onboarding in progress'),
    ('TN-09-EF-9012','2026-07-01','Windshield and body damage claim pending fault determination delaying settlement','Escalate to insurer surveyor for expedited assessment and provide workshop repair estimate','closed','Legal & Claims Coordinator','2026-07-30','2026-07-28','No-fault determination confirmed; claim settled and closed ahead of target')
  ) as q(vr, pm, rc, ca, cst, ownr, tcd, acd, nt)
  join public.motor_insurance_r3745 e
    on e.organization_id = v_org_id and e.vehicle_registration = q.vr and e.period_month = q.pm::date;
end;
$seed$;
