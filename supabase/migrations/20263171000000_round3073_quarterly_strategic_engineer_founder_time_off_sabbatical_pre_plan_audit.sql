-- Round 3073: Founder Quarterly Strategic Engineer-Founder Time-Off Sabbatical Pre-Plan Audit
-- 2 tables, 7 RPCs, founder-gated.

create table if not exists sabbatical_pre_plan_audits_r3073 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_quarter text not null check (audit_quarter in ('Q1-2026','Q2-2026','Q3-2026','Q4-2026','Q1-2027','Q2-2027')),
  audit_owner text not null check (audit_owner in ('founder','coo','chief_of_staff','board_advisor','external_auditor')),
  sabbatical_candidate text not null check (sabbatical_candidate in ('founder','cto','head_engineering','field_ops_lead','principal_engineer','platform_lead','coo','chief_of_staff')),
  planned_start_date date not null,
  planned_end_date date not null,
  duration_weeks int not null check (duration_weeks between 1 and 26),
  readiness_score int not null check (readiness_score between 0 and 100),
  blast_radius text not null check (blast_radius in ('low','moderate','high','critical')),
  successor_named text not null check (successor_named in ('named_committed','named_tentative','shortlist','none')),
  oncall_coverage_pct int not null check (oncall_coverage_pct between 0 and 100),
  knowledge_transfer_status text not null check (knowledge_transfer_status in ('not_started','documenting','in_review','signed_off')),
  audit_verdict text not null check (audit_verdict in ('green_go','yellow_conditional','red_blocked','deferred')),
  cost_to_business_inr_lakhs numeric(10,2) check (cost_to_business_inr_lakhs >= 0),
  reentry_plan_quality text not null check (reentry_plan_quality in ('excellent','adequate','weak','missing')),
  notes text
);

create table if not exists sabbatical_risk_register_r3073 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_id uuid references sabbatical_pre_plan_audits_r3073(id) on delete cascade,
  risk_area text not null check (risk_area in ('customer_escalation','engineer_morale','board_signal','investor_signal','product_velocity','revenue_continuity','hospital_relationships','regulatory_compliance','hiring_pipeline')),
  risk_severity text not null check (risk_severity in ('p0','p1','p2','p3')),
  likelihood_pct int not null check (likelihood_pct between 0 and 100),
  mitigation_owner text not null check (mitigation_owner in ('founder','coo','chief_of_staff','head_sales','head_engineering','board_advisor')),
  mitigation_status text not null check (mitigation_status in ('not_started','in_progress','mitigated','accepted','transferred')),
  mitigation_deadline date,
  residual_score int not null check (residual_score between 0 and 100),
  escalation_path text not null check (escalation_path in ('founder_phone','board_chair','coo_only','async_email','none')),
  notes text
);

alter table sabbatical_pre_plan_audits_r3073 enable row level security;
alter table sabbatical_risk_register_r3073 enable row level security;

drop policy if exists sabbatical_pre_plan_audits_r3073_founder_all on sabbatical_pre_plan_audits_r3073;
create policy sabbatical_pre_plan_audits_r3073_founder_all on sabbatical_pre_plan_audits_r3073
  for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists sabbatical_risk_register_r3073_founder_all on sabbatical_risk_register_r3073;
create policy sabbatical_risk_register_r3073_founder_all on sabbatical_risk_register_r3073
  for all to authenticated using (is_founder()) with check (is_founder());

-- Seed audits (16 rows)
insert into sabbatical_pre_plan_audits_r3073
  (audit_quarter, audit_owner, sabbatical_candidate, planned_start_date, planned_end_date, duration_weeks, readiness_score, blast_radius, successor_named, oncall_coverage_pct, knowledge_transfer_status, audit_verdict, cost_to_business_inr_lakhs, reentry_plan_quality, notes)
