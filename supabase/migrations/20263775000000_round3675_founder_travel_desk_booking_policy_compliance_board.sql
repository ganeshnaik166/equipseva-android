-- Round 3675: Founder Travel-Desk Booking / Policy-Compliance Board
-- Travel-desk admin ops — office × department × travel type × advance-booking window × policy violations × out-of-policy spend × booking channel × compliance status × CAPA

-- =============================================================================
-- TABLE 1: travel_desk_r3675 — per-department per-month travel booking compliance records
-- =============================================================================
create table if not exists public.travel_desk_r3675 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  record_code text not null,
  office text not null,
  department text not null,
  travel_type text not null check (travel_type in (
    'domestic_flight','international_flight','train','hotel','cab_rental','bus'
  )),
  period_month date not null,
  trips_booked int not null,
  advance_booked_pct numeric(5,2),
  avg_advance_days numeric(6,2),
  policy_violations int not null default 0,
  out_of_policy_spend_rupees numeric(12,2),
  total_travel_spend_rupees numeric(14,2),
  avg_cost_per_trip_rupees numeric(12,2),
  preferred_vendor_pct numeric(5,2),
  cancellations int not null default 0,
  booking_channel text not null check (booking_channel in (
    'travel_desk','self_ota','corporate_portal','direct_vendor','emergency'
  )),
  compliance_status text not null check (compliance_status in (
    'compliant','minor_violations','frequent_violations','uncontrolled','emergency_heavy'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.travel_desk_r3675 enable row level security;

create index if not exists idx_travel_desk_r3675_org on public.travel_desk_r3675(organization_id);
create index if not exists idx_travel_desk_r3675_month on public.travel_desk_r3675(period_month);
create index if not exists idx_travel_desk_r3675_status on public.travel_desk_r3675(compliance_status);

-- =============================================================================
-- TABLE 2: travel_desk_capa_actions_r3675 — CAPA & policy-enforcement actions
-- =============================================================================
create table if not exists public.travel_desk_capa_actions_r3675 (
  id uuid primary key default gen_random_uuid(),
  record_id uuid not null references public.travel_desk_r3675(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'low_advance_booking','out_of_policy_vendor','class_of_travel_violation',
    'last_minute_emergency_booking','self_booking_outside_desk','excess_cancellations',
    'budget_overrun','missing_approval'
  )),
  root_cause text not null check (root_cause in (
    'no_travel_planning_calendar','approval_workflow_delay','policy_awareness_gap',
    'preferred_vendor_unavailable','manager_override_culture','urgent_client_escalations',
    'ota_convenience_preference','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'enforce_advance_booking_window','block_self_ota_reimbursement','mandate_corporate_portal',
    'renegotiate_vendor_contract','policy_training_refresher','tighten_approval_matrix',
    'introduce_travel_calendar','escalate_to_cfo','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  out_of_policy_impact_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.travel_desk_capa_actions_r3675 enable row level security;

create index if not exists idx_travel_desk_capa_r3675_record on public.travel_desk_capa_actions_r3675(record_id);
create index if not exists idx_travel_desk_capa_r3675_status on public.travel_desk_capa_actions_r3675(capa_status);

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

  -- 16 travel-desk compliance rows
  insert into public.travel_desk_r3675 (
    organization_id, record_code, office, department, travel_type, period_month,
    trips_booked, advance_booked_pct, avg_advance_days, policy_violations,
    out_of_policy_spend_rupees, total_travel_spend_rupees, avg_cost_per_trip_rupees,
    preferred_vendor_pct, cancellations, booking_channel, compliance_status, trend_dir, notes
  )
  select v_org_id, q.rcode, q.office, q.dept, q.ttype, q.pmonth::date,
    q.trips, q.advpct, q.advdays, q.viol,
    q.oopspend, q.totspend, q.cpt,
    q.prefpct, q.cancels, q.channel, q.cstatus, q.tdir, q.nt
  from (values
    ('TRV-MUM-SAL-05','Mumbai HQ','Sales','domestic_flight','2026-07-01',
     42,78.6,9.2,3,84500.00,1260000.00,30000.00,82.0,2,'travel_desk','minor_violations','improving','Sales domestic flights mostly booked 9 days ahead via travel desk'),
    ('TRV-MUM-MGT-06','Mumbai HQ','Management','international_flight','2026-07-01',
     6,50.0,6.5,3,310000.00,1450000.00,241666.67,55.0,1,'direct_vendor','frequent_violations','worsening','Leadership intl sectors booked direct with airline bypassing portal'),
    ('TRV-CHN-FSV-11','Chennai branch','Field Service','train','2026-07-01',
     58,91.4,12.8,1,12000.00,348000.00,6000.00,88.0,3,'corporate_portal','compliant','stable','Service engineer train travel well within policy window'),
    ('TRV-CHN-SAL-12','Chennai branch','Sales','cab_rental','2026-07-01',
     36,66.7,4.1,6,42300.00,234000.00,6500.00,61.0,2,'self_ota','frequent_violations','worsening','Local cab rentals booked on personal OTA apps and reimbursed'),
    ('TRV-DEL-SCM-21','Delhi warehouse','Supply Chain','domestic_flight','2026-07-01',
     14,85.7,10.6,1,18000.00,392000.00,28000.00,79.0,1,'travel_desk','compliant','stable','Warehouse audit trips booked within the 10-day advance window'),
    ('TRV-DEL-HRA-22','Delhi warehouse','HR & Admin','bus','2026-07-01',
     22,95.5,15.3,0,0.00,66000.00,3000.00,92.0,0,'corporate_portal','compliant','improving','Staff shuttle and training travel fully compliant'),
    ('TRV-BLR-FSV-31','Bengaluru service hub','Field Service','domestic_flight','2026-07-01',
     48,43.8,2.9,14,296000.00,1104000.00,23000.00,46.0,5,'emergency','uncontrolled','worsening','Breakdown-call flights booked under 3 days out — emergency-heavy pattern'),
    ('TRV-BLR-RND-32','Bengaluru service hub','R&D','hotel','2026-07-01',
     19,73.7,7.8,4,51000.00,418000.00,22000.00,68.0,2,'self_ota','minor_violations','stable','Conference hotels booked on OTA above negotiated corporate rate'),
    ('TRV-HYD-SAL-41','Hyderabad sales office','Sales','domestic_flight','2026-06-01',
     39,71.8,6.9,5,92000.00,1053000.00,27000.00,64.0,3,'travel_desk','minor_violations','improving','June sales blitz — advance window slipped during quarter close'),
    ('TRV-HYD-FIN-42','Hyderabad sales office','Finance','train','2026-06-01',
     12,100.0,18.4,0,0.00,54000.00,4500.00,95.0,0,'corporate_portal','compliant','stable','Audit travel planned a full sprint ahead — model department'),
    ('TRV-PUN-REG-51','Pune R&D center','Regulatory','domestic_flight','2026-06-01',
     9,55.6,3.4,4,76000.00,279000.00,31000.00,52.0,1,'emergency','emergency_heavy','stable','CDSCO hearing dates arrive late — bookings forced inside 3 days'),
    ('TRV-PUN-RND-52','Pune R&D center','R&D','international_flight','2026-06-01',
     4,75.0,21.0,1,68000.00,640000.00,160000.00,71.0,0,'travel_desk','minor_violations','improving','One business-class upgrade taken without pre-approval'),
    ('TRV-MUM-FIN-07','Mumbai HQ','Finance','hotel','2026-05-01',
     11,90.9,11.7,1,9500.00,132000.00,12000.00,84.0,1,'corporate_portal','compliant','stable','Banker roadshow hotels at negotiated corporate rates'),
    ('TRV-CHN-SCM-13','Chennai branch','Supply Chain','cab_rental','2026-05-01',
     27,59.3,3.8,7,38700.00,175500.00,6500.00,49.0,4,'direct_vendor','frequent_violations','stable','Port-run cabs hired directly at gate rates — no contracted vendor'),
    ('TRV-DEL-SAL-23','Delhi warehouse','Sales','domestic_flight','2026-05-01',
     31,80.6,8.8,2,41000.00,868000.00,28000.00,74.0,2,'travel_desk','minor_violations','improving','North-region dealer visits largely inside booking window'),
    ('TRV-BLR-MGT-33','Bengaluru service hub','Management','domestic_flight','2026-05-01',
     8,37.5,2.2,5,129000.00,344000.00,43000.00,38.0,1,'self_ota','uncontrolled','worsening','Hub leadership self-booking full-fare flights on OTA apps')
  ) as q(rcode, office, dept, ttype, pmonth, trips, advpct, advdays, viol, oopspend, totspend, cpt, prefpct, cancels, channel, cstatus, tdir, nt);

  -- CAPA seed — attach to specific records via record_code
  insert into public.travel_desk_capa_actions_r3675 (
    record_id, finding_category, root_cause, corrective_action,
    capa_status, out_of_policy_impact_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('TRV-BLR-FSV-31','last_minute_emergency_booking','no_travel_planning_calendar','introduce_travel_calendar','in_progress',296000.00,'Regional Service Head','2026-08-20',null,'Weekly breakdown-visit forecast being wired into travel desk'),
    ('TRV-MUM-MGT-06','out_of_policy_vendor','manager_override_culture','escalate_to_cfo','escalated',310000.00,'CFO Office','2026-08-14',null,'Direct airline bookings by leadership escalated for CFO directive'),
    ('TRV-CHN-SAL-12','self_booking_outside_desk','ota_convenience_preference','block_self_ota_reimbursement','open',42300.00,'Finance Controller','2026-08-25',null,'Expense tool rule to reject OTA invoices without desk reference'),
    ('TRV-BLR-MGT-33','budget_overrun','manager_override_culture','tighten_approval_matrix','open',129000.00,'HR & Admin Head','2026-08-28',null,'Two-level approval for any fare above slab under rollout'),
    ('TRV-PUN-REG-51','last_minute_emergency_booking','urgent_client_escalations','none_required','closed',76000.00,'Travel Desk Lead','2026-07-31','2026-07-28','Regulatory hearing dates are external — emergency channel formally allowed'),
    ('TRV-CHN-SCM-13','out_of_policy_vendor','preferred_vendor_unavailable','renegotiate_vendor_contract','verification_pending',38700.00,'Supply Chain Manager','2026-08-10',null,'New port-area cab contract signed — verifying August usage'),
    ('TRV-HYD-SAL-41','low_advance_booking','approval_workflow_delay','tighten_approval_matrix','overdue',92000.00,'Sales Ops Manager','2026-07-25',null,'Approval SLA fix slipped past target — quarter-close crunch'),
    ('TRV-BLR-RND-32','out_of_policy_vendor','policy_awareness_gap','policy_training_refresher','in_progress',51000.00,'L&D Partner','2026-08-18',null,'Hotel-slab refresher scheduled for R&D travellers')
  ) as q(rcode, fc, rc, ca, cst, impact, ownr, tcd, acd, nt)
  join public.travel_desk_r3675 e
    on e.organization_id = v_org_id and e.record_code = q.rcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance status distribution
create or replace function public.founder_r3675_compliance_status_rollup()
returns table(compliance_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.travel_desk_r3675)
  select l.compliance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.travel_desk_r3675 l
  group by l.compliance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3675_compliance_status_rollup() from public, anon;
grant execute on function public.founder_r3675_compliance_status_rollup() to authenticated;

-- 2) Department scorecard
create or replace function public.founder_r3675_department_scorecard()
returns table(
  department text,
  records bigint,
  trips bigint,
  compliant_records bigint,
  high_risk_records bigint,
  policy_violations bigint,
  avg_advance_pct numeric,
  avg_cost_per_trip_rupees numeric,
  total_spend_rupees numeric,
  out_of_policy_spend_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department,
    count(*)::bigint,
    coalesce(sum(l.trips_booked),0)::bigint,
    count(*) filter (where l.compliance_status = 'compliant')::bigint,
    count(*) filter (where l.compliance_status in ('frequent_violations','uncontrolled','emergency_heavy'))::bigint,
    coalesce(sum(l.policy_violations),0)::bigint,
    round(avg(l.advance_booked_pct), 1),
    round(avg(l.avg_cost_per_trip_rupees), 0),
    coalesce(sum(l.total_travel_spend_rupees),0)::numeric,
    coalesce(sum(l.out_of_policy_spend_rupees),0)::numeric
  from public.travel_desk_r3675 l
  group by l.department
  order by coalesce(sum(l.out_of_policy_spend_rupees),0) desc;
end;
$$;

revoke all on function public.founder_r3675_department_scorecard() from public, anon;
grant execute on function public.founder_r3675_department_scorecard() to authenticated;

-- 3) Booking channel × compliance status matrix
create or replace function public.founder_r3675_channel_status_matrix()
returns table(booking_channel text, compliance_status text, records bigint, trips bigint, policy_violations bigint, out_of_policy_spend_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.booking_channel, l.compliance_status, count(*)::bigint,
    coalesce(sum(l.trips_booked),0)::bigint,
    coalesce(sum(l.policy_violations),0)::bigint,
    coalesce(sum(l.out_of_policy_spend_rupees),0)::numeric
  from public.travel_desk_r3675 l
  group by l.booking_channel, l.compliance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3675_channel_status_matrix() from public, anon;
grant execute on function public.founder_r3675_channel_status_matrix() to authenticated;

-- 4) Monthly spend trend
create or replace function public.founder_r3675_monthly_spend_trend()
returns table(period_month date, records bigint, trips bigint, total_spend_rupees numeric, out_of_policy_spend_rupees numeric, policy_violations bigint, avg_advance_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.trips_booked),0)::bigint,
    coalesce(sum(l.total_travel_spend_rupees),0)::numeric,
    coalesce(sum(l.out_of_policy_spend_rupees),0)::numeric,
    coalesce(sum(l.policy_violations),0)::bigint,
    round(avg(l.avg_advance_days), 1)
  from public.travel_desk_r3675 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3675_monthly_spend_trend() from public, anon;
grant execute on function public.founder_r3675_monthly_spend_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3675_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.out_of_policy_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.travel_desk_capa_actions_r3675 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3675_capa_status_board() from public, anon;
grant execute on function public.founder_r3675_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3675_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.travel_desk_capa_actions_r3675)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.out_of_policy_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.travel_desk_capa_actions_r3675 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3675_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3675_root_cause_pareto() to authenticated;

-- 7) Out-of-policy spend digest by travel type
create or replace function public.founder_r3675_out_of_policy_digest()
returns table(travel_type text, records bigint, trips bigint, policy_violations bigint, out_of_policy_spend_rupees numeric, total_spend_rupees numeric, oop_share_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.travel_type, count(*)::bigint,
    coalesce(sum(l.trips_booked),0)::bigint,
    coalesce(sum(l.policy_violations),0)::bigint,
    coalesce(sum(l.out_of_policy_spend_rupees),0)::numeric,
    coalesce(sum(l.total_travel_spend_rupees),0)::numeric,
    round(100.0 * coalesce(sum(l.out_of_policy_spend_rupees),0) / nullif(coalesce(sum(l.total_travel_spend_rupees),0),0), 1)
  from public.travel_desk_r3675 l
  group by l.travel_type
  order by coalesce(sum(l.out_of_policy_spend_rupees),0) desc;
end;
$$;

revoke all on function public.founder_r3675_out_of_policy_digest() from public, anon;
grant execute on function public.founder_r3675_out_of_policy_digest() to authenticated;

-- 8) High-risk queue (uncontrolled / frequent violations / emergency-heavy)
create or replace function public.founder_r3675_high_risk_queue()
returns table(
  office text,
  department text,
  record_code text,
  travel_type text,
  period_month date,
  booking_channel text,
  compliance_status text,
  trend_dir text,
  policy_violations int,
  out_of_policy_spend_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.office, l.department, l.record_code, l.travel_type, l.period_month,
    l.booking_channel, l.compliance_status, l.trend_dir,
    l.policy_violations, l.out_of_policy_spend_rupees, l.notes
  from public.travel_desk_r3675 l
  where l.compliance_status in ('uncontrolled','frequent_violations','emergency_heavy')
     or l.trend_dir = 'worsening'
     or l.booking_channel = 'emergency'
  order by l.period_month desc, l.out_of_policy_spend_rupees desc nulls last;
end;
$$;

revoke all on function public.founder_r3675_high_risk_queue() from public, anon;
grant execute on function public.founder_r3675_high_risk_queue() to authenticated;
