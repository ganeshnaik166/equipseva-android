-- Round 2945: Founder Quarterly Strategic Cohort Customer Lifetime-Value Curve Audit
-- 2 tables + 7 RPCs, is_founder() gated

create table if not exists quarterly_strategic_cohort_ltv_curves_r2945 (
  id uuid primary key default gen_random_uuid(),
  cohort_quarter text not null,
  cohort_label text not null,
  segment text not null check (segment in ('hospital_chain','standalone_hospital','clinic','diagnostic_lab','dental')),
  customers_acquired int not null check (customers_acquired >= 0),
  customers_retained_q1 int not null check (customers_retained_q1 >= 0),
  customers_retained_q4 int not null check (customers_retained_q4 >= 0),
  customers_retained_q8 int not null check (customers_retained_q8 >= 0),
  ltv_q1_rupees bigint not null check (ltv_q1_rupees >= 0),
  ltv_q4_rupees bigint not null check (ltv_q4_rupees >= 0),
  ltv_q8_rupees bigint not null check (ltv_q8_rupees >= 0),
  cac_rupees bigint not null check (cac_rupees >= 0),
  curve_shape text not null check (curve_shape in ('steep','linear','plateau','declining','accelerating')),
  payback_months numeric(6,2) not null check (payback_months >= 0),
  notes text not null default '',
  created_at timestamptz not null default now()
);

alter table quarterly_strategic_cohort_ltv_curves_r2945 enable row level security;

create table if not exists quarterly_strategic_cohort_ltv_audit_findings_r2945 (
  id uuid primary key default gen_random_uuid(),
  curve_id uuid not null references quarterly_strategic_cohort_ltv_curves_r2945(id) on delete cascade,
  finding_type text not null check (finding_type in ('healthy','at_risk','churning','outperforming','underperforming','flagged')),
  severity text not null check (severity in ('low','medium','high','critical')),
  observed_at timestamptz not null default now()::timestamptz,
  observation text not null,
  recommended_action text not null,
  expected_uplift_rupees bigint not null default 0 check (expected_uplift_rupees >= 0),
  owner_role text not null check (owner_role in ('founder','growth','ops','sales','cs')),
  status text not null check (status in ('open','in_review','actioned','closed','deferred')),
  created_at timestamptz not null default now()
);

alter table quarterly_strategic_cohort_ltv_audit_findings_r2945 enable row level security;

-- Seed curves (18 rows)
insert into quarterly_strategic_cohort_ltv_curves_r2945
  (cohort_quarter, cohort_label, segment, customers_acquired, customers_retained_q1, customers_retained_q4, customers_retained_q8, ltv_q1_rupees, ltv_q4_rupees, ltv_q8_rupees, cac_rupees, curve_shape, payback_months, notes)
values
  ('2024-Q1','Pilot wave Hyd','hospital_chain',12,12,11,9,180000,820000,1640000,55000,'accelerating',3.2,'Anchor accounts'),
  ('2024-Q2','Bengaluru seed','standalone_hospital',24,22,18,14,90000,420000,760000,32000,'plateau',4.8,'Early traction'),
  ('2024-Q3','Chennai clinic push','clinic',40,35,26,18,28000,140000,260000,11000,'linear',5.4,'Mid funnel decay'),
  ('2024-Q4','Diagnostic blitz','diagnostic_lab',18,17,15,12,72000,310000,590000,24000,'accelerating',3.9,'Strong LTV'),
  ('2025-Q1','Dental pilot HYD','dental',22,20,15,10,34000,160000,290000,13500,'plateau',6.1,'Long sales cycle'),
  ('2025-Q2','Tier-2 chain','hospital_chain',8,8,8,7,210000,960000,2100000,68000,'accelerating',2.8,'Best cohort'),
  ('2025-Q3','Pune standalone','standalone_hospital',30,26,19,12,82000,360000,640000,29000,'declining',5.9,'Churn spike Q5'),
  ('2025-Q4','Kerala clinics','clinic',55,46,30,19,26000,130000,220000,10000,'linear',5.6,'Stable mid-tier'),
  ('2026-Q1','Mumbai diagnostic','diagnostic_lab',26,24,20,0,68000,290000,0,22500,'steep',4.1,'In-flight'),
  ('2026-Q2','Dental Bangalore','dental',34,30,22,0,36000,170000,0,14000,'plateau',5.8,'In-flight'),
  ('2026-Q3','Hospital chain expansion','hospital_chain',15,15,14,0,195000,880000,0,60000,'accelerating',3.0,'Anchor wave 2'),
  ('2026-Q3','Standalone Coimbatore','standalone_hospital',28,25,0,0,86000,0,0,30000,'linear',5.2,'New cohort'),
  ('2023-Q4','Beta cohort','hospital_chain',6,5,4,3,165000,720000,1480000,52000,'declining',4.5,'Earliest set'),
  ('2024-Q1','Beta clinic Hyd','clinic',38,30,21,13,24000,118000,210000,9800,'declining',6.2,'Churn risk'),
  ('2025-Q2','Lab Vizag','diagnostic_lab',14,13,11,8,70000,300000,560000,23000,'plateau',4.4,'Stable'),
  ('2025-Q3','Dental Chennai','dental',26,22,16,11,33000,155000,285000,13000,'linear',5.9,'Mid'),
  ('2026-Q1','Hospital Indore','standalone_hospital',20,18,15,0,84000,350000,0,28000,'accelerating',4.0,'Promising'),
  ('2026-Q2','Clinic Jaipur','clinic',48,40,28,0,27000,135000,0,10500,'linear',5.5,'In-flight');

