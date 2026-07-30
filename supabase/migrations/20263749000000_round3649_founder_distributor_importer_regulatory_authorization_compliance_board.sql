-- Round 3649: Founder Distributor / Importer Regulatory-Authorization Compliance Board
-- Distributor / importer regulatory-authorization (Form MD-42 wholesale licence) + compliance per partner:
-- partner type × territory × licence expiry × cold-chain capability × complaints routed × training completion ×
-- audit score × authorization status × trend × CAPA closure.

-- =============================================================================
-- TABLE 1: distributor_auth_r3649 — per-partner regulatory-authorization compliance
-- =============================================================================
create table if not exists public.distributor_auth_r3649 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  partner_name text not null,
  partner_code text not null,
  partner_type text not null check (partner_type in (
    'distributor','importer','c_and_f','stockist','e_pharmacy'
  )),
  territory text not null,
  period_month date not null,
  wholesale_licence_no text not null,
  licence_expiry date,
  days_to_expiry int,
  cold_chain_capable boolean not null,
  complaints_routed int,
  training_completion_pct numeric(5,2),
  audit_score numeric(5,2),
  last_audit_date date,
  authorization_status text not null check (authorization_status in (
    'authorized','renewal_due','conditional','suspended','delisted'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.distributor_auth_r3649 enable row level security;

create index if not exists idx_distributor_auth_r3649_org on public.distributor_auth_r3649(organization_id);
create index if not exists idx_distributor_auth_r3649_month on public.distributor_auth_r3649(period_month);
create index if not exists idx_distributor_auth_r3649_status on public.distributor_auth_r3649(authorization_status);

-- =============================================================================
-- TABLE 2: distributor_auth_capa_actions_r3649 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.distributor_auth_capa_actions_r3649 (
  id uuid primary key default gen_random_uuid(),
  auth_log_id uuid not null references public.distributor_auth_r3649(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'licence_expired','renewal_overdue','cold_chain_gap','training_shortfall',
    'audit_score_low','complaint_routing_failure','documentation_gap','unauthorized_distribution'
  )),
  root_cause text not null check (root_cause in (
    'renewal_not_filed','warehouse_temperature_excursion','staff_turnover','process_not_followed',
    'vendor_delay','record_keeping_lapse','regulatory_change','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'file_renewal_application','install_cold_chain_equipment','retrain_partner_staff','conduct_reaudit',
    'issue_show_cause_notice','suspend_authorization','delist_partner','update_sop','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cdsco_notifiable','state_licensing_finding','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.distributor_auth_capa_actions_r3649 enable row level security;

create index if not exists idx_distributor_auth_capa_r3649_log on public.distributor_auth_capa_actions_r3649(auth_log_id);
create index if not exists idx_distributor_auth_capa_r3649_status on public.distributor_auth_capa_actions_r3649(capa_status);

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

  -- 16 partner authorization rows
  insert into public.distributor_auth_r3649 (
    organization_id, partner_name, partner_code, partner_type, territory, period_month,
    wholesale_licence_no, licence_expiry, days_to_expiry, cold_chain_capable, complaints_routed,
    training_completion_pct, audit_score, last_audit_date, authorization_status, trend_dir, notes
  )
  select v_org_id, q.pname, q.pcode, q.ptype, q.terr, q.pmonth::date,
    q.lno, q.lexp::date, q.dexp, q.cold, q.compl,
    q.trn, q.audsc, q.ladt::date, q.astat, q.trnd, q.nt
  from (values
    ('MedEquip Distributors Pvt Ltd','DIST-MH-01','distributor','Maharashtra','2026-07-01',
     'MH-WL-MD42-11023','2027-03-15',258,true,3,94.0,88.5,'2026-06-10','authorized','stable','Full-line distributor Mumbai — Form MD-42 valid, cold-chain enabled'),
    ('Surgicare Imports LLP','IMP-DL-02','importer','Delhi-NCR','2026-07-01',
     'DL-WL-MD42-20881','2026-09-05',37,true,5,81.0,74.0,'2026-05-22','renewal_due','worsening','Importer of ventilators & monitors — renewal window open, training lagging'),
    ('SouthMed C&F Agencies','CNF-KA-03','c_and_f','Karnataka','2026-07-01',
     'KA-WL-MD42-33410','2027-01-20',204,true,1,90.0,85.0,'2026-06-01','authorized','improving','C&F agent Bengaluru — cold-chain warehouse audited clean'),
    ('Kerala Health Stockists','STK-KL-04','stockist','Kerala','2026-07-01',
     'KL-WL-MD42-44190','2026-08-12',13,false,7,66.0,61.5,'2026-04-30','renewal_due','worsening','Stockist Kochi — licence near expiry, no cold-chain, complaints high'),
    ('PharmEasy Devices','EPH-PAN-05','e_pharmacy','Pan-India','2026-07-01',
     'TS-WL-MD42-55002','2027-06-30',335,true,2,88.0,82.0,'2026-06-15','authorized','stable','E-pharmacy device fulfilment — pan-India MD-42 valid'),
    ('Gujarat Meditech Distributors','DIST-GJ-06','distributor','Gujarat','2026-07-01',
     'GJ-WL-MD42-66713','2026-06-20',-11,true,9,58.0,52.0,'2026-03-15','suspended','worsening','Suspended — Form MD-42 expired, CDSCO show-cause pending'),
    ('Eastern Surgicals C&F','CNF-WB-07','c_and_f','West Bengal','2026-07-01',
     'WB-WL-MD42-77234','2026-12-01',153,false,2,79.0,71.0,'2026-05-18','conditional','stable','Conditional authorization pending cold-chain upgrade'),
    ('Chennai MedImports','IMP-TN-08','importer','Tamil Nadu','2026-07-01',
     'TN-WL-MD42-88120','2027-02-28',242,true,0,96.0,91.0,'2026-06-20','authorized','improving','Importer of infusion pumps — strong audit, zero complaints'),
    ('Rajasthan Device Stockists','STK-RJ-09','stockist','Rajasthan','2026-07-01',
     'RJ-WL-MD42-99001','2026-08-30',60,false,4,72.0,68.0,'2026-04-10','renewal_due','stable','Stockist Jaipur — renewal due in 60 days, training moderate'),
    ('Apollo Pharmacy Devices','EPH-PAN-10','e_pharmacy','Pan-India','2026-07-01',
     'KA-WL-MD42-10233','2027-05-15',318,true,1,91.0,86.0,'2026-06-25','authorized','stable','E-pharmacy channel — defibrillator & monitor fulfilment authorized'),
    ('North India Meditech','DIST-DL-11','distributor','Delhi-NCR','2026-07-01',
     'DL-WL-MD42-11890','2026-09-20',82,true,6,68.0,64.0,'2026-05-05','renewal_due','worsening','Distributor Delhi — complaints trending up, renewal due'),
    ('Hyderabad MedC&F','CNF-TS-12','c_and_f','Telangana','2026-07-01',
     'TS-WL-MD42-22456','2027-04-10',283,true,3,85.0,80.0,'2026-06-08','authorized','improving','C&F Hyderabad — C-arm & imaging logistics, cold-chain OK'),
    ('Punjab Surgical Stockists','STK-PB-13','stockist','Punjab','2026-07-01',
     'PB-WL-MD42-33678','2026-07-15',14,false,8,55.0,49.0,'2026-02-20','suspended','worsening','Suspended stockist — audit score below threshold, licence near expiry'),
    ('Coastal Imports Pvt Ltd','IMP-GA-14','importer','Goa','2026-07-01',
     'GA-WL-MD42-44120','2026-11-05',127,true,2,83.0,77.0,'2026-05-30','authorized','stable','Importer Goa — dialysis machine imports, licence valid'),
    ('MP Health Distributors','DIST-MP-15','distributor','Madhya Pradesh','2026-07-01',
     'MP-WL-MD42-55901','2026-06-10',-21,false,11,48.0,44.0,'2026-01-15','delisted','worsening','Delisted — repeated non-compliance, Form MD-42 lapsed, no cold-chain'),
    ('MediBuddy Devices','EPH-PAN-16','e_pharmacy','Pan-India','2026-07-01',
     'MH-WL-MD42-66044','2027-07-01',365,true,0,93.0,89.0,'2026-06-28','authorized','improving','E-pharmacy — newly onboarded, strong compliance baseline')
  ) as q(pname, pcode, ptype, terr, pmonth, lno, lexp, dexp, cold, compl, trn, audsc, ladt, astat, trnd, nt);

  -- CAPA seed — attach to specific partners via partner_code
  insert into public.distributor_auth_capa_actions_r3649 (
    auth_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.ownr, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('IMP-DL-02','renewal_overdue','renewal_not_filed','file_renewal_application','in_progress','state_licensing_finding','Regulatory Affairs','2026-08-01',null,25000.00,'MD-42 renewal application in progress with state FDA'),
    ('STK-KL-04','cold_chain_gap','warehouse_temperature_excursion','install_cold_chain_equipment','open','cdsco_notifiable','Quality Head','2026-08-20',null,180000.00,'Cold-chain unit to be installed at Kochi warehouse'),
    ('DIST-GJ-06','licence_expired','renewal_not_filed','issue_show_cause_notice','escalated','cdsco_notifiable','Regulatory Affairs','2026-07-20',null,0.00,'Show-cause issued — licence lapsed, distribution halted'),
    ('CNF-WB-07','cold_chain_gap','vendor_delay','install_cold_chain_equipment','verification_pending','state_licensing_finding','Operations','2026-08-15',null,145000.00,'Cold-chain upgrade nearing completion — verification pending'),
    ('DIST-DL-11','complaint_routing_failure','process_not_followed','update_sop','open','internal_only','Quality Head','2026-08-05',null,12000.00,'Complaint routing SOP revised — retraining scheduled'),
    ('STK-PB-13','audit_score_low','staff_turnover','retrain_partner_staff','in_progress','state_licensing_finding','Training Lead','2026-08-10',null,30000.00,'Partner re-audit and staff retraining underway'),
    ('DIST-MP-15','unauthorized_distribution','record_keeping_lapse','delist_partner','closed','cdsco_notifiable','Regulatory Affairs','2026-06-30','2026-06-25',0.00,'Partner delisted — CDSCO notified, stock recalled'),
    ('STK-RJ-09','training_shortfall','staff_turnover','retrain_partner_staff','overdue','internal_only','Training Lead','2026-06-25',null,18000.00,'Training completion below target — overdue, escalating')
  ) as q(pcode, fc, rc, ca, cst, ri, ownr, tcd, acd, cost, nt)
  join public.distributor_auth_r3649 e
    on e.organization_id = v_org_id and e.partner_code = q.pcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Authorization status distribution
create or replace function public.founder_r3649_authorization_status_rollup()
returns table(authorization_status text, partners bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.distributor_auth_r3649)
  select l.authorization_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.distributor_auth_r3649 l
  group by l.authorization_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3649_authorization_status_rollup() from public, anon;
grant execute on function public.founder_r3649_authorization_status_rollup() to authenticated;

-- 2) Partner-type scorecard
create or replace function public.founder_r3649_partner_type_scorecard()
returns table(
  partner_type text,
  total_partners bigint,
  authorized bigint,
  renewal_due bigint,
  suspended bigint,
  cold_chain_partners bigint,
  avg_audit_score numeric,
  avg_training_pct numeric,
  authorized_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.partner_type,
    count(*)::bigint,
    count(*) filter (where l.authorization_status = 'authorized')::bigint,
    count(*) filter (where l.authorization_status = 'renewal_due')::bigint,
    count(*) filter (where l.authorization_status in ('suspended','delisted'))::bigint,
    count(*) filter (where l.cold_chain_capable = true)::bigint,
    round(avg(l.audit_score), 1),
    round(avg(l.training_completion_pct), 1),
    round(100.0 * count(*) filter (where l.authorization_status = 'authorized')::numeric / nullif(count(*),0), 1)
  from public.distributor_auth_r3649 l
  group by l.partner_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3649_partner_type_scorecard() from public, anon;
grant execute on function public.founder_r3649_partner_type_scorecard() to authenticated;

-- 3) Partner-type × authorization-status matrix
create or replace function public.founder_r3649_partner_type_status_matrix()
returns table(partner_type text, authorization_status text, partners bigint, avg_days_to_expiry numeric, avg_audit_score numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.partner_type, l.authorization_status, count(*)::bigint,
    round(avg(l.days_to_expiry), 1),
    round(avg(l.audit_score), 1)
  from public.distributor_auth_r3649 l
  group by l.partner_type, l.authorization_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3649_partner_type_status_matrix() from public, anon;
grant execute on function public.founder_r3649_partner_type_status_matrix() to authenticated;

-- 4) Monthly authorization trend
create or replace function public.founder_r3649_monthly_authorization_trend()
returns table(period_month date, partners bigint, authorized bigint, renewal_due bigint, suspended bigint, avg_audit_score numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.authorization_status = 'authorized')::bigint,
    count(*) filter (where l.authorization_status = 'renewal_due')::bigint,
    count(*) filter (where l.authorization_status in ('suspended','delisted'))::bigint,
    round(avg(l.audit_score), 1)
  from public.distributor_auth_r3649 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3649_monthly_authorization_trend() from public, anon;
grant execute on function public.founder_r3649_monthly_authorization_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3649_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.distributor_auth_capa_actions_r3649 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3649_capa_status_board() from public, anon;
grant execute on function public.founder_r3649_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3649_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.distributor_auth_capa_actions_r3649)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.distributor_auth_capa_actions_r3649 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3649_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3649_root_cause_pareto() to authenticated;

-- 7) Expiry-exposure digest
create or replace function public.founder_r3649_expiry_exposure_digest()
returns table(expiry_bucket text, partners bigint, cold_chain_partners bigint, avg_days_to_expiry numeric, min_days_to_expiry int)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select case
      when l.days_to_expiry is null then 'unknown'
      when l.days_to_expiry < 0 then 'expired'
      when l.days_to_expiry <= 30 then 'lte_30_days'
      when l.days_to_expiry <= 90 then 'lte_90_days'
      when l.days_to_expiry <= 180 then 'lte_180_days'
      else 'over_180_days'
    end as expiry_bucket,
    count(*)::bigint,
    count(*) filter (where l.cold_chain_capable = true)::bigint,
    round(avg(l.days_to_expiry), 1),
    min(l.days_to_expiry)
  from public.distributor_auth_r3649 l
  group by 1
  order by min(l.days_to_expiry);
end;
$$;

revoke execute on function public.founder_r3649_expiry_exposure_digest() from public, anon;
grant execute on function public.founder_r3649_expiry_exposure_digest() to authenticated;

-- 8) High-risk authorization queue (suspended / renewal_due / conditional / delisted / near-expiry)
create or replace function public.founder_r3649_high_risk_queue()
returns table(
  partner_name text,
  partner_code text,
  partner_type text,
  territory text,
  period_month date,
  authorization_status text,
  wholesale_licence_no text,
  licence_expiry date,
  days_to_expiry int,
  audit_score numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.partner_name, l.partner_code, l.partner_type, l.territory, l.period_month,
    l.authorization_status, l.wholesale_licence_no, l.licence_expiry, l.days_to_expiry,
    l.audit_score, l.notes
  from public.distributor_auth_r3649 l
  where l.authorization_status in ('suspended','renewal_due','conditional','delisted')
     or l.days_to_expiry <= 60
     or l.audit_score < 70
     or l.cold_chain_capable = false
  order by l.days_to_expiry asc nulls last, l.audit_score asc;
end;
$$;

revoke execute on function public.founder_r3649_high_risk_queue() from public, anon;
grant execute on function public.founder_r3649_high_risk_queue() to authenticated;
