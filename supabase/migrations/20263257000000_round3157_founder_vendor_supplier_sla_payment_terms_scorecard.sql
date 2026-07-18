-- Round 3157: Founder Vendor / Supplier SLA & Payment-Terms Compliance Scorecard
-- Vendor scorecard — category × SLA target vs actual lead × OTIF % × quality reject % × payment terms × dispute × tier + CAPA

-- =============================================================================
-- TABLE 1: vendor_sla_r3157 — vendor SLA & payment-terms compliance records
-- =============================================================================
create table if not exists public.vendor_sla_r3157 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  vendor_name text not null,
  vendor_code text not null,
  hospital_name text not null,
  category text not null check (category in (
    'spare_parts','logistics_transport','calibration_metrology','saas_software',
    'consumables','amc_service','it_hardware','sterile_supplies'
  )),
  region text not null check (region in (
    'south','north','east','west','central','pan_india'
  )),
  period_month date not null,
  sla_target_days int not null,
  actual_lead_days int not null,
  otif_pct numeric(5,2) not null,
  quality_reject_pct numeric(5,2) not null,
  payment_terms_days int not null,
  payment_terms_status text not null check (payment_terms_status in (
    'within_terms','overdue_30','overdue_60','disputed_hold','advance_paid','on_hold'
  )),
  dispute_status text not null check (dispute_status in (
    'none','open','under_review','escalated','resolved','write_off'
  )),
  vendor_tier text not null check (vendor_tier in (
    'strategic','preferred','approved','probation','blacklisted'
  )),
  compliance_verdict text not null check (compliance_verdict in (
    'compliant','minor_breach','major_breach','critical_breach','under_watch','terminated'
  )),
  contract_value_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.vendor_sla_r3157 enable row level security;

create index if not exists idx_vendor_sla_r3157_org on public.vendor_sla_r3157(organization_id);
create index if not exists idx_vendor_sla_r3157_verdict on public.vendor_sla_r3157(compliance_verdict);
create index if not exists idx_vendor_sla_r3157_category on public.vendor_sla_r3157(category);

