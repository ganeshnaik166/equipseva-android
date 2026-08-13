-- Round 3747: Founder Company Canteen / Food-Service FSSAI Hygiene Board
-- Employee canteen/food-service operations — FSSAI license validity, hygiene audit
-- scores, subsidy cost per meal, and vendor compliance across in-house kitchens,
-- outsourced caterers, vending machines, tuck shops, and tea/coffee service points.
-- Distinct from any pest-control-AMC-compliance page and any vendor-invoice-processing
-- page, which are facilities/finance topics, not food-safety/hygiene.

-- =============================================================================
-- TABLE 1: canteen_fssai_r3747 — per-site/vendor canteen food-safety facts
-- =============================================================================
create table if not exists public.canteen_fssai_r3747 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  site_name text not null,
  vendor_name text not null,
  period_month date not null,
  fssai_license_number text,
  license_expiry_date date,
  hygiene_audit_score numeric,
  meals_served int,
  subsidy_cost_rupees numeric(12,2),
  cost_per_meal_rupees numeric,
  food_safety_incidents int,
  pest_control_verified boolean not null,
  service_class text not null check (service_class in (
    'in_house_kitchen','outsourced_catering','vending_machine','tuck_shop','tea_coffee_service'
  )),
  compliance_status text not null check (compliance_status in (
    'compliant','license_renewal_due','hygiene_gap','incident_reported','license_lapsed'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.canteen_fssai_r3747 enable row level security;

create index if not exists idx_canteen_fssai_r3747_org on public.canteen_fssai_r3747(organization_id);
create index if not exists idx_canteen_fssai_r3747_month on public.canteen_fssai_r3747(period_month);
create index if not exists idx_canteen_fssai_r3747_status on public.canteen_fssai_r3747(compliance_status);

-- =============================================================================
-- TABLE 2: canteen_fssai_capa_actions_r3747 — CAPA for hygiene/compliance gaps
-- =============================================================================
create table if not exists public.canteen_fssai_capa_actions_r3747 (
  id uuid primary key default gen_random_uuid(),
  canteen_id uuid references public.canteen_fssai_r3747(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.canteen_fssai_capa_actions_r3747 enable row level security;

create index if not exists idx_canteen_fssai_capa_r3747_main on public.canteen_fssai_capa_actions_r3747(canteen_id);
create index if not exists idx_canteen_fssai_capa_r3747_status on public.canteen_fssai_capa_actions_r3747(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance-status distribution
create or replace function public.founder_r3747_compliance_status_rollup()
returns table(compliance_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.canteen_fssai_r3747)
  select l.compliance_status, count(*)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.canteen_fssai_r3747 l
  group by l.compliance_status
  order by count(*) desc;
end;
$$;

-- 2) Site scorecard
create or replace function public.founder_r3747_site_scorecard()
returns table(
  site_name text,
  records bigint,
  compliant bigint,
  license_renewal_due bigint,
  hygiene_gap bigint,
  incident_reported bigint,
  license_lapsed bigint,
  meals_served_total bigint,
  subsidy_cost_total numeric,
  avg_hygiene_audit_score numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'compliant')::bigint,
    count(*) filter (where l.compliance_status = 'license_renewal_due')::bigint,
    count(*) filter (where l.compliance_status = 'hygiene_gap')::bigint,
    count(*) filter (where l.compliance_status = 'incident_reported')::bigint,
    count(*) filter (where l.compliance_status = 'license_lapsed')::bigint,
    coalesce(sum(l.meals_served), 0)::bigint,
    coalesce(sum(l.subsidy_cost_rupees), 0)::numeric,
    round(avg(l.hygiene_audit_score), 1)
  from public.canteen_fssai_r3747 l
  group by l.site_name
  order by count(*) desc;
end;
$$;

-- 3) Service-class x compliance-status matrix
create or replace function public.founder_r3747_service_class_status_matrix()
returns table(service_class text, compliance_status text, records bigint, avg_cost_per_meal_rupees numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.service_class, l.compliance_status, count(*)::bigint,
    round(avg(l.cost_per_meal_rupees), 2)
  from public.canteen_fssai_r3747 l
  group by l.service_class, l.compliance_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly hygiene-score trend
create or replace function public.founder_r3747_monthly_hygiene_score_trend()
returns table(
  period_month date,
  records bigint,
  avg_hygiene_audit_score numeric,
  meals_served_total bigint,
  subsidy_cost_total numeric,
  food_safety_incidents_total bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.hygiene_audit_score), 1),
    coalesce(sum(l.meals_served), 0)::bigint,
    coalesce(sum(l.subsidy_cost_rupees), 0)::numeric,
    coalesce(sum(l.food_safety_incidents), 0)::bigint
  from public.canteen_fssai_r3747 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3747_capa_status_board()
returns table(capa_status text, findings bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.canteen_fssai_capa_actions_r3747 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root-cause pareto
create or replace function public.founder_r3747_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.canteen_fssai_capa_actions_r3747)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot), 0) * 100.0, 1)
  from public.canteen_fssai_capa_actions_r3747 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Food-safety incident digest
