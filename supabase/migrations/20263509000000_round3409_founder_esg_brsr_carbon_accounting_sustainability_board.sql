-- Round 3409: Founder ESG BRSR Carbon-Accounting & Sustainability Board
-- ESG governance — esg_pillar × metric_name × period_quarter × current/target value × variance × trend × data_quality × BRSR disclosure readiness × materiality × esg_verdict × CAPA

-- =============================================================================
-- TABLE 1: esg_brsr_metrics_r3409 — per metric/period ESG & carbon-accounting rows
-- =============================================================================
create table if not exists public.esg_brsr_metrics_r3409 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  esg_pillar text not null check (esg_pillar in (
    'environment','social','governance'
  )),
  metric_name text not null check (metric_name in (
    'scope1_emissions_tco2e','scope2_emissions_tco2e','scope3_emissions_tco2e',
    'energy_intensity','water_usage','ewaste_recycled_pct','diversity_ratio',
    'safety_ltifr','board_independence','supplier_esg_screened_pct'
  )),
  period_quarter text not null,
  current_value numeric(14,3),
  target_value numeric(14,3),
  unit text not null,
  variance_vs_target_pct numeric(7,2),
  trend text not null check (trend in (
    'improving','stable','worsening'
  )),
  data_quality text not null check (data_quality in (
    'verified','estimated','unverified'
  )),
  brsr_disclosure_ready boolean not null,
  materiality text not null check (materiality in (
    'high','medium','low'
  )),
  esg_verdict text not null check (esg_verdict in (
    'on_track','ahead','behind_target','data_gap','disclosure_risk','action_needed'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.esg_brsr_metrics_r3409 enable row level security;

create index if not exists idx_esg_brsr_metrics_r3409_org on public.esg_brsr_metrics_r3409(organization_id);
create index if not exists idx_esg_brsr_metrics_r3409_pillar on public.esg_brsr_metrics_r3409(esg_pillar);
create index if not exists idx_esg_brsr_metrics_r3409_verdict on public.esg_brsr_metrics_r3409(esg_verdict);

-- =============================================================================
-- TABLE 2: esg_brsr_metrics_capa_actions_r3409 — improvement / data-quality / disclosure actions
-- =============================================================================
create table if not exists public.esg_brsr_metrics_capa_actions_r3409 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  metric_id uuid not null references public.esg_brsr_metrics_r3409(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'emissions_reduction_gap','data_quality_gap','disclosure_readiness_gap','target_miss',
    'verification_pending','supplier_screening_gap','diversity_shortfall','safety_incident_followup'
  )),
  root_cause text not null check (root_cause in (
    'metering_gap','estimation_methodology','missing_evidence','vendor_data_pending',
    'process_inefficiency','scope3_boundary_undefined','staffing_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'install_sub_metering','adopt_ghg_protocol_method','collect_supplier_evidence','third_party_verification',
    'energy_efficiency_upgrade','define_scope3_boundary','diversity_hiring_plan','safety_training','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  disclosure_impact text not null check (disclosure_impact in (
    'brsr_core_kpi','brsr_leadership_indicator','sebi_disclosure','none','internal_only','investor_esg_query'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.esg_brsr_metrics_capa_actions_r3409 enable row level security;

create index if not exists idx_esg_brsr_capa_r3409_org on public.esg_brsr_metrics_capa_actions_r3409(organization_id);
create index if not exists idx_esg_brsr_capa_r3409_metric on public.esg_brsr_metrics_capa_actions_r3409(metric_id);
create index if not exists idx_esg_brsr_capa_r3409_status on public.esg_brsr_metrics_capa_actions_r3409(capa_status);

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

  -- 14 ESG metric rows
  insert into public.esg_brsr_metrics_r3409 (
    organization_id, hospital_name, esg_pillar, metric_name, period_quarter,
    current_value, target_value, unit, variance_vs_target_pct, trend,
    data_quality, brsr_disclosure_ready, materiality, esg_verdict, notes
  )
  select v_org_id, q.hosp, q.pillar, q.metric, q.period,
    q.curval::numeric, q.tgtval::numeric, q.unit, q.variance::numeric, q.trend,
    q.dq, q.disc_ready, q.mat, q.verdict, q.nt
  from (values
    ('Apollo Chennai','environment','scope1_emissions_tco2e','FY26-Q1',
     420.0,400.0,'tCO2e',5.00,'worsening','verified',true,'high','behind_target','Scope 1 diesel genset emissions above target — DG runtime high during grid outages'),
    ('Apollo Chennai','environment','scope2_emissions_tco2e','FY26-Q1',
     1180.0,1250.0,'tCO2e',-5.60,'improving','verified',true,'high','ahead','Scope 2 grid electricity down on rooftop solar PPA'),
    ('Fortis Gurgaon','environment','scope3_emissions_tco2e','FY26-Q1',
     2600.0,2400.0,'tCO2e',8.33,'worsening','estimated',false,'high','data_gap','Scope 3 supplier logistics estimated — value-chain boundary incomplete'),
    ('Fortis Gurgaon','environment','energy_intensity','FY26-Q1',
     285.0,300.0,'kWh_per_bed_day',-5.00,'improving','verified',true,'medium','on_track','Energy intensity per bed-day within target after HVAC retrofit'),
    ('Manipal Bengaluru','environment','water_usage','FY26-Q1',
     540.0,500.0,'kL_per_day',8.00,'worsening','estimated',false,'medium','behind_target','Water usage above target — cooling-tower makeup and RO reject high'),
    ('Manipal Bengaluru','environment','ewaste_recycled_pct','FY26-Q1',
     72.0,80.0,'percent',-10.00,'improving','verified',true,'medium','behind_target','E-waste recycling below target — biomedical asset disposal backlog'),
    ('AIIMS Delhi','social','diversity_ratio','FY26-Q1',
     38.0,40.0,'percent',-5.00,'stable','verified',true,'high','on_track','Gender diversity ratio near target across clinical and field workforce'),
    ('AIIMS Delhi','social','safety_ltifr','FY26-Q1',
     1.8,1.5,'per_million_hours',20.00,'worsening','verified',true,'high','action_needed','LTIFR above target — field-service lifting and electrical incidents up'),
    ('CMC Vellore','governance','board_independence','FY26-Q1',
     50.0,50.0,'percent',0.00,'stable','verified',true,'high','on_track','Independent directors at target 50 percent of board'),
    ('CMC Vellore','governance','supplier_esg_screened_pct','FY26-Q1',
     62.0,75.0,'percent',-17.33,'improving','estimated',false,'high','disclosure_risk','Supplier ESG screening below target — BRSR core KPI disclosure at risk'),
    ('KIMS Hyderabad','environment','scope1_emissions_tco2e','FY25-Q4',
     405.0,410.0,'tCO2e',-1.22,'improving','verified',true,'high','on_track','Prior-quarter scope 1 within target after genset load balancing'),
    ('KIMS Hyderabad','environment','scope2_emissions_tco2e','FY25-Q4',
     1320.0,1250.0,'tCO2e',5.60,'worsening','unverified',false,'high','data_gap','Scope 2 unverified — utility meter data reconciliation pending'),
    ('Yashoda Hyderabad','social','safety_ltifr','FY26-Q1',
     1.2,1.5,'per_million_hours',-20.00,'improving','verified',true,'medium','ahead','LTIFR below target after field-engineer safety training rollout'),
    ('Kokilaben Mumbai','governance','supplier_esg_screened_pct','FY26-Q1',
     88.0,75.0,'percent',17.33,'improving','verified',true,'medium','ahead','Supplier ESG screening ahead of target — vendor code-of-conduct signed')
  ) as q(hosp, pillar, metric, period, curval, tgtval, unit, variance, trend, dq, disc_ready, mat, verdict, nt);

  -- CAPA seed — attach to specific at-risk metric rows via (hospital, metric, period)
  insert into public.esg_brsr_metrics_capa_actions_r3409 (
    organization_id, metric_id, finding_category, root_cause, corrective_action,
    capa_status, disclosure_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.di, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('Apollo Chennai','scope1_emissions_tco2e','FY26-Q1','emissions_reduction_gap','process_inefficiency','energy_efficiency_upgrade','in_progress','brsr_core_kpi','2026-08-15',null,250000.00,'DG runtime reduction and solar-plus-storage expansion in progress'),
    ('Fortis Gurgaon','scope3_emissions_tco2e','FY26-Q1','data_quality_gap','scope3_boundary_undefined','define_scope3_boundary','open','brsr_leadership_indicator','2026-08-30',null,120000.00,'Define GHG-protocol scope 3 boundary and collect supplier logistics data'),
    ('Manipal Bengaluru','water_usage','FY26-Q1','target_miss','metering_gap','install_sub_metering','in_progress','brsr_core_kpi','2026-08-10',null,180000.00,'Install sub-metering on cooling-tower makeup and RO reject lines'),
    ('Manipal Bengaluru','ewaste_recycled_pct','FY26-Q1','disclosure_readiness_gap','missing_evidence','collect_supplier_evidence','verification_pending','brsr_core_kpi','2026-08-05',null,45000.00,'Collect authorized-recycler manifests as e-waste disclosure evidence'),
    ('AIIMS Delhi','safety_ltifr','FY26-Q1','safety_incident_followup','staffing_gap','safety_training','escalated','investor_esg_query','2026-08-01',null,90000.00,'Field-service safety training and PPE audit — escalated to board ESG committee'),
    ('CMC Vellore','supplier_esg_screened_pct','FY26-Q1','supplier_screening_gap','vendor_data_pending','collect_supplier_evidence','overdue','sebi_disclosure','2026-07-20',null,60000.00,'Supplier ESG screening drive overdue — SEBI BRSR core KPI exposure'),
    ('KIMS Hyderabad','scope2_emissions_tco2e','FY25-Q4','verification_pending','estimation_methodology','third_party_verification','closed','brsr_core_kpi','2026-07-10','2026-07-08',150000.00,'Third-party verification completed for scope 2 meter data reconciliation')
  ) as q(hosp, metric, period, fc, rc, ca, cst, di, tcd, acd, cost, nt)
  join public.esg_brsr_metrics_r3409 e
    on e.organization_id = v_org_id and e.hospital_name = q.hosp
   and e.metric_name = q.metric and e.period_quarter = q.period;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) ESG verdict distribution
create or replace function public.founder_r3409_esg_verdict_rollup()
returns table(esg_verdict text, metrics bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.esg_brsr_metrics_r3409)
  select m.esg_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.esg_brsr_metrics_r3409 m
  group by m.esg_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3409_esg_verdict_rollup() from public, anon;
grant execute on function public.founder_r3409_esg_verdict_rollup() to authenticated;

-- 2) ESG pillar scorecard
create or replace function public.founder_r3409_pillar_scorecard()
returns table(
  esg_pillar text,
  total_metrics bigint,
  on_track bigint,
  ahead bigint,
  behind bigint,
  data_gap bigint,
  disclosure_ready bigint,
  avg_variance_pct numeric,
  on_track_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.esg_pillar,
    count(*)::bigint,
    count(*) filter (where m.esg_verdict in ('on_track','ahead'))::bigint,
    count(*) filter (where m.esg_verdict = 'ahead')::bigint,
    count(*) filter (where m.esg_verdict in ('behind_target','action_needed'))::bigint,
    count(*) filter (where m.esg_verdict in ('data_gap','disclosure_risk'))::bigint,
    count(*) filter (where m.brsr_disclosure_ready = true)::bigint,
    round(avg(m.variance_vs_target_pct), 1),
    round(100.0 * count(*) filter (where m.esg_verdict in ('on_track','ahead'))::numeric / nullif(count(*),0), 1)
  from public.esg_brsr_metrics_r3409 m
  group by m.esg_pillar
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3409_pillar_scorecard() from public, anon;
grant execute on function public.founder_r3409_pillar_scorecard() to authenticated;

-- 3) Metric × quarter matrix
create or replace function public.founder_r3409_metric_quarter_matrix()
returns table(metric_name text, period_quarter text, metrics bigint, on_track bigint, behind bigint, avg_variance_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.metric_name, m.period_quarter, count(*)::bigint,
    count(*) filter (where m.esg_verdict in ('on_track','ahead'))::bigint,
    count(*) filter (where m.esg_verdict in ('behind_target','action_needed','disclosure_risk','data_gap'))::bigint,
    round(avg(m.variance_vs_target_pct), 2)
  from public.esg_brsr_metrics_r3409 m
  group by m.metric_name, m.period_quarter
  order by count(*) desc, m.metric_name;
end;
$$;

revoke execute on function public.founder_r3409_metric_quarter_matrix() from public, anon;
grant execute on function public.founder_r3409_metric_quarter_matrix() to authenticated;

-- 4) Quarterly ESG trend
create or replace function public.founder_r3409_quarterly_trend()
returns table(period_quarter text, metrics bigint, on_track bigint, behind bigint, data_gap bigint, disclosure_ready bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.period_quarter,
    count(*)::bigint,
    count(*) filter (where m.esg_verdict in ('on_track','ahead'))::bigint,
    count(*) filter (where m.esg_verdict in ('behind_target','action_needed'))::bigint,
    count(*) filter (where m.esg_verdict in ('data_gap','disclosure_risk'))::bigint,
    count(*) filter (where m.brsr_disclosure_ready = true)::bigint
  from public.esg_brsr_metrics_r3409 m
  group by m.period_quarter
  order by m.period_quarter desc;
end;
$$;

revoke execute on function public.founder_r3409_quarterly_trend() from public, anon;
grant execute on function public.founder_r3409_quarterly_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3409_capa_status_board()
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
  from public.esg_brsr_metrics_capa_actions_r3409 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3409_capa_status_board() from public, anon;
grant execute on function public.founder_r3409_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3409_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.esg_brsr_metrics_capa_actions_r3409)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.esg_brsr_metrics_capa_actions_r3409 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3409_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3409_root_cause_pareto() to authenticated;

-- 7) Disclosure impact digest
create or replace function public.founder_r3409_disclosure_impact_digest()
returns table(disclosure_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.disclosure_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.esg_brsr_metrics_capa_actions_r3409 c
  group by c.disclosure_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3409_disclosure_impact_digest() from public, anon;
grant execute on function public.founder_r3409_disclosure_impact_digest() to authenticated;

-- 8) High-risk ESG queue (top individual concerns)
create or replace function public.founder_r3409_high_risk_queue()
returns table(
  hospital_name text,
  metric_name text,
  esg_pillar text,
  period_quarter text,
  esg_verdict text,
  data_quality text,
  materiality text,
  brsr_disclosure_ready boolean,
  variance_vs_target_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.hospital_name, m.metric_name, m.esg_pillar, m.period_quarter,
    m.esg_verdict, m.data_quality, m.materiality, m.brsr_disclosure_ready,
    m.variance_vs_target_pct, m.notes
  from public.esg_brsr_metrics_r3409 m
  where m.esg_verdict in ('behind_target','data_gap','disclosure_risk','action_needed')
     or m.data_quality in ('estimated','unverified')
     or m.brsr_disclosure_ready = false
     or m.trend = 'worsening'
  order by m.materiality, m.variance_vs_target_pct desc nulls last, m.hospital_name;
end;
$$;

revoke execute on function public.founder_r3409_high_risk_queue() from public, anon;
grant execute on function public.founder_r3409_high_risk_queue() to authenticated;
