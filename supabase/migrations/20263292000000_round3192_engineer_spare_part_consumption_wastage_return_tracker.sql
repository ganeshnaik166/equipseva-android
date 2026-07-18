-- Round 3192: Engineer Spare-Part Consumption, Wastage & Return-Rate Tracker
-- Parts discipline log — engineer × part category × issued/used/returned × wastage % × wrong-part orders × warranty-misuse × cost consumed × CAPA

-- =============================================================================
-- TABLE 1: spare_consumption_r3192 — per-engineer per-slip parts consumption log
-- =============================================================================
create table if not exists public.spare_consumption_r3192 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  engineer_name text not null,
  issue_slip_no text not null,
  part_category text not null check (part_category in (
    'sensor_probe','pcb_control_board','battery_pack','flow_valve','o2_cell',
    'patient_cable','filter_hepa','compressor_unit','display_panel','tubing_kit'
  )),
  audit_date date not null,
  parts_issued int not null,
  parts_used int not null,
  parts_returned int not null default 0,
  wrong_part_orders int not null default 0,
  warranty_part_misuse_flag boolean not null default false,
  issue_channel text not null check (issue_channel in (
    'central_store','regional_hub','courier_direct','engineer_boot_stock','vendor_drop_ship'
  )),
  dominant_return_reason text not null check (dominant_return_reason in (
    'not_required','wrong_part_ordered','defective_on_arrival',
    'over_ordered_buffer','job_cancelled','not_returned','no_returns'
  )),
  wastage_pct numeric(5,2) not null,
  return_rate_pct numeric(5,2),
  cost_consumed_rupees numeric(12,2) not null,
  cost_wasted_rupees numeric(12,2),
  consumption_verdict text not null check (consumption_verdict in (
    'efficient','acceptable','watch','wasteful','critical_wastage','under_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.spare_consumption_r3192 enable row level security;

create index if not exists idx_spare_consumption_r3192_org on public.spare_consumption_r3192(organization_id);
create index if not exists idx_spare_consumption_r3192_date on public.spare_consumption_r3192(audit_date);
create index if not exists idx_spare_consumption_r3192_verdict on public.spare_consumption_r3192(consumption_verdict);

-- =============================================================================
-- TABLE 2: spare_consumption_capa_actions_r3192 — CAPA & recovery actions
-- =============================================================================
create table if not exists public.spare_consumption_capa_actions_r3192 (
  id uuid primary key default gen_random_uuid(),
  consumption_log_id uuid not null references public.spare_consumption_r3192(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'excess_wastage','wrong_part_pattern','warranty_misuse','low_return_compliance',
    'boot_stock_shrinkage','cost_overrun','doa_spike','hoarding_suspected'
  )),
  root_cause text not null check (root_cause in (
    'incorrect_diagnosis','catalog_lookup_error','training_gap','poor_packaging',
    'vendor_quality_issue','no_return_process','asset_model_mismatch',
    'intentional_diversion','demand_forecast_error','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'retrain_engineer','update_part_catalog','enforce_return_policy','switch_vendor',
    'add_photo_proof_step','audit_boot_stock','recover_cost_from_engineer',
    'tighten_warranty_claim_check','introduce_kitting','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'oem_warranty_breach','vendor_sla_breach','none','internal_only',
    'financial_writeoff','insurance_claim_impact'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.spare_consumption_capa_actions_r3192 enable row level security;

create index if not exists idx_spare_capa_r3192_log on public.spare_consumption_capa_actions_r3192(consumption_log_id);
create index if not exists idx_spare_capa_r3192_status on public.spare_consumption_capa_actions_r3192(capa_status);

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

  -- 14 consumption log rows
  insert into public.spare_consumption_r3192 (
    organization_id, hospital_name, engineer_name, issue_slip_no, part_category,
    audit_date, parts_issued, parts_used, parts_returned, wrong_part_orders,
    warranty_part_misuse_flag, issue_channel, dominant_return_reason,
    wastage_pct, return_rate_pct, cost_consumed_rupees, cost_wasted_rupees,
    consumption_verdict, notes
  )
  select v_org_id, q.hosp, q.eng, q.slip, q.cat,
    q.ad::date, q.iss, q.used, q.ret, q.wrong,
    q.misuse, q.chan, q.rr,
    q.wp, q.rp, q.cc, q.cw,
    q.cv, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','Ravi Kumar','SLP-3192-001','o2_cell','2026-07-01',
     6,5,1,0,false,'central_store','over_ordered_buffer',0.00,16.67,42500.00,0.00,'efficient','Clean O2 cell swap — one sealed cell returned to store'),
    ('Apollo Hyderabad Jubilee Hills','Ravi Kumar','SLP-3192-002','patient_cable','2026-07-01',
     10,7,1,1,false,'engineer_boot_stock','wrong_part_ordered',20.00,10.00,18900.00,3780.00,'watch','Two SpO2 cables damaged during routing; one wrong ECG cable ordered'),
    ('Fortis Bannerghatta Bengaluru','Sandeep Verma','SLP-3192-003','pcb_control_board','2026-06-30',
     4,2,0,2,true,'vendor_drop_ship','not_returned',50.00,0.00,156000.00,78000.00,'critical_wastage','Two boards blown in rework; warranty board fitted on out-of-warranty ventilator'),
    ('Fortis Bannerghatta Bengaluru','Sandeep Verma','SLP-3192-004','flow_valve','2026-06-30',
     5,4,1,0,false,'regional_hub','over_ordered_buffer',0.00,20.00,33400.00,0.00,'efficient','Valve overhaul kit — spare returned unopened'),
    ('Manipal Whitefield Bengaluru','Priya Nair','SLP-3192-005','battery_pack','2026-06-29',
     8,6,0,1,false,'central_store','defective_on_arrival',25.00,0.00,96000.00,24000.00,'wasteful','Two packs dead on arrival — no return docket raised with vendor'),
    ('Manipal Whitefield Bengaluru','Kavya Shetty','SLP-3192-006','filter_hepa','2026-06-29',
     12,11,1,0,false,'central_store','not_required',0.00,8.33,26400.00,0.00,'efficient','Ventilator HEPA drive — one filter not needed after inspection'),
    ('AIIMS New Delhi Ansari Nagar','Vikram Singh','SLP-3192-007','sensor_probe','2026-06-28',
     9,6,1,2,false,'courier_direct','wrong_part_ordered',22.22,11.11,71100.00,15800.00,'watch','Temp probes ordered against wrong monitor model twice'),
    ('AIIMS New Delhi Ansari Nagar','Vikram Singh','SLP-3192-008','compressor_unit','2026-06-28',
     2,2,0,0,false,'vendor_drop_ship','no_returns',0.00,0.00,184000.00,0.00,'efficient','Both compressors fitted and commissioned same day'),
    ('KIMS Secunderabad','Arjun Reddy','SLP-3192-009','display_panel','2026-06-27',
     3,1,0,1,true,'regional_hub','not_returned',66.67,0.00,87000.00,58000.00,'critical_wastage','Two panels cracked in boot stock; warranty panel used on billable job'),
    ('KIMS Secunderabad','Arjun Reddy','SLP-3192-010','tubing_kit','2026-06-27',
     15,12,2,0,false,'engineer_boot_stock','job_cancelled',6.67,13.33,13500.00,900.00,'acceptable','One kit consumed on cancelled job before stand-down call'),
    ('Care Hospitals Banjara Hills','Mohammed Faisal','SLP-3192-011','o2_cell','2026-06-26',
     7,5,2,0,false,'central_store','over_ordered_buffer',0.00,28.57,35500.00,0.00,'efficient','Buffer cells returned sealed within 48 hours'),
    ('Yashoda Somajiguda Hyderabad','Deepak Rao','SLP-3192-012','pcb_control_board','2026-06-26',
     6,4,0,1,false,'courier_direct','not_returned',33.33,0.00,234000.00,78000.00,'wasteful','Two boards unaccounted after job closure — boot-stock audit raised'),
    ('St John''s Bengaluru','Sneha Kulkarni','SLP-3192-013','battery_pack','2026-06-25',
     5,5,0,0,false,'regional_hub','no_returns',0.00,0.00,60000.00,0.00,'efficient','Defib battery refresh — full consumption, zero wastage'),
    ('Rainbow Children''s Hyderabad','Anil Joshi','SLP-3192-014','sensor_probe','2026-06-25',
     8,4,1,1,false,'engineer_boot_stock','defective_on_arrival',37.50,12.50,63200.00,23700.00,'under_review','Three probes failed out-of-box calibration — DOA claim pending')
  ) as q(hosp, eng, slip, cat, ad, iss, used, ret, wrong, misuse, chan, rr, wp, rp, cc, cw, cv, nt);

  -- CAPA seed — attach to specific issue slips
  insert into public.spare_consumption_capa_actions_r3192 (
    consumption_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cs, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('SLP-3192-003','warranty_misuse','intentional_diversion','recover_cost_from_engineer','escalated','oem_warranty_breach','2026-07-08',null,78000.00,'Warranty PCB fitted on out-of-warranty unit — cost recovery memo issued'),
    ('SLP-3192-009','warranty_misuse','training_gap','tighten_warranty_claim_check','in_progress','oem_warranty_breach','2026-07-06',null,58000.00,'OEM rejected panel claim — pre-claim checklist rolled out'),
    ('SLP-3192-005','doa_spike','vendor_quality_issue','switch_vendor','closed','vendor_sla_breach','2026-07-04','2026-07-02',24000.00,'Battery vendor lot recalled — alternate vendor onboarded'),
    ('SLP-3192-007','wrong_part_pattern','catalog_lookup_error','update_part_catalog','verification_pending','internal_only','2026-07-05',null,15800.00,'Monitor model to probe mapping corrected in part catalog'),
    ('SLP-3192-012','boot_stock_shrinkage','no_return_process','audit_boot_stock','open','financial_writeoff','2026-07-10',null,78000.00,'Physical boot-stock audit scheduled for Hyderabad cluster'),
    ('SLP-3192-014','doa_spike','vendor_quality_issue','add_photo_proof_step','overdue','insurance_claim_impact','2026-06-30',null,23700.00,'Unboxing photo proof now mandatory before DOA claims')
  ) as q(slip, fc, rc, ca, cs, ri, tcd, acd, cost, nt)
  join public.spare_consumption_r3192 e
    on e.organization_id = v_org_id and e.issue_slip_no = q.slip;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Consumption verdict distribution
create or replace function public.founder_r3192_verdict_rollup()
returns table(consumption_verdict text, logs bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.spare_consumption_r3192)
  select l.consumption_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.spare_consumption_r3192 l
  group by l.consumption_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3192_verdict_rollup() from public, anon;
grant execute on function public.founder_r3192_verdict_rollup() to authenticated;

-- 2) Engineer parts-discipline scorecard
create or replace function public.founder_r3192_engineer_scorecard()
returns table(
  engineer_name text,
  hospital_name text,
  logs bigint,
  parts_issued bigint,
  parts_used bigint,
  parts_returned bigint,
  avg_wastage_pct numeric,
  wrong_part_orders bigint,
  misuse_flags bigint,
  cost_consumed_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.hospital_name,
    count(*)::bigint,
    coalesce(sum(l.parts_issued),0)::bigint,
    coalesce(sum(l.parts_used),0)::bigint,
    coalesce(sum(l.parts_returned),0)::bigint,
    round(avg(l.wastage_pct), 2),
    coalesce(sum(l.wrong_part_orders),0)::bigint,
    count(*) filter (where l.warranty_part_misuse_flag)::bigint,
    coalesce(sum(l.cost_consumed_rupees),0)::numeric
  from public.spare_consumption_r3192 l
  group by l.engineer_name, l.hospital_name
  order by round(avg(l.wastage_pct), 2) desc;
end;
$$;

revoke execute on function public.founder_r3192_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3192_engineer_scorecard() to authenticated;

-- 3) Part category × issue channel matrix
create or replace function public.founder_r3192_category_channel_matrix()
returns table(part_category text, issue_channel text, logs bigint, parts_issued bigint, avg_wastage_pct numeric, cost_consumed_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.part_category, l.issue_channel, count(*)::bigint,
    coalesce(sum(l.parts_issued),0)::bigint,
    round(avg(l.wastage_pct), 2),
    coalesce(sum(l.cost_consumed_rupees),0)::numeric
  from public.spare_consumption_r3192 l
  group by l.part_category, l.issue_channel
  order by coalesce(sum(l.cost_consumed_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3192_category_channel_matrix() from public, anon;
grant execute on function public.founder_r3192_category_channel_matrix() to authenticated;

-- 4) Daily consumption trend
create or replace function public.founder_r3192_daily_consumption_trend()
returns table(audit_date date, logs bigint, parts_issued bigint, parts_used bigint, parts_returned bigint, avg_wastage_pct numeric, cost_consumed_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date, count(*)::bigint,
    coalesce(sum(l.parts_issued),0)::bigint,
    coalesce(sum(l.parts_used),0)::bigint,
    coalesce(sum(l.parts_returned),0)::bigint,
    round(avg(l.wastage_pct), 2),
    coalesce(sum(l.cost_consumed_rupees),0)::numeric
  from public.spare_consumption_r3192 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3192_daily_consumption_trend() from public, anon;
grant execute on function public.founder_r3192_daily_consumption_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3192_capa_status_board()
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
  from public.spare_consumption_capa_actions_r3192 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3192_capa_status_board() from public, anon;
grant execute on function public.founder_r3192_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3192_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.spare_consumption_capa_actions_r3192)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.spare_consumption_capa_actions_r3192 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3192_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3192_root_cause_pareto() to authenticated;

-- 7) Regulatory / commercial impact digest
create or replace function public.founder_r3192_regulatory_impact_digest()
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
  from public.spare_consumption_capa_actions_r3192 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3192_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3192_regulatory_impact_digest() to authenticated;

-- 8) High-risk consumption queue (top individual concerns)
create or replace function public.founder_r3192_high_risk_queue()
returns table(
  hospital_name text,
  engineer_name text,
  issue_slip_no text,
  part_category text,
  audit_date date,
  wastage_pct numeric,
  wrong_part_orders int,
  warranty_misuse text,
  consumption_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.issue_slip_no, l.part_category, l.audit_date,
    l.wastage_pct, l.wrong_part_orders,
    case when l.warranty_part_misuse_flag then 'yes' else 'no' end,
    l.consumption_verdict, l.notes
  from public.spare_consumption_r3192 l
  where l.consumption_verdict in ('watch','wasteful','critical_wastage','under_review')
     or l.warranty_part_misuse_flag
     or l.wrong_part_orders > 0
     or l.wastage_pct >= 20
  order by l.wastage_pct desc, l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3192_high_risk_queue() from public, anon;
grant execute on function public.founder_r3192_high_risk_queue() to authenticated;
