-- Round 3393: Founder Capex / Equipment-Investment ROI Post-Implementation-Audit Board
-- Capex ROI post-audit — asset category × business case × projected vs actual return × payback × utilization × ROI variance × benefit realization × CAPA

-- =============================================================================
-- TABLE 1: capex_roi_postaudit_r3393 — per-asset capex ROI post-audit
-- =============================================================================
create table if not exists public.capex_roi_postaudit_r3393 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  asset_name text not null,
  asset_category text not null check (asset_category in (
    'imaging','lab','dialysis','test_equipment','vehicles','it_infra','workshop_tools'
  )),
  business_case_ref text not null,
  capex_amount_rupees numeric(14,2) not null,
  approved_date date not null,
  commissioned_date date not null,
  projected_annual_return_rupees numeric(14,2) not null,
  actual_annual_return_rupees numeric(14,2) not null,
  projected_payback_months int not null,
  actual_payback_months int not null,
  utilization_pct numeric(5,2) not null,
  roi_variance_pct numeric(6,2) not null,
  benefit_realization text not null check (benefit_realization in (
    'exceeded','on_track','below_case','not_realized'
  )),
  post_audit_status text not null check (post_audit_status in (
    'pending','completed','deferred'
  )),
  roi_verdict text not null check (roi_verdict in (
    'value_confirmed','on_track','underperforming','write_off_review','lessons_learned'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.capex_roi_postaudit_r3393 enable row level security;

create index if not exists idx_capex_roi_postaudit_r3393_org on public.capex_roi_postaudit_r3393(organization_id);
create index if not exists idx_capex_roi_postaudit_r3393_verdict on public.capex_roi_postaudit_r3393(roi_verdict);

-- =============================================================================
-- TABLE 2: capex_roi_postaudit_capa_actions_r3393 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.capex_roi_postaudit_capa_actions_r3393 (
  id uuid primary key default gen_random_uuid(),
  audit_log_id uuid not null references public.capex_roi_postaudit_r3393(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'utilization_below_case','return_below_projection','payback_slippage','benefit_not_realized',
    'post_audit_overdue','assumption_error','asset_idle','write_off_candidate'
  )),
  root_cause text not null check (root_cause in (
    'demand_overestimated','pricing_below_plan','utilization_ramp_slow','competing_capacity',
    'operational_downtime','wrong_location','assumption_error','pending_investigation','market_shift'
  )),
  corrective_action text not null check (corrective_action in (
    'redeploy_asset','reprice_service','demand_generation','relocate_asset','improve_uptime',
    'divest_asset','update_investment_policy','capture_lessons_learned','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  financial_impact text not null check (financial_impact in (
    'high_value_leak','moderate','low','none','impairment_risk','strategic'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_recovery_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.capex_roi_postaudit_capa_actions_r3393 enable row level security;

create index if not exists idx_capex_roi_capa_r3393_log on public.capex_roi_postaudit_capa_actions_r3393(audit_log_id);
create index if not exists idx_capex_roi_capa_r3393_status on public.capex_roi_postaudit_capa_actions_r3393(capa_status);

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

  insert into public.capex_roi_postaudit_r3393 (
    organization_id, asset_name, asset_category, business_case_ref, capex_amount_rupees,
    approved_date, commissioned_date, projected_annual_return_rupees, actual_annual_return_rupees,
    projected_payback_months, actual_payback_months, utilization_pct, roi_variance_pct,
    benefit_realization, post_audit_status, roi_verdict, notes
  )
  select v_org_id, q.asset, q.cat, q.ref, q.capex::numeric,
    q.appr::date, q.comm::date, q.projret::numeric, q.actret::numeric,
    q.projpb::int, q.actpb::int, q.util::numeric, q.roivar::numeric,
    q.benefit, q.pas, q.rv, q.nt
  from (values
    ('CT Field Calibration Rig','test_equipment','BC-2024-011','2500000','2024-09-01','2024-11-15','1200000','1350000',25,22,88.0,12.5,'exceeded','completed','value_confirmed','Calibration rig utilization high; returns beat case'),
    ('Chennai Cal-Lab Multifunction Analyzer','test_equipment','BC-2024-018','1800000','2024-10-01','2024-12-01','900000','940000',24,23,82.0,4.4,'on_track','completed','on_track','Multifunction analyzer on plan'),
    ('Gurgaon Workshop Bench Fleet','workshop_tools','BC-2024-022','1200000','2024-08-15','2024-10-01','700000','520000',21,29,64.0,-25.7,'below_case','completed','underperforming','Bench utilization below case — redeploy some benches'),
    ('Field Service Van Fleet (5)','vehicles','BC-2024-030','4000000','2024-07-01','2024-09-01','1600000','1520000',30,32,79.0,-5.0,'on_track','completed','on_track','Van fleet slightly below plan, acceptable'),
    ('Bengaluru Demo Dialysis Unit','dialysis','BC-2024-035','2200000','2024-11-01','2025-01-15','850000','410000',31,64,41.0,-51.8,'not_realized','completed','write_off_review','Demo dialysis unit idle — relocate or divest'),
    ('Cloud FSM / IT Infra Upgrade','it_infra','BC-2024-041','1500000','2024-06-01','2024-08-01','1100000','1240000',16,14,92.0,12.7,'exceeded','completed','value_confirmed','FSM platform efficiency gains exceeded case'),
    ('Hyderabad Imaging Test Suite','imaging','BC-2025-004','3200000','2025-01-01','2025-03-01','1400000','1180000',27,33,71.0,-15.7,'below_case','completed','underperforming','Imaging test suite utilization ramp slow'),
    ('Mobile Lab Analyzer Kit','lab','BC-2025-009','950000','2025-02-01','2025-04-01','520000','560000',22,20,85.0,7.7,'on_track','completed','on_track','Mobile lab kit on plan'),
    ('Defib Analyzer Fleet','test_equipment','BC-2025-012','680000','2025-03-01','2025-05-01','360000','380000',23,21,80.0,5.6,'on_track','pending','on_track','Post-audit pending final quarter data'),
    ('Vellore Regional Cal-Lab Standards','test_equipment','BC-2025-015','2900000','2025-01-15','2025-04-01','1250000','1300000',28,26,84.0,4.0,'on_track','completed','value_confirmed','Regional cal-lab standards performing to case'),
    ('Workshop Diagnostic Tooling','workshop_tools','BC-2025-020','780000','2025-02-15','2025-04-15','420000','300000',22,31,58.0,-28.6,'below_case','deferred','underperforming','Diagnostic tooling underused — post-audit deferred, expedite'),
    ('IT Security / DR Infra','it_infra','BC-2025-024','1300000','2025-03-01','2025-05-01','900000','870000',17,18,90.0,-3.3,'on_track','pending','on_track','Security/DR infra ROI in intangible risk-reduction, on track'),
    ('Second Imaging Demo Unit','imaging','BC-2025-028','3600000','2025-02-01','2025-05-15','1500000','620000',29,70,38.0,-58.7,'not_realized','completed','write_off_review','Second imaging demo unit heavily underutilized — divest review'),
    ('Vehicle Telematics Rollout','vehicles','BC-2025-031','620000','2025-04-01','2025-06-01','480000','510000',15,14,94.0,6.3,'exceeded','pending','lessons_learned','Telematics beat case; capture playbook for future fleet')
  ) as q(asset, cat, ref, capex, appr, comm, projret, actret, projpb, actpb, util, roivar, benefit, pas, rv, nt);

  insert into public.capex_roi_postaudit_capa_actions_r3393 (
    audit_log_id, finding_category, root_cause, corrective_action,
    capa_status, financial_impact, target_closure_date, actual_closure_date,
    estimated_recovery_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.fi, q.tcd::date, q.acd::date,
    q.rec::numeric, q.nt
  from (values
    ('BC-2024-035','benefit_not_realized','wrong_location','relocate_asset','in_progress','impairment_risk','2026-08-15',null,1400000,'Demo dialysis unit relocation to higher-demand site under evaluation'),
    ('BC-2025-028','asset_idle','demand_overestimated','divest_asset','escalated','high_value_leak','2026-08-01',null,2500000,'Second imaging demo unit divestment / redeployment escalated'),
    ('BC-2024-022','utilization_below_case','competing_capacity','redeploy_asset','open','moderate','2026-08-20',null,400000,'Redeploy idle workshop benches to Chennai hub'),
    ('BC-2025-004','return_below_projection','utilization_ramp_slow','demand_generation','open','moderate','2026-08-25',null,600000,'Imaging test suite demand-generation push planned'),
    ('BC-2025-020','post_audit_overdue','assumption_error','update_investment_policy','overdue','low','2026-07-30',null,0,'Deferred post-audit of diagnostic tooling — complete and update policy'),
    ('BC-2024-011','benefit_not_realized','market_shift','capture_lessons_learned','closed','strategic','2026-07-15','2026-07-10',0,'Calibration rig outperformance playbook captured for future capex'),
    ('BC-2025-031','benefit_not_realized','market_shift','capture_lessons_learned','verification_pending','strategic','2026-08-05',null,0,'Telematics ROI playbook to standardize across fleet purchases')
  ) as q(ref, fc, rc, ca, cst, fi, tcd, acd, rec, nt)
  join public.capex_roi_postaudit_r3393 e
    on e.organization_id = v_org_id and e.business_case_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

create or replace function public.founder_r3393_roi_verdict_rollup()
returns table(roi_verdict text, assets bigint, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.capex_roi_postaudit_r3393)
  select l.roi_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.capex_roi_postaudit_r3393 l group by l.roi_verdict order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3393_roi_verdict_rollup() from public, anon;
grant execute on function public.founder_r3393_roi_verdict_rollup() to authenticated;

create or replace function public.founder_r3393_category_scorecard()
returns table(
  asset_category text, assets bigint, total_capex_rupees numeric, total_actual_return_rupees numeric,
  underperforming bigint, write_off_review bigint, avg_utilization_pct numeric, avg_roi_variance_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_category, count(*)::bigint,
    coalesce(sum(l.capex_amount_rupees),0)::numeric,
    coalesce(sum(l.actual_annual_return_rupees),0)::numeric,
    count(*) filter (where l.roi_verdict = 'underperforming')::bigint,
    count(*) filter (where l.roi_verdict = 'write_off_review')::bigint,
    round(avg(l.utilization_pct), 1),
    round(avg(l.roi_variance_pct), 1)
  from public.capex_roi_postaudit_r3393 l group by l.asset_category order by sum(l.capex_amount_rupees) desc;
end;
$$;
revoke execute on function public.founder_r3393_category_scorecard() from public, anon;
grant execute on function public.founder_r3393_category_scorecard() to authenticated;

create or replace function public.founder_r3393_category_realization_matrix()
returns table(asset_category text, benefit_realization text, assets bigint, total_capex_rupees numeric, avg_roi_variance_pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_category, l.benefit_realization, count(*)::bigint,
    coalesce(sum(l.capex_amount_rupees),0)::numeric,
    round(avg(l.roi_variance_pct), 1)
  from public.capex_roi_postaudit_r3393 l group by l.asset_category, l.benefit_realization order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3393_category_realization_matrix() from public, anon;
grant execute on function public.founder_r3393_category_realization_matrix() to authenticated;

create or replace function public.founder_r3393_commissioning_trend()
returns table(commissioned_month text, assets bigint, total_capex_rupees numeric, underperforming bigint, avg_roi_variance_pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(l.commissioned_date, 'YYYY-MM') as commissioned_month, count(*)::bigint,
    coalesce(sum(l.capex_amount_rupees),0)::numeric,
    count(*) filter (where l.roi_verdict in ('underperforming','write_off_review'))::bigint,
    round(avg(l.roi_variance_pct), 1)
  from public.capex_roi_postaudit_r3393 l group by 1 order by 1 desc;
end;
$$;
revoke execute on function public.founder_r3393_commissioning_trend() from public, anon;
grant execute on function public.founder_r3393_commissioning_trend() to authenticated;

create or replace function public.founder_r3393_capa_status_board()
returns table(capa_status text, findings bigint, avg_recovery_rupees numeric, overdue_flag bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_recovery_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.capex_roi_postaudit_capa_actions_r3393 c group by c.capa_status order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3393_capa_status_board() from public, anon;
grant execute on function public.founder_r3393_capa_status_board() to authenticated;

create or replace function public.founder_r3393_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_recovery_rupees numeric, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.capex_roi_postaudit_capa_actions_r3393)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_recovery_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.capex_roi_postaudit_capa_actions_r3393 c group by c.root_cause order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3393_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3393_root_cause_pareto() to authenticated;

create or replace function public.founder_r3393_financial_impact_digest()
returns table(financial_impact text, findings bigint, open_findings bigint, total_recovery_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.financial_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_recovery_rupees),0)::numeric
  from public.capex_roi_postaudit_capa_actions_r3393 c group by c.financial_impact order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3393_financial_impact_digest() from public, anon;
grant execute on function public.founder_r3393_financial_impact_digest() to authenticated;

create or replace function public.founder_r3393_high_risk_queue()
returns table(
  asset_name text, asset_category text, business_case_ref text, capex_amount_rupees numeric,
  actual_annual_return_rupees numeric, utilization_pct numeric, roi_variance_pct numeric,
  benefit_realization text, roi_verdict text, notes text
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_name, l.asset_category, l.business_case_ref, l.capex_amount_rupees,
    l.actual_annual_return_rupees, l.utilization_pct, l.roi_variance_pct,
    l.benefit_realization, l.roi_verdict, l.notes
  from public.capex_roi_postaudit_r3393 l
  where l.roi_verdict in ('underperforming','write_off_review','lessons_learned')
     or l.benefit_realization in ('below_case','not_realized')
     or l.post_audit_status in ('pending','deferred')
     or l.roi_variance_pct < 0
  order by l.roi_variance_pct asc, l.capex_amount_rupees desc;
end;
$$;
revoke execute on function public.founder_r3393_high_risk_queue() from public, anon;
grant execute on function public.founder_r3393_high_risk_queue() to authenticated;
