-- Round 3500: Engineer Installed-Base Service-Coverage-Gap / Orphan-Equipment Tracker
-- Installed-base coverage log — hospital × device model × asset tag × install year × coverage type ×
-- coverage expiry × days uncovered × annual service value × criticality × coverage status × recovery action × CAPA

-- =============================================================================
-- TABLE 1: service_coverage_gap_r3500 — per-asset installed-base coverage record
-- =============================================================================
create table if not exists public.service_coverage_gap_r3500 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_model text not null,
  asset_tag text not null,
  install_year int,
  coverage_type text not null check (coverage_type in (
    'amc','cmc','warranty','uncovered','expired'
  )),
  coverage_expiry date,
  days_uncovered int,
  annual_service_value_rupees numeric(12,2),
  criticality text not null check (criticality in (
    'critical','high','medium','low'
  )),
  coverage_status text not null check (coverage_status in (
    'active','expiring_soon','lapsed','orphan','never_covered'
  )),
  recovery_action text not null check (recovery_action in (
    'renewal_sent','quote_pending','converted','declined','no_action'
  )),
  last_service_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.service_coverage_gap_r3500 enable row level security;

create index if not exists idx_service_coverage_gap_r3500_org on public.service_coverage_gap_r3500(organization_id);
create index if not exists idx_service_coverage_gap_r3500_expiry on public.service_coverage_gap_r3500(coverage_expiry);
create index if not exists idx_service_coverage_gap_r3500_status on public.service_coverage_gap_r3500(coverage_status);