-- =============================================================================
-- TABLE 2: vendor_sla_capa_actions_r3157 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.vendor_sla_capa_actions_r3157 (
  id uuid primary key default gen_random_uuid(),
  vendor_sla_id uuid not null references public.vendor_sla_r3157(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'sla_breach','late_delivery','quality_rejection','payment_dispute','otif_shortfall',
    'price_escalation','documentation_gap','compliance_lapse','stockout_risk','service_downtime'
  )),
  root_cause text not null check (root_cause in (
    'capacity_constraint','logistics_delay','quality_control_gap','pricing_disagreement',
    'invoice_mismatch','contract_ambiguity','forecast_miss','subvendor_failure',
    'regulatory_hold','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'renegotiate_sla','issue_penalty_debit','dual_source_vendor','escalate_to_management',
    'revise_payment_terms','onboard_alternate','quality_audit_visit','contract_amendment',
    'none_required','vendor_offboarding'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'procurement_policy_breach','nabh_supply_finding','gst_compliance_risk',
    'none','internal_only','contract_sla_penalty'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.vendor_sla_capa_actions_r3157 enable row level security;

create index if not exists idx_vendor_sla_capa_r3157_vendor on public.vendor_sla_capa_actions_r3157(vendor_sla_id);
create index if not exists idx_vendor_sla_capa_r3157_status on public.vendor_sla_capa_actions_r3157(capa_status);

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

  -- 13 vendor SLA records
  insert into public.vendor_sla_r3157 (
    organization_id, vendor_name, vendor_code, hospital_name, category, region,
    period_month, sla_target_days, actual_lead_days, otif_pct, quality_reject_pct,
    payment_terms_days, payment_terms_status, dispute_status, vendor_tier,
    compliance_verdict, contract_value_rupees
  )
  select v_org_id, q.vn, q.vc, q.hosp, q.cat, q.reg,
    q.pm::date, q.tgt, q.act, q.otif, q.qrej,
    q.ptd, q.pts, q.disp, q.tier,
    q.verdict, q.cval
  from (values
    ('Siemens Healthineers Spares','VN-SIE-01','Apollo Hyderabad Jubilee Hills','spare_parts','south',
     '2026-06-01',7,6,98.50,0.50,45,'within_terms','none','strategic','compliant',12500000.00),
    ('Blue Dart Medical Logistics','VN-BLD-02','Fortis Bannerghatta Bengaluru','logistics_transport','south',
     '2026-06-01',2,4,88.00,1.20,30,'overdue_30','open','preferred','minor_breach',3200000.00),
    ('Fluke Biomedical Calibration','VN-FLK-03','Manipal Whitefield Bengaluru','calibration_metrology','south',
     '2026-06-01',14,21,76.00,2.00,60,'disputed_hold','escalated','probation','major_breach',1800000.00),
    ('Meditab SaaS Systems','VN-MED-04','AIIMS New Delhi Ansari Nagar','saas_software','north',
     '2026-06-01',1,1,99.90,0.00,30,'within_terms','none','strategic','compliant',8600000.00),
    ('GE Healthcare Parts','VN-GEH-05','KIMS Secunderabad','spare_parts','south',
     '2026-06-01',10,18,70.00,3.50,45,'overdue_60','under_review','probation','critical_breach',9400000.00),
    ('Agappe Diagnostics Consumables','VN-AGP-06','Care Hospitals Banjara Hills','consumables','south',
     '2026-06-01',5,5,95.00,0.80,30,'within_terms','none','preferred','compliant',2100000.00),
    ('Trivitron AMC Services','VN-TRV-07','Yashoda Somajiguda Hyderabad','amc_service','south',
     '2026-06-01',3,7,82.00,1.50,45,'on_hold','open','approved','minor_breach',5600000.00),
    ('Wipro GE Logistics','VN-WPG-08','St John''s Bengaluru','logistics_transport','south',
     '2026-06-01',2,3,91.00,0.60,30,'within_terms','none','approved','under_watch',1500000.00),
    ('Mindray Spares India','VN-MIN-09','Rainbow Children''s Hyderabad','spare_parts','south',
     '2026-06-01',8,8,97.00,0.40,45,'within_terms','none','preferred','compliant',4300000.00),
    ('Nucleus Calibration Labs','VN-NCL-10','Apollo Hyderabad Jubilee Hills','calibration_metrology','south',
     '2026-05-01',14,14,94.00,0.90,60,'advance_paid','none','approved','compliant',1200000.00),
    ('Delhivery Cold Chain','VN-DLV-11','Fortis Bannerghatta Bengaluru','logistics_transport','south',
     '2026-05-01',2,5,79.00,2.80,30,'overdue_30','escalated','probation','major_breach',2700000.00),
    ('Cerner Cloud EHR','VN-CRN-12','AIIMS New Delhi Ansari Nagar','saas_software','north',
     '2026-05-01',1,2,96.50,0.10,30,'within_terms','resolved','strategic','under_watch',11200000.00),
    ('Skanray Calibration','VN-SKN-13','KIMS Secunderabad','calibration_metrology','south',
     '2026-05-01',14,30,60.00,5.00,60,'disputed_hold','write_off','blacklisted','terminated',900000.00)
  ) as q(vn, vc, hosp, cat, reg, pm, tgt, act, otif, qrej, ptd, pts, disp, tier, verdict, cval);

  -- 6 CAPA action rows — attach to specific vendor records by vendor_code
  insert into public.vendor_sla_capa_actions_r3157 (
    vendor_sla_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.cs, q.ri, q.tcd::date, q.acd::date, q.cost, q.nt
  from (values
    ('VN-GEH-05','late_delivery','logistics_delay','escalate_to_management','in_progress','contract_sla_penalty',
     '2026-07-05',null,120000.00,'Spare part lead 18d vs 10d SLA - production line down'),
    ('VN-FLK-03','quality_rejection','quality_control_gap','quality_audit_visit','verification_pending','nabh_supply_finding',
     '2026-07-02',null,45000.00,'Calibration cert discrepancy flagged in NABH audit'),
    ('VN-SKN-13','sla_breach','subvendor_failure','vendor_offboarding','escalated','procurement_policy_breach',
     '2026-06-20',null,200000.00,'30d lead + 5pct reject - blacklisted, offboarding in progress'),
    ('VN-BLD-02','payment_dispute','invoice_mismatch','revise_payment_terms','open','gst_compliance_risk',
     '2026-07-10',null,32000.00,'GST invoice mismatch holding 30d payment'),
    ('VN-DLV-11','otif_shortfall','logistics_delay','dual_source_vendor','in_progress','internal_only',
     '2026-07-08',null,27000.00,'Cold chain OTIF 79pct - adding backup carrier'),
    ('VN-GEH-05','price_escalation','pricing_disagreement','renegotiate_sla','closed','none',
     '2026-06-15','2026-06-14',15000.00,'Price hike 8pct renegotiated to 3pct')
  ) as q(vc_key, fc, rc, ca, cs, ri, tcd, acd, cost, nt)
  join public.vendor_sla_r3157 e
    on e.organization_id = v_org_id and e.vendor_code = q.vc_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance verdict distribution
create or replace function public.founder_r3157_verdict_rollup()
returns table(compliance_verdict text, vendors bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vendor_sla_r3157)
  select l.compliance_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.vendor_sla_r3157 l
  group by l.compliance_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3157_verdict_rollup() from public, anon;
grant execute on function public.founder_r3157_verdict_rollup() to authenticated;

-- 2) Vendor / entity scorecard
create or replace function public.founder_r3157_vendor_scorecard()
returns table(
  vendor_name text,
  hospital_name text,
  category text,
  vendor_tier text,
  records bigint,
  avg_otif_pct numeric,
  avg_sla_gap_days numeric,
  avg_quality_reject_pct numeric,
  compliant_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.vendor_name, l.hospital_name, l.category, l.vendor_tier,
    count(*)::bigint,
    round(avg(l.otif_pct), 1),
    round(avg(l.actual_lead_days - l.sla_target_days), 1),
    round(avg(l.quality_reject_pct), 2),
    round(100.0 * count(*) filter (where l.compliance_verdict = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.vendor_sla_r3157 l
  group by l.vendor_name, l.hospital_name, l.category, l.vendor_tier
  order by round(avg(l.otif_pct), 1) asc;
end;
$$;

revoke execute on function public.founder_r3157_vendor_scorecard() from public, anon;
grant execute on function public.founder_r3157_vendor_scorecard() to authenticated;

-- 3) Category matrix
create or replace function public.founder_r3157_category_matrix()
returns table(
  category text,
  vendors bigint,
  avg_otif_pct numeric,
  avg_quality_reject_pct numeric,
  breaches bigint,
  avg_payment_terms_days numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category, count(*)::bigint,
    round(avg(l.otif_pct), 1),
    round(avg(l.quality_reject_pct), 2),
    count(*) filter (where l.compliance_verdict in ('minor_breach','major_breach','critical_breach','terminated'))::bigint,
    round(avg(l.payment_terms_days), 0)
  from public.vendor_sla_r3157 l
  group by l.category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3157_category_matrix() from public, anon;
grant execute on function public.founder_r3157_category_matrix() to authenticated;

-- 4) SLA monthly trend
create or replace function public.founder_r3157_sla_monthly_trend()
returns table(
  period_month date,
  records bigint,
  avg_otif_pct numeric,
  breaches bigint,
  disputes bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month, count(*)::bigint,
    round(avg(l.otif_pct), 1),
    count(*) filter (where l.compliance_verdict in ('minor_breach','major_breach','critical_breach','terminated'))::bigint,
    count(*) filter (where l.dispute_status in ('open','under_review','escalated','write_off'))::bigint
  from public.vendor_sla_r3157 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3157_sla_monthly_trend() from public, anon;
grant execute on function public.founder_r3157_sla_monthly_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3157_capa_status_board()
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
  from public.vendor_sla_capa_actions_r3157 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3157_capa_status_board() from public, anon;
grant execute on function public.founder_r3157_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3157_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vendor_sla_capa_actions_r3157)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.vendor_sla_capa_actions_r3157 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3157_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3157_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3157_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.vendor_sla_capa_actions_r3157 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3157_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3157_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority vendor queue
create or replace function public.founder_r3157_high_risk_queue()
returns table(
  vendor_name text,
  hospital_name text,
  category text,
  vendor_tier text,
  compliance_verdict text,
  otif_pct numeric,
  actual_lead_days int,
  sla_target_days int,
  dispute_status text,
  payment_terms_status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.vendor_name, l.hospital_name, l.category, l.vendor_tier,
    l.compliance_verdict, l.otif_pct, l.actual_lead_days, l.sla_target_days,
    l.dispute_status, l.payment_terms_status
  from public.vendor_sla_r3157 l
  where l.compliance_verdict in ('minor_breach','major_breach','critical_breach','under_watch','terminated')
     or l.dispute_status in ('open','under_review','escalated','write_off')
     or l.otif_pct < 85
     or l.payment_terms_status in ('overdue_30','overdue_60','disputed_hold','on_hold')
  order by l.otif_pct asc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3157_high_risk_queue() from public, anon;
grant execute on function public.founder_r3157_high_risk_queue() to authenticated;
