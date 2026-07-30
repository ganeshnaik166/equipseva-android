-- Round 3626: Founder CSR Spend / 2% Mandate Compliance Board
-- Companies Act sec-135 2% CSR mandate — per project: obligation vs spent vs committed vs unspent,
-- spend ratio, beneficiaries, admin overhead, ongoing flag, compliance status, trend & CAPA closure.

-- =============================================================================
-- TABLE 1: csr_spend_r3626 — per-project CSR spend & mandate compliance
-- =============================================================================
create table if not exists public.csr_spend_r3626 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  project_code text not null,
  project_name text not null,
  csr_theme text not null check (csr_theme in (
    'education','healthcare','environmental_sustainability','rural_development',
    'women_empowerment','skill_development','sanitation_water','disaster_relief'
  )),
  period_month date not null,
  csr_obligation_rupees numeric(14,2) not null,
  amount_spent_rupees numeric(14,2) not null,
  amount_committed_rupees numeric(14,2) not null,
  unspent_rupees numeric(14,2) not null,
  spend_ratio_pct numeric(6,2) not null,
  beneficiaries_count int not null,
  admin_overhead_pct numeric(5,2) not null,
  ongoing_project boolean not null,
  compliance_status text not null check (compliance_status in (
    'compliant','on_track','shortfall','unspent_transfer_due','non_compliant'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.csr_spend_r3626 enable row level security;

create index if not exists idx_csr_spend_r3626_org on public.csr_spend_r3626(organization_id);
create index if not exists idx_csr_spend_r3626_month on public.csr_spend_r3626(period_month);
create index if not exists idx_csr_spend_r3626_status on public.csr_spend_r3626(compliance_status);

-- =============================================================================
-- TABLE 2: csr_spend_capa_actions_r3626 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.csr_spend_capa_actions_r3626 (
  id uuid primary key default gen_random_uuid(),
  csr_id uuid not null references public.csr_spend_r3626(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'spend_below_2pct_threshold','unspent_not_transferred','ongoing_project_underfunded',
    'admin_overhead_exceeded','committed_not_disbursed','impact_documentation_gap',
    'csr_committee_approval_pending','implementation_partner_delay'
  )),
  root_cause text not null check (root_cause in (
    'project_pipeline_delay','fund_disbursement_delay','vendor_ngo_capacity_gap',
    'budget_reforecast','board_approval_delay','beneficiary_identification_delay',
    'regulatory_change','documentation_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'accelerate_disbursement','transfer_to_unspent_account','onboard_new_implementation_partner',
    'reallocate_to_ongoing_project','reduce_admin_overhead','expedite_board_approval',
    'strengthen_impact_reporting','no_action_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  shortfall_amount_rupees numeric(14,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.csr_spend_capa_actions_r3626 enable row level security;

create index if not exists idx_csr_spend_capa_r3626_csr on public.csr_spend_capa_actions_r3626(csr_id);
create index if not exists idx_csr_spend_capa_r3626_status on public.csr_spend_capa_actions_r3626(capa_status);

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

  -- 16 CSR project rows
  insert into public.csr_spend_r3626 (
    organization_id, project_code, project_name, csr_theme, period_month,
    csr_obligation_rupees, amount_spent_rupees, amount_committed_rupees, unspent_rupees,
    spend_ratio_pct, beneficiaries_count, admin_overhead_pct, ongoing_project,
    compliance_status, trend_dir, notes
  )
  select v_org_id, q.pcode, q.pname, q.theme, q.pmonth::date,
    q.oblig, q.spent, q.committed, q.unspent,
    q.ratio, q.bene, q.admin, q.ongoing,
    q.cstat, q.tdir, q.nt
  from (values
    ('PROJ-EDU-01','Rural School Diagnostics Lab','education','2026-06-01',
     1200000.00,1180000.00,20000.00,0.00,98.33,4200,3.5,false,'compliant','improving','Education CSR fully disbursed for the quarter'),
    ('PROJ-HLT-02','Mobile Health Camp Program','healthcare','2026-06-01',
     1800000.00,900000.00,600000.00,300000.00,50.00,8600,4.2,true,'on_track','stable','Camps rolling out district-wise on schedule'),
    ('PROJ-ENV-03','Biomedical Waste Recycling Unit','environmental_sustainability','2026-06-01',
     900000.00,250000.00,100000.00,550000.00,27.78,1500,5.1,true,'shortfall','worsening','Vendor onboarding delay stalled disbursement'),
    ('PROJ-RUR-04','Rural PHC Equipment Grant','rural_development','2026-06-01',
     1500000.00,1500000.00,0.00,0.00,100.00,6200,2.8,false,'compliant','improving','PHC equipment handed over and commissioned'),
    ('PROJ-WMN-05','Women Technicians Skilling Cohort','women_empowerment','2026-06-01',
     700000.00,180000.00,50000.00,470000.00,25.71,320,6.5,false,'non_compliant','worsening','Cohort under-enrolled; spend well below plan'),
    ('PROJ-SKL-06','Biomedical Engineer Apprenticeship','skill_development','2026-06-01',
     1100000.00,640000.00,300000.00,160000.00,58.18,540,4.0,true,'on_track','improving','Apprentice batch 2 tranche released'),
    ('PROJ-SAN-07','Hospital Sanitation and Water','sanitation_water','2026-06-01',
     800000.00,120000.00,80000.00,600000.00,15.00,3100,5.8,false,'unspent_transfer_due','worsening','Completed project; unspent must move to sec-135 account'),
    ('PROJ-DIS-08','Disaster Medical Response Kits','disaster_relief','2026-06-01',
     600000.00,590000.00,0.00,10000.00,98.33,2400,3.2,false,'compliant','stable','Kits pre-positioned across three districts'),
    ('PROJ-EDU-09','Nursing College Scholarships','education','2026-07-01',
     1000000.00,720000.00,200000.00,80000.00,72.00,260,3.0,true,'on_track','improving','Scholarship tranche 2 disbursed to college'),
    ('PROJ-HLT-10','Cancer Screening Drive','healthcare','2026-07-01',
     2000000.00,400000.00,300000.00,1300000.00,20.00,5400,4.9,false,'non_compliant','worsening','Screening camps far behind plan; large unspent'),
    ('PROJ-ENV-11','Solar for Rural Clinics','environmental_sustainability','2026-07-01',
     1300000.00,1280000.00,20000.00,0.00,98.46,1900,2.5,false,'compliant','improving','Solar installs completed at rural clinics'),
    ('PROJ-RUR-12','Tribal Area Ambulance Fit-out','rural_development','2026-07-01',
     1600000.00,800000.00,500000.00,300000.00,50.00,7200,3.7,true,'on_track','stable','Ambulances fitted in phases; on schedule'),
    ('PROJ-WMN-13','SHG Medical Device Assembly','women_empowerment','2026-07-01',
     750000.00,700000.00,30000.00,20000.00,93.33,410,4.4,false,'compliant','improving','Self-help-group assembly unit fully funded'),
    ('PROJ-SKL-14','Rural Diagnostics Skilling','skill_development','2026-07-01',
     950000.00,300000.00,150000.00,500000.00,31.58,480,5.5,true,'shortfall','worsening','Trainer shortage stalled spend against plan'),
    ('PROJ-SAN-15','Clean Water for District Hospital','sanitation_water','2026-07-01',
     1050000.00,1050000.00,0.00,0.00,100.00,4800,2.9,false,'compliant','stable','RO and storage plant commissioned in full'),
    ('PROJ-DIS-16','Flood Relief Medical Supplies','disaster_relief','2026-07-01',
     550000.00,90000.00,60000.00,400000.00,16.36,2100,6.0,false,'unspent_transfer_due','worsening','Relief window closed; unspent transfer due')
  ) as q(pcode, pname, theme, pmonth, oblig, spent, committed, unspent, ratio, bene, admin, ongoing, cstat, tdir, nt);

  -- CAPA seed — attach to specific projects via project_code
  insert into public.csr_spend_capa_actions_r3626 (
    csr_id, finding_category, root_cause, corrective_action,
    capa_status, shortfall_amount_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.shortfall, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('PROJ-ENV-03','ongoing_project_underfunded','project_pipeline_delay','accelerate_disbursement',
     'in_progress',550000.00,'CSR Lead - Priya Menon','2026-08-15',null,'Fast-track vendor PO to unblock recycling unit spend'),
    ('PROJ-WMN-05','spend_below_2pct_threshold','vendor_ngo_capacity_gap','onboard_new_implementation_partner',
     'open',470000.00,'CSR Head - Rajesh Kumar','2026-08-30',null,'Replace low-capacity NGO to lift enrolment and spend'),
    ('PROJ-SAN-07','unspent_not_transferred','fund_disbursement_delay','transfer_to_unspent_account',
     'escalated',600000.00,'Finance Controller - Anil Shah','2026-08-10',null,'Move unspent to sec-135 Unspent CSR Account before deadline'),
    ('PROJ-HLT-10','ongoing_project_underfunded','beneficiary_identification_delay','reallocate_to_ongoing_project',
     'in_progress',1300000.00,'CSR Lead - Priya Menon','2026-09-05',null,'Reallocate to faster-moving screening geographies'),
    ('PROJ-SKL-14','implementation_partner_delay','vendor_ngo_capacity_gap','onboard_new_implementation_partner',
     'open',500000.00,'CSR Coordinator - Meena Iyer','2026-08-25',null,'Trainer shortage; source alternate skilling partner'),
    ('PROJ-DIS-16','unspent_not_transferred','board_approval_delay','expedite_board_approval',
     'verification_pending',400000.00,'Company Secretary - Suresh Rao','2026-08-05',null,'Board note drafted for unspent transfer ratification'),
    ('PROJ-EDU-09','impact_documentation_gap','documentation_backlog','strengthen_impact_reporting',
     'closed',80000.00,'CSR Coordinator - Meena Iyer','2026-07-20','2026-07-18','Impact assessment report filed; utilisation certified'),
    ('PROJ-HLT-02','committed_not_disbursed','fund_disbursement_delay','accelerate_disbursement',
     'overdue',300000.00,'Finance Controller - Anil Shah','2026-07-10',null,'Committed camp funds not yet disbursed past target date')
  ) as q(pcode, fc, rc, ca, cst, shortfall, ownr, tcd, acd, nt)
  join public.csr_spend_r3626 e
    on e.organization_id = v_org_id and e.project_code = q.pcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance-status distribution
create or replace function public.founder_r3626_compliance_status_rollup()
returns table(compliance_status text, projects bigint, total_obligation_rupees numeric, total_spent_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.csr_spend_r3626)
  select s.compliance_status, count(*)::bigint,
         coalesce(sum(s.csr_obligation_rupees),0)::numeric,
         coalesce(sum(s.amount_spent_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.csr_spend_r3626 s
  group by s.compliance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3626_compliance_status_rollup() from public, anon;
grant execute on function public.founder_r3626_compliance_status_rollup() to authenticated;

-- 2) CSR theme scorecard
create or replace function public.founder_r3626_theme_scorecard()
returns table(
  csr_theme text,
  projects bigint,
  total_obligation_rupees numeric,
  total_spent_rupees numeric,
  total_unspent_rupees numeric,
  compliant bigint,
  non_compliant bigint,
  avg_spend_ratio_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.csr_theme,
    count(*)::bigint,
    coalesce(sum(s.csr_obligation_rupees),0)::numeric,
    coalesce(sum(s.amount_spent_rupees),0)::numeric,
    coalesce(sum(s.unspent_rupees),0)::numeric,
    count(*) filter (where s.compliance_status = 'compliant')::bigint,
    count(*) filter (where s.compliance_status in ('shortfall','non_compliant','unspent_transfer_due'))::bigint,
    round(avg(s.spend_ratio_pct), 2)
  from public.csr_spend_r3626 s
  group by s.csr_theme
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3626_theme_scorecard() from public, anon;
grant execute on function public.founder_r3626_theme_scorecard() to authenticated;

-- 3) CSR theme × compliance-status matrix
create or replace function public.founder_r3626_theme_status_matrix()
returns table(csr_theme text, compliance_status text, projects bigint, total_obligation_rupees numeric, total_spent_rupees numeric, avg_spend_ratio_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.csr_theme, s.compliance_status, count(*)::bigint,
    coalesce(sum(s.csr_obligation_rupees),0)::numeric,
    coalesce(sum(s.amount_spent_rupees),0)::numeric,
    round(avg(s.spend_ratio_pct), 2)
  from public.csr_spend_r3626 s
  group by s.csr_theme, s.compliance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3626_theme_status_matrix() from public, anon;
grant execute on function public.founder_r3626_theme_status_matrix() to authenticated;

-- 4) Monthly spend trend
create or replace function public.founder_r3626_monthly_spend_trend()
returns table(period_month date, projects bigint, total_obligation_rupees numeric, total_spent_rupees numeric, total_unspent_rupees numeric, avg_spend_ratio_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.period_month,
    count(*)::bigint,
    coalesce(sum(s.csr_obligation_rupees),0)::numeric,
    coalesce(sum(s.amount_spent_rupees),0)::numeric,
    coalesce(sum(s.unspent_rupees),0)::numeric,
    round(avg(s.spend_ratio_pct), 2)
  from public.csr_spend_r3626 s
  group by s.period_month
  order by s.period_month desc;
end;
$$;

revoke execute on function public.founder_r3626_monthly_spend_trend() from public, anon;
grant execute on function public.founder_r3626_monthly_spend_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3626_capa_status_board()
returns table(capa_status text, findings bigint, total_shortfall_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    coalesce(sum(c.shortfall_amount_rupees),0)::numeric,
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.csr_spend_capa_actions_r3626 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3626_capa_status_board() from public, anon;
grant execute on function public.founder_r3626_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3626_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_shortfall_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.csr_spend_capa_actions_r3626)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.shortfall_amount_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.csr_spend_capa_actions_r3626 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3626_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3626_root_cause_pareto() to authenticated;

-- 7) Unspent-impact digest (by finding category)
create or replace function public.founder_r3626_unspent_impact_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_shortfall_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.shortfall_amount_rupees),0)::numeric
  from public.csr_spend_capa_actions_r3626 c
  group by c.finding_category
  order by coalesce(sum(c.shortfall_amount_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3626_unspent_impact_digest() from public, anon;
grant execute on function public.founder_r3626_unspent_impact_digest() to authenticated;

-- 8) High-risk queue (shortfall / non_compliant / unspent transfer due)
create or replace function public.founder_r3626_high_risk_queue()
returns table(
  project_code text,
  project_name text,
  csr_theme text,
  period_month date,
  csr_obligation_rupees numeric,
  amount_spent_rupees numeric,
  unspent_rupees numeric,
  spend_ratio_pct numeric,
  compliance_status text,
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
  select s.project_code, s.project_name, s.csr_theme, s.period_month,
    s.csr_obligation_rupees, s.amount_spent_rupees, s.unspent_rupees, s.spend_ratio_pct,
    s.compliance_status, s.trend_dir, s.notes
  from public.csr_spend_r3626 s
  where s.compliance_status in ('shortfall','non_compliant','unspent_transfer_due')
     or s.spend_ratio_pct < 50
  order by case s.compliance_status
             when 'non_compliant' then 0
             when 'unspent_transfer_due' then 1
             when 'shortfall' then 2
             else 3
           end,
           s.unspent_rupees desc;
end;
$$;

revoke execute on function public.founder_r3626_high_risk_queue() from public, anon;
grant execute on function public.founder_r3626_high_risk_queue() to authenticated;