-- Seed findings (20 rows)
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'outperforming','high','Q8 LTV 29.8x CAC, strongest cohort','Replicate ICP filters for Q4 acquisition',850000,'founder','in_review'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Tier-2 chain' limit 1;
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'healthy','medium','Curve plateauing but payback <5mo','Maintain CS cadence',120000,'cs','open'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Bengaluru seed' limit 1;
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'at_risk','high','Q4->Q8 retention drop 35%','Launch reactivation campaign',420000,'growth','open'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Pune standalone' limit 1;
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'churning','critical','Churn 66% by Q8, lowest LTV','Pause clinic acquisition until ICP refined',680000,'founder','actioned'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Beta clinic Hyd' limit 1;
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'underperforming','medium','Dental segment payback >6mo','Tighten qualification on dental leads',150000,'sales','in_review'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Dental pilot HYD' limit 1;
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'outperforming','high','Diagnostic labs converting at 92%','Double diagnostic allocation Q4',520000,'growth','open'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Diagnostic blitz' limit 1;
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'flagged','high','In-flight cohort tracking 18% below model','Review onboarding friction',280000,'ops','open'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Dental Bangalore' limit 1;
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'healthy','low','Linear curve, stable mid-tier','Continue current motion',60000,'cs','closed'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Kerala clinics' limit 1;
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'outperforming','medium','Anchor wave 2 mirroring Q2 2025 leader','Lock-in 24-mo AMCs',410000,'founder','in_review'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Hospital chain expansion' limit 1;
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'at_risk','medium','Beta cohort decay accelerating','Re-engage with strategic review',180000,'cs','deferred'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Beta cohort' limit 1;
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'healthy','low','Vizag lab cohort stable','Quarterly check-in',45000,'cs','open'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Lab Vizag' limit 1;
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'flagged','high','Steep curve, possible over-discount','Audit pricing discipline',310000,'ops','open'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Mumbai diagnostic' limit 1;
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'underperforming','medium','Chennai clinic LTV trailing peers','Localized retention offer',95000,'growth','in_review'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Chennai clinic push' limit 1;
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'healthy','low','Indore standalone accelerating','Promote to anchor cohort tracking',75000,'founder','open'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Hospital Indore' limit 1;
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'churning','high','Dental Chennai losing 4 customers/quarter','Assign dental CS specialist',220000,'cs','open'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Dental Chennai' limit 1;
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'outperforming','medium','Pilot wave compounding','Use as flagship case study',360000,'growth','actioned'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Pilot wave Hyd' limit 1;
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'flagged','medium','Coimbatore cohort too young to score','Re-audit at Q4',0,'ops','deferred'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Standalone Coimbatore' limit 1;
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'at_risk','high','Jaipur clinic onboarding sluggish','Tighten activation SLA',130000,'ops','in_review'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Clinic Jaipur' limit 1;
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'healthy','medium','Vizag lab churn 0% over 6 quarters','Document playbook',55000,'cs','closed'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Lab Vizag' limit 1;
insert into quarterly_strategic_cohort_ltv_audit_findings_r2945
  (curve_id, finding_type, severity, observation, recommended_action, expected_uplift_rupees, owner_role, status)
select id, 'underperforming','low','Beta clinic Hyd unrecoverable','Sunset',0,'founder','closed'
  from quarterly_strategic_cohort_ltv_curves_r2945 where cohort_label='Beta clinic Hyd' limit 1;

-- RPCs