create or replace function public.founder_r3747_incident_digest()
returns table(
  site_name text,
  records bigint,
  incident_records bigint,
  food_safety_incidents_total bigint,
  avg_hygiene_audit_score numeric,
  pest_control_gaps bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name,
    count(*)::bigint,
    count(*) filter (where l.food_safety_incidents > 0)::bigint,
    coalesce(sum(l.food_safety_incidents), 0)::bigint,
    round(avg(l.hygiene_audit_score), 1),
    count(*) filter (where l.pest_control_verified = false)::bigint
  from public.canteen_fssai_r3747 l
  where l.food_safety_incidents > 0 or l.pest_control_verified = false
  group by l.site_name
  order by food_safety_incidents_total desc;
end;
$$;

-- 8) High-risk queue (hygiene-gap / incident-reported / license-lapsed, worst first)
create or replace function public.founder_r3747_high_risk_queue()
returns table(
  site_name text,
  vendor_name text,
  period_month date,
  service_class text,
  compliance_status text,
  license_expiry_date date,
  hygiene_audit_score numeric,
  food_safety_incidents int,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name, l.vendor_name, l.period_month, l.service_class,
    l.compliance_status, l.license_expiry_date, l.hygiene_audit_score,
    l.food_safety_incidents, l.notes
  from public.canteen_fssai_r3747 l
  where l.compliance_status in ('license_lapsed','incident_reported','hygiene_gap')
  order by l.hygiene_audit_score asc nulls last, l.period_month desc
  limit 20;
end;
$$;

-- =============================================================================
-- Grants — founder-gated, authenticated-only surface
-- =============================================================================
revoke all on function public.founder_r3747_compliance_status_rollup() from public, anon;
revoke all on function public.founder_r3747_site_scorecard() from public, anon;
revoke all on function public.founder_r3747_service_class_status_matrix() from public, anon;
revoke all on function public.founder_r3747_monthly_hygiene_score_trend() from public, anon;
revoke all on function public.founder_r3747_capa_status_board() from public, anon;
revoke all on function public.founder_r3747_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3747_incident_digest() from public, anon;
revoke all on function public.founder_r3747_high_risk_queue() from public, anon;

grant execute on function public.founder_r3747_compliance_status_rollup() to authenticated;
grant execute on function public.founder_r3747_site_scorecard() to authenticated;
grant execute on function public.founder_r3747_service_class_status_matrix() to authenticated;
grant execute on function public.founder_r3747_monthly_hygiene_score_trend() to authenticated;
grant execute on function public.founder_r3747_capa_status_board() to authenticated;
grant execute on function public.founder_r3747_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3747_incident_digest() to authenticated;
grant execute on function public.founder_r3747_high_risk_queue() to authenticated;

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

  -- 16 canteen/food-service rows across sites, vendors, service classes & months
  insert into public.canteen_fssai_r3747 (
    organization_id, site_name, vendor_name, period_month, fssai_license_number,
    license_expiry_date, hygiene_audit_score, meals_served, subsidy_cost_rupees,
    cost_per_meal_rupees, food_safety_incidents, pest_control_verified, service_class,
    compliance_status, trend_dir, notes
  )
  select v_org_id, q.sn, q.vn, q.pm::date, q.fln,
    q.led::date, q.has::numeric, q.ms::int, q.scr::numeric,
    q.cpm::numeric, q.fsi::int, q.pcv, q.sc, q.cst, q.td, q.nt
  from (values
    ('Bengaluru HQ','Sodexo Facilities India','2026-07-01','21422001000123','2027-03-15',92.5,8400,420000.00,50.00,0,true,'in_house_kitchen','compliant','stable','Monthly FSSAI-mandated audit passed with high score; canteen running smoothly'),
    ('Bengaluru HQ','Sodexo Facilities India','2026-06-01','21422001000123','2027-03-15',91.0,8100,405000.00,50.00,0,true,'in_house_kitchen','compliant','improving','Kitchen hygiene checklist compliance improved after staff retraining'),
    ('Pune Tech Park','Compass Group India','2026-07-01','21422002000456','2026-09-30',78.0,5200,260000.00,50.00,1,true,'outsourced_catering','hygiene_gap','worsening','Storage temperature log gaps flagged during surprise audit; minor food-handling lapse noted'),
    ('Chennai Campus','CSS Corp Catering Services','2026-07-01','21422003000789','2026-08-10',85.5,6300,315000.00,50.00,0,true,'outsourced_catering','license_renewal_due','stable','FSSAI license renewal application submitted, awaiting approval before expiry'),
    ('Hyderabad Center','Urban Platter Vending','2026-07-01','21422004000012','2026-12-20',88.0,1200,0.00,25.00,0,true,'vending_machine','compliant','stable','Vending machines restocked weekly; hygiene score consistently above threshold'),
    ('Mumbai Annex','Local Tiffin Vendor Co-op','2026-06-01',null,null,62.0,900,45000.00,50.00,2,false,'tuck_shop','incident_reported','worsening','Two employees reported mild food poisoning symptoms after lunch; investigation ongoing'),
    ('Gurugram Office','Chaipoint Beverage Services','2026-07-01','21422005000345','2027-01-05',95.0,3100,0.00,0.00,0,true,'tea_coffee_service','compliant','improving','Tea/coffee service point consistently rated highest in employee satisfaction survey'),
    ('Bengaluru Annex-2','Sodexo Facilities India','2026-07-01','21422006000678','2026-07-05',55.0,4800,240000.00,50.00,1,false,'in_house_kitchen','license_lapsed','worsening','FSSAI license lapsed after renewal delay; kitchen operating under provisional clearance'),
    ('Pune Tech Park','Compass Group India','2026-06-01','21422002000456','2026-09-30',80.0,5000,250000.00,50.00,0,true,'outsourced_catering','compliant','improving','Corrective actions from prior audit implemented; score improved this cycle'),
    ('Chennai Campus','CSS Corp Catering Services','2026-06-01','21422003000789','2026-08-10',83.0,6100,305000.00,50.00,0,true,'outsourced_catering','compliant','stable','Routine audit passed with minor observations, no repeat findings'),
    ('Hyderabad Center','Urban Platter Vending','2026-06-01','21422004000012','2026-12-20',87.5,1150,0.00,25.00,0,true,'vending_machine','compliant','stable','No complaints logged this cycle'),
    ('Mumbai Annex','Local Tiffin Vendor Co-op','2026-07-01',null,null,58.0,850,42500.00,50.00,1,false,'tuck_shop','incident_reported','worsening','Follow-up inspection still finds pest activity near storage area; vendor contract under review'),
    ('Gurugram Office','Chaipoint Beverage Services','2026-06-01','21422005000345','2027-01-05',94.0,2950,0.00,0.00,0,true,'tea_coffee_service','compliant','stable','Consistent hygiene standards maintained across all dispensing units'),
    ('Noida Delivery Hub','Fresh Bites Catering','2026-07-01','21422007000901','2026-08-25',72.0,3400,170000.00,50.00,1,true,'outsourced_catering','hygiene_gap','worsening','Cross-contamination risk noted in food prep area; corrective training scheduled'),
    ('Kolkata Site','Bengal Fresh Foods','2026-07-01','21422008000234','2026-11-12',90.0,2700,135000.00,50.00,0,true,'in_house_kitchen','compliant','improving','New chef-in-charge has driven visible improvement in kitchen hygiene practices'),
    ('Ahmedabad Office','Gujarat Snacks Tuck Shop','2026-07-01','21422009000567','2026-09-18',68.0,1400,70000.00,50.00,0,false,'tuck_shop','hygiene_gap','worsening','Pest control certificate expired and not yet renewed; storage shelving needs cleanup')
  ) as q(sn, vn, pm, fln, led, has, ms, scr, cpm, fsi, pcv, sc, cst, td, nt);

  -- 8 CAPA rows — attach to canteen rows via site_name + period_month
  insert into public.canteen_fssai_capa_actions_r3747 (
    canteen_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('Pune Tech Park','2026-07-01','Storage temperature log gaps found during surprise audit indicate inconsistent monitoring','Install automated temperature logging sensors in cold storage and retrain kitchen staff on manual log backup','in_progress','Facilities Manager','2026-08-20',null,'Sensors procured; staff retraining session scheduled for next week'),
    ('Chennai Campus','2026-07-01','FSSAI license nearing expiry with renewal still under processing by authority','Follow up with FSSAI regional office and prepare interim compliance declaration for site display','open','Compliance Officer','2026-08-08',null,'Renewal fee paid; awaiting inspection slot confirmation from FSSAI office'),
    ('Mumbai Annex','2026-06-01','Food-handling lapse led to two employees reporting mild food poisoning symptoms','Suspend vendor operations pending root-cause investigation and mandate full kitchen deep-clean before reopening','overdue','Site HR Head','2026-07-15',null,'Investigation report delayed by two weeks; vendor still suspended pending findings'),
    ('Bengaluru Annex-2','2026-07-01','FSSAI license lapsed due to delayed renewal submission by facilities team','Expedite renewal filing with FSSAI and engage temporary provisional-license consultant','in_progress','Facilities Manager','2026-08-01',null,'Provisional clearance obtained; permanent renewal filing in final review'),
    ('Mumbai Annex','2026-07-01','Recurring pest activity near food storage area despite prior pest-control visit','Terminate current pest-control vendor contract and onboard certified replacement with monthly audits','open','Facilities Manager','2026-08-25',null,'Two replacement vendors shortlisted; contract finalization in progress'),
    ('Noida Delivery Hub','2026-07-01','Cross-contamination risk identified in shared food-prep area between veg and non-veg lines','Install physical separation and color-coded utensils for veg and non-veg prep stations','closed','Regional Facilities Head','2026-08-05','2026-07-30','Separation barriers installed and staff trained; follow-up audit confirmed compliance'),
    ('Ahmedabad Office','2026-07-01','Pest control certificate expired and storage shelving not maintained per hygiene checklist','Renew pest control contract immediately and schedule deep-clean of tuck shop storage shelving','in_progress','Facilities Manager','2026-08-10',null,'Pest control renewal quote received; deep-clean scheduled for this weekend'),
    ('Bengaluru Annex-2','2026-07-01','Kitchen operating under provisional clearance poses ongoing regulatory risk until full license restored','Assign dedicated compliance liaison to track FSSAI application status weekly until closure','in_progress','Compliance Officer','2026-08-15',null,'Weekly status calls with FSSAI office established; expect resolution within three weeks')
  ) as q(sn, pm, rc, ca, cst, ownr, tcd, acd, nt)
  join public.canteen_fssai_r3747 e
    on e.organization_id = v_org_id and e.site_name = q.sn and e.period_month = q.pm::date;
end;
$seed$;
