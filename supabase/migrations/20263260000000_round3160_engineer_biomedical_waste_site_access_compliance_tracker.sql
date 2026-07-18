-- Round 3160: Engineer Customer-Site Biomedical-Waste Handling & Site-Access Compliance Tracker
-- Site visit log — engineer × waste category × segregation × PPE × gate-pass × induction × spill × verdict × CAPA

-- =============================================================================
-- TABLE 1: bmw_site_access_r3160 — per site-visit biomedical-waste & access compliance log
-- =============================================================================
create table if not exists public.bmw_site_access_r3160 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  site_code text not null,
  visit_ref text not null,
  engineer_name text not null,
  visit_date date not null,
  visit_started_at timestamptz not null,
  visit_ended_at timestamptz,
  waste_category text not null check (waste_category in (
    'sharps','e_waste','contaminated_plastics','anatomical_waste',
    'chemical_pharmaceutical','cytotoxic_waste','general_non_hazardous','glass_metallic_implants'
  )),
  segregation_status text not null check (segregation_status in (
    'compliant_color_coded','partial_mixing','major_mixing','no_segregation','color_code_error'
  )),
  ppe_worn text not null check (ppe_worn in (
    'full_ppe_kit','partial_ppe','gloves_mask_only','respirator_full','none_worn'
  )),
  gate_pass_status text not null check (gate_pass_status in (
    'valid_verified','expired','not_carried','biometric_verified','visitor_temporary'
  )),
  induction_status text not null check (induction_status in (
    'completed_current','refresh_due','not_done','waived_short_visit','completed_online'
  )),
  spill_incident text not null check (spill_incident in (
    'none','minor_contained','major_spill','needlestick_injury','chemical_spill'
  )),
  bmw_bins_audited int not null default 0,
  verdict text not null check (verdict in (
    'compliant','minor_nc','major_nc','critical_nc','site_access_denied','conditional_pass'
  )),
  closed_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.bmw_site_access_r3160 enable row level security;

create index if not exists idx_bmw_site_access_r3160_org on public.bmw_site_access_r3160(organization_id);
create index if not exists idx_bmw_site_access_r3160_date on public.bmw_site_access_r3160(visit_date);
create index if not exists idx_bmw_site_access_r3160_verdict on public.bmw_site_access_r3160(verdict);

