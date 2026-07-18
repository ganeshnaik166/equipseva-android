-- Round 3145: Founder Non-Dilutive Grant & Tender Funding Pipeline Tracker
-- Grant/tender pipeline log — programme × funding-stream × stage × probability × dilution=none × status + CAPA follow-up actions

-- =============================================================================
-- TABLE 1: grant_funding_r3145 — grant / tender application pipeline log
-- =============================================================================
create table if not exists public.grant_funding_r3145 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  programme_code text not null check (programme_code in (
    'birac_big','birac_sbiri','birac_pace_ace',
    'sidbi_fund_of_funds','sidbi_4e_scheme',
    'startup_india_seed_fund','nidhi_prayas','tdb_medtech_grant',
    'meity_tide_2','dst_nidhi_epc',
    'state_msme_capital_subsidy','state_medtech_park_grant',
    'hospital_tender_gem','hospital_tender_psu_procurement','aiims_innovation_tender'
  )),
  funding_stream text not null check (funding_stream in (
    'central_grant','state_subsidy','dbt_birac_grant','soft_loan_debt','hospital_tender','challenge_prize'
  )),
  application_ref text not null,
  amount_sought_rupees numeric(14,2) not null,
  amount_awarded_rupees numeric(14,2),
  stage text not null check (stage in (
    'lead_identified','eligibility_check','drafting_proposal','submitted',
    'technical_screening','due_diligence','presentation_pitch','sanction_pending',
    'disbursed','rejected','withdrawn'
  )),
  probability_pct numeric(5,2),
  dilution_type text not null default 'none' check (dilution_type in (
    'none','equity','convertible','royalty','revenue_share'
  )),
  submitted_date date,
  decision_expected_date date,
  decision_date date,
  status text not null check (status in (
    'active_pipeline','shortlisted','awarded','disbursed','rejected','on_hold','withdrawn','resubmit_required'
  )),
  lead_owner text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.grant_funding_r3145 enable row level security;

create index if not exists idx_grant_funding_r3145_org on public.grant_funding_r3145(organization_id);
create index if not exists idx_grant_funding_r3145_submitted on public.grant_funding_r3145(submitted_date);
create index if not exists idx_grant_funding_r3145_status on public.grant_funding_r3145(status);

