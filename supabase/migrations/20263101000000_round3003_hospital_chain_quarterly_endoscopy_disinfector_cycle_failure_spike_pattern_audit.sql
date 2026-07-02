-- Round 3003 — Hospital Chain Quarterly Endoscopy Disinfector Cycle-Failure Spike Pattern Audit
-- HEAVY ★★★★

create extension if not exists pgcrypto;

-- =========================================================
-- Tables
-- =========================================================

create table if not exists endoscopy_disinfector_cycles_r3003 (
  id uuid primary key default gen_random_uuid(),
  chain_code text not null,
  hospital_site text not null,
  quarter text not null check (quarter in ('Q1','Q2','Q3','Q4')),
  fiscal_year int not null check (fiscal_year between 2023 and 2030),
  disinfector_model text not null check (disinfector_model in ('aer_pro_2','aer_pro_3','olympus_etd','medivators_advantage')),
  cycle_outcome text not null check (cycle_outcome in ('pass','fail','abort','rerun_pass')),
  failure_mode text not null check (failure_mode in ('leak_test','temperature','chemistry','rinse','none')),
  cycles_run int not null check (cycles_run >= 0),
  cycles_failed int not null check (cycles_failed >= 0),
  spike_flag boolean not null default false,
  audit_status text not null check (audit_status in ('open','in_progress','closed')),
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists endoscopy_disinfector_spike_findings_r3003 (
  id uuid primary key default gen_random_uuid(),
  chain_code text not null,
  finding_type text not null check (finding_type in ('cluster_spike','model_recall_risk','reprocessing_breach','training_gap','consumable_lot_defect')),
  severity text not null check (severity in ('low','medium','high','critical')),
  q_period text not null check (q_period in ('Q1','Q2','Q3','Q4')),
  fiscal_year int not null check (fiscal_year between 2023 and 2030),
  remediation_status text not null check (remediation_status in ('open','in_progress','closed')),
  flagged_sites int not null check (flagged_sites >= 0),
  patient_exposure_estimate int not null check (patient_exposure_estimate >= 0),
  cost_estimate_rupees bigint not null check (cost_estimate_rupees >= 0),
  summary text not null,
  created_at timestamptz not null default now()
);

alter table endoscopy_disinfector_cycles_r3003 enable row level security;
alter table endoscopy_disinfector_spike_findings_r3003 enable row level security;

drop policy if exists cycles_r3003_founder_select on endoscopy_disinfector_cycles_r3003;
create policy cycles_r3003_founder_select on endoscopy_disinfector_cycles_r3003
  for select to authenticated using (is_founder());

drop policy if exists findings_r3003_founder_select on endoscopy_disinfector_spike_findings_r3003;
create policy findings_r3003_founder_select on endoscopy_disinfector_spike_findings_r3003
  for select to authenticated using (is_founder());

-- =========================================================
-- Seed data
-- =========================================================

insert into endoscopy_disinfector_cycles_r3003
  (chain_code, hospital_site, quarter, fiscal_year, disinfector_model, cycle_outcome, failure_mode, cycles_run, cycles_failed, spike_flag, audit_status, recorded_at)
values
  ('apollo','apollo_jubilee','Q1',2026,'aer_pro_2','pass','none',420,3,false,'closed','2026-03-30 09:00:00+05:30'::timestamptz),
  ('apollo','apollo_jubilee','Q2',2026,'aer_pro_2','fail','leak_test',410,28,true,'open','2026-06-28 10:00:00+05:30'::timestamptz),
  ('apollo','apollo_secunderabad','Q1',2026,'aer_pro_3','pass','none',380,2,false,'closed','2026-03-30 11:00:00+05:30'::timestamptz),
  ('apollo','apollo_secunderabad','Q2',2026,'aer_pro_3','fail','temperature',395,33,true,'in_progress','2026-06-28 12:00:00+05:30'::timestamptz),
  ('yashoda','yashoda_somajiguda','Q1',2026,'olympus_etd','pass','none',290,1,false,'closed','2026-03-30 13:00:00+05:30'::timestamptz),
  ('yashoda','yashoda_somajiguda','Q2',2026,'olympus_etd','fail','chemistry',310,22,true,'open','2026-06-28 14:00:00+05:30'::timestamptz),
  ('yashoda','yashoda_malakpet','Q2',2026,'olympus_etd','rerun_pass','rinse',260,18,true,'in_progress','2026-06-28 15:00:00+05:30'::timestamptz),
  ('care','care_banjara','Q1',2026,'medivators_advantage','pass','none',220,0,false,'closed','2026-03-30 16:00:00+05:30'::timestamptz),
  ('care','care_banjara','Q2',2026,'medivators_advantage','fail','leak_test',245,30,true,'open','2026-06-28 17:00:00+05:30'::timestamptz),
  ('care','care_hitec','Q2',2026,'medivators_advantage','fail','temperature',230,25,true,'open','2026-06-28 18:00:00+05:30'::timestamptz),
  ('kims','kims_kondapur','Q1',2026,'aer_pro_2','pass','none',340,4,false,'closed','2026-03-30 19:00:00+05:30'::timestamptz),
  ('kims','kims_kondapur','Q2',2026,'aer_pro_2','fail','chemistry',360,29,true,'in_progress','2026-06-28 20:00:00+05:30'::timestamptz),
  ('kims','kims_secunderabad','Q2',2026,'aer_pro_3','rerun_pass','rinse',320,15,true,'open','2026-06-28 21:00:00+05:30'::timestamptz),
  ('continental','continental_gachibowli','Q1',2026,'aer_pro_3','pass','none',270,2,false,'closed','2026-03-30 22:00:00+05:30'::timestamptz),
  ('continental','continental_gachibowli','Q2',2026,'aer_pro_3','fail','leak_test',285,21,true,'open','2026-06-28 23:00:00+05:30'::timestamptz),
  ('continental','continental_kukatpally','Q2',2026,'olympus_etd','fail','temperature',240,17,true,'in_progress','2026-06-28 08:00:00+05:30'::timestamptz),
  ('rainbow','rainbow_madhapur','Q2',2026,'medivators_advantage','rerun_pass','rinse',180,9,false,'closed','2026-06-28 09:30:00+05:30'::timestamptz),
  ('rainbow','rainbow_banjara','Q2',2026,'medivators_advantage','fail','chemistry',195,14,true,'open','2026-06-28 10:30:00+05:30'::timestamptz),
  ('aig','aig_gachibowli','Q1',2026,'olympus_etd','pass','none',510,3,false,'closed','2026-03-30 11:30:00+05:30'::timestamptz),
  ('aig','aig_gachibowli','Q2',2026,'olympus_etd','fail','leak_test',525,40,true,'open','2026-06-28 12:30:00+05:30'::timestamptz);

insert into endoscopy_disinfector_spike_findings_r3003
  (chain_code, finding_type, severity, q_period, fiscal_year, remediation_status, flagged_sites, patient_exposure_estimate, cost_estimate_rupees, summary)
values
  ('apollo','cluster_spike','high','Q2',2026,'in_progress',2,610,1800000,'leak_test fail rate jumped 9x q-o-q across 2 sites'),
  ('apollo','training_gap','medium','Q2',2026,'open',1,180,420000,'pre-cleaning bedside step skipped per logs'),
  ('yashoda','consumable_lot_defect','critical','Q2',2026,'open',2,520,2400000,'OPA lot 22A failing chemistry titration band'),
  ('yashoda','reprocessing_breach','high','Q2',2026,'in_progress',1,310,1100000,'rinse cycle abort not retried, 14 scopes shipped to wards'),
  ('care','model_recall_risk','high','Q2',2026,'open',2,440,2800000,'medivators_advantage leak_test sensor drift, vendor advisory pending'),
  ('care','training_gap','medium','Q2',2026,'open',1,150,380000,'night-shift techs not refreshed in 9 months'),
  ('kims','cluster_spike','high','Q2',2026,'in_progress',2,580,2100000,'chemistry fail spike kondapur + secunderabad on shared OPA lot'),
  ('kims','consumable_lot_defect','high','Q2',2026,'open',2,420,1450000,'OPA supplier batch quarantine recommended'),
  ('continental','model_recall_risk','medium','Q2',2026,'open',2,360,1600000,'aer_pro_3 temperature drift, post-firmware patch needed'),
  ('continental','reprocessing_breach','high','Q2',2026,'open',1,210,860000,'failed cycle bypassed and scope reused in ICU'),
  ('rainbow','cluster_spike','medium','Q2',2026,'in_progress',2,290,720000,'pediatric scope rinse aborts cluster in madhapur'),
  ('rainbow','training_gap','low','Q2',2026,'open',1,95,180000,'new hire onboarding gap on chemistry strips'),
  ('aig','model_recall_risk','critical','Q2',2026,'open',1,820,3600000,'olympus_etd leak_test 40 failures in 1 quarter — vendor escalation'),
  ('aig','consumable_lot_defect','high','Q2',2026,'in_progress',1,460,1900000,'detergent lot drift outside titration spec'),
  ('apollo','reprocessing_breach','critical','Q2',2026,'open',2,720,3100000,'2 ERCP scopes used post-failed cycle pending culture results');

-- =========================================================
-- RPCs (7) — all is_founder() gated
-- =========================================================

create or replace function r3003_chain_failure_rollup()
returns table(chain_code text, cycles_run bigint, cycles_failed bigint, fail_rate_pct numeric, spike_quarters int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.chain_code,
         sum(c.cycles_run)::bigint,
         sum(c.cycles_failed)::bigint,
         round((sum(c.cycles_failed)::numeric / nullif(sum(c.cycles_run),0)) * 100, 2),
         (count(*) filter (where c.spike_flag))::int
  from endoscopy_disinfector_cycles_r3003 c
  group by c.chain_code
  order by sum(c.cycles_failed) desc;
end; $$;

create or replace function r3003_model_failure_breakdown()
returns table(disinfector_model text, total_cycles bigint, total_failures bigint, sites_affected bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.disinfector_model,
         sum(c.cycles_run)::bigint,
         sum(c.cycles_failed)::bigint,
         count(distinct c.hospital_site)
  from endoscopy_disinfector_cycles_r3003 c
  group by c.disinfector_model
  order by sum(c.cycles_failed) desc;
end; $$;

create or replace function r3003_quarter_spike_trend()
returns table(quarter text, fiscal_year int, spikes int, failed_cycles bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.quarter, c.fiscal_year,
         (count(*) filter (where c.spike_flag))::int,
         sum(c.cycles_failed)::bigint
  from endoscopy_disinfector_cycles_r3003 c
  group by c.quarter, c.fiscal_year
  order by c.fiscal_year, c.quarter;
end; $$;

create or replace function r3003_failure_mode_pareto()
returns table(failure_mode text, occurrences int, failed_cycles bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.failure_mode,
         (count(*))::int,
         sum(c.cycles_failed)::bigint
  from endoscopy_disinfector_cycles_r3003 c
  where c.failure_mode <> 'none'
  group by c.failure_mode
  order by sum(c.cycles_failed) desc;
end; $$;

create or replace function r3003_open_findings_by_severity()
returns table(severity text, open_count int, total_cost_rupees bigint, exposed_patients bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.severity,
         (count(*) filter (where f.remediation_status in ('open','in_progress')))::int,
         sum(f.cost_estimate_rupees)::bigint,
         sum(f.patient_exposure_estimate)::bigint
  from endoscopy_disinfector_spike_findings_r3003 f
  group by f.severity
  order by case f.severity when 'critical' then 1 when 'high' then 2 when 'medium' then 3 else 4 end;
end; $$;

create or replace function r3003_top_risk_sites()
returns table(chain_code text, hospital_site text, failed_cycles bigint, fail_rate_pct numeric, audit_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.chain_code, c.hospital_site,
         sum(c.cycles_failed)::bigint,
         round((sum(c.cycles_failed)::numeric / nullif(sum(c.cycles_run),0)) * 100, 2),
         max(c.audit_status)
  from endoscopy_disinfector_cycles_r3003 c
  group by c.chain_code, c.hospital_site
  order by sum(c.cycles_failed) desc
  limit 12;
end; $$;

create or replace function r3003_finding_type_summary()
returns table(finding_type text, finding_count int, flagged_sites bigint, cost_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.finding_type,
         (count(*))::int,
         sum(f.flagged_sites)::bigint,
         sum(f.cost_estimate_rupees)::bigint
  from endoscopy_disinfector_spike_findings_r3003 f
  group by f.finding_type
  order by sum(f.cost_estimate_rupees) desc;
end; $$;

-- =========================================================
-- Grants
-- =========================================================

revoke all on function r3003_chain_failure_rollup() from public, anon;
revoke all on function r3003_model_failure_breakdown() from public, anon;
revoke all on function r3003_quarter_spike_trend() from public, anon;
revoke all on function r3003_failure_mode_pareto() from public, anon;
revoke all on function r3003_open_findings_by_severity() from public, anon;
revoke all on function r3003_top_risk_sites() from public, anon;
revoke all on function r3003_finding_type_summary() from public, anon;

grant execute on function r3003_chain_failure_rollup() to authenticated;
grant execute on function r3003_model_failure_breakdown() to authenticated;
grant execute on function r3003_quarter_spike_trend() to authenticated;
grant execute on function r3003_failure_mode_pareto() to authenticated;
grant execute on function r3003_open_findings_by_severity() to authenticated;
grant execute on function r3003_top_risk_sites() to authenticated;
grant execute on function r3003_finding_type_summary() to authenticated;
