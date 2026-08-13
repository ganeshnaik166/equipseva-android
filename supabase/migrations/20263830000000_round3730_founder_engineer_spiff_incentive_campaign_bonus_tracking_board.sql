-- Round 3730: Founder Engineer SPIFF / Incentive-Campaign Bonus Tracking Board
-- Field-engineer SPIFF/incentive-campaign bonuses (time-boxed campaigns e.g. AMC-attach drive,
-- spare-parts push) — target vs achievement, payout accuracy/timeliness, campaign ROI x CAPA.
-- Distinct from any sales-commission-attainment-payout page, which is the STANDING sales-team
-- commission plan, not engineer-side time-boxed campaigns.

-- =============================================================================
-- TABLE 1: eng_spiff_r3730 — per-engineer/campaign SPIFF facts
-- =============================================================================
create table if not exists public.eng_spiff_r3730 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  campaign_name text not null,
  period_month date not null,
  campaign_start_date date,
  campaign_end_date date,
  target_units int,
  achieved_units int,
  achievement_pct numeric,
  spiff_amount_rupees numeric(12,2),
  payout_amount_rupees numeric(12,2),
  payout_on_time boolean not null,
  campaign_cost_rupees numeric(12,2),
  incremental_revenue_rupees numeric(12,2),
  campaign_class text not null check (campaign_class in (
    'amc_attach','spare_parts_push','new_lead_referral','upsell_bundle','reactivation_drive'
  )),
  payout_status text not null check (payout_status in (
    'paid_on_time','paid_late','pending','disputed','clawback_applied'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.eng_spiff_r3730 enable row level security;

create index if not exists idx_eng_spiff_r3730_org on public.eng_spiff_r3730(organization_id);
create index if not exists idx_eng_spiff_r3730_month on public.eng_spiff_r3730(period_month);
create index if not exists idx_eng_spiff_r3730_status on public.eng_spiff_r3730(payout_status);

-- =============================================================================
-- TABLE 2: eng_spiff_capa_actions_r3730 — CAPA & SPIFF remediation actions
-- =============================================================================
create table if not exists public.eng_spiff_capa_actions_r3730 (
  id uuid primary key default gen_random_uuid(),
  eng_spiff_id uuid references public.eng_spiff_r3730(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.eng_spiff_capa_actions_r3730 enable row level security;

create index if not exists idx_eng_spiff_capa_r3730_es on public.eng_spiff_capa_actions_r3730(eng_spiff_id);
create index if not exists idx_eng_spiff_capa_r3730_status on public.eng_spiff_capa_actions_r3730(capa_status);

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

  -- 16 SPIFF campaign rows
  insert into public.eng_spiff_r3730 (
    organization_id, engineer_name, campaign_name, period_month,
    campaign_start_date, campaign_end_date, target_units, achieved_units,
    achievement_pct, spiff_amount_rupees, payout_amount_rupees, payout_on_time,
    campaign_cost_rupees, incremental_revenue_rupees, campaign_class, payout_status,
    trend_dir, notes
  )
  select v_org_id, q.eng, q.camp, q.pm::date,
    q.csd::date, q.ced::date, q.tu::int, q.au::int,
    q.apct::numeric, q.sar::numeric, q.par::numeric, q.pot,
    q.ccr::numeric, q.irr::numeric, q.cc, q.ps,
    q.trd, q.nt
  from (values
    ('Arjun Mehta','AMC Attach Drive Q2','2026-06-01','2026-04-01','2026-06-30',
     40,46,115.0,25000.00,25000.00,true,180000.00,940000.00,'amc_attach','paid_on_time','improving',
     'Strong AMC attach on new compressor installs, payout released within SLA'),
    ('Sunita Rao','Spare Parts Push July','2026-07-01','2026-07-01','2026-07-31',
     60,58,96.7,18000.00,18000.00,true,95000.00,410000.00,'spare_parts_push','paid_on_time','stable',
     'Consistent spares attach across AMC visits, payout on schedule'),
    ('Vikram Singh','New Lead Referral Bonanza','2026-07-01','2026-07-01','2026-07-31',
     20,9,45.0,6000.00,6000.00,false,40000.00,150000.00,'new_lead_referral','disputed','worsening',
     'Engineer disputes achieved-unit count, referral tracking mismatch with CRM under review'),
    ('Priya Nair','Upsell Bundle Sprint','2026-06-01','2026-05-15','2026-06-30',
     30,33,110.0,21000.00,21000.00,true,120000.00,560000.00,'upsell_bundle','paid_on_time','improving',
     'Bundle upsell on filter and coolant kits exceeded target comfortably'),
    ('Rohan Kapoor','Reactivation Drive West','2026-06-01','2026-05-01','2026-06-15',
     25,19,76.0,9500.00,9500.00,false,70000.00,260000.00,'reactivation_drive','paid_late','worsening',
     'Payout delayed two cycles due to finance backlog, engineer flagged low morale'),
    ('Meera Iyer','AMC Attach Drive Q2','2026-06-01','2026-04-01','2026-06-30',
     40,52,130.0,30000.00,30000.00,true,180000.00,1120000.00,'amc_attach','paid_on_time','improving',
     'Top performer this cycle, AMC attach rate highest in Hyderabad cluster'),
    ('Karan Malhotra','Spare Parts Push July','2026-07-01','2026-07-01','2026-07-31',
     60,71,118.3,22000.00,0.00,false,95000.00,480000.00,'spare_parts_push','clawback_applied','worsening',
     'Post-payout audit found duplicate parts-invoice claims, clawback initiated'),
    ('Divya Krishnan','New Lead Referral Bonanza','2026-07-01','2026-07-01','2026-07-31',
     20,14,70.0,4200.00,null,false,40000.00,210000.00,'new_lead_referral','pending','stable',
     'Referral verification pending from sales-ops before payout release'),
    ('Sameer Joshi','Upsell Bundle Sprint','2026-06-01','2026-05-15','2026-06-30',
     30,22,73.3,7500.00,7500.00,false,120000.00,290000.00,'upsell_bundle','paid_late','worsening',
     'Payout processed 18 days past SLA, finance cited backlog'),
    ('Ananya Ghosh','Reactivation Drive West','2026-06-01','2026-05-01','2026-06-15',
     25,27,108.0,12000.00,12000.00,true,70000.00,340000.00,'reactivation_drive','paid_on_time','improving',
     'Reactivated dormant AMC accounts ahead of schedule'),
    ('Faisal Ahmed','AMC Attach Drive Q2','2026-05-01','2026-04-01','2026-05-31',
     40,31,77.5,14000.00,14000.00,false,180000.00,610000.00,'amc_attach','disputed','worsening',
     'Engineer contests achieved-unit tally against field visit logs'),
    ('Neha Bhatt','Spare Parts Push July','2026-05-01','2026-05-01','2026-05-31',
     60,63,105.0,19500.00,null,false,95000.00,455000.00,'spare_parts_push','pending','stable',
     'Payout queued, awaiting finance batch run for May cycle'),
    ('Gaurav Desai','New Lead Referral Bonanza','2026-05-01','2026-05-01','2026-05-31',
     20,23,115.0,7200.00,7200.00,true,40000.00,190000.00,'new_lead_referral','paid_on_time','improving',
     'Best referral quarter to date, payout cleared same week'),
    ('Shreya Pillai','Upsell Bundle Sprint','2026-05-01','2026-04-15','2026-05-31',
     30,35,116.7,24000.00,0.00,false,120000.00,600000.00,'upsell_bundle','clawback_applied','worsening',
     'Two upsell deals reversed post-payout after customer cancellation, clawback applied'),
    ('Aditya Verma','Reactivation Drive West','2026-07-01','2026-06-01','2026-07-15',
     25,16,64.0,5800.00,5800.00,false,70000.00,180000.00,'reactivation_drive','paid_late','worsening',
     'Payout delayed pending manager sign-off on reactivation criteria'),
    ('Ritu Chawla','AMC Attach Drive Q2','2026-07-01','2026-06-01','2026-07-31',
     40,37,92.5,17000.00,null,false,180000.00,720000.00,'amc_attach','pending','stable',
     'Payout in finance queue for July AMC-attach cycle')
  ) as q(eng, camp, pm, csd, ced, tu, au, apct, sar, par, pot, ccr, irr, cc, ps, trd, nt);

  -- CAPA seed — attach to specific rows via engineer_name + campaign_name
  insert into public.eng_spiff_capa_actions_r3730 (
    eng_spiff_id, root_cause, corrective_action,
    capa_status, owner, target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca,
    q.cst, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('Vikram Singh','New Lead Referral Bonanza','Referral tracking tool logs leads a cycle behind CRM','Sync referral tracker with CRM nightly and re-audit disputed count','in_progress','Sales Ops Lead','2026-08-25',null,'Referral count re-audit in progress with engineer present'),
    ('Karan Malhotra','Spare Parts Push July','Duplicate parts invoices submitted across two service tickets','Add invoice-dedup check to SPIFF payout pipeline before disbursal','closed','Finance Controller','2026-07-20','2026-07-18','Dedup check deployed, clawback of duplicate amount recovered from next cycle payout'),
    ('Divya Krishnan','New Lead Referral Bonanza','Sales-ops verification queue backlogged for referral leads','Add dedicated reviewer slot for SPIFF referral verification','open','Sales Ops Manager','2026-08-20',null,'Escalated after one-week SLA breach on referral verification'),
    ('Rohan Kapoor','Reactivation Drive West','Finance payout batch run delayed by month-end close overlap','Move SPIFF payout batch ahead of month-end close in finance calendar','in_progress','Finance Controller','2026-08-30',null,'Payout calendar change proposed, awaiting finance-ops sign-off'),
    ('Faisal Ahmed','AMC Attach Drive Q2','Field visit log app under-recorded attach events on poor network days','Enable offline-sync mode for field visit app in low-connectivity zones','open','Regional Service Head','2026-09-01',null,'Offline-sync fix scheduled for next app release'),
    ('Neha Bhatt','Spare Parts Push July','Finance batch run for May cycle missed the standard payout window','Add automated alert for missed monthly SPIFF batch runs','closed','Finance Controller','2026-07-10','2026-07-08','May-cycle payout released after manual batch trigger, alert now live'),
    ('Shreya Pillai','Upsell Bundle Sprint','Upsell deals counted as achieved before customer cancellation window closed','Hold SPIFF credit until post-cancellation window expires','overdue','Sales Ops Lead','2026-08-05',null,'Policy change drafted, pending sign-off before rollout; deadline slipped once'),
    ('Aditya Verma','Reactivation Drive West','Manager sign-off step added mid-campaign without engineer notice','Communicate sign-off requirement at campaign kickoff going forward','in_progress','Regional Service Head','2026-08-28',null,'Sign-off obtained for this cycle, process update being documented')
  ) as q(eng, camp, rc, ca, cst, ownr, tcd, acd, nt)
  join public.eng_spiff_r3730 e
    on e.organization_id = v_org_id and e.engineer_name = q.eng and e.campaign_name = q.camp;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Payout-status distribution
create or replace function public.founder_r3730_payout_status_rollup()
returns table(payout_status text, campaigns bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.eng_spiff_r3730)
  select l.payout_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.eng_spiff_r3730 l
  group by l.payout_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3730_payout_status_rollup() from public, anon;
grant execute on function public.founder_r3730_payout_status_rollup() to authenticated;

-- 2) Engineer scorecard
create or replace function public.founder_r3730_engineer_scorecard()
returns table(
  engineer_name text,
  campaigns bigint,
  paid_on_time bigint,
  paid_late bigint,
  disputed bigint,
  clawback_applied bigint,
  avg_achievement_pct numeric,
  total_spiff_amount_rupees numeric,
  total_payout_amount_rupees numeric
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
    count(*) filter (where l.payout_status = 'paid_on_time')::bigint,
    count(*) filter (where l.payout_status = 'paid_late')::bigint,
    count(*) filter (where l.payout_status = 'disputed')::bigint,
    count(*) filter (where l.payout_status = 'clawback_applied')::bigint,
    round(avg(l.achievement_pct), 1),
    coalesce(sum(l.spiff_amount_rupees),0)::numeric,
    coalesce(sum(l.payout_amount_rupees),0)::numeric
  from public.eng_spiff_r3730 l
  group by l.engineer_name
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3730_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3730_engineer_scorecard() to authenticated;

-- 3) Campaign-class x payout-status matrix
create or replace function public.founder_r3730_campaign_class_status_matrix()
returns table(campaign_class text, payout_status text, campaigns bigint, avg_achievement_pct numeric, avg_spiff_amount_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.campaign_class, l.payout_status, count(*)::bigint,
    round(avg(l.achievement_pct), 1),
    round(avg(l.spiff_amount_rupees), 2)
  from public.eng_spiff_r3730 l
  group by l.campaign_class, l.payout_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3730_campaign_class_status_matrix() from public, anon;
grant execute on function public.founder_r3730_campaign_class_status_matrix() to authenticated;

-- 4) Monthly achievement trend
create or replace function public.founder_r3730_monthly_achievement_trend()
returns table(period_month date, campaigns bigint, avg_achievement_pct numeric, total_spiff_amount_rupees numeric, on_time_payouts bigint, worsening_campaigns bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.achievement_pct), 1),
    coalesce(sum(l.spiff_amount_rupees),0)::numeric,
    count(*) filter (where l.payout_on_time = true)::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.eng_spiff_r3730 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3730_monthly_achievement_trend() from public, anon;
grant execute on function public.founder_r3730_monthly_achievement_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3730_capa_status_board()
returns table(capa_status text, findings bigint, closed_count bigint, overdue_count bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'closed')::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.eng_spiff_capa_actions_r3730 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3730_capa_status_board() from public, anon;
grant execute on function public.founder_r3730_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3730_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.eng_spiff_capa_actions_r3730)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.eng_spiff_capa_actions_r3730 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3730_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3730_root_cause_pareto() to authenticated;

-- 7) Campaign ROI digest (weak-ROI risk: incremental revenue under 3x campaign cost)
create or replace function public.founder_r3730_campaign_roi_digest()
returns table(
  engineer_name text,
  campaign_name text,
  period_month date,
  campaign_cost_rupees numeric,
  incremental_revenue_rupees numeric,
  roi_ratio numeric,
  spiff_amount_rupees numeric,
  payout_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.campaign_name, l.period_month,
    l.campaign_cost_rupees, l.incremental_revenue_rupees,
    round(l.incremental_revenue_rupees / nullif(l.campaign_cost_rupees,0), 2),
    l.spiff_amount_rupees, l.payout_status, l.notes
  from public.eng_spiff_r3730 l
  where l.campaign_cost_rupees is not null
    and l.incremental_revenue_rupees is not null
    and (l.incremental_revenue_rupees / nullif(l.campaign_cost_rupees,0)) < 3
  order by (l.incremental_revenue_rupees / nullif(l.campaign_cost_rupees,0)) asc;
end;
$$;

revoke all on function public.founder_r3730_campaign_roi_digest() from public, anon;
grant execute on function public.founder_r3730_campaign_roi_digest() to authenticated;

-- 8) High-risk payout queue (disputed / clawback-applied campaigns)
create or replace function public.founder_r3730_high_risk_queue()
returns table(
  engineer_name text,
  campaign_name text,
  period_month date,
  payout_status text,
  achievement_pct numeric,
  spiff_amount_rupees numeric,
  payout_amount_rupees numeric,
  campaign_cost_rupees numeric,
  incremental_revenue_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.campaign_name, l.period_month, l.payout_status,
    l.achievement_pct, l.spiff_amount_rupees, l.payout_amount_rupees,
    l.campaign_cost_rupees, l.incremental_revenue_rupees, l.notes
  from public.eng_spiff_r3730 l
  where l.payout_status in ('disputed','clawback_applied')
  order by l.achievement_pct asc nulls last, l.period_month desc
  limit 20;
end;
$$;

revoke all on function public.founder_r3730_high_risk_queue() from public, anon;
grant execute on function public.founder_r3730_high_risk_queue() to authenticated;