-- =============================================================================
-- TABLE 2: bmw_site_access_capa_actions_r3160 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.bmw_site_access_capa_actions_r3160 (
  id uuid primary key default gen_random_uuid(),
  site_access_id uuid not null references public.bmw_site_access_r3160(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'waste_mixing','ppe_violation','gate_pass_lapse','induction_lapse','spill_response_gap',
    'manifest_discrepancy','storage_overflow','labeling_error','transport_delay','documentation_gap'
  )),
  root_cause text not null check (root_cause in (
    'inadequate_training','staff_shortage','bin_shortage','vendor_pickup_delay','supervisor_absent',
    'policy_unaware','equipment_unavailable','process_gap','pending_investigation','contractor_negligence'
  )),
  corrective_action text not null check (corrective_action in (
    'retrain_staff','provide_bins','escalate_vendor_sla','issue_ppe_kit','revise_sop',
    'disciplinary_action','install_signage','schedule_audit','none_required','renew_gate_pass_system'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cpcb_bmw_rules_violation','spcb_notifiable','nabh_finding','none','internal_only','patient_safety_alert'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.bmw_site_access_capa_actions_r3160 enable row level security;

create index if not exists idx_bmw_capa_r3160_site on public.bmw_site_access_capa_actions_r3160(site_access_id);
create index if not exists idx_bmw_capa_r3160_status on public.bmw_site_access_capa_actions_r3160(capa_status);

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

  -- 14 site-visit compliance rows
  insert into public.bmw_site_access_r3160 (
    organization_id, hospital_name, site_code, visit_ref, engineer_name,
    visit_date, visit_started_at, visit_ended_at,
    waste_category, segregation_status, ppe_worn, gate_pass_status, induction_status,
    spill_incident, bmw_bins_audited, verdict, closed_at, notes
  )
  select v_org_id, q.hosp, q.sc, q.vref, q.eng,
    q.vd::date, q.vs::timestamptz, q.ve::timestamptz,
    q.wc, q.seg, q.ppe, q.gate, q.ind,
    q.spill, q.bins, q.verdict, q.closed::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','SITE-APL-01','BMW-APL-001','Ravi Kumar','2026-07-15','2026-07-15 09:10:00+05:30','2026-07-15 10:30:00+05:30',
     'sharps','compliant_color_coded','full_ppe_kit','valid_verified','completed_current','none',4,'compliant','2026-07-15 11:00:00+05:30','Sharps bins sealed, color code correct'),
    ('Apollo Hyderabad Jubilee Hills','SITE-APL-01','BMW-APL-002','Ravi Kumar','2026-07-15','2026-07-15 11:15:00+05:30','2026-07-15 12:00:00+05:30',
     'e_waste','compliant_color_coded','full_ppe_kit','biometric_verified','completed_current','none',2,'compliant','2026-07-15 12:20:00+05:30','E-waste handed to CPCB authorized vendor'),
    ('Fortis Bannerghatta Bengaluru','SITE-FRT-01','BMW-FRT-001','Suresh Nair','2026-07-14','2026-07-14 08:30:00+05:30','2026-07-14 09:40:00+05:30',
     'contaminated_plastics','partial_mixing','partial_ppe','valid_verified','refresh_due','minor_contained',3,'minor_nc',null,'Red-yellow partial mix, minor spill mopped'),
    ('Fortis Bannerghatta Bengaluru','SITE-FRT-01','BMW-FRT-002','Suresh Nair','2026-07-14','2026-07-14 10:00:00+05:30','2026-07-14 11:10:00+05:30',
     'anatomical_waste','major_mixing','gloves_mask_only','expired','not_done','none',3,'major_nc',null,'Anatomical waste mixed with general, gate pass expired'),
    ('Manipal Whitefield Bengaluru','SITE-MNP-01','BMW-MNP-001','Anita Desai','2026-07-13','2026-07-13 07:20:00+05:30','2026-07-13 08:30:00+05:30',
     'cytotoxic_waste','compliant_color_coded','respirator_full','valid_verified','completed_current','none',5,'compliant','2026-07-13 09:00:00+05:30','Cytotoxic segregated, respirator worn'),
    ('Manipal Whitefield Bengaluru','SITE-MNP-01','BMW-MNP-002','Anita Desai','2026-07-13','2026-07-13 09:30:00+05:30','2026-07-13 10:50:00+05:30',
     'chemical_pharmaceutical','color_code_error','partial_ppe','valid_verified','refresh_due','chemical_spill',4,'major_nc',null,'Wrong color bin for pharma, chemical spill contained late'),
    ('AIIMS New Delhi Ansari Nagar','SITE-AIM-01','BMW-AIM-001','Vikram Singh','2026-07-13','2026-07-13 06:15:00+05:30','2026-07-13 07:40:00+05:30',
     'contaminated_plastics','no_segregation','none_worn','not_carried','not_done','major_spill',2,'critical_nc',null,'No segregation, major spill, no PPE — access flagged'),
    ('AIIMS New Delhi Ansari Nagar','SITE-AIM-01','BMW-AIM-002','Vikram Singh','2026-07-12','2026-07-12 08:00:00+05:30','2026-07-12 09:15:00+05:30',
     'sharps','compliant_color_coded','full_ppe_kit','biometric_verified','completed_current','needlestick_injury',3,'major_nc',null,'Needlestick during sharps handling, incident reported'),
    ('KIMS Secunderabad','SITE-KIM-01','BMW-KIM-001','Priya Reddy','2026-07-12','2026-07-12 05:45:00+05:30','2026-07-12 06:50:00+05:30',
     'general_non_hazardous','compliant_color_coded','gloves_mask_only','valid_verified','completed_online','none',4,'compliant','2026-07-12 07:10:00+05:30','General waste black bin, all compliant'),
    ('KIMS Secunderabad','SITE-KIM-01','BMW-KIM-002','Priya Reddy','2026-07-11','2026-07-11 07:00:00+05:30','2026-07-11 08:05:00+05:30',
     'glass_metallic_implants','partial_mixing','partial_ppe','expired','refresh_due','none',2,'minor_nc',null,'Blue bin glass partly mixed, pass expired'),
    ('Care Hospitals Banjara Hills','SITE-CAR-01','BMW-CAR-001','Mohan Rao','2026-07-11','2026-07-11 09:00:00+05:30','2026-07-11 09:55:00+05:30',
     'e_waste','compliant_color_coded','full_ppe_kit','valid_verified','completed_current','none',1,'compliant','2026-07-11 10:15:00+05:30','E-waste manifest reconciled'),
    ('Yashoda Somajiguda Hyderabad','SITE-YSH-01','BMW-YSH-001','Deepak Sharma','2026-07-10','2026-07-10 06:30:00+05:30','2026-07-10 07:45:00+05:30',
     'contaminated_plastics','major_mixing','gloves_mask_only','visitor_temporary','waived_short_visit','minor_contained',3,'major_nc',null,'Yellow-red major mix, temporary visitor pass only'),
    ('St John''s Bengaluru','SITE-STJ-01','BMW-STJ-001','Fatima Khan','2026-07-10','2026-07-10 05:50:00+05:30','2026-07-10 06:55:00+05:30',
     'sharps','compliant_color_coded','full_ppe_kit','valid_verified','completed_current','none',4,'compliant','2026-07-10 07:20:00+05:30','Weekly sharps audit clean'),
    ('Rainbow Children''s Hyderabad','SITE-RBW-01','BMW-RBW-001','Karthik Menon','2026-07-09','2026-07-09 07:00:00+05:30',null,
     'anatomical_waste','no_segregation','none_worn','not_carried','not_done','major_spill',2,'site_access_denied',null,'Access denied — no induction, no PPE, no gate pass')
  ) as q(hosp, sc, vref, eng, vd, vs, ve, wc, seg, ppe, gate, ind, spill, bins, verdict, closed, nt);

  -- CAPA seed — attach to specific visits by visit_ref
  insert into public.bmw_site_access_capa_actions_r3160 (
    site_access_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('BMW-FRT-002','waste_mixing','inadequate_training','retrain_staff','2026-07-20',null,'in_progress','cpcb_bmw_rules_violation',15000.00,'Housekeeping retraining on 4-bin segregation scheduled'),
    ('BMW-AIM-001','spill_response_gap','staff_shortage','revise_sop','2026-07-19',null,'escalated','spcb_notifiable',45000.00,'Major spill SOP revision, SPCB notification drafted'),
    ('BMW-AIM-002','spill_response_gap','process_gap','revise_sop','2026-07-18',null,'verification_pending','patient_safety_alert',8000.00,'Needlestick — PEP started, sharps container redesign'),
    ('BMW-MNP-002','labeling_error','policy_unaware','install_signage','2026-07-22',null,'open','nabh_finding',6500.00,'Color-code signage for pharma waste ordered'),
    ('BMW-RBW-001','gate_pass_lapse','contractor_negligence','renew_gate_pass_system','2026-07-21',null,'escalated','cpcb_bmw_rules_violation',22000.00,'Gate-pass + induction system overhaul for contractor'),
    ('BMW-YSH-001','waste_mixing','bin_shortage','provide_bins','2026-07-16','2026-07-15','closed','internal_only',4200.00,'Additional color bins supplied, retrained on the spot')
  ) as q(vref_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.bmw_site_access_r3160 e
    on e.organization_id = v_org_id and e.visit_ref = q.vref_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Verdict distribution
create or replace function public.founder_r3160_verdict_rollup()
returns table(verdict text, visits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.bmw_site_access_r3160)
  select l.verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.bmw_site_access_r3160 l
  group by l.verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3160_verdict_rollup() from public, anon;
grant execute on function public.founder_r3160_verdict_rollup() to authenticated;

-- 2) Hospital-level compliance scorecard
create or replace function public.founder_r3160_hospital_scorecard()
returns table(
  hospital_name text,
  total_visits bigint,
  compliant bigint,
  minor_nc bigint,
  major_nc bigint,
  critical_nc bigint,
  denied bigint,
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
    count(*) filter (where l.verdict = 'compliant')::bigint,
    count(*) filter (where l.verdict = 'minor_nc')::bigint,
    count(*) filter (where l.verdict = 'major_nc')::bigint,
    count(*) filter (where l.verdict = 'critical_nc')::bigint,
    count(*) filter (where l.verdict = 'site_access_denied')::bigint,
    round(100.0 * count(*) filter (where l.verdict = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.bmw_site_access_r3160 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3160_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3160_hospital_scorecard() to authenticated;

-- 3) Waste-category × segregation matrix
create or replace function public.founder_r3160_waste_category_matrix()
returns table(waste_category text, segregation_status text, visits bigint, compliant bigint, avg_bins numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.waste_category, l.segregation_status, count(*)::bigint,
    count(*) filter (where l.verdict = 'compliant')::bigint,
    round(avg(l.bmw_bins_audited), 2)
  from public.bmw_site_access_r3160 l
  group by l.waste_category, l.segregation_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3160_waste_category_matrix() from public, anon;
grant execute on function public.founder_r3160_waste_category_matrix() to authenticated;

-- 4) Daily site-visit trend
create or replace function public.founder_r3160_visit_daily_trend()
returns table(visit_date date, visits bigint, compliant bigint, major_critical bigint, spill_events bigint, denied bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.visit_date,
    count(*)::bigint,
    count(*) filter (where l.verdict = 'compliant')::bigint,
    count(*) filter (where l.verdict in ('major_nc','critical_nc'))::bigint,
    count(*) filter (where l.spill_incident in ('minor_contained','major_spill','needlestick_injury','chemical_spill'))::bigint,
    count(*) filter (where l.verdict = 'site_access_denied')::bigint
  from public.bmw_site_access_r3160 l
  group by l.visit_date
  order by l.visit_date desc;
end;
$$;

revoke execute on function public.founder_r3160_visit_daily_trend() from public, anon;
grant execute on function public.founder_r3160_visit_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3160_capa_status_board()
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
  from public.bmw_site_access_capa_actions_r3160 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3160_capa_status_board() from public, anon;
grant execute on function public.founder_r3160_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3160_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.bmw_site_access_capa_actions_r3160)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.bmw_site_access_capa_actions_r3160 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3160_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3160_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3160_regulatory_impact_digest()
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
  from public.bmw_site_access_capa_actions_r3160 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3160_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3160_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority queue (individual concerns)
create or replace function public.founder_r3160_high_risk_queue()
returns table(
  hospital_name text,
  site_code text,
  engineer_name text,
  visit_date date,
  verdict text,
  waste_category text,
  segregation_status text,
  ppe_worn text,
  spill_incident text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.site_code, l.engineer_name, l.visit_date,
    l.verdict, l.waste_category, l.segregation_status, l.ppe_worn, l.spill_incident, l.notes
  from public.bmw_site_access_r3160 l
  where l.verdict in ('minor_nc','major_nc','critical_nc','site_access_denied','conditional_pass')
     or l.segregation_status in ('major_mixing','no_segregation','color_code_error')
     or l.ppe_worn in ('none_worn','gloves_mask_only')
     or l.spill_incident in ('major_spill','needlestick_injury','chemical_spill')
     or l.gate_pass_status in ('expired','not_carried')
  order by l.visit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3160_high_risk_queue() from public, anon;
grant execute on function public.founder_r3160_high_risk_queue() to authenticated;
