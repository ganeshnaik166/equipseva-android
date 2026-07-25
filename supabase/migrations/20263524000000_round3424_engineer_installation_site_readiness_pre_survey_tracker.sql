-- Round 3424: Engineer Installation Site-Readiness & Pre-Install Survey Tracker
-- Pre-install site survey — equipment type × region × power/HVAC/shielding/floor/access/civil/utilities/network readiness × blockers × go-live verdict × CAPA blocker resolution

-- =============================================================================
-- TABLE 1: engineer_install_site_readiness_r3424 — per site-survey readiness
-- =============================================================================
create table if not exists public.engineer_install_site_readiness_r3424 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  region text not null check (region in (
    'north','south','east','west','central'
  )),
  survey_code text not null,
  equipment_type text not null check (equipment_type in (
    'ct_scanner','mri','cath_lab','linac','lab_analyzer','dialysis_fleet','ot_integration'
  )),
  survey_date date not null,
  power_supply_ready boolean not null,
  hvac_cooling_ready boolean not null,
  shielding_ready text not null check (shielding_ready in (
    'ready','in_progress','not_applicable','gap'
  )),
  floor_loading_ok boolean not null,
  access_route_clear boolean not null,
  civil_works_complete boolean not null,
  utilities_water_gas_ready boolean not null,
  network_ready boolean not null,
  blockers_open int not null default 0,
  target_install_date date,
  readiness_pct numeric(5,2),
  site_verdict text not null check (site_verdict in (
    'go_ready','minor_gaps','civil_pending','major_blocker','install_at_risk'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_install_site_readiness_r3424 enable row level security;

create index if not exists idx_eng_site_readiness_r3424_org on public.engineer_install_site_readiness_r3424(organization_id);
create index if not exists idx_eng_site_readiness_r3424_date on public.engineer_install_site_readiness_r3424(survey_date);
create index if not exists idx_eng_site_readiness_r3424_verdict on public.engineer_install_site_readiness_r3424(site_verdict);

-- =============================================================================
-- TABLE 2: engineer_install_site_readiness_capa_actions_r3424 — blocker resolution CAPA
-- =============================================================================
create table if not exists public.engineer_install_site_readiness_capa_actions_r3424 (
  id uuid primary key default gen_random_uuid(),
  survey_id uuid not null references public.engineer_install_site_readiness_r3424(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'power_supply_gap','hvac_cooling_gap','shielding_incomplete','floor_loading_gap',
    'access_route_blocked','civil_works_pending','utilities_gap','network_not_ready',
    'permits_pending','preventive_check_due'
  )),
  root_cause text not null check (root_cause in (
    'vendor_delay','civil_contractor_delay','design_change','budget_hold','permit_pending',
    'site_access_dispute','oem_lead_time','measurement_error','pending_investigation','utility_provider_delay'
  )),
  corrective_action text not null check (corrective_action in (
    'upgrade_power_supply','install_hvac_cooling','complete_shielding','reinforce_floor',
    'clear_access_route','complete_civil_works','provision_utilities','provision_network',
    'expedite_permits','reschedule_install','escalate_to_pmo','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  go_live_impact text not null check (go_live_impact in (
    'blocks_go_live','delays_go_live','none','minor_delay','contractual_penalty_risk','service_launch_delay'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_install_site_readiness_capa_actions_r3424 enable row level security;

create index if not exists idx_eng_site_readiness_capa_r3424_survey on public.engineer_install_site_readiness_capa_actions_r3424(survey_id);
create index if not exists idx_eng_site_readiness_capa_r3424_status on public.engineer_install_site_readiness_capa_actions_r3424(capa_status);

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

  -- 14 site-survey rows
  insert into public.engineer_install_site_readiness_r3424 (
    organization_id, engineer_name, hospital_name, region, survey_code, equipment_type, survey_date,
    power_supply_ready, hvac_cooling_ready, shielding_ready, floor_loading_ok, access_route_clear,
    civil_works_complete, utilities_water_gas_ready, network_ready, blockers_open, target_install_date,
    readiness_pct, site_verdict, notes
  )
  select v_org_id, q.eng, q.hosp, q.region, q.scode, q.etype, q.sdate::date,
    q.power, q.hvac, q.shield, q.floor, q.access,
    q.civil, q.util, q.network, q.blk::int, q.tid::date,
    q.rpct::numeric, q.verdict, q.nt
  from (values
    ('Ravi Kumar','Apollo Chennai','south','SRV-APL-CT-01','ct_scanner','2026-07-10',
     true,true,'ready',true,true,true,true,true,0,'2026-08-05',100,'go_ready',
     'CT scanner bay ready — power, HVAC, lead shielding and access all cleared'),
    ('Anil Sharma','Fortis Gurgaon','north','SRV-FRT-MR-02','mri','2026-07-09',
     true,true,'in_progress',true,true,true,true,false,1,'2026-08-10',88,'minor_gaps',
     'MRI RF shielding in progress and data network drop pending — otherwise ready'),
    ('Suresh Rao','Manipal Bengaluru','south','SRV-MNP-CL-03','cath_lab','2026-07-09',
     true,true,'ready',true,true,false,true,false,2,'2026-08-20',72,'civil_pending',
     'Cath lab civil works incomplete and network not ready — false floor pending'),
    ('Vikram Nair','AIIMS Delhi','north','SRV-AIM-LN-04','linac','2026-07-08',
     false,true,'gap',true,true,true,true,false,3,'2026-09-01',55,'major_blocker',
     'Linac bunker power supply undersized and radiation shielding gap — major blocker'),
    ('Deepak Menon','CMC Vellore','south','SRV-CMC-LA-05','lab_analyzer','2026-07-08',
     true,true,'not_applicable',true,true,true,true,true,0,'2026-07-30',100,'go_ready',
     'Lab analyzer site fully ready — no shielding required'),
    ('Karthik Reddy','KIMS Hyderabad','south','SRV-KIM-DF-06','dialysis_fleet','2026-07-07',
     true,true,'not_applicable',true,true,true,false,true,2,'2026-08-12',84,'minor_gaps',
     'Dialysis fleet — RO water and drainage utilities not fully provisioned'),
    ('Prakash Iyer','Yashoda Hyderabad','south','SRV-YSH-OT-07','ot_integration','2026-07-07',
     true,false,'not_applicable',false,true,false,false,false,4,'2026-09-15',48,'install_at_risk',
     'OT integration — HVAC, floor loading, civil, utilities and network all pending, at risk'),
    ('Sanjay Patil','Kokilaben Mumbai','west','SRV-KKB-MR-08','mri','2026-07-06',
     true,true,'ready',false,true,false,true,true,2,'2026-08-25',68,'civil_pending',
     'MRI floor loading reinforcement and civil works pending — magnet delivery on hold'),
    ('Amit Verma','Medanta Gurgaon','north','SRV-MDT-CT-09','ct_scanner','2026-07-06',
     true,true,'ready',true,true,true,true,true,0,'2026-08-02',98,'go_ready',
     'CT scanner site cleared — final snag list minor'),
    ('Sourav Das','Narayana Kolkata','east','SRV-NAR-CL-10','cath_lab','2026-07-05',
     true,true,'in_progress',true,true,true,true,false,1,'2026-08-08',90,'minor_gaps',
     'Cath lab ready bar structured network cabling — shielding nearly done'),
    ('Nitin Joshi','Ruby Hall Pune','west','SRV-RBY-LN-11','linac','2026-07-05',
     true,false,'gap',true,true,true,true,false,3,'2026-09-05',52,'major_blocker',
     'Linac chiller/HVAC capacity short and shielding gap — network pending'),
    ('Rahul Mishra','SGPGI Lucknow','central','SRV-SGP-LA-12','lab_analyzer','2026-07-04',
     true,true,'not_applicable',true,true,true,true,true,0,'2026-07-28',100,'go_ready',
     'Lab analyzer bench and utilities fully ready for install'),
    ('Ganesh Pillai','Tata Memorial Mumbai','west','SRV-TMH-LN-13','linac','2026-07-04',
     false,true,'gap',true,false,false,true,false,5,'2026-09-20',40,'install_at_risk',
     'Linac — power, access route, civil and shielding all open, five blockers, at risk'),
    ('Manoj Thomas','Amrita Kochi','south','SRV-AMR-DF-14','dialysis_fleet','2026-07-03',
     true,true,'not_applicable',true,true,true,false,true,1,'2026-08-14',86,'minor_gaps',
     'Dialysis fleet — water treatment plant tie-in pending, else ready')
  ) as q(eng, hosp, region, scode, etype, sdate, power, hvac, shield, floor, access,
         civil, util, network, blk, tid, rpct, verdict, nt);

  -- CAPA seed — attach to specific surveys via survey_code
  insert into public.engineer_install_site_readiness_capa_actions_r3424 (
    survey_id, finding_category, root_cause, corrective_action,
    capa_status, go_live_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.gli, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('SRV-AIM-LN-04','power_supply_gap','utility_provider_delay','upgrade_power_supply','in_progress','blocks_go_live','2026-08-15',null,850000.00,'Bunker feeder upgrade to dedicated transformer — utility provider slot awaited'),
    ('SRV-MNP-CL-03','civil_works_pending','civil_contractor_delay','complete_civil_works','open','delays_go_live','2026-08-10',null,320000.00,'False floor and cable trench civil works — contractor remobilising'),
    ('SRV-YSH-OT-07','network_not_ready','vendor_delay','provision_network','escalated','service_launch_delay','2026-09-01',null,150000.00,'OT integration LAN backbone and switches pending — escalated to PMO'),
    ('SRV-TMH-LN-13','shielding_incomplete','oem_lead_time','complete_shielding','open','contractual_penalty_risk','2026-09-10',null,1200000.00,'Linac lead/concrete shielding scope with OEM lead time — penalty clause at risk'),
    ('SRV-RBY-LN-11','hvac_cooling_gap','design_change','install_hvac_cooling','in_progress','blocks_go_live','2026-08-28',null,640000.00,'Chiller capacity redesign for linac heat load — new HVAC unit on order'),
    ('SRV-FRT-MR-02','network_not_ready','vendor_delay','provision_network','verification_pending','minor_delay','2026-08-05',null,45000.00,'Network drop installed — verify link before go-live'),
    ('SRV-KIM-DF-06','utilities_gap','civil_contractor_delay','provision_utilities','closed','none','2026-07-25','2026-07-20',90000.00,'RO water and drainage tie-in completed and commissioned')
  ) as q(scode, fc, rc, ca, cst, gli, tcd, acd, cost, nt)
  join public.engineer_install_site_readiness_r3424 e
    on e.organization_id = v_org_id and e.survey_code = q.scode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Site-verdict distribution
create or replace function public.founder_r3424_verdict_rollup()
returns table(site_verdict text, surveys bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_install_site_readiness_r3424)
  select l.site_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.engineer_install_site_readiness_r3424 l
  group by l.site_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3424_verdict_rollup() from public, anon;
grant execute on function public.founder_r3424_verdict_rollup() to authenticated;

-- 2) Region-level readiness scorecard
create or replace function public.founder_r3424_region_scorecard()
returns table(
  region text,
  total_surveys bigint,
  go_ready bigint,
  minor_gaps bigint,
  blocked bigint,
  avg_readiness_pct numeric,
  open_blockers bigint,
  go_ready_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region,
    count(*)::bigint,
    count(*) filter (where l.site_verdict = 'go_ready')::bigint,
    count(*) filter (where l.site_verdict = 'minor_gaps')::bigint,
    count(*) filter (where l.site_verdict in ('civil_pending','major_blocker','install_at_risk'))::bigint,
    round(avg(l.readiness_pct), 1),
    coalesce(sum(l.blockers_open),0)::bigint,
    round(100.0 * count(*) filter (where l.site_verdict = 'go_ready')::numeric / nullif(count(*),0), 1)
  from public.engineer_install_site_readiness_r3424 l
  group by l.region
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3424_region_scorecard() from public, anon;
grant execute on function public.founder_r3424_region_scorecard() to authenticated;

-- 3) Equipment-type × region readiness matrix
create or replace function public.founder_r3424_equipment_region_matrix()
returns table(equipment_type text, region text, surveys bigint, go_ready bigint, at_risk bigint, avg_readiness_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.region, count(*)::bigint,
    count(*) filter (where l.site_verdict = 'go_ready')::bigint,
    count(*) filter (where l.site_verdict in ('major_blocker','install_at_risk'))::bigint,
    round(avg(l.readiness_pct), 1)
  from public.engineer_install_site_readiness_r3424 l
  group by l.equipment_type, l.region
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3424_equipment_region_matrix() from public, anon;
grant execute on function public.founder_r3424_equipment_region_matrix() to authenticated;

-- 4) Survey-date readiness trend
create or replace function public.founder_r3424_survey_date_trend()
returns table(survey_date date, surveys bigint, go_ready bigint, blocked bigint, open_blockers bigint, avg_readiness_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.survey_date,
    count(*)::bigint,
    count(*) filter (where l.site_verdict = 'go_ready')::bigint,
    count(*) filter (where l.site_verdict in ('civil_pending','major_blocker','install_at_risk'))::bigint,
    coalesce(sum(l.blockers_open),0)::bigint,
    round(avg(l.readiness_pct), 1)
  from public.engineer_install_site_readiness_r3424 l
  group by l.survey_date
  order by l.survey_date desc;
end;
$$;

revoke execute on function public.founder_r3424_survey_date_trend() from public, anon;
grant execute on function public.founder_r3424_survey_date_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3424_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_flag bigint)
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
  from public.engineer_install_site_readiness_capa_actions_r3424 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3424_capa_status_board() from public, anon;
grant execute on function public.founder_r3424_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3424_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_install_site_readiness_capa_actions_r3424)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.engineer_install_site_readiness_capa_actions_r3424 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3424_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3424_root_cause_pareto() to authenticated;

-- 7) Go-live impact digest
create or replace function public.founder_r3424_go_live_impact_digest()
returns table(go_live_impact text, actions bigint, open_actions bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.go_live_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.engineer_install_site_readiness_capa_actions_r3424 c
  group by c.go_live_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3424_go_live_impact_digest() from public, anon;
grant execute on function public.founder_r3424_go_live_impact_digest() to authenticated;

-- 8) High-risk go-live-blocker queue
create or replace function public.founder_r3424_high_risk_queue()
returns table(
  hospital_name text,
  survey_code text,
  equipment_type text,
  region text,
  survey_date date,
  site_verdict text,
  shielding_ready text,
  blockers_open int,
  readiness_pct numeric,
  target_install_date date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.survey_code, l.equipment_type, l.region, l.survey_date,
    l.site_verdict, l.shielding_ready, l.blockers_open, l.readiness_pct, l.target_install_date, l.notes
  from public.engineer_install_site_readiness_r3424 l
  where l.site_verdict in ('minor_gaps','civil_pending','major_blocker','install_at_risk')
     or l.shielding_ready = 'gap'
     or l.blockers_open > 0
     or l.power_supply_ready = false
     or l.hvac_cooling_ready = false
     or l.floor_loading_ok = false
     or l.access_route_clear = false
     or l.civil_works_complete = false
     or l.utilities_water_gas_ready = false
     or l.network_ready = false
  order by l.readiness_pct asc, l.survey_date desc;
end;
$$;

revoke execute on function public.founder_r3424_high_risk_queue() from public, anon;
grant execute on function public.founder_r3424_high_risk_queue() to authenticated;
