-- Round 3636: Founder Ind-AS Transition / First-Time-Adoption GAAP-Gap Board
-- iGAAP vs Ind-AS transition log — GAAP area × standard ref × period × iGAAP value × Ind-AS value × transition adjustment × OCI impact × retained-earnings impact × materiality × disclosure readiness × adoption status × trend × CAPA

-- =============================================================================
-- TABLE 1: indas_transition_r3636 — per-area first-time-adoption GAAP-gap lines
-- =============================================================================
create table if not exists public.indas_transition_r3636 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_name text not null,
  area_code text not null,
  gaap_area text not null,
  standard_ref text not null,
  period_month date not null,
  igaap_value_rupees numeric(16,2) not null,
  indas_value_rupees numeric(16,2) not null,
  transition_adjustment_rupees numeric(16,2) not null,
  oci_impact_rupees numeric(16,2) not null,
  retained_earnings_impact_rupees numeric(16,2) not null,
  materiality_pct numeric(6,2),
  disclosure_ready boolean not null,
  adoption_status text not null check (adoption_status in (
    'adopted','in_progress','under_assessment','deferred','not_applicable'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.indas_transition_r3636 enable row level security;

create index if not exists idx_indas_transition_r3636_org on public.indas_transition_r3636(organization_id);
create index if not exists idx_indas_transition_r3636_period on public.indas_transition_r3636(period_month);
create index if not exists idx_indas_transition_r3636_status on public.indas_transition_r3636(adoption_status);

-- =============================================================================
-- TABLE 2: indas_transition_capa_actions_r3636 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.indas_transition_capa_actions_r3636 (
  id uuid primary key default gen_random_uuid(),
  transition_id uuid not null references public.indas_transition_r3636(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'unrecognized_deferred_tax','fair_value_remeasurement_gap','lease_liability_not_recognized',
    'expected_credit_loss_shortfall','revenue_timing_difference','ppe_componentization_pending',
    'financial_instrument_classification','employee_benefit_actuarial_gap','disclosure_note_incomplete',
    'consolidation_adjustment_missing'
  )),
  root_cause text not null check (root_cause in (
    'first_time_adoption_exemption_choice','valuation_report_pending','actuary_input_delayed',
    'lease_data_incomplete','system_not_configured_for_indas','auditor_query_open',
    'management_judgement_pending','pending_investigation','policy_documentation_gap','historical_data_unavailable'
  )),
  corrective_action text not null check (corrective_action in (
    'obtain_valuation_report','recompute_deferred_tax','recognize_lease_liability','book_ecl_provision',
    'restate_revenue_schedule','engage_actuary','update_accounting_policy','reconfigure_erp_indas',
    'prepare_disclosure_note','obtain_auditor_signoff','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  adjustment_impact_rupees numeric(16,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.indas_transition_capa_actions_r3636 enable row level security;

create index if not exists idx_indas_transition_capa_r3636_link on public.indas_transition_capa_actions_r3636(transition_id);
create index if not exists idx_indas_transition_capa_r3636_status on public.indas_transition_capa_actions_r3636(capa_status);

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

  -- 16 transition GAAP-gap lines
  insert into public.indas_transition_r3636 (
    organization_id, entity_name, area_code, gaap_area, standard_ref, period_month,
    igaap_value_rupees, indas_value_rupees, transition_adjustment_rupees, oci_impact_rupees,
    retained_earnings_impact_rupees, materiality_pct, disclosure_ready, adoption_status, trend_dir, notes
  )
  select v_org_id, q.entity, q.acode, q.area, q.sref, q.pmon::date,
    q.igaap, q.indas, q.adj, q.oci,
    q.re, q.mat, q.disc, q.astat, q.trend, q.nt
  from (values
    ('EquipSeva Medtech Pvt Ltd','FTA-PPE-01','Property, Plant & Equipment','Ind AS 16','2026-03-01',
     45000000.00,52000000.00,7000000.00,0.00,7000000.00,6.20,true,'adopted','stable','PPE fair-value-as-deemed-cost election under Ind AS 101 applied'),
    ('EquipSeva Medtech Pvt Ltd','FTA-PPE-02','Property, Plant & Equipment','Ind AS 16','2026-04-01',
     12000000.00,11200000.00,-800000.00,0.00,-800000.00,1.10,true,'adopted','stable','Componentization of imaging equipment completed'),
    ('EquipSeva Services LLP','FTA-LEASE-01','Leases','Ind AS 116','2026-03-01',
     0.00,8600000.00,8600000.00,0.00,-420000.00,4.80,false,'in_progress','improving','ROU asset and lease liability being recognized for branch offices'),
    ('EquipSeva Diagnostics Pvt Ltd','FTA-LEASE-02','Leases','Ind AS 116','2026-05-01',
     0.00,3200000.00,3200000.00,0.00,-180000.00,2.10,false,'under_assessment','worsening','Embedded leases in AMC service contracts under review'),
    ('EquipSeva Medtech Pvt Ltd','FTA-FININST-01','Financial Instruments','Ind AS 109','2026-04-01',
     2400000.00,3650000.00,1250000.00,0.00,-1250000.00,3.40,false,'in_progress','improving','ECL model on trade receivables replacing incurred-loss provision'),
    ('EquipSeva Diagnostics Pvt Ltd','FTA-FININST-02','Financial Instruments','Ind AS 113','2026-06-01',
     5000000.00,5420000.00,420000.00,420000.00,0.00,1.90,false,'under_assessment','stable','FVTOCI classification of mutual fund investments pending fair value'),
    ('EquipSeva Medtech Pvt Ltd','FTA-REV-01','Revenue','Ind AS 115','2026-05-01',
     88000000.00,85600000.00,-2400000.00,0.00,-2400000.00,5.60,true,'adopted','stable','Bundled AMC and install contracts unbundled to performance obligations'),
    ('EquipSeva Services LLP','FTA-REV-02','Revenue','Ind AS 115','2026-06-01',
     15000000.00,15000000.00,0.00,0.00,0.00,0.20,true,'adopted','stable','Service revenue timing unchanged; documented for disclosure'),
    ('EquipSeva Medtech Pvt Ltd','FTA-EMPB-01','Employee Benefits','Ind AS 19','2026-04-01',
     1800000.00,2350000.00,550000.00,-550000.00,0.00,2.70,false,'in_progress','improving','Actuarial gratuity remeasurement routed through OCI'),
    ('EquipSeva Diagnostics Pvt Ltd','FTA-EMPB-02','Employee Benefits','Ind AS 19','2026-07-01',
     900000.00,1180000.00,280000.00,-280000.00,0.00,1.30,false,'under_assessment','worsening','Leave encashment actuarial valuation not yet received'),
    ('EquipSeva Medtech Pvt Ltd','FTA-TAX-01','Income Taxes','Ind AS 12','2026-05-01',
     3200000.00,5100000.00,1900000.00,0.00,-1900000.00,4.10,false,'in_progress','improving','Deferred tax on all Ind-AS transition adjustments being recomputed'),
    ('EquipSeva Services LLP','FTA-TAX-02','Income Taxes','Ind AS 12','2026-06-01',
     400000.00,620000.00,220000.00,60000.00,-160000.00,0.90,false,'under_assessment','stable','DTA on lease liability differences under assessment'),
    ('EquipSeva Medtech Pvt Ltd','FTA-BC-01','Business Combinations','Ind AS 103','2026-03-01',
     6000000.00,6000000.00,0.00,0.00,0.00,0.10,true,'not_applicable','stable','Ind AS 101 exemption: past business combinations not restated'),
    ('EquipSeva Diagnostics Pvt Ltd','FTA-PROV-01','Provisions and Contingencies','Ind AS 37','2026-07-01',
     1200000.00,1050000.00,-150000.00,0.00,150000.00,0.80,true,'adopted','stable','Warranty provision discounting applied'),
    ('EquipSeva Medtech Pvt Ltd','FTA-LEASE-03','Leases','Ind AS 116','2026-07-01',
     0.00,5400000.00,5400000.00,0.00,-260000.00,3.10,false,'deferred','worsening','Warehouse lease recognition deferred pending contract renegotiation'),
    ('EquipSeva Diagnostics Pvt Ltd','FTA-FININST-03','Financial Instruments','Ind AS 109','2026-06-01',
     3000000.00,2780000.00,-220000.00,0.00,-220000.00,1.50,false,'deferred','worsening','Borrowings measured at amortized cost with EIR; deferred to Q2')
  ) as q(entity, acode, area, sref, pmon, igaap, indas, adj, oci, re, mat, disc, astat, trend, nt);

  -- CAPA seed — attach to specific lines via area_code
  insert into public.indas_transition_capa_actions_r3636 (
    transition_id, finding_category, root_cause, corrective_action,
    capa_status, adjustment_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('FTA-LEASE-02','lease_liability_not_recognized','lease_data_incomplete','recognize_lease_liability','in_progress',3200000.00,'CFO Office','2026-08-15',null,'Embedded lease register being built from AMC contracts'),
    ('FTA-FININST-01','expected_credit_loss_shortfall','system_not_configured_for_indas','book_ecl_provision','verification_pending',1250000.00,'Financial Controller','2026-08-10',null,'ECL provision matrix built; auditor validating aging buckets'),
    ('FTA-EMPB-02','employee_benefit_actuarial_gap','actuary_input_delayed','engage_actuary','open',280000.00,'HR Finance','2026-08-20',null,'Leave encashment actuarial report awaited from consultant'),
    ('FTA-TAX-01','unrecognized_deferred_tax','management_judgement_pending','recompute_deferred_tax','in_progress',1900000.00,'Tax Lead','2026-08-05',null,'Deferred tax recomputation on cumulative transition adjustments'),
    ('FTA-LEASE-03','lease_liability_not_recognized','management_judgement_pending','recognize_lease_liability','escalated',5400000.00,'CFO Office','2026-07-25',null,'Warehouse lease deferral flagged by auditor as non-compliant'),
    ('FTA-FININST-02','fair_value_remeasurement_gap','valuation_report_pending','obtain_valuation_report','open',420000.00,'Treasury','2026-08-18',null,'FVTOCI fair value of MF investments from fund house pending'),
    ('FTA-REV-01','revenue_timing_difference','first_time_adoption_exemption_choice','restate_revenue_schedule','closed',2400000.00,'Revenue Accounting','2026-06-30','2026-06-28','Bundled contract performance-obligation allocation completed and disclosed'),
    ('FTA-EMPB-01','disclosure_note_incomplete','policy_documentation_gap','prepare_disclosure_note','overdue',550000.00,'Financial Reporting','2026-07-15',null,'OCI remeasurement disclosure note past target date')
  ) as q(acode, fc, rc, ca, cst, impact, ownr, tcd, acd, nt)
  join public.indas_transition_r3636 e
    on e.organization_id = v_org_id and e.area_code = q.acode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Adoption-status distribution
create or replace function public.founder_r3636_adoption_status_rollup()
returns table(adoption_status text, areas bigint, total_adjustment_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.indas_transition_r3636)
  select l.adoption_status, count(*)::bigint,
         coalesce(sum(l.transition_adjustment_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.indas_transition_r3636 l
  group by l.adoption_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3636_adoption_status_rollup() from public, anon;
grant execute on function public.founder_r3636_adoption_status_rollup() to authenticated;

-- 2) GAAP-area scorecard
create or replace function public.founder_r3636_gaap_area_scorecard()
returns table(
  gaap_area text,
  line_items bigint,
  adopted bigint,
  in_progress bigint,
  under_assessment bigint,
  deferred bigint,
  total_transition_adj_rupees numeric,
  total_oci_impact_rupees numeric,
  total_re_impact_rupees numeric,
  disclosure_ready_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.gaap_area,
    count(*)::bigint,
    count(*) filter (where l.adoption_status = 'adopted')::bigint,
    count(*) filter (where l.adoption_status = 'in_progress')::bigint,
    count(*) filter (where l.adoption_status = 'under_assessment')::bigint,
    count(*) filter (where l.adoption_status = 'deferred')::bigint,
    coalesce(sum(l.transition_adjustment_rupees),0)::numeric,
    coalesce(sum(l.oci_impact_rupees),0)::numeric,
    coalesce(sum(l.retained_earnings_impact_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.disclosure_ready = true)::numeric / nullif(count(*),0), 1)
  from public.indas_transition_r3636 l
  group by l.gaap_area
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3636_gaap_area_scorecard() from public, anon;
grant execute on function public.founder_r3636_gaap_area_scorecard() to authenticated;

-- 3) GAAP-area × adoption-status matrix
create or replace function public.founder_r3636_area_status_matrix()
returns table(gaap_area text, adoption_status text, line_items bigint, total_adjustment_rupees numeric, avg_materiality_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.gaap_area, l.adoption_status, count(*)::bigint,
    coalesce(sum(l.transition_adjustment_rupees),0)::numeric,
    round(avg(l.materiality_pct), 2)
  from public.indas_transition_r3636 l
  group by l.gaap_area, l.adoption_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3636_area_status_matrix() from public, anon;
grant execute on function public.founder_r3636_area_status_matrix() to authenticated;

-- 4) Monthly adoption trend
create or replace function public.founder_r3636_monthly_adoption_trend()
returns table(period_month date, line_items bigint, adopted bigint, under_assessment bigint, total_adjustment_rupees numeric, total_oci_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.adoption_status = 'adopted')::bigint,
    count(*) filter (where l.adoption_status in ('under_assessment','deferred'))::bigint,
    coalesce(sum(l.transition_adjustment_rupees),0)::numeric,
    coalesce(sum(l.oci_impact_rupees),0)::numeric
  from public.indas_transition_r3636 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3636_monthly_adoption_trend() from public, anon;
grant execute on function public.founder_r3636_monthly_adoption_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3636_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.adjustment_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.indas_transition_capa_actions_r3636 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3636_capa_status_board() from public, anon;
grant execute on function public.founder_r3636_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3636_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.indas_transition_capa_actions_r3636)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.adjustment_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.indas_transition_capa_actions_r3636 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3636_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3636_root_cause_pareto() to authenticated;

-- 7) Adjustment-impact digest (by finding category)
create or replace function public.founder_r3636_adjustment_impact_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.adjustment_impact_rupees),0)::numeric
  from public.indas_transition_capa_actions_r3636 c
  group by c.finding_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3636_adjustment_impact_digest() from public, anon;
grant execute on function public.founder_r3636_adjustment_impact_digest() to authenticated;

-- 8) High-risk queue (under-assessment / deferred / not disclosure-ready)
create or replace function public.founder_r3636_high_risk_queue()
returns table(
  entity_name text,
  area_code text,
  gaap_area text,
  standard_ref text,
  period_month date,
  adoption_status text,
  transition_adjustment_rupees numeric,
  materiality_pct numeric,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name, l.area_code, l.gaap_area, l.standard_ref, l.period_month,
    l.adoption_status, l.transition_adjustment_rupees, l.materiality_pct, l.trend_dir, l.notes
  from public.indas_transition_r3636 l
  where l.adoption_status in ('under_assessment','deferred')
     or l.disclosure_ready = false
     or l.trend_dir = 'worsening'
  order by case l.adoption_status
             when 'deferred' then 0
             when 'under_assessment' then 1
             when 'in_progress' then 2
             else 3
           end,
           l.period_month desc, l.entity_name;
end;
$$;

revoke execute on function public.founder_r3636_high_risk_queue() from public, anon;
grant execute on function public.founder_r3636_high_risk_queue() to authenticated;