values
  ('Q1-2026','founder','founder','2026-03-01'::date,'2026-04-12'::date,6,72,'high','named_tentative',80,'in_review','yellow_conditional',18.50,'adequate','Founder 6-week sabbatical conditional on COO ramp'),
  ('Q1-2026','coo','cto','2026-03-15'::date,'2026-04-26'::date,6,84,'moderate','named_committed',92,'signed_off','green_go',9.25,'excellent','CTO well-covered by platform lead'),
  ('Q2-2026','chief_of_staff','head_engineering','2026-05-01'::date,'2026-05-29'::date,4,68,'high','named_tentative',75,'documenting','yellow_conditional',12.10,'adequate','Eng head sabbatical mid-roadmap risk'),
  ('Q2-2026','founder','founder','2026-06-01'::date,'2026-07-13'::date,6,55,'critical','shortlist',60,'not_started','red_blocked',31.00,'weak','Founder pre-plan red: no named successor'),
  ('Q3-2026','board_advisor','founder','2026-08-15'::date,'2026-10-10'::date,8,88,'moderate','named_committed',95,'signed_off','green_go',14.75,'excellent','Founder 8-week sabbatical fully covered'),
  ('Q3-2026','coo','field_ops_lead','2026-09-01'::date,'2026-09-29'::date,4,79,'moderate','named_committed',88,'in_review','green_go',6.50,'adequate','Field ops lead 4-week recharge'),
  ('Q4-2026','founder','principal_engineer','2026-10-15'::date,'2026-12-10'::date,8,82,'moderate','named_committed',90,'signed_off','green_go',11.25,'excellent','Principal eng paternity sabbatical'),
  ('Q4-2026','external_auditor','founder','2026-11-01'::date,'2026-12-27'::date,8,49,'critical','none',45,'not_started','red_blocked',42.00,'missing','Founder sabbatical blocked by external audit'),
  ('Q1-2027','founder','cto','2027-02-01'::date,'2027-03-15'::date,6,76,'moderate','named_committed',85,'in_review','yellow_conditional',10.50,'adequate','CTO sabbatical pending KT signoff'),
  ('Q1-2027','coo','platform_lead','2027-03-01'::date,'2027-03-29'::date,4,91,'low','named_committed',98,'signed_off','green_go',4.25,'excellent','Platform lead well-covered'),
  ('Q2-2027','chief_of_staff','founder','2027-04-15'::date,'2027-06-26'::date,10,65,'critical','named_tentative',70,'documenting','yellow_conditional',58.00,'adequate','Founder 10-week sabbatical needs more prep'),
  ('Q2-2027','founder','head_engineering','2027-05-01'::date,'2027-06-12'::date,6,73,'high','named_tentative',78,'in_review','yellow_conditional',16.25,'adequate','Eng head needs deeper bench'),
  ('Q3-2026','founder','coo','2026-09-15'::date,'2026-10-13'::date,4,38,'critical','none',40,'not_started','red_blocked',28.50,'missing','COO sabbatical blocked - no successor'),
  ('Q4-2026','board_advisor','platform_lead','2026-11-15'::date,'2026-12-13'::date,4,86,'low','named_committed',94,'signed_off','green_go',3.75,'excellent','Platform lead routine recharge'),
  ('Q1-2027','founder','field_ops_lead','2027-01-15'::date,'2027-02-26'::date,6,70,'moderate','named_tentative',82,'documenting','deferred',8.50,'adequate','Deferred to Q2-2027 for KT completion'),
  ('Q2-2026','external_auditor','principal_engineer','2026-06-15'::date,'2026-07-13'::date,4,81,'low','named_committed',91,'signed_off','green_go',5.25,'excellent','Routine principal eng sabbatical');

-- Seed risk register (20 rows)
insert into sabbatical_risk_register_r3073
  (risk_area, risk_severity, likelihood_pct, mitigation_owner, mitigation_status, mitigation_deadline, residual_score, escalation_path, notes)
