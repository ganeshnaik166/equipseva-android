-- Round 3681: Founder Shops & Establishment / Professional-Tax Registration Board
-- Statutory premises compliance — shops & establishment registration × professional tax × labour welfare fund × trade/signage licences per office × remittance discipline × display obligations × notices × CAPA

-- =============================================================================
-- TABLE 1: shops_estab_r3681 — per-office statutory registration compliance rows
-- =============================================================================
create table if not exists public.shops_estab_r3681 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_location text not null,
  state_region text not null,
  period_month date not null,
  se_registration_no text not null,
  se_valid_till date,
  days_to_expiry int,
  employees_covered int,
  pt_registered boolean not null,
  pt_remitted_on_time_pct numeric(5,2),
  lwf_remitted boolean not null,
  holiday_list_displayed boolean not null,
  notices_open int not null default 0,
  registration_type text not null check (registration_type in (
    'shops_establishment','professional_tax','labour_welfare_fund','trade_licence','signage_licence'
  )),
  compliance_status text not null check (compliance_status in (
    'compliant','renewal_due','remittance_gap','display_gap','notice_received'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.shops_estab_r3681 enable row level security;

create index if not exists idx_shops_estab_r3681_org on public.shops_estab_r3681(organization_id);
create index if not exists idx_shops_estab_r3681_month on public.shops_estab_r3681(period_month);
create index if not exists idx_shops_estab_r3681_status on public.shops_estab_r3681(compliance_status);

-- =============================================================================
-- TABLE 2: shops_estab_capa_actions_r3681 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.shops_estab_capa_actions_r3681 (
  id uuid primary key default gen_random_uuid(),
  registration_id uuid not null references public.shops_estab_r3681(id) on delete cascade,
  root_cause text not null check (root_cause in (
    'renewal_missed_diary','headcount_slab_change','challan_payment_delay','portal_credential_lapse',
    'branch_manager_turnover','consultant_dependency','notice_response_delay','display_board_not_updated',
    'pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'file_renewal_application','remit_arrears_with_interest','update_display_boards','appoint_compliance_owner',
    'automate_renewal_calendar','respond_to_notice','update_employee_slab_mapping','engage_labour_consultant',
    'none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  penalty_exposure_rupees numeric(12,2),
  owner_name text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.shops_estab_capa_actions_r3681 enable row level security;

create index if not exists idx_shops_estab_capa_r3681_reg on public.shops_estab_capa_actions_r3681(registration_id);
create index if not exists idx_shops_estab_capa_r3681_status on public.shops_estab_capa_actions_r3681(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance status distribution
create or replace function public.founder_r3681_compliance_status_rollup()
returns table(compliance_status text, registrations bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.shops_estab_r3681)
  select l.compliance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.shops_estab_r3681 l
  group by l.compliance_status
  order by count(*) desc;
end;
$$;

-- 2) State-wise compliance scorecard
create or replace function public.founder_r3681_state_scorecard()
returns table(
  state_region text,
  registrations bigint,
  compliant bigint,
  renewal_due bigint,
  remittance_gap bigint,
  notices_open_total bigint,
  employees_covered_total bigint,
  avg_pt_on_time_pct numeric,
  compliant_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.state_region,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'compliant')::bigint,
    count(*) filter (where l.compliance_status = 'renewal_due')::bigint,
    count(*) filter (where l.compliance_status = 'remittance_gap')::bigint,
    coalesce(sum(l.notices_open),0)::bigint,
    coalesce(sum(l.employees_covered),0)::bigint,
    round(avg(l.pt_remitted_on_time_pct), 1),
    round(100.0 * count(*) filter (where l.compliance_status = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.shops_estab_r3681 l
  group by l.state_region
  order by count(*) desc;
end;
$$;

-- 3) Registration type × compliance status matrix
create or replace function public.founder_r3681_regtype_status_matrix()
returns table(registration_type text, compliance_status text, registrations bigint, notices_open_total bigint, avg_days_to_expiry numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.registration_type, l.compliance_status, count(*)::bigint,
    coalesce(sum(l.notices_open),0)::bigint,
    round(avg(l.days_to_expiry), 0)
  from public.shops_estab_r3681 l
  group by l.registration_type, l.compliance_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly compliance trend
create or replace function public.founder_r3681_monthly_compliance_trend()
returns table(period_month date, registrations bigint, compliant bigint, gaps bigint, notices bigint, avg_pt_on_time_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'compliant')::bigint,
    count(*) filter (where l.compliance_status in ('remittance_gap','display_gap'))::bigint,
    count(*) filter (where l.compliance_status = 'notice_received')::bigint,
    round(avg(l.pt_remitted_on_time_pct), 1)
  from public.shops_estab_r3681 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3681_capa_status_board()
returns table(capa_status text, actions bigint, avg_penalty_exposure_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.penalty_exposure_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.shops_estab_capa_actions_r3681 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3681_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_penalty_exposure_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.shops_estab_capa_actions_r3681)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.penalty_exposure_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.shops_estab_capa_actions_r3681 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Remittance-gap digest by office
create or replace function public.founder_r3681_remittance_gap_digest()
returns table(
  office_location text,
  state_region text,
  registrations bigint,
  remittance_gap_regs bigint,
  lwf_missed bigint,
  avg_pt_on_time_pct numeric,
  employees_at_risk bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.office_location, l.state_region,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'remittance_gap')::bigint,
    count(*) filter (where l.lwf_remitted = false)::bigint,
    round(avg(l.pt_remitted_on_time_pct), 1),
    coalesce(sum(l.employees_covered) filter (where l.compliance_status = 'remittance_gap'),0)::bigint
  from public.shops_estab_r3681 l
  where l.compliance_status = 'remittance_gap'
     or l.lwf_remitted = false
     or l.pt_remitted_on_time_pct < 95
  group by l.office_location, l.state_region
  order by count(*) filter (where l.compliance_status = 'remittance_gap') desc, l.office_location;
end;
$$;

-- 8) High-risk registration queue
create or replace function public.founder_r3681_high_risk_queue()
returns table(
  office_location text,
  state_region text,
  se_registration_no text,
  registration_type text,
  period_month date,
  compliance_status text,
  days_to_expiry int,
  notices_open int,
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
  select l.office_location, l.state_region, l.se_registration_no, l.registration_type,
    l.period_month, l.compliance_status, l.days_to_expiry, l.notices_open, l.trend_dir, l.notes
  from public.shops_estab_r3681 l
  where l.compliance_status in ('notice_received','remittance_gap')
     or l.notices_open > 0
     or l.days_to_expiry <= 45
  order by l.period_month desc, l.office_location;
end;
$$;

-- =============================================================================
-- GRANTS
-- =============================================================================
revoke all on function public.founder_r3681_compliance_status_rollup() from public, anon;
revoke all on function public.founder_r3681_state_scorecard() from public, anon;
revoke all on function public.founder_r3681_regtype_status_matrix() from public, anon;
revoke all on function public.founder_r3681_monthly_compliance_trend() from public, anon;
revoke all on function public.founder_r3681_capa_status_board() from public, anon;
revoke all on function public.founder_r3681_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3681_remittance_gap_digest() from public, anon;
revoke all on function public.founder_r3681_high_risk_queue() from public, anon;

grant execute on function public.founder_r3681_compliance_status_rollup() to authenticated;
grant execute on function public.founder_r3681_state_scorecard() to authenticated;
grant execute on function public.founder_r3681_regtype_status_matrix() to authenticated;
grant execute on function public.founder_r3681_monthly_compliance_trend() to authenticated;
grant execute on function public.founder_r3681_capa_status_board() to authenticated;
grant execute on function public.founder_r3681_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3681_remittance_gap_digest() to authenticated;
grant execute on function public.founder_r3681_high_risk_queue() to authenticated;

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

  -- 16 registration compliance rows
  insert into public.shops_estab_r3681 (
    organization_id, office_location, state_region, period_month, se_registration_no,
    se_valid_till, days_to_expiry, employees_covered, pt_registered, pt_remitted_on_time_pct,
    lwf_remitted, holiday_list_displayed, notices_open, registration_type, compliance_status,
    trend_dir, notes
  )
  select v_org_id, q.office, q.streg, q.pm::date, q.regno,
    q.validtill::date, q.dexp, q.emp, q.ptreg, q.ptpct,
    q.lwf, q.hol, q.ntc, q.rtype, q.cstat,
    q.tdir, q.nt
  from (values
    ('Mumbai HQ','MH','2026-07-01','MUM-SE-118765','2026-12-31',175,182,true,null,
     true,true,0,'shops_establishment','compliant','stable','BMC Shops & Establishment certificate current; abstract and holiday list displayed at reception'),
    ('Mumbai HQ','MH','2026-07-01','MUM-PTRC-27331942','2027-03-31',265,182,true,96.5,
     true,true,0,'professional_tax','compliant','improving','PTRC monthly returns filed; June challan remitted on time via Mahakosh'),
    ('Mumbai HQ','MH','2026-07-01','MUM-LWF-88412','2026-12-31',175,182,true,null,
     false,true,0,'labour_welfare_fund','remittance_gap','worsening','MLWF June-cycle contribution missed — arrears with interest computed'),
    ('Mumbai HQ','MH','2026-06-01','MUM-SIGN-55901','2026-08-15',75,182,true,null,
     true,true,0,'signage_licence','renewal_due','stable','BMC glow-sign licence renewal window opens July — application drafted'),
    ('Chennai Service Hub','TN','2026-07-01','CHN-SE-334455','2027-06-30',355,64,true,null,
     true,true,0,'shops_establishment','compliant','stable','TN Shops & Establishments registration renewed; Form R registers maintained'),
    ('Chennai Service Hub','TN','2026-07-01','CHN-PT-771260','2026-09-30',85,64,true,88.0,
     true,true,0,'professional_tax','remittance_gap','worsening','Chennai Corporation half-yearly PT missed slab revision for two engineers'),
    ('Chennai Service Hub','TN','2026-06-01','CHN-LWF-40233','2026-12-31',200,64,true,null,
     true,false,0,'labour_welfare_fund','display_gap','improving','TN LWF remitted; holiday list and wage abstract missing at service bay'),
    ('Chennai Service Hub','TN','2026-05-01','CHN-TL-909812','2027-03-31',290,64,true,null,
     true,true,0,'trade_licence','compliant','stable','GCC trade licence current for calibration workshop'),
    ('Delhi Warehouse','DL','2026-07-01','DEL-SE-667001','2026-07-31',22,38,false,null,
     true,true,1,'shops_establishment','renewal_due','worsening','Delhi S&E registration expiring this month — renewal filed, fee challan pending'),
    ('Delhi Warehouse','DL','2026-07-01','DEL-LWF-51877','2026-12-31',180,38,false,null,
     true,true,0,'labour_welfare_fund','compliant','stable','Delhi Labour Welfare Board contribution remitted for June cycle'),
    ('Delhi Warehouse','DL','2026-06-01','DEL-TL-228190','2027-03-31',300,38,false,null,
     true,true,2,'trade_licence','notice_received','worsening','MCD notice on godown storage-licence classification — reply due 15 Jul'),
    ('Delhi Warehouse','DL','2026-05-01','DEL-SIGN-77321','2026-10-31',150,38,false,null,
     true,true,0,'signage_licence','compliant','stable','MCD signage licence for warehouse gantry board current'),
    ('Bengaluru Refurb Center','KA','2026-07-01','BLR-SE-445210','2027-01-31',210,96,true,null,
     true,true,0,'shops_establishment','compliant','improving','Karnataka S&CE registration current; e-Karmika record updated'),
    ('Bengaluru Refurb Center','KA','2026-07-01','BLR-PT-660034','2026-08-31',55,96,true,74.0,
     true,true,1,'professional_tax','notice_received','worsening','KA PT officer notice — enrolment slab mismatch for 12 refurb technicians'),
    ('Bengaluru Refurb Center','KA','2026-06-01','BLR-LWF-30112','2026-12-31',195,96,true,null,
     false,true,0,'labour_welfare_fund','remittance_gap','stable','KLWF January-cycle arrears traced during internal audit — payment queued'),
    ('Bengaluru Refurb Center','KA','2026-05-01','BLR-TL-812245','2027-06-30',380,96,true,null,
     true,false,0,'trade_licence','display_gap','improving','BBMP trade licence current; licence copy not displayed at refurb bay')
  ) as q(office, streg, pm, regno, validtill, dexp, emp, ptreg, ptpct, lwf, hol, ntc, rtype, cstat, tdir, nt);

  -- 8 CAPA rows — attach to registrations via se_registration_no
  insert into public.shops_estab_capa_actions_r3681 (
    registration_id, root_cause, corrective_action, capa_status,
    penalty_exposure_rupees, owner_name, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.pen, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('MUM-LWF-88412','challan_payment_delay','remit_arrears_with_interest','in_progress',18500.00,'Priya Nair — Mumbai HR Ops','2026-07-20',null,'MLWF arrears plus 12% interest computed; challan queued on Mahakosh portal'),
    ('CHN-PT-771260','headcount_slab_change','update_employee_slab_mapping','open',9600.00,'S. Raghavan — Chennai Admin','2026-07-25',null,'Two engineers crossed half-yearly slab after June increment — differential PT due'),
    ('DEL-SE-667001','renewal_missed_diary','file_renewal_application','verification_pending',5000.00,'Amit Chauhan — Delhi Facility','2026-07-15',null,'Renewal filed on Delhi labour portal; awaiting digitally-signed certificate'),
    ('DEL-TL-228190','notice_response_delay','respond_to_notice','escalated',60000.00,'Amit Chauhan — Delhi Facility','2026-07-12',null,'MCD storage-classification notice escalated to legal counsel; hearing date sought'),
    ('BLR-PT-660034','headcount_slab_change','remit_arrears_with_interest','in_progress',41000.00,'Kavya Hegde — Bengaluru Admin','2026-07-18',null,'KA PT differential for 12 technicians with interest — part payment made'),
    ('BLR-LWF-30112','consultant_dependency','automate_renewal_calendar','overdue',7200.00,'Kavya Hegde — Bengaluru Admin','2026-06-30',null,'KLWF cycle missed after consultant exit — moving all offices to renewal calendar'),
    ('CHN-LWF-40233','display_board_not_updated','update_display_boards','closed',0.00,'S. Raghavan — Chennai Admin','2026-07-05','2026-06-28','Holiday list and wage abstract laminated and mounted at service bay'),
    ('MUM-SIGN-55901','renewal_missed_diary','file_renewal_application','closed',2500.00,'Priya Nair — Mumbai HR Ops','2026-07-31','2026-07-08','Glow-sign renewal filed with BMC licence department; receipt archived')
  ) as q(regno, rc, ca, cst, pen, own, tcd, acd, nt)
  join public.shops_estab_r3681 e
    on e.organization_id = v_org_id and e.se_registration_no = q.regno;
end;
$seed$;
