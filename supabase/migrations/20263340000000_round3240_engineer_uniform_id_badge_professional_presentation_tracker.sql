-- Round 3240: Engineer Uniform, ID-Badge & Professional-Presentation Compliance Tracker
-- Presentation checks — check source × uniform × id badge × grooming × tool bag × vehicle branding × customer perception × CAPA

-- =============================================================================
-- TABLE 1: presentation_check_r3240 — individual presentation checks
-- =============================================================================
create table if not exists public.presentation_check_r3240 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  engineer_name text not null,
  engineer_code text not null,
  check_ref text not null,
  check_date date not null,
  check_source text not null check (check_source in (
    'customer_report','spot_audit','selfie_checkin','supervisor_ride_along','cctv_review','mystery_audit'
  )),
  uniform_worn boolean not null default false,
  uniform_condition text not null check (uniform_condition in (
    'clean_pressed','acceptable','soiled','torn','non_standard','not_worn'
  )),
  id_badge_visible boolean not null default false,
  id_badge_status text not null check (id_badge_status in (
    'valid_visible','valid_pocketed','expired','damaged','missing','wrong_person_photo'
  )),
  grooming_ok boolean not null default false,
  grooming_rating text not null check (grooming_rating in (
    'excellent','good','acceptable','poor','unacceptable'
  )),
  tool_bag_branded boolean not null default false,
  tool_bag_condition text not null check (tool_bag_condition in (
    'branded_good','branded_worn','unbranded','damaged','missing'
  )),
  vehicle_branding text not null check (vehicle_branding in (
    'full_wrap','partial_decals','magnetic_signage','none','personal_vehicle','not_applicable'
  )),
  customer_perception_score int not null check (customer_perception_score between 1 and 10),
  presentation_verdict text not null check (presentation_verdict in (
    'exemplary','compliant','minor_lapse','major_lapse','critical_violation','pending_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.presentation_check_r3240 enable row level security;

create index if not exists idx_presentation_check_r3240_org on public.presentation_check_r3240(organization_id);
create index if not exists idx_presentation_check_r3240_date on public.presentation_check_r3240(check_date);
create index if not exists idx_presentation_check_r3240_verdict on public.presentation_check_r3240(presentation_verdict);

-- =============================================================================
-- TABLE 2: presentation_check_capa_actions_r3240 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.presentation_check_capa_actions_r3240 (
  id uuid primary key default gen_random_uuid(),
  presentation_check_id uuid not null references public.presentation_check_r3240(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'uniform_violation','badge_violation','grooming_lapse','tool_bag_unbranded',
    'vehicle_unbranded','customer_complaint','repeat_offense','policy_gap'
  )),
  root_cause text not null check (root_cause in (
    'uniform_stock_shortage','badge_renewal_backlog','new_hire_kit_pending',
    'engineer_negligence','laundry_logistics_gap','branding_budget_freeze',
    'policy_awareness_gap','vendor_supply_delay','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'issue_new_uniform_kit','reissue_id_badge','grooming_counseling',
    'issue_branded_tool_bag','apply_vehicle_decals','retrain_on_dress_code',
    'written_warning','update_onboarding_kit_sop','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'brand_risk_high','customer_contract_breach','none','internal_only',
    'hospital_access_policy','safety_policy_violation'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.presentation_check_capa_actions_r3240 enable row level security;

create index if not exists idx_presentation_capa_r3240_check on public.presentation_check_capa_actions_r3240(presentation_check_id);
create index if not exists idx_presentation_capa_r3240_status on public.presentation_check_capa_actions_r3240(capa_status);

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

  -- 13 presentation check rows
  insert into public.presentation_check_r3240 (
    organization_id, hospital_name, engineer_name, engineer_code, check_ref,
    check_date, check_source, uniform_worn, uniform_condition,
    id_badge_visible, id_badge_status, grooming_ok, grooming_rating,
    tool_bag_branded, tool_bag_condition, vehicle_branding,
    customer_perception_score, presentation_verdict, notes
  )
  select v_org_id, q.hosp, q.eng, q.ecode, q.ref,
    q.cd::date, q.src, q.uw, q.uc,
    q.bv, q.bs, q.gok, q.gr,
    q.tbb, q.tbc, q.vb,
    q.cps, q.pv, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','Ravi Teja','ENG-HYD-014','PRES-001','2026-07-02','spot_audit',
     true,'clean_pressed',true,'valid_visible',true,'excellent',true,'branded_good','partial_decals',9,'exemplary','Complete kit; biomedical team praised turnout'),
    ('Apollo Hyderabad Jubilee Hills','Sandeep Rao','ENG-HYD-022','PRES-002','2026-07-02','selfie_checkin',
     true,'acceptable',false,'valid_pocketed',true,'good',true,'branded_worn','none',7,'minor_lapse','Badge kept in pocket during check-in selfie'),
    ('Fortis Bannerghatta Bengaluru','Mohan Das','ENG-BLR-007','PRES-003','2026-07-01','customer_report',
     false,'not_worn',false,'missing',true,'acceptable',false,'unbranded','personal_vehicle',3,'critical_violation','Biomedical HOD complaint — plain clothes and no badge on OT floor'),
    ('Fortis Bannerghatta Bengaluru','Arjun Shetty','ENG-BLR-015','PRES-004','2026-07-01','spot_audit',
     true,'soiled',true,'valid_visible',true,'good',true,'branded_good','magnetic_signage',6,'minor_lapse','Uniform soiled from previous visit; spare shirt recommended'),
    ('Manipal Whitefield Bengaluru','Praveen Gowda','ENG-BLR-019','PRES-005','2026-06-30','supervisor_ride_along',
     true,'clean_pressed',true,'valid_visible',true,'excellent',true,'branded_good','full_wrap',10,'exemplary','Ride-along audit; model presentation across two sites'),
    ('Manipal Whitefield Bengaluru','Imran Khan','ENG-BLR-024','PRES-006','2026-06-30','cctv_review',
     true,'non_standard',true,'expired',true,'good',false,'missing','none',5,'major_lapse','Old-logo polo; badge expired 40 days ago; no tool bag visible on CCTV'),
    ('AIIMS New Delhi Ansari Nagar','Vikram Singh','ENG-DEL-031','PRES-007','2026-06-30','spot_audit',
     true,'clean_pressed',false,'damaged',true,'acceptable',true,'branded_worn','not_applicable',7,'minor_lapse','Badge laminate cracked; photo unreadable at security gate'),
    ('AIIMS New Delhi Ansari Nagar','Deepak Yadav','ENG-DEL-035','PRES-008','2026-06-29','mystery_audit',
     true,'torn',true,'valid_visible',false,'poor',true,'branded_worn','personal_vehicle',4,'major_lapse','Torn sleeve and unshaven; flagged by mystery auditor'),
    ('KIMS Secunderabad','Srinivas Reddy','ENG-HYD-041','PRES-009','2026-06-29','selfie_checkin',
     true,'acceptable',true,'valid_visible',true,'good',true,'branded_good','partial_decals',8,'compliant','Routine check-in; all items in order'),
    ('Care Hospitals Banjara Hills','Naveen Kumar','ENG-HYD-046','PRES-010','2026-06-28','customer_report',
     true,'clean_pressed',true,'wrong_person_photo',true,'good',true,'branded_good','none',6,'major_lapse','Security flagged badge photo mismatch — badge swapped with colleague'),
    ('Yashoda Somajiguda Hyderabad','Kiran Babu','ENG-HYD-052','PRES-011','2026-06-28','spot_audit',
     true,'clean_pressed',true,'valid_visible',true,'excellent',false,'unbranded','magnetic_signage',8,'compliant','Only gap is unbranded tool bag; branded kit requested'),
    ('St John''s Bengaluru','Alwin Thomas','ENG-BLR-028','PRES-012','2026-06-27','selfie_checkin',
     true,'acceptable',true,'valid_visible',true,'acceptable',true,'branded_worn','none',7,'compliant','Check-in selfie complete; bag strap fraying'),
    ('Rainbow Children''s Hyderabad','Suresh Naidu','ENG-HYD-058','PRES-013','2026-06-27','cctv_review',
     true,'clean_pressed',false,'valid_pocketed',true,'good',true,'branded_good','full_wrap',9,'pending_review','CCTV frame unclear on badge orientation; supervisor review pending')
  ) as q(hosp, eng, ecode, ref, cd, src, uw, uc, bv, bs, gok, gr, tbb, tbc, vb, cps, pv, nt);

  -- CAPA seed — attach to specific checks
  insert into public.presentation_check_capa_actions_r3240 (
    presentation_check_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('PRES-003','customer_complaint','engineer_negligence','written_warning','2026-07-05',null,'escalated','customer_contract_breach',0,'Hospital threatened access revocation; HR escalation done'),
    ('PRES-006','badge_violation','badge_renewal_backlog','reissue_id_badge','2026-07-04',null,'in_progress','hospital_access_policy',350.00,'Badge print vendor batch queued this week'),
    ('PRES-006','uniform_violation','uniform_stock_shortage','issue_new_uniform_kit','2026-07-08',null,'open','brand_risk_high',2400.00,'Old-logo polos still in circulation — stock swap needed'),
    ('PRES-007','badge_violation','vendor_supply_delay','reissue_id_badge','2026-07-03','2026-07-01','closed','hospital_access_policy',350.00,'Replacement badge issued and verified at gate'),
    ('PRES-008','grooming_lapse','policy_awareness_gap','grooming_counseling','2026-07-06',null,'verification_pending','internal_only',0,'Counseling completed; re-audit scheduled'),
    ('PRES-010','badge_violation','engineer_negligence','retrain_on_dress_code','2026-06-25',null,'overdue','customer_contract_breach',500.00,'Badge-swap incident; dress-code retraining overdue'),
    ('PRES-011','tool_bag_unbranded','branding_budget_freeze','issue_branded_tool_bag','2026-07-12',null,'open','none',1800.00,'Branded tool-bag batch pending budget release')
  ) as q(ref, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.presentation_check_r3240 e
    on e.organization_id = v_org_id and e.check_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Presentation verdict distribution
create or replace function public.founder_r3240_verdict_rollup()
returns table(presentation_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.presentation_check_r3240)
  select l.presentation_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.presentation_check_r3240 l
  group by l.presentation_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3240_verdict_rollup() from public, anon;
grant execute on function public.founder_r3240_verdict_rollup() to authenticated;

-- 2) Hospital-level presentation scorecard
create or replace function public.founder_r3240_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  exemplary bigint,
  critical_violations bigint,
  uniform_lapses bigint,
  badge_lapses bigint,
  avg_perception numeric,
  compliance_pct numeric
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
    count(*) filter (where l.presentation_verdict = 'exemplary')::bigint,
    count(*) filter (where l.presentation_verdict = 'critical_violation')::bigint,
    count(*) filter (where not l.uniform_worn or l.uniform_condition in ('soiled','torn','non_standard','not_worn'))::bigint,
    count(*) filter (where not l.id_badge_visible or l.id_badge_status in ('expired','damaged','missing','wrong_person_photo'))::bigint,
    round(avg(l.customer_perception_score)::numeric, 1),
    round(100.0 * count(*) filter (where l.presentation_verdict in ('exemplary','compliant'))::numeric / nullif(count(*),0), 1)
  from public.presentation_check_r3240 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3240_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3240_hospital_scorecard() to authenticated;

-- 3) Check-source × verdict matrix
create or replace function public.founder_r3240_source_verdict_matrix()
returns table(check_source text, presentation_verdict text, checks bigint, avg_perception numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_source, l.presentation_verdict, count(*)::bigint,
    round(avg(l.customer_perception_score)::numeric, 1)
  from public.presentation_check_r3240 l
  group by l.check_source, l.presentation_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3240_source_verdict_matrix() from public, anon;
grant execute on function public.founder_r3240_source_verdict_matrix() to authenticated;

-- 4) Daily presentation trend
create or replace function public.founder_r3240_daily_trend()
returns table(check_date date, checks bigint, uniform_ok bigint, badge_ok bigint, grooming_pass bigint, avg_perception numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.uniform_worn and l.uniform_condition in ('clean_pressed','acceptable'))::bigint,
    count(*) filter (where l.id_badge_visible and l.id_badge_status = 'valid_visible')::bigint,
    count(*) filter (where l.grooming_ok)::bigint,
    round(avg(l.customer_perception_score)::numeric, 1)
  from public.presentation_check_r3240 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3240_daily_trend() from public, anon;
grant execute on function public.founder_r3240_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3240_capa_status_board()
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
  from public.presentation_check_capa_actions_r3240 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3240_capa_status_board() from public, anon;
grant execute on function public.founder_r3240_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3240_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.presentation_check_capa_actions_r3240)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.presentation_check_capa_actions_r3240 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3240_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3240_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3240_regulatory_impact_digest()
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
  from public.presentation_check_capa_actions_r3240 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3240_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3240_regulatory_impact_digest() to authenticated;

-- 8) High-risk presentation checks queue
create or replace function public.founder_r3240_high_risk_queue()
returns table(
  hospital_name text,
  engineer_name text,
  engineer_code text,
  check_date date,
  check_source text,
  presentation_verdict text,
  customer_perception_score int,
  id_badge_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.engineer_code, l.check_date,
    l.check_source, l.presentation_verdict, l.customer_perception_score, l.id_badge_status, l.notes
  from public.presentation_check_r3240 l
  where l.presentation_verdict in ('major_lapse','critical_violation','pending_review')
     or l.customer_perception_score <= 4
     or l.id_badge_status in ('expired','missing','wrong_person_photo')
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3240_high_risk_queue() from public, anon;
grant execute on function public.founder_r3240_high_risk_queue() to authenticated;