-- =============================================================================
-- TABLE 2: grant_funding_capa_actions_r3145 — CAPA / follow-up actions
-- =============================================================================
create table if not exists public.grant_funding_capa_actions_r3145 (
  id uuid primary key default gen_random_uuid(),
  grant_id uuid not null references public.grant_funding_r3145(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'incomplete_documentation','eligibility_gap','budget_mismatch','missed_deadline',
    'weak_technical_narrative','compliance_certificate_missing','ip_clarity_gap',
    'matching_fund_shortfall','tender_spec_noncompliance','follow_up_pending'
  )),
  root_cause text not null check (root_cause in (
    'proposal_team_bandwidth','unclear_scheme_guidelines','delayed_partner_signoff',
    'financial_model_error','missing_gst_udyam_registration','weak_prototype_evidence',
    'consultant_dependency','portal_technical_issue','pending_investigation','board_approval_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'rewrite_technical_section','engage_grant_consultant','complete_udyam_registration',
    'revise_budget_sheet','secure_matching_commitment','resubmit_in_next_window',
    'escalate_to_founder','obtain_compliance_certificate','none_required','schedule_mock_pitch'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'gem_portal_compliance','birac_grant_condition','cdsco_dependency','none','internal_only','state_subsidy_condition'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.grant_funding_capa_actions_r3145 enable row level security;

create index if not exists idx_grant_capa_r3145_grant on public.grant_funding_capa_actions_r3145(grant_id);
create index if not exists idx_grant_capa_r3145_status on public.grant_funding_capa_actions_r3145(capa_status);

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

  -- 14 grant / tender pipeline rows
  insert into public.grant_funding_r3145 (
    organization_id, hospital_name, programme_code, funding_stream, application_ref,
    amount_sought_rupees, amount_awarded_rupees, stage, probability_pct, dilution_type,
    submitted_date, decision_expected_date, decision_date, status, lead_owner, notes
  )
  select v_org_id, q.hosp, q.prog, q.stream, q.ref,
    q.sought, q.awarded, q.stage, q.prob, q.dil,
    q.sub::date, q.exp::date, q.dec::date, q.status, q.owner, q.notes
  from (values
    ('Apollo Hyderabad Jubilee Hills','birac_big','dbt_birac_grant','BIG-2026-0142',
     5000000.00,null,'technical_screening',55.00,'none',
     '2026-05-12','2026-08-15',null,'active_pipeline','Dr. Meera Rao','BIG grant for portable sterilizer IoT retrofit'),
    ('Fortis Bannerghatta Bengaluru','hospital_tender_gem','hospital_tender','GEM-2026-88431',
     12000000.00,null,'submitted',40.00,'none',
     '2026-06-01','2026-07-30',null,'active_pipeline','Rahul Nair','GeM tender for AMC of 45 biomedical assets'),
    ('Manipal Whitefield Bengaluru','sidbi_fund_of_funds','soft_loan_debt','SIDBI-FOF-2026-311',
     20000000.00,null,'due_diligence',60.00,'none',
     '2026-04-20','2026-09-01',null,'shortlisted','Rahul Nair','Working-capital debt line via AIF'),
    ('AIIMS New Delhi Ansari Nagar','aiims_innovation_tender','hospital_tender','AIIMS-INNO-2026-07',
     8500000.00,8500000.00,'disbursed',100.00,'none',
     '2026-02-10','2026-04-30','2026-05-05','awarded','Dr. Meera Rao','Innovation partner tender awarded and disbursed'),
    ('KIMS Secunderabad','startup_india_seed_fund','central_grant','SISFS-2026-2290',
     4500000.00,null,'sanction_pending',70.00,'none',
     '2026-03-15','2026-07-25',null,'shortlisted','Anita Desai','Seed fund via incubator T-Hub'),
    ('Care Hospitals Banjara Hills','state_msme_capital_subsidy','state_subsidy','TS-MSME-2026-0455',
     3000000.00,null,'submitted',45.00,'none',
     '2026-06-05','2026-08-20',null,'active_pipeline','Anita Desai','Telangana capital subsidy on lab equipment'),
    ('Yashoda Somajiguda Hyderabad','birac_sbiri','dbt_birac_grant','SBIRI-2026-0781',
     15000000.00,null,'presentation_pitch',50.00,'none',
     '2026-05-28','2026-09-10',null,'active_pipeline','Dr. Meera Rao','SBIRI for AI predictive-maintenance module'),
    ('St John''s Bengaluru','nidhi_prayas','central_grant','PRAYAS-2026-0119',
     1000000.00,1000000.00,'disbursed',100.00,'none',
     '2026-01-20','2026-03-15','2026-03-20','disbursed','Anita Desai','Prototype grant fully disbursed'),
    ('Rainbow Children''s Hyderabad','hospital_tender_psu_procurement','hospital_tender','PSU-PROC-2026-664',
     6500000.00,null,'technical_screening',35.00,'none',
     '2026-06-12','2026-08-05',null,'active_pipeline','Rahul Nair','PSU procurement — L1 evaluation pending'),
    ('Fortis Bannerghatta Bengaluru','tdb_medtech_grant','central_grant','TDB-2026-0503',
     25000000.00,null,'drafting_proposal',30.00,'none',
     null,'2026-10-01',null,'active_pipeline','Dr. Meera Rao','TDB medtech commercialization — DPR in draft'),
    ('Manipal Whitefield Bengaluru','meity_tide_2','central_grant','TIDE2-2026-0288',
     4000000.00,null,'rejected',0.00,'none',
     '2026-02-25','2026-05-01','2026-05-08','rejected','Anita Desai','Rejected — weak commercialization plan; resubmit next window'),
    ('Apollo Hyderabad Jubilee Hills','sidbi_4e_scheme','soft_loan_debt','SIDBI-4E-2026-177',
     5000000.00,null,'eligibility_check',25.00,'none',
     null,'2026-09-15',null,'active_pipeline','Rahul Nair','4E end-to-end energy efficiency loan — screening'),
    ('AIIMS New Delhi Ansari Nagar','dst_nidhi_epc','central_grant','EPC-2026-0442',
     3500000.00,null,'submitted',48.00,'none',
     '2026-06-18','2026-09-20',null,'active_pipeline','Dr. Meera Rao','NIDHI EPC accelerator cohort application'),
    ('KIMS Secunderabad','hospital_tender_gem','hospital_tender','GEM-2026-90112',
     9000000.00,null,'withdrawn',0.00,'none',
     '2026-05-05','2026-07-10','2026-06-01','withdrawn','Rahul Nair','Withdrew — spec favored incumbent OEM')
  ) as q(hosp, prog, stream, ref, sought, awarded, stage, prob, dil, sub, exp, dec, status, owner, notes);

  -- 6 CAPA / follow-up rows — attach to specific applications by ref
  insert into public.grant_funding_capa_actions_r3145 (
    grant_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('GEM-2026-88431','missed_deadline','portal_technical_issue','resubmit_in_next_window',
     '2026-07-05',null,'in_progress','gem_portal_compliance',15000.00,'GeM portal timed out at upload; support ticket raised'),
    ('TIDE2-2026-0288','weak_technical_narrative','unclear_scheme_guidelines','rewrite_technical_section',
     '2026-06-15','2026-06-20','closed','internal_only',40000.00,'Reworked narrative with consultant for resubmission'),
    ('BIG-2026-0142','ip_clarity_gap','weak_prototype_evidence','rewrite_technical_section',
     '2026-07-20',null,'open','birac_grant_condition',60000.00,'BIRAC reviewer flagged freedom-to-operate; patent search commissioned'),
    ('SISFS-2026-2290','matching_fund_shortfall','delayed_partner_signoff','secure_matching_commitment',
     '2026-07-15',null,'escalated','internal_only',25000.00,'Need incubator co-investment letter before sanction'),
    ('TS-MSME-2026-0455','compliance_certificate_missing','missing_gst_udyam_registration','complete_udyam_registration',
     '2026-06-30',null,'overdue','state_subsidy_condition',5000.00,'Udyam re-registration pending — blocks subsidy claim'),
    ('PSU-PROC-2026-664','tender_spec_noncompliance','financial_model_error','revise_budget_sheet',
     '2026-07-08',null,'in_progress','internal_only',12000.00,'BoQ pricing revised to meet L1 evaluation')
  ) as q(app_ref, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.grant_funding_r3145 e
    on e.organization_id = v_org_id and e.application_ref = q.app_ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Status / verdict rollup (+ pct)
create or replace function public.founder_r3145_status_rollup()
returns table(status text, applications bigint, total_sought numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.grant_funding_r3145)
  select g.status, count(*)::bigint,
         coalesce(sum(g.amount_sought_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.grant_funding_r3145 g
  group by g.status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3145_status_rollup() from public, anon;
grant execute on function public.founder_r3145_status_rollup() to authenticated;

-- 2) Hospital / entity scorecard
create or replace function public.founder_r3145_hospital_scorecard()
returns table(
  hospital_name text,
  applications bigint,
  awarded bigint,
  disbursed bigint,
  rejected bigint,
  total_sought numeric,
  total_awarded numeric,
  win_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select g.hospital_name,
    count(*)::bigint,
    count(*) filter (where g.status in ('awarded','disbursed'))::bigint,
    count(*) filter (where g.status = 'disbursed')::bigint,
    count(*) filter (where g.status = 'rejected')::bigint,
    coalesce(sum(g.amount_sought_rupees),0)::numeric,
    coalesce(sum(g.amount_awarded_rupees),0)::numeric,
    round(100.0 * count(*) filter (where g.status in ('awarded','disbursed'))::numeric / nullif(count(*),0), 1)
  from public.grant_funding_r3145 g
  group by g.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3145_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3145_hospital_scorecard() to authenticated;

-- 3) Funding-stream × stage category matrix
create or replace function public.founder_r3145_stream_stage_matrix()
returns table(funding_stream text, stage text, applications bigint, total_sought numeric, avg_probability numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select g.funding_stream, g.stage, count(*)::bigint,
    coalesce(sum(g.amount_sought_rupees),0)::numeric,
    round(avg(g.probability_pct), 1)
  from public.grant_funding_r3145 g
  group by g.funding_stream, g.stage
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3145_stream_stage_matrix() from public, anon;
grant execute on function public.founder_r3145_stream_stage_matrix() to authenticated;

-- 4) Submission time trend
create or replace function public.founder_r3145_submission_trend()
returns table(submitted_date date, submissions bigint, total_sought numeric, avg_probability numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select g.submitted_date, count(*)::bigint,
    coalesce(sum(g.amount_sought_rupees),0)::numeric,
    round(avg(g.probability_pct), 1)
  from public.grant_funding_r3145 g
  where g.submitted_date is not null
  group by g.submitted_date
  order by g.submitted_date desc;
end;
$$;

revoke execute on function public.founder_r3145_submission_trend() from public, anon;
grant execute on function public.founder_r3145_submission_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3145_capa_status_board()
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
  from public.grant_funding_capa_actions_r3145 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3145_capa_status_board() from public, anon;
grant execute on function public.founder_r3145_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3145_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.grant_funding_capa_actions_r3145)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.grant_funding_capa_actions_r3145 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3145_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3145_root_cause_pareto() to authenticated;

-- 7) Regulatory / impact digest
create or replace function public.founder_r3145_regulatory_impact_digest()
returns table(regulatory_impact text, actions bigint, open_actions bigint, total_cost_rupees numeric)
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
  from public.grant_funding_capa_actions_r3145 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3145_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3145_regulatory_impact_digest() to authenticated;

-- 8) High-priority pipeline queue
create or replace function public.founder_r3145_priority_queue()
returns table(
  hospital_name text,
  programme_code text,
  application_ref text,
  amount_sought_rupees numeric,
  stage text,
  probability_pct numeric,
  status text,
  decision_expected_date date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select g.hospital_name, g.programme_code, g.application_ref, g.amount_sought_rupees,
    g.stage, g.probability_pct, g.status, g.decision_expected_date, g.notes
  from public.grant_funding_r3145 g
  where g.status in ('active_pipeline','shortlisted','on_hold','resubmit_required')
     or g.stage in ('technical_screening','due_diligence','presentation_pitch','sanction_pending')
  order by g.probability_pct desc nulls last, g.amount_sought_rupees desc;
end;
$$;

revoke execute on function public.founder_r3145_priority_queue() from public, anon;
grant execute on function public.founder_r3145_priority_queue() to authenticated;
