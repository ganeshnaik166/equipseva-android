-- Round 3280: Engineer Field-Service Charge-Capture & Billing-Accuracy Tracker
-- Revenue integrity — per completed job: parts + labour + visit charges captured vs billed,
-- coverage classification, invoice status, billing-gap leak detection, capture verdict × CAPA recovery

-- =============================================================================
-- TABLE 1: service_charge_capture_r3280 — per completed job charge-capture audit
-- =============================================================================
create table if not exists public.service_charge_capture_r3280 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  region text not null,
  job_code text not null,
  service_type text not null check (service_type in (
    'breakdown_repair','preventive_maintenance','installation','calibration','amc_visit','warranty'
  )),
  job_close_date date not null,
  parts_used_value_rupees numeric(12,2) not null,
  parts_billed_value_rupees numeric(12,2) not null,
  labour_hours numeric(6,2) not null,
  labour_billed_rupees numeric(12,2) not null,
  visit_charge_rupees numeric(12,2) not null,
  contract_coverage text not null check (contract_coverage in (
    'amc_covered','warranty_covered','chargeable','goodwill_free'
  )),
  invoice_raised boolean not null,
  billing_gap_rupees numeric(12,2) not null,
  gap_reason text not null check (gap_reason in (
    'no_gap','amc_misclassified','parts_not_logged','labour_undercharged','free_goodwill','pending_invoice','duplicate'
  )),
  capture_verdict text not null check (capture_verdict in (
    'accurate','minor_leak','major_leak','not_invoiced','under_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.service_charge_capture_r3280 enable row level security;

create index if not exists idx_service_charge_capture_r3280_org on public.service_charge_capture_r3280(organization_id);
create index if not exists idx_service_charge_capture_r3280_date on public.service_charge_capture_r3280(job_close_date);
create index if not exists idx_service_charge_capture_r3280_verdict on public.service_charge_capture_r3280(capture_verdict);

-- =============================================================================
-- TABLE 2: service_charge_capture_capa_actions_r3280 — recovery / invoicing CAPA actions
-- =============================================================================
create table if not exists public.service_charge_capture_capa_actions_r3280 (
  id uuid primary key default gen_random_uuid(),
  capture_log_id uuid not null references public.service_charge_capture_r3280(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'parts_not_billed','labour_undercharged','visit_charge_missed','amc_misclassification',
    'duplicate_charge','pending_invoice','goodwill_leak'
  )),
  root_cause text not null check (root_cause in (
    'parts_not_logged_in_app','coverage_misclassified','rate_card_outdated','engineer_data_entry_gap',
    'invoice_not_raised','duplicate_entry','deliberate_goodwill','pending_customer_po'
  )),
  corrective_action text not null check (corrective_action in (
    'raise_supplementary_invoice','reclassify_coverage','log_missing_parts','update_rate_card',
    'retrain_engineer','cancel_duplicate','write_off_approved','recover_from_customer','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  revenue_impact text not null check (revenue_impact in (
    'full_recovery','partial_recovery','write_off','goodwill_retained','disputed','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  recovery_amount_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.service_charge_capture_capa_actions_r3280 enable row level security;

create index if not exists idx_service_charge_capture_capa_r3280_log on public.service_charge_capture_capa_actions_r3280(capture_log_id);
create index if not exists idx_service_charge_capture_capa_r3280_status on public.service_charge_capture_capa_actions_r3280(capa_status);

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

  -- 14 charge-capture job rows
  insert into public.service_charge_capture_r3280 (
    organization_id, engineer_name, region, job_code, service_type, job_close_date,
    parts_used_value_rupees, parts_billed_value_rupees, labour_hours, labour_billed_rupees,
    visit_charge_rupees, contract_coverage, invoice_raised, billing_gap_rupees,
    gap_reason, capture_verdict, notes
  )
  select v_org_id, q.eng, q.reg, q.jc, q.st, q.jcd::date,
    q.puv, q.pbv, q.lh, q.lbr,
    q.vc, q.cc, q.inv, q.gap,
    q.gr, q.cv, q.nt
  from (values
    ('Rajesh Kumar','Chennai','JOB-CHN-2401','breakdown_repair','2026-07-10',
     8500.00,8500.00,3.50,3500.00,1500.00,'chargeable',true,0.00,'no_gap','accurate','Apollo Chennai — full charge-capture, invoice raised same day'),
    ('Suresh Nair','Chennai','JOB-CHN-2402','preventive_maintenance','2026-07-09',
     1200.00,0.00,2.00,0.00,0.00,'amc_covered',true,0.00,'no_gap','accurate','Apollo Chennai — AMC PM visit correctly non-chargeable, consumables under contract'),
    ('Karthik Iyer','Bengaluru','JOB-BLR-3301','breakdown_repair','2026-07-08',
     15000.00,0.00,4.00,0.00,0.00,'amc_covered',false,15000.00,'amc_misclassified','major_leak','Manipal Bengaluru — closed as AMC but device out of contract, Rs15k parts unrecovered'),
    ('Vikram Reddy','Hyderabad','JOB-HYD-4401','installation','2026-07-08',
     45000.00,45000.00,6.00,9000.00,2000.00,'chargeable',true,0.00,'no_gap','accurate','KIMS Hyderabad — new ventilator install, full invoice raised'),
    ('Manoj Pillai','Vellore','JOB-VEL-5501','calibration','2026-07-07',
     0.00,0.00,2.50,0.00,0.00,'chargeable',false,6250.00,'labour_undercharged','not_invoiced','CMC Vellore — calibration labour never invoiced, 2.5h @ Rs2500 unbilled'),
    ('Anil Deshmukh','Gurgaon','JOB-GGN-6601','breakdown_repair','2026-07-07',
     9800.00,6000.00,3.00,3000.00,1500.00,'chargeable',true,3800.00,'parts_not_logged','minor_leak','Fortis Gurgaon — parts partially logged, Rs3.8k under-billed'),
    ('Farhan Sheikh','Delhi','JOB-DEL-7701','warranty','2026-07-06',
     22000.00,0.00,5.00,0.00,0.00,'warranty_covered',false,0.00,'no_gap','accurate','AIIMS Delhi — in-warranty board replacement, correctly zero-billed to customer'),
    ('Deepak Sharma','Delhi','JOB-DEL-7702','amc_visit','2026-07-06',
     800.00,0.00,1.50,0.00,0.00,'amc_covered',true,0.00,'no_gap','accurate','AIIMS Delhi — scheduled AMC visit closed under contract'),
    ('Sanjay Gupta','Gurgaon','JOB-GGN-6602','breakdown_repair','2026-07-05',
     12000.00,12000.00,4.00,4000.00,1500.00,'chargeable',false,17500.00,'pending_invoice','not_invoiced','Fortis Gurgaon — work done + parts logged, invoice pending customer PO, Rs17.5k at risk'),
    ('Ramesh Patel','Bengaluru','JOB-BLR-3302','preventive_maintenance','2026-07-05',
     3500.00,3500.00,2.00,2000.00,1000.00,'chargeable',true,0.00,'no_gap','accurate','Manipal Bengaluru — chargeable PM, full capture'),
    ('Karthik Iyer','Bengaluru','JOB-BLR-3303','breakdown_repair','2026-07-04',
     6000.00,6000.00,3.00,3000.00,1500.00,'chargeable',true,-10500.00,'duplicate','under_review','Manipal Bengaluru — second invoice raised for same job, Rs10.5k duplicate under review'),
    ('Suresh Nair','Chennai','JOB-CHN-2403','breakdown_repair','2026-07-04',
     4200.00,0.00,2.00,0.00,0.00,'goodwill_free',false,4200.00,'free_goodwill','minor_leak','Apollo Chennai — engineer waived charge as goodwill without approval, Rs4.2k leak'),
    ('Vikram Reddy','Hyderabad','JOB-HYD-4402','calibration','2026-07-03',
     0.00,0.00,3.00,3000.00,1200.00,'chargeable',true,0.00,'no_gap','accurate','KIMS Hyderabad — calibration invoiced fully'),
    ('Manoj Pillai','Vellore','JOB-VEL-5502','breakdown_repair','2026-07-03',
     28000.00,20000.00,5.00,5000.00,1500.00,'chargeable',true,8000.00,'parts_not_logged','minor_leak','CMC Vellore — high-value parts under-logged, Rs8k missing from invoice')
  ) as q(eng, reg, jc, st, jcd, puv, pbv, lh, lbr, vc, cc, inv, gap, gr, cv, nt);

  -- CAPA seed — attach to specific jobs via job_code
  insert into public.service_charge_capture_capa_actions_r3280 (
    capture_log_id, finding_category, root_cause, corrective_action,
    capa_status, revenue_impact, target_closure_date, actual_closure_date,
    recovery_amount_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.amt, q.nt
  from (values
    ('JOB-BLR-3301','amc_misclassification','coverage_misclassified','reclassify_coverage','in_progress','partial_recovery','2026-07-14',null,15000.00,'Device confirmed out of AMC — raising chargeable invoice for Rs15k parts'),
    ('JOB-VEL-5501','labour_undercharged','invoice_not_raised','raise_supplementary_invoice','open','full_recovery','2026-07-15',null,6250.00,'Calibration labour to be invoiced, customer notified'),
    ('JOB-GGN-6601','parts_not_billed','parts_not_logged_in_app','log_missing_parts','closed','full_recovery','2026-07-10','2026-07-09',3800.00,'Missing parts logged and supplementary invoice raised — recovered'),
    ('JOB-GGN-6602','pending_invoice','pending_customer_po','raise_supplementary_invoice','escalated','full_recovery','2026-07-12',null,17500.00,'Awaiting customer PO — escalated to account manager, Rs17.5k at risk'),
    ('JOB-BLR-3303','duplicate_charge','duplicate_entry','cancel_duplicate','verification_pending','disputed','2026-07-11',null,0.00,'Duplicate invoice identified — credit note to be issued, no net revenue'),
    ('JOB-CHN-2403','goodwill_leak','deliberate_goodwill','write_off_approved','closed','goodwill_retained','2026-07-08','2026-07-08',0.00,'Goodwill waiver retro-approved by regional head — no recovery pursued'),
    ('JOB-VEL-5502','parts_not_billed','engineer_data_entry_gap','retrain_engineer','overdue','partial_recovery','2026-07-09',null,8000.00,'Engineer retrained on parts logging, partial recovery pending — past due')
  ) as q(jc, fc, rc, ca, cst, ri, tcd, acd, amt, nt)
  join public.service_charge_capture_r3280 e
    on e.organization_id = v_org_id and e.job_code = q.jc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Capture verdict distribution
create or replace function public.founder_r3280_capture_verdict_rollup()
returns table(capture_verdict text, jobs bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.service_charge_capture_r3280)
  select l.capture_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.service_charge_capture_r3280 l
  group by l.capture_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3280_capture_verdict_rollup() from public, anon;
grant execute on function public.founder_r3280_capture_verdict_rollup() to authenticated;

-- 2) Engineer-level charge-capture scorecard
create or replace function public.founder_r3280_engineer_scorecard()
returns table(
  engineer_name text,
  total_jobs bigint,
  accurate bigint,
  minor_leak bigint,
  major_leak bigint,
  not_invoiced bigint,
  total_gap_rupees numeric,
  accuracy_pct numeric
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
    count(*) filter (where l.capture_verdict = 'accurate')::bigint,
    count(*) filter (where l.capture_verdict = 'minor_leak')::bigint,
    count(*) filter (where l.capture_verdict = 'major_leak')::bigint,
    count(*) filter (where l.capture_verdict = 'not_invoiced')::bigint,
    coalesce(sum(l.billing_gap_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.capture_verdict = 'accurate')::numeric / nullif(count(*),0), 1)
  from public.service_charge_capture_r3280 l
  group by l.engineer_name
  order by coalesce(sum(l.billing_gap_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3280_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3280_engineer_scorecard() to authenticated;

-- 3) Service-type × contract-coverage matrix
create or replace function public.founder_r3280_service_coverage_matrix()
returns table(service_type text, contract_coverage text, jobs bigint, accurate bigint, total_gap_rupees numeric, avg_gap_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.service_type, l.contract_coverage, count(*)::bigint,
    count(*) filter (where l.capture_verdict = 'accurate')::bigint,
    coalesce(sum(l.billing_gap_rupees),0)::numeric,
    round(avg(l.billing_gap_rupees), 0)
  from public.service_charge_capture_r3280 l
  group by l.service_type, l.contract_coverage
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3280_service_coverage_matrix() from public, anon;
grant execute on function public.founder_r3280_service_coverage_matrix() to authenticated;

-- 4) Daily billing-accuracy trend
create or replace function public.founder_r3280_daily_billing_trend()
returns table(job_close_date date, jobs bigint, accurate bigint, leaks bigint, not_invoiced bigint, total_gap_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.job_close_date,
    count(*)::bigint,
    count(*) filter (where l.capture_verdict = 'accurate')::bigint,
    count(*) filter (where l.capture_verdict in ('minor_leak','major_leak'))::bigint,
    count(*) filter (where l.capture_verdict = 'not_invoiced')::bigint,
    coalesce(sum(l.billing_gap_rupees),0)::numeric
  from public.service_charge_capture_r3280 l
  group by l.job_close_date
  order by l.job_close_date desc;
end;
$$;

revoke execute on function public.founder_r3280_daily_billing_trend() from public, anon;
grant execute on function public.founder_r3280_daily_billing_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3280_capa_status_board()
returns table(capa_status text, findings bigint, avg_recovery_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.recovery_amount_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.service_charge_capture_capa_actions_r3280 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3280_capa_status_board() from public, anon;
grant execute on function public.founder_r3280_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3280_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_recovery_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.service_charge_capture_capa_actions_r3280)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.recovery_amount_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.service_charge_capture_capa_actions_r3280 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3280_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3280_root_cause_pareto() to authenticated;

-- 7) Revenue-impact recovery digest
create or replace function public.founder_r3280_revenue_impact_digest()
returns table(revenue_impact text, findings bigint, open_findings bigint, total_recovery_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.revenue_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.recovery_amount_rupees),0)::numeric
  from public.service_charge_capture_capa_actions_r3280 c
  group by c.revenue_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3280_revenue_impact_digest() from public, anon;
grant execute on function public.founder_r3280_revenue_impact_digest() to authenticated;

-- 8) High-risk billing-leak queue (top individual concerns)
create or replace function public.founder_r3280_high_risk_queue()
returns table(
  engineer_name text,
  region text,
  job_code text,
  service_type text,
  job_close_date date,
  contract_coverage text,
  capture_verdict text,
  gap_reason text,
  billing_gap_rupees numeric,
  invoice_raised boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.region, l.job_code, l.service_type, l.job_close_date,
    l.contract_coverage, l.capture_verdict, l.gap_reason, l.billing_gap_rupees,
    l.invoice_raised, l.notes
  from public.service_charge_capture_r3280 l
  where l.capture_verdict in ('minor_leak','major_leak','not_invoiced','under_review')
     or l.gap_reason in ('amc_misclassified','parts_not_logged','labour_undercharged','free_goodwill','pending_invoice','duplicate')
     or (l.contract_coverage = 'chargeable' and l.invoice_raised = false)
  order by l.billing_gap_rupees desc, l.job_close_date desc;
end;
$$;

revoke execute on function public.founder_r3280_high_risk_queue() from public, anon;
grant execute on function public.founder_r3280_high_risk_queue() to authenticated;