-- =============================================================================
-- TABLE 2: service_coverage_gap_capa_actions_r3500 — CAPA & recovery actions
-- =============================================================================
create table if not exists public.service_coverage_gap_capa_actions_r3500 (
  id uuid primary key default gen_random_uuid(),
  coverage_id uuid not null references public.service_coverage_gap_r3500(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'amc_lapsed_not_renewed','orphan_never_covered','warranty_expired_no_amc','renewal_quote_not_sent',
    'customer_declined_renewal','asset_untraceable','coverage_data_missing','service_overdue_uncovered',
    'duplicate_coverage_billing','high_value_asset_uncovered'
  )),
  root_cause text not null check (root_cause in (
    'renewal_reminder_missed','sales_follow_up_gap','crm_data_stale','customer_budget_freeze',
    'competitor_amc_captured','asset_decommissioned_untracked','pricing_dispute','pending_investigation',
    'install_base_not_onboarded','contract_expiry_not_flagged'
  )),
  corrective_action text not null check (corrective_action in (
    'send_renewal_quote','field_visit_and_audit','reconcile_crm_install_base','offer_discounted_cmc',
    'escalate_to_regional_manager','reclassify_as_decommissioned','convert_to_amc','convert_to_cmc',
    'write_off_uncoverable','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  owner text,
  recoverable_value_rupees numeric(12,2),
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.service_coverage_gap_capa_actions_r3500 enable row level security;

create index if not exists idx_service_coverage_capa_r3500_link on public.service_coverage_gap_capa_actions_r3500(coverage_id);
create index if not exists idx_service_coverage_capa_r3500_status on public.service_coverage_gap_capa_actions_r3500(capa_status);

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

  -- 16 installed-base coverage rows
  insert into public.service_coverage_gap_r3500 (
    organization_id, hospital_name, device_model, asset_tag, install_year, coverage_type,
    coverage_expiry, days_uncovered, annual_service_value_rupees, criticality, coverage_status,
    recovery_action, last_service_date, notes
  )
  select v_org_id, q.hosp, q.dmodel, q.atag, q.iyr, q.ctype,
    q.cexp::date, q.dunc, q.asv, q.crit, q.cstat,
    q.ract, q.lsd::date, q.nt
  from (values
    ('Apollo Chennai','Draeger Evita V500 Ventilator','APL-VNT-014',2019,'amc',
     '2026-11-30',0,185000.00,'critical','active','no_action','2026-06-20','Ventilator under active AMC — renewal due Nov'),
    ('Apollo Chennai','GE Vivid E95 Ultrasound','APL-USG-022',2020,'amc',
     '2026-08-15',0,145000.00,'high','expiring_soon','renewal_sent','2026-06-01','AMC expiring in 45 days — renewal quote sent'),
    ('Fortis Mohali','Philips MX550 Patient Monitor','FRT-MON-101',2018,'expired',
     '2026-02-28',149,62000.00,'high','lapsed','quote_pending','2026-01-10','AMC lapsed Feb; monitor still in ICU use uncovered'),
    ('Fortis Mohali','Mindray SV300 Ventilator','FRT-VNT-108',2017,'uncovered',
     null,320,172000.00,'critical','orphan','no_action','2025-09-05','Critical ventilator never renewed after warranty — orphan'),
    ('Manipal Bengaluru','Siemens Cios Alpha C-Arm','MNP-CARM-045',2021,'warranty',
     '2026-09-30',0,210000.00,'high','active','no_action','2026-05-18','C-arm within OEM warranty'),
    ('Manipal Bengaluru','BPL Defibrillator DF2509','MNP-DEF-051',2016,'uncovered',
     null,540,34000.00,'critical','never_covered','quote_pending',null,'Legacy defib never onboarded to AMC — coverage gap'),
    ('AIIMS Delhi','Nihon Kohden BSM-6000','AIM-MON-210',2019,'cmc',
     '2027-01-31',0,98000.00,'medium','active','no_action','2026-06-15','Comprehensive CMC active'),
    ('AIIMS Delhi','Trivitron Syringe Pump','AIM-PMP-233',2020,'expired',
     '2026-05-31',57,22000.00,'medium','lapsed','converted','2026-04-20','Lapsed May — converted to fresh CMC in Jul'),
    ('CMC Vellore','GE Carescape B650','CMC-MON-311',2018,'amc',
     '2026-10-15',0,118000.00,'high','active','no_action','2026-06-25','Monitor AMC active'),
    ('CMC Vellore','Maquet Servo-i Ventilator','CMC-VNT-318',2015,'uncovered',
     null,410,205000.00,'critical','orphan','renewal_sent','2025-11-12','High-value ventilator orphaned — renewal push underway'),
    ('KIMS Hyderabad','Philips Efficia CM12','KIM-MON-402',2022,'warranty',
     '2026-12-31',0,76000.00,'medium','active','no_action','2026-06-10','Under warranty till Dec'),
    ('KIMS Hyderabad','Erbe VIO 300D Electrosurgery','KIM-ESU-415',2017,'expired',
     '2026-03-31',118,88000.00,'high','lapsed','declined','2026-02-15','Customer declined renewal citing budget freeze'),
    ('Yashoda Hyderabad','Draeger Fabius Anaesthesia','YSH-ANE-501',2019,'amc',
     '2026-08-31',0,156000.00,'critical','expiring_soon','renewal_sent','2026-06-05','Anaesthesia workstation AMC expiring Aug'),
    ('Yashoda Hyderabad','Medtronic Bair Hugger Warmer','YSH-WRM-514',2021,'uncovered',
     null,210,18000.00,'low','never_covered','no_action',null,'Low-value warmer never covered — low priority'),
    ('Kokilaben Mumbai','Toshiba Aplio 500 Ultrasound','KKB-USG-601',2016,'expired',
     '2025-12-31',209,132000.00,'high','orphan','quote_pending','2025-10-08','USG orphaned 7 months — high recoverable value'),
    ('Kokilaben Mumbai','Hamilton C6 Ventilator','KKB-VNT-609',2023,'warranty',
     '2027-03-31',0,240000.00,'critical','active','no_action','2026-06-28','New ventilator under warranty')
  ) as q(hosp, dmodel, atag, iyr, ctype, cexp, dunc, asv, crit, cstat, ract, lsd, nt);

  -- CAPA seed — attach to specific assets by asset_tag
  insert into public.service_coverage_gap_capa_actions_r3500 (
    coverage_id, organization_id, finding_category, root_cause, corrective_action,
    capa_status, owner, recoverable_value_rupees, target_closure_date, actual_closure_date, notes
  )
  select e.id, v_org_id, q.fc, q.rc, q.ca,
    q.cst, q.own, q.rec, q.tcd::date, q.acd::date, q.nt
  from (values
    ('FRT-MON-101','amc_lapsed_not_renewed','renewal_reminder_missed','send_renewal_quote',
     'in_progress','Rohit Sharma',62000.00,'2026-08-10',null,'ICU monitor AMC lapsed 149 days — quote resent'),
    ('FRT-VNT-108','high_value_asset_uncovered','competitor_amc_captured','escalate_to_regional_manager',
     'escalated','Anjali Menon',172000.00,'2026-08-05',null,'Competitor captured AMC; escalated to win back'),
    ('MNP-DEF-051','orphan_never_covered','install_base_not_onboarded','reconcile_crm_install_base',
     'open','Karthik Rao',34000.00,'2026-08-20',null,'Legacy defib absent from CRM install base'),
    ('AIM-PMP-233','amc_lapsed_not_renewed','renewal_reminder_missed','convert_to_cmc',
     'closed','Sunita Verma',22000.00,'2026-07-15','2026-07-12','Converted to CMC and closed'),
    ('CMC-VNT-318','high_value_asset_uncovered','sales_follow_up_gap','send_renewal_quote',
     'verification_pending','Deepak Nair',205000.00,'2026-08-01',null,'Ventilator renewal quote sent — awaiting PO'),
    ('KIM-ESU-415','customer_declined_renewal','customer_budget_freeze','offer_discounted_cmc',
     'escalated','Priya Iyer',88000.00,'2026-07-28',null,'Customer declined — offering discounted CMC'),
    ('YSH-WRM-514','orphan_never_covered','asset_decommissioned_untracked','reclassify_as_decommissioned',
     'closed','Manoj Gupta',18000.00,'2026-07-10','2026-07-08','Warmer decommissioned — reclassified, no coverage needed'),
    ('KKB-USG-601','warranty_expired_no_amc','contract_expiry_not_flagged','convert_to_amc',
     'open','Rahul Desai',132000.00,'2026-08-15',null,'USG warranty expired unflagged — converting to AMC')
  ) as q(atag, fc, rc, ca, cst, own, rec, tcd, acd, nt)
  join public.service_coverage_gap_r3500 e
    on e.organization_id = v_org_id and e.asset_tag = q.atag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Coverage-status distribution
create or replace function public.founder_r3500_coverage_status_rollup()
returns table(coverage_status text, assets bigint, total_value_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.service_coverage_gap_r3500)
  select l.coverage_status, count(*)::bigint,
         coalesce(sum(l.annual_service_value_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.service_coverage_gap_r3500 l
  group by l.coverage_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3500_coverage_status_rollup() from public, anon;
grant execute on function public.founder_r3500_coverage_status_rollup() to authenticated;

-- 2) Coverage-type scorecard
create or replace function public.founder_r3500_coverage_type_scorecard()
returns table(
  coverage_type text,
  assets bigint,
  orphan_assets bigint,
  lapsed_assets bigint,
  critical_assets bigint,
  total_value_rupees numeric,
  avg_days_uncovered numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.coverage_type,
    count(*)::bigint,
    count(*) filter (where l.coverage_status = 'orphan')::bigint,
    count(*) filter (where l.coverage_status = 'lapsed')::bigint,
    count(*) filter (where l.criticality = 'critical')::bigint,
    coalesce(sum(l.annual_service_value_rupees),0)::numeric,
    round(avg(l.days_uncovered), 1)
  from public.service_coverage_gap_r3500 l
  group by l.coverage_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3500_coverage_type_scorecard() from public, anon;
grant execute on function public.founder_r3500_coverage_type_scorecard() to authenticated;

-- 3) Coverage-type × criticality matrix
create or replace function public.founder_r3500_type_criticality_matrix()
returns table(coverage_type text, criticality text, assets bigint, uncovered_assets bigint, total_value_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.coverage_type, l.criticality, count(*)::bigint,
    count(*) filter (where l.coverage_status in ('lapsed','orphan','never_covered'))::bigint,
    coalesce(sum(l.annual_service_value_rupees),0)::numeric
  from public.service_coverage_gap_r3500 l
  group by l.coverage_type, l.criticality
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3500_type_criticality_matrix() from public, anon;
grant execute on function public.founder_r3500_type_criticality_matrix() to authenticated;

-- 4) Monthly coverage-expiry trend
create or replace function public.founder_r3500_monthly_coverage_trend()
returns table(coverage_month date, expiring_assets bigint, total_value_rupees numeric, uncovered_assets bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.coverage_expiry)::date,
    count(*)::bigint,
    coalesce(sum(l.annual_service_value_rupees),0)::numeric,
    count(*) filter (where l.coverage_status in ('lapsed','orphan','never_covered'))::bigint
  from public.service_coverage_gap_r3500 l
  where l.coverage_expiry is not null
  group by date_trunc('month', l.coverage_expiry)
  order by date_trunc('month', l.coverage_expiry) desc;
end;
$$;

revoke execute on function public.founder_r3500_monthly_coverage_trend() from public, anon;
grant execute on function public.founder_r3500_monthly_coverage_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3500_capa_status_board()
returns table(capa_status text, findings bigint, avg_recoverable_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.recoverable_value_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.service_coverage_gap_capa_actions_r3500 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3500_capa_status_board() from public, anon;
grant execute on function public.founder_r3500_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3500_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_recoverable_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.service_coverage_gap_capa_actions_r3500)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.recoverable_value_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.service_coverage_gap_capa_actions_r3500 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3500_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3500_root_cause_pareto() to authenticated;

-- 7) Service-value impact digest (per hospital)
create or replace function public.founder_r3500_service_value_impact_digest()
returns table(
  hospital_name text,
  assets bigint,
  uncovered_assets bigint,
  total_annual_value_rupees numeric,
  value_at_risk_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.coverage_status in ('lapsed','orphan','never_covered'))::bigint,
    coalesce(sum(l.annual_service_value_rupees),0)::numeric,
    coalesce(sum(l.annual_service_value_rupees) filter (where l.coverage_status in ('lapsed','orphan','never_covered','expiring_soon')),0)::numeric
  from public.service_coverage_gap_r3500 l
  group by l.hospital_name
  order by coalesce(sum(l.annual_service_value_rupees) filter (where l.coverage_status in ('lapsed','orphan','never_covered','expiring_soon')),0) desc;
end;
$$;

revoke execute on function public.founder_r3500_service_value_impact_digest() from public, anon;
grant execute on function public.founder_r3500_service_value_impact_digest() to authenticated;

-- 8) High-risk coverage queue (orphan / lapsed / critical-uncovered)
create or replace function public.founder_r3500_high_risk_queue()
returns table(
  hospital_name text,
  device_model text,
  asset_tag text,
  coverage_type text,
  coverage_status text,
  criticality text,
  days_uncovered int,
  annual_service_value_rupees numeric,
  recovery_action text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_model, l.asset_tag, l.coverage_type, l.coverage_status,
    l.criticality, l.days_uncovered, l.annual_service_value_rupees, l.recovery_action, l.notes
  from public.service_coverage_gap_r3500 l
  where l.coverage_status in ('lapsed','orphan','never_covered')
     or (l.criticality in ('critical','high') and l.coverage_type in ('uncovered','expired'))
  order by case l.criticality
             when 'critical' then 0
             when 'high' then 1
             when 'medium' then 2
             else 3
           end,
           l.days_uncovered desc nulls last,
           l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3500_high_risk_queue() from public, anon;
grant execute on function public.founder_r3500_high_risk_queue() to authenticated;