values
  ('customer_escalation','p1',45,'coo','in_progress','2026-02-15'::date,28,'founder_phone','Top-5 hospital accounts need warm handoff'),
  ('engineer_morale','p2',30,'chief_of_staff','in_progress','2026-02-28'::date,18,'coo_only','Skip-level meetings during sabbatical'),
  ('board_signal','p1',55,'founder','mitigated','2026-01-15'::date,15,'board_chair','Board pre-briefed; signed off'),
  ('investor_signal','p0',65,'founder','in_progress','2026-02-10'::date,42,'board_chair','LP letter drafted, pending review'),
  ('product_velocity','p2',40,'head_engineering','in_progress','2026-03-01'::date,25,'coo_only','Roadmap frozen for sabbatical period'),
  ('revenue_continuity','p1',35,'coo','mitigated','2026-01-30'::date,12,'founder_phone','Q1 deals pre-closed before sabbatical'),
  ('hospital_relationships','p1',50,'coo','in_progress','2026-02-20'::date,30,'founder_phone','Relationship matrix transferred to COO'),
  ('regulatory_compliance','p2',20,'chief_of_staff','mitigated','2026-01-25'::date,8,'async_email','CDSCO + DPDP filings caught up'),
  ('hiring_pipeline','p3',25,'head_sales','accepted','2026-03-15'::date,22,'async_email','Hiring paused during sabbatical'),
  ('customer_escalation','p0',70,'founder','not_started',null,68,'founder_phone','Critical escalation path undefined for founder sabbatical'),
  ('engineer_morale','p1',45,'head_engineering','in_progress','2026-05-15'::date,30,'coo_only','Morale check-ins weekly'),
  ('board_signal','p2',35,'founder','mitigated','2026-04-30'::date,14,'board_chair','Q2 board pre-read locked'),
  ('investor_signal','p1',50,'chief_of_staff','in_progress','2026-05-10'::date,32,'board_chair','Quarterly LP update template ready'),
  ('product_velocity','p1',55,'head_engineering','in_progress','2026-05-20'::date,40,'coo_only','Q2 roadmap may slip 2 weeks'),
  ('revenue_continuity','p2',30,'head_sales','accepted','2026-06-01'::date,20,'founder_phone','Sales pipeline self-sustaining'),
  ('hospital_relationships','p0',60,'coo','not_started',null,58,'founder_phone','Tier-1 hospitals expect founder presence'),
  ('regulatory_compliance','p1',40,'chief_of_staff','in_progress','2026-08-01'::date,28,'async_email','GST + DPDP audits during Q3 sabbatical'),
  ('hiring_pipeline','p3',15,'head_sales','transferred','2026-09-15'::date,10,'async_email','Recruiter agency handles pipeline'),
  ('customer_escalation','p2',25,'coo','mitigated','2026-08-20'::date,12,'coo_only','Tier-2/3 accounts COO-led'),
  ('product_velocity','p0',75,'founder','not_started',null,70,'founder_phone','Founder sabbatical Q4 = no shipped features risk');

-- RPC 1: list audits
create or replace function rpc_r3073_list_audits()
returns setof sabbatical_pre_plan_audits_r3073
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select * from sabbatical_pre_plan_audits_r3073
    order by planned_start_date asc, audit_quarter asc;
end;
$$;

