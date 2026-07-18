-- Round 3249: Founder Office/Warehouse Lease, Rent & Utilities Cost Board
-- Founder business board — location × site type × lease window × rent & deposit × escalation × utilities × occupancy × renewal decision × CAPA

-- =============================================================================
-- TABLE 1: office_lease_cost_r3249 — per-location lease & running-cost register
-- =============================================================================
create table if not exists public.office_lease_cost_r3249 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  location_name text not null,
  city text not null,
  site_type text not null check (site_type in (
    'head_office','regional_office','warehouse','service_center','training_center'
  )),
  lease_start date not null,
  lease_end date not null,
  monthly_rent_rupees numeric(12,2) not null,
  security_deposit_rupees numeric(12,2) not null,
  escalation_pct numeric(5,2),
  lock_in_months int,
  monthly_utilities_rupees numeric(12,2),
  seats_capacity int,
  occupancy_pct numeric(5,2),
  rent_per_seat_rupees numeric(10,2),
  renewal_decision text not null check (renewal_decision in (
    'renew','renegotiate','relocate','downsize','exit','pending_review'
  )),
  lease_verdict text not null check (lease_verdict in (
    'healthy','above_market','underutilized','expiring_soon','critical'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.office_lease_cost_r3249 enable row level security;

create index if not exists idx_office_lease_r3249_org on public.office_lease_cost_r3249(organization_id);
create index if not exists idx_office_lease_r3249_end on public.office_lease_cost_r3249(lease_end);
create index if not exists idx_office_lease_r3249_verdict on public.office_lease_cost_r3249(lease_verdict);

-- =============================================================================
-- TABLE 2: office_lease_cost_capa_actions_r3249 — cost-optimization actions
-- =============================================================================
create table if not exists public.office_lease_cost_capa_actions_r3249 (
  id uuid primary key default gen_random_uuid(),
  lease_id uuid not null references public.office_lease_cost_r3249(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'above_market_rent','low_occupancy','utility_overrun','expiring_lease',
    'deposit_recovery','escalation_clause_risk','space_shortfall','duplicate_site'
  )),
  root_cause text not null check (root_cause in (
    'market_rate_shift','headcount_change','poor_space_planning','power_tariff_hike',
    'landlord_dispute','remote_work_shift','rapid_team_growth','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'renegotiate_rent','sublease_excess_space','relocate_to_cheaper_site','consolidate_offices',
    'install_solar_and_led','renegotiate_escalation','exit_at_lock_in_end','expand_current_site',
    'none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  cost_impact text not null check (cost_impact in (
    'savings_high','savings_medium','savings_low','cost_neutral','cost_increase'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_savings_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.office_lease_cost_capa_actions_r3249 enable row level security;

create index if not exists idx_office_lease_capa_r3249_lease on public.office_lease_cost_capa_actions_r3249(lease_id);
create index if not exists idx_office_lease_capa_r3249_status on public.office_lease_cost_capa_actions_r3249(capa_status);

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

  -- 14 location lease rows
  insert into public.office_lease_cost_r3249 (
    organization_id, location_name, city, site_type,
    lease_start, lease_end, monthly_rent_rupees, security_deposit_rupees,
    escalation_pct, lock_in_months, monthly_utilities_rupees, seats_capacity,
    occupancy_pct, rent_per_seat_rupees, renewal_decision, lease_verdict, notes
  )
  select v_org_id, q.loc, q.city, q.st,
    q.ls::date, q.le::date, q.rent, q.dep,
    q.esc, q.lkm, q.util, q.seats,
    q.occ, q.rps, q.rd, q.lv, q.nt
  from (values
    ('EquipSeva HQ Koramangala','Bengaluru','head_office','2024-04-01','2029-03-31',
     1850000.00,11100000.00,5.00,36,320000.00,220,88.5,8409.00,'renew','healthy',
     'Anchor HQ — engineering, ops and support hub; landlord relationship strong'),
    ('Mumbai Andheri Regional Office','Mumbai','regional_office','2023-07-01','2026-09-30',
     950000.00,5700000.00,7.00,24,145000.00,80,62.5,11875.00,'renegotiate','above_market',
     'Rent 18% above Andheri East comps and 7% escalation — renegotiation opened'),
    ('Delhi Okhla Regional Office','New Delhi','regional_office','2024-01-15','2027-01-14',
     720000.00,4320000.00,5.00,24,118000.00,70,81.4,10286.00,'renew','healthy',
     'North-zone sales plus service coordination; costs within budget'),
    ('Hyderabad HITEC City Office','Hyderabad','regional_office','2025-03-01','2028-02-29',
     540000.00,3240000.00,4.50,18,96000.00,60,46.7,9000.00,'downsize','underutilized',
     'Two floors leased, second floor nearly empty after team consolidation'),
    ('Chennai Guindy Warehouse','Chennai','warehouse','2022-10-01','2026-09-30',
     480000.00,2880000.00,5.00,36,88000.00,25,92.0,19200.00,'renegotiate','expiring_soon',
     'Spare-parts hub lease ends in under 90 days — renewal terms under discussion'),
    ('Pune Chakan Warehouse','Pune','warehouse','2024-06-01','2029-05-31',
     420000.00,2520000.00,5.00,36,72000.00,20,85.0,21000.00,'renew','healthy',
     'West-zone logistics node close to OEM plants; utilization healthy'),
    ('Kolkata Salt Lake Service Center','Kolkata','service_center','2023-04-01','2026-08-31',
     210000.00,1260000.00,6.00,12,46000.00,30,38.3,7000.00,'exit','critical',
     'Occupancy 38% and landlord pushing 6% escalation — exit at lock-in end'),
    ('Gurgaon Udyog Vihar Warehouse','Gurgaon','warehouse','2025-01-01','2030-12-31',
     610000.00,3660000.00,5.50,48,104000.00,22,90.9,27727.00,'renew','healthy',
     'NCR distribution hub; long lock-in traded for flat first-year rent'),
    ('Ahmedabad SG Highway Service Center','Ahmedabad','service_center','2024-09-01','2027-08-31',
     185000.00,1110000.00,5.00,18,39000.00,24,75.0,7708.00,'renew','healthy',
     'Gujarat service coverage; steady job-card volume supports the site'),
    ('Kochi Kakkanad Service Center','Kochi','service_center','2023-11-01','2026-10-31',
     165000.00,990000.00,5.00,12,52000.00,20,70.0,8250.00,'renegotiate','expiring_soon',
     'Lease ends October; utilities overrun — AC running round the clock'),
    ('Bengaluru Whitefield Training Center','Bengaluru','training_center','2025-06-01','2028-05-31',
     340000.00,2040000.00,5.00,24,78000.00,90,55.6,3778.00,'pending_review','underutilized',
     'Engineer-training batches fill 55% of seats — review vs virtual-training mix'),
    ('Jaipur Sitapura Service Center','Jaipur','service_center','2024-02-01','2027-01-31',
     125000.00,750000.00,4.00,12,28000.00,16,87.5,7813.00,'renew','healthy',
     'Rajasthan coverage; lowest rent-per-seat among service centers'),
    ('Lucknow Gomti Nagar Service Center','Lucknow','service_center','2025-08-01','2028-07-31',
     140000.00,840000.00,5.00,18,31000.00,18,83.3,7778.00,'renew','healthy',
     'UP-east coverage; opened last year, ramping as planned'),
    ('Coimbatore Peelamedu Service Center','Coimbatore','service_center','2023-05-01','2026-07-31',
     155000.00,930000.00,8.00,12,34000.00,18,61.1,8611.00,'relocate','critical',
     '8% escalation clause and lease ends this month — relocation shortlist ready')
  ) as q(loc, city, st, ls, le, rent, dep, esc, lkm, util, seats, occ, rps, rd, lv, nt);

  -- CAPA seed — attach to specific locations via location name
  insert into public.office_lease_cost_capa_actions_r3249 (
    lease_id, finding_category, root_cause, corrective_action,
    capa_status, cost_impact, target_closure_date, actual_closure_date,
    estimated_savings_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ci, q.tcd::date, q.acd::date,
    q.sav, q.nt
  from (values
    ('Mumbai Andheri Regional Office','above_market_rent','market_rate_shift','renegotiate_rent','in_progress','savings_high','2026-08-15',null,1710000.00,'Broker comps shared with landlord — targeting 15% cut at renewal'),
    ('Hyderabad HITEC City Office','low_occupancy','headcount_change','sublease_excess_space','open','savings_medium','2026-09-01',null,2900000.00,'Second floor sublease mandate given to IPC — two prospects touring'),
    ('Chennai Guindy Warehouse','expiring_lease','market_rate_shift','renegotiate_escalation','verification_pending','savings_low','2026-08-20',null,290000.00,'Renewal draft caps escalation at 4% — legal review pending'),
    ('Kolkata Salt Lake Service Center','low_occupancy','remote_work_shift','exit_at_lock_in_end','escalated','savings_high','2026-08-31',null,2520000.00,'Exit notice drafted; jobs reroute to Bhubaneswar partner network'),
    ('Kochi Kakkanad Service Center','utility_overrun','power_tariff_hike','install_solar_and_led','in_progress','savings_medium','2026-09-30',null,260000.00,'Rooftop solar quote approved; LED retrofit half done'),
    ('Coimbatore Peelamedu Service Center','expiring_lease','landlord_dispute','relocate_to_cheaper_site','overdue','savings_medium','2026-07-10',null,480000.00,'Landlord refused escalation cut — two Saravanampatti options past target date'),
    ('Bengaluru Whitefield Training Center','low_occupancy','poor_space_planning','consolidate_offices','closed','savings_low','2026-07-01','2026-06-28',150000.00,'Weekend batches merged into two halls; third hall released to landlord')
  ) as q(loc, fc, rc, ca, cst, ci, tcd, acd, sav, nt)
  join public.office_lease_cost_r3249 e
    on e.organization_id = v_org_id and e.location_name = q.loc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Lease verdict distribution
create or replace function public.founder_r3249_lease_verdict_rollup()
returns table(lease_verdict text, locations bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.office_lease_cost_r3249)
  select l.lease_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.office_lease_cost_r3249 l
  group by l.lease_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3249_lease_verdict_rollup() from public, anon;
grant execute on function public.founder_r3249_lease_verdict_rollup() to authenticated;

-- 2) City-level cost scorecard
create or replace function public.founder_r3249_city_cost_scorecard()
returns table(
  city text,
  locations bigint,
  total_monthly_rent_rupees numeric,
  total_monthly_utilities_rupees numeric,
  avg_occupancy_pct numeric,
  avg_rent_per_seat_rupees numeric,
  at_risk_locations bigint,
  healthy_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.city,
    count(*)::bigint,
    coalesce(sum(l.monthly_rent_rupees),0)::numeric,
    coalesce(sum(l.monthly_utilities_rupees),0)::numeric,
    round(avg(l.occupancy_pct), 1),
    round(avg(l.rent_per_seat_rupees), 0),
    count(*) filter (where l.lease_verdict in ('above_market','underutilized','expiring_soon','critical'))::bigint,
    round(100.0 * count(*) filter (where l.lease_verdict = 'healthy')::numeric / nullif(count(*),0), 1)
  from public.office_lease_cost_r3249 l
  group by l.city
  order by sum(l.monthly_rent_rupees) desc;
end;
$$;

revoke execute on function public.founder_r3249_city_cost_scorecard() from public, anon;
grant execute on function public.founder_r3249_city_cost_scorecard() to authenticated;

-- 3) Site type × lease verdict matrix
create or replace function public.founder_r3249_site_type_verdict_matrix()
returns table(site_type text, lease_verdict text, locations bigint, total_monthly_rent_rupees numeric, avg_occupancy_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_type, l.lease_verdict, count(*)::bigint,
    coalesce(sum(l.monthly_rent_rupees),0)::numeric,
    round(avg(l.occupancy_pct), 1)
  from public.office_lease_cost_r3249 l
  group by l.site_type, l.lease_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3249_site_type_verdict_matrix() from public, anon;
grant execute on function public.founder_r3249_site_type_verdict_matrix() to authenticated;

-- 4) Lease expiry trend
create or replace function public.founder_r3249_lease_expiry_trend()
returns table(lease_end date, expiring_locations bigint, monthly_rent_at_stake_rupees numeric, pending_or_renegotiate bigint, exit_or_relocate bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.lease_end,
    count(*)::bigint,
    coalesce(sum(l.monthly_rent_rupees),0)::numeric,
    count(*) filter (where l.renewal_decision in ('pending_review','renegotiate'))::bigint,
    count(*) filter (where l.renewal_decision in ('exit','relocate','downsize'))::bigint
  from public.office_lease_cost_r3249 l
  group by l.lease_end
  order by l.lease_end asc;
end;
$$;

revoke execute on function public.founder_r3249_lease_expiry_trend() from public, anon;
grant execute on function public.founder_r3249_lease_expiry_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3249_capa_status_board()
returns table(capa_status text, findings bigint, avg_savings_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_savings_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.office_lease_cost_capa_actions_r3249 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3249_capa_status_board() from public, anon;
grant execute on function public.founder_r3249_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3249_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_savings_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.office_lease_cost_capa_actions_r3249)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_savings_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.office_lease_cost_capa_actions_r3249 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3249_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3249_root_cause_pareto() to authenticated;

-- 7) Cost impact digest
create or replace function public.founder_r3249_cost_impact_digest()
returns table(cost_impact text, findings bigint, open_findings bigint, total_savings_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.cost_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_savings_rupees),0)::numeric
  from public.office_lease_cost_capa_actions_r3249 c
  group by c.cost_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3249_cost_impact_digest() from public, anon;
grant execute on function public.founder_r3249_cost_impact_digest() to authenticated;

-- 8) High-risk lease queue (top individual concerns)
create or replace function public.founder_r3249_high_risk_queue()
returns table(
  location_name text,
  city text,
  site_type text,
  lease_end date,
  monthly_rent_rupees numeric,
  occupancy_pct numeric,
  renewal_decision text,
  lease_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.location_name, l.city, l.site_type, l.lease_end,
    l.monthly_rent_rupees, l.occupancy_pct, l.renewal_decision, l.lease_verdict,
    l.notes
  from public.office_lease_cost_r3249 l
  where l.lease_verdict in ('above_market','underutilized','expiring_soon','critical')
     or l.renewal_decision in ('renegotiate','relocate','downsize','exit','pending_review')
     or l.occupancy_pct < 60
  order by l.lease_end asc, l.location_name;
end;
$$;

revoke execute on function public.founder_r3249_high_risk_queue() from public, anon;
grant execute on function public.founder_r3249_high_risk_queue() to authenticated;