create or replace function r2945_curve_overview()
returns table (
  cohort_quarter text, cohort_label text, segment text,
  customers_acquired int, ltv_q8_rupees bigint, cac_rupees bigint,
  ltv_cac_ratio numeric, curve_shape text, payback_months numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select c.cohort_quarter, c.cohort_label, c.segment,
         c.customers_acquired, c.ltv_q8_rupees, c.cac_rupees,
         case when c.cac_rupees = 0 then 0 else round((c.ltv_q8_rupees::numeric / c.cac_rupees::numeric), 2) end,
         c.curve_shape, c.payback_months
  from quarterly_strategic_cohort_ltv_curves_r2945 c
  order by c.cohort_quarter desc, c.ltv_q8_rupees desc;
end; $$;
revoke all on function r2945_curve_overview() from public, anon;
grant execute on function r2945_curve_overview() to authenticated;

create or replace function r2945_segment_rollup()
returns table (segment text, cohorts int, total_acquired int, avg_payback numeric, total_ltv_q8 bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select c.segment,
         count(*)::int,
         sum(c.customers_acquired)::int,
         round(avg(c.payback_months), 2),
         sum(c.ltv_q8_rupees)::bigint
  from quarterly_strategic_cohort_ltv_curves_r2945 c
  group by c.segment
  order by sum(c.ltv_q8_rupees) desc;
end; $$;
revoke all on function r2945_segment_rollup() from public, anon;
grant execute on function r2945_segment_rollup() to authenticated;

create or replace function r2945_curve_shape_mix()
returns table (curve_shape text, cohort_count int, healthy_count int, at_risk_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select c.curve_shape,
         count(*)::int,
         (count(*) filter (where c.curve_shape in ('accelerating','linear','plateau')))::int,
         (count(*) filter (where c.curve_shape in ('declining','steep')))::int
  from quarterly_strategic_cohort_ltv_curves_r2945 c
  group by c.curve_shape
  order by count(*) desc;
end; $$;
revoke all on function r2945_curve_shape_mix() from public, anon;
grant execute on function r2945_curve_shape_mix() to authenticated;

create or replace function r2945_retention_decay()
returns table (cohort_label text, segment text, q1_retention numeric, q4_retention numeric, q8_retention numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select c.cohort_label, c.segment,
         case when c.customers_acquired = 0 then 0 else round(c.customers_retained_q1::numeric / c.customers_acquired::numeric * 100, 1) end,
         case when c.customers_acquired = 0 then 0 else round(c.customers_retained_q4::numeric / c.customers_acquired::numeric * 100, 1) end,
         case when c.customers_acquired = 0 then 0 else round(c.customers_retained_q8::numeric / c.customers_acquired::numeric * 100, 1) end
  from quarterly_strategic_cohort_ltv_curves_r2945 c
  order by c.cohort_quarter desc;
end; $$;
revoke all on function r2945_retention_decay() from public, anon;
grant execute on function r2945_retention_decay() to authenticated;

create or replace function r2945_audit_findings_log()
returns table (cohort_label text, finding_type text, severity text, observation text, recommended_action text, owner_role text, status text, expected_uplift_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select c.cohort_label, f.finding_type, f.severity, f.observation, f.recommended_action, f.owner_role, f.status, f.expected_uplift_rupees
  from quarterly_strategic_cohort_ltv_audit_findings_r2945 f
  join quarterly_strategic_cohort_ltv_curves_r2945 c on c.id = f.curve_id
  order by case f.severity when 'critical' then 0 when 'high' then 1 when 'medium' then 2 else 3 end, f.created_at desc;
end; $$;
revoke all on function r2945_audit_findings_log() from public, anon;
grant execute on function r2945_audit_findings_log() to authenticated;

create or replace function r2945_severity_breakdown()
returns table (severity text, finding_count int, open_count int, total_uplift bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select f.severity,
         count(*)::int,
         (count(*) filter (where f.status in ('open','in_review')))::int,
         sum(f.expected_uplift_rupees)::bigint
  from quarterly_strategic_cohort_ltv_audit_findings_r2945 f
  group by f.severity
  order by case f.severity when 'critical' then 0 when 'high' then 1 when 'medium' then 2 else 3 end;
end; $$;
revoke all on function r2945_severity_breakdown() from public, anon;
grant execute on function r2945_severity_breakdown() to authenticated;

create or replace function r2945_top_uplift_actions()
returns table (cohort_label text, segment text, recommended_action text, owner_role text, status text, expected_uplift_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select c.cohort_label, c.segment, f.recommended_action, f.owner_role, f.status, f.expected_uplift_rupees
  from quarterly_strategic_cohort_ltv_audit_findings_r2945 f
  join quarterly_strategic_cohort_ltv_curves_r2945 c on c.id = f.curve_id
  where f.status in ('open','in_review','actioned')
  order by f.expected_uplift_rupees desc
  limit 10;
end; $$;
revoke all on function r2945_top_uplift_actions() from public, anon;
grant execute on function r2945_top_uplift_actions() to authenticated;