-- RPC 2: verdict rollup by quarter
create or replace function rpc_r3073_verdict_rollup()
returns table (
  audit_quarter text,
  total_audits int,
  green_go int,
  yellow_conditional int,
  red_blocked int,
  deferred int,
  avg_readiness numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      a.audit_quarter,
      count(*)::int as total_audits,
      (count(*) filter (where a.audit_verdict = 'green_go'))::int as green_go,
      (count(*) filter (where a.audit_verdict = 'yellow_conditional'))::int as yellow_conditional,
      (count(*) filter (where a.audit_verdict = 'red_blocked'))::int as red_blocked,
      (count(*) filter (where a.audit_verdict = 'deferred'))::int as deferred,
      round(avg(a.readiness_score)::numeric, 1) as avg_readiness
    from sabbatical_pre_plan_audits_r3073 a
    group by a.audit_quarter
    order by a.audit_quarter asc;
end;
$$;

-- RPC 3: blocked sabbaticals
create or replace function rpc_r3073_blocked_sabbaticals()
returns table (
  id uuid,
  audit_quarter text,
  sabbatical_candidate text,
  planned_start_date date,
  duration_weeks int,
  readiness_score int,
  blast_radius text,
  successor_named text,
  cost_to_business_inr_lakhs numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select a.id, a.audit_quarter, a.sabbatical_candidate, a.planned_start_date,
           a.duration_weeks, a.readiness_score, a.blast_radius, a.successor_named,
           a.cost_to_business_inr_lakhs, a.notes
    from sabbatical_pre_plan_audits_r3073 a
    where a.audit_verdict = 'red_blocked'
    order by a.readiness_score asc;
end;
$$;

-- RPC 4: readiness by candidate role
create or replace function rpc_r3073_readiness_by_candidate()
returns table (
  sabbatical_candidate text,
  audit_count int,
  avg_readiness numeric,
  avg_oncall_coverage numeric,
  signed_off_kt int,
  critical_blast int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      a.sabbatical_candidate,
      count(*)::int as audit_count,
      round(avg(a.readiness_score)::numeric, 1) as avg_readiness,
      round(avg(a.oncall_coverage_pct)::numeric, 1) as avg_oncall_coverage,
      (count(*) filter (where a.knowledge_transfer_status = 'signed_off'))::int as signed_off_kt,
      (count(*) filter (where a.blast_radius = 'critical'))::int as critical_blast
    from sabbatical_pre_plan_audits_r3073 a
    group by a.sabbatical_candidate
    order by avg_readiness desc;
end;
$$;

-- RPC 5: risk register summary
create or replace function rpc_r3073_risk_summary()
returns table (
  risk_area text,
  risk_count int,
  p0_count int,
  p1_count int,
  avg_likelihood numeric,
  avg_residual numeric,
  mitigated_count int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      r.risk_area,
      count(*)::int as risk_count,
      (count(*) filter (where r.risk_severity = 'p0'))::int as p0_count,
      (count(*) filter (where r.risk_severity = 'p1'))::int as p1_count,
      round(avg(r.likelihood_pct)::numeric, 1) as avg_likelihood,
      round(avg(r.residual_score)::numeric, 1) as avg_residual,
      (count(*) filter (where r.mitigation_status = 'mitigated'))::int as mitigated_count
    from sabbatical_risk_register_r3073 r
    group by r.risk_area
    order by avg_residual desc;
end;
$$;

-- RPC 6: cost-of-business projection
create or replace function rpc_r3073_cost_projection()
returns table (
  audit_quarter text,
  total_cost_inr_lakhs numeric,
  avg_cost_inr_lakhs numeric,
  max_cost_inr_lakhs numeric,
  blocked_cost_inr_lakhs numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      a.audit_quarter,
      round(coalesce(sum(a.cost_to_business_inr_lakhs), 0)::numeric, 2) as total_cost_inr_lakhs,
      round(coalesce(avg(a.cost_to_business_inr_lakhs), 0)::numeric, 2) as avg_cost_inr_lakhs,
      round(coalesce(max(a.cost_to_business_inr_lakhs), 0)::numeric, 2) as max_cost_inr_lakhs,
      round(coalesce(sum(a.cost_to_business_inr_lakhs) filter (where a.audit_verdict = 'red_blocked'), 0)::numeric, 2) as blocked_cost_inr_lakhs
    from sabbatical_pre_plan_audits_r3073 a
    group by a.audit_quarter
    order by a.audit_quarter asc;
end;
$$;

-- RPC 7: high-residual risks
create or replace function rpc_r3073_high_residual_risks()
returns table (
  id uuid,
  risk_area text,
  risk_severity text,
  likelihood_pct int,
  residual_score int,
  mitigation_owner text,
  mitigation_status text,
  mitigation_deadline date,
  escalation_path text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select r.id, r.risk_area, r.risk_severity, r.likelihood_pct, r.residual_score,
           r.mitigation_owner, r.mitigation_status, r.mitigation_deadline,
           r.escalation_path, r.notes
    from sabbatical_risk_register_r3073 r
    where r.residual_score >= 30
    order by r.residual_score desc, r.likelihood_pct desc;
end;
$$;

revoke all on function rpc_r3073_list_audits() from public, anon;
revoke all on function rpc_r3073_verdict_rollup() from public, anon;
revoke all on function rpc_r3073_blocked_sabbaticals() from public, anon;
revoke all on function rpc_r3073_readiness_by_candidate() from public, anon;
revoke all on function rpc_r3073_risk_summary() from public, anon;
revoke all on function rpc_r3073_cost_projection() from public, anon;
revoke all on function rpc_r3073_high_residual_risks() from public, anon;

grant execute on function rpc_r3073_list_audits() to authenticated;
grant execute on function rpc_r3073_verdict_rollup() to authenticated;
grant execute on function rpc_r3073_blocked_sabbaticals() to authenticated;
grant execute on function rpc_r3073_readiness_by_candidate() to authenticated;
grant execute on function rpc_r3073_risk_summary() to authenticated;
grant execute on function rpc_r3073_cost_projection() to authenticated;
grant execute on function rpc_r3073_high_residual_risks() to authenticated;
