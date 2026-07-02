-- Round r3000 — Customer Monthly Engineer Hospital Surgical-Drape Burn-Test & FDA-Compliance Spot Verification
-- HEAVY ★★★★ milestone ship

create table if not exists surgical_drape_burn_tests_r3000 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid,
  engineer_user_id uuid,
  test_month date not null,
  drape_lot_code text not null,
  drape_manufacturer text not null,
  drape_material text not null check (drape_material in ('spunbond_meltblown','polypropylene','polyester','reinforced_sms','cotton_blend')),
  flame_spread_seconds numeric(6,2) not null,
  char_length_mm numeric(6,2) not null,
  afterflame_seconds numeric(6,2) not null,
  fda_class text not null check (fda_class in ('class_i','class_ii','class_iii','exempt')),
  cpsc_16cfr1610_class text not null check (cpsc_16cfr1610_class in ('class_1_normal','class_2_intermediate','class_3_rapid')),
  nfpa701_pass boolean not null default false,
  astm_f1959_pass boolean not null default false,
  test_outcome text not null check (test_outcome in ('passed','failed','marginal','retest_required')),
  remediation_required boolean not null default false,
  founder_signoff text not null check (founder_signoff in ('pending','approved','rejected','escalated')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists fda_compliance_spot_audits_r3000 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid,
  engineer_user_id uuid,
  audit_date date not null,
  device_category text not null check (device_category in ('drapes','gowns','gloves','sutures','endoscopes','ventilators','imaging')),
  udi_di text not null,
  fda_510k_number text,
  fda_pma_number text,
  ce_mark_present boolean not null default false,
  cdsco_license_number text,
  expiry_date date not null,
  sterilization_method text not null check (sterilization_method in ('eo_gas','gamma','steam','vhp','none')),
  packaging_integrity text not null check (packaging_integrity in ('intact','breached','marginal','expired_seal')),
  compliance_status text not null check (compliance_status in ('compliant','non_compliant','observation','critical_finding')),
  corrective_action_due date,
  risk_score int not null check (risk_score between 1 and 10),
  audit_outcome text not null check (audit_outcome in ('clean','minor_obs','major_obs','critical')),
  created_at timestamptz not null default now()
);

alter table surgical_drape_burn_tests_r3000 enable row level security;
alter table fda_compliance_spot_audits_r3000 enable row level security;

drop policy if exists drape_burn_founder_read on surgical_drape_burn_tests_r3000;
create policy drape_burn_founder_read on surgical_drape_burn_tests_r3000 for select to authenticated using (is_founder());

drop policy if exists fda_audit_founder_read on fda_compliance_spot_audits_r3000;
create policy fda_audit_founder_read on fda_compliance_spot_audits_r3000 for select to authenticated using (is_founder());

-- Seeds: 18 drape burn tests
insert into surgical_drape_burn_tests_r3000 (test_month, drape_lot_code, drape_manufacturer, drape_material, flame_spread_seconds, char_length_mm, afterflame_seconds, fda_class, cpsc_16cfr1610_class, nfpa701_pass, astm_f1959_pass, test_outcome, remediation_required, founder_signoff, notes) values
('2026-06-01'::date,'LOT-A-2410-001','Cardinal Health','spunbond_meltblown',12.4,38.2,1.1,'class_ii','class_1_normal',true,true,'passed',false,'approved','NFPA 701 small-scale pass'),
('2026-06-01'::date,'LOT-A-2410-002','Halyard Health','reinforced_sms',14.8,42.1,0.9,'class_ii','class_1_normal',true,true,'passed',false,'approved','Reinforced SMS, top tier'),
('2026-06-01'::date,'LOT-B-2410-003','Mölnlycke','spunbond_meltblown',8.2,55.4,2.3,'class_ii','class_2_intermediate',false,true,'marginal',true,'escalated','char length above 50mm'),
('2026-06-01'::date,'LOT-C-2410-004','3M','polypropylene',5.1,72.8,4.2,'class_i','class_3_rapid',false,false,'failed',true,'rejected','Fails NFPA + ASTM, recall lot'),
('2026-06-01'::date,'LOT-D-2410-005','Medline','reinforced_sms',13.9,40.5,1.0,'class_ii','class_1_normal',true,true,'passed',false,'approved','Clean burn profile'),
('2026-06-01'::date,'LOT-E-2410-006','Cardinal Health','polyester',9.8,48.3,1.8,'class_ii','class_1_normal',true,true,'passed',false,'approved','Polyester reinforced edge'),
('2026-06-01'::date,'LOT-F-2410-007','Local-Vendor-MH','cotton_blend',3.2,98.1,8.4,'exempt','class_3_rapid',false,false,'failed',true,'rejected','BANNED — cotton blend, rapid burn'),
('2026-06-01'::date,'LOT-G-2410-008','Halyard Health','spunbond_meltblown',11.5,39.7,1.2,'class_ii','class_1_normal',true,true,'passed',false,'approved','Within spec'),
('2026-06-01'::date,'LOT-H-2410-009','Mölnlycke','reinforced_sms',15.2,36.8,0.7,'class_ii','class_1_normal',true,true,'passed',false,'approved','Best in class burn'),
('2026-06-01'::date,'LOT-I-2410-010','Medline','spunbond_meltblown',10.3,44.2,1.5,'class_ii','class_1_normal',true,true,'passed',false,'approved','Acceptable'),
('2026-05-01'::date,'LOT-J-2409-011','Cardinal Health','spunbond_meltblown',11.8,40.1,1.3,'class_ii','class_1_normal',true,true,'passed',false,'approved','Prior month'),
('2026-05-01'::date,'LOT-K-2409-012','3M','polypropylene',6.4,68.2,3.5,'class_i','class_2_intermediate',false,true,'marginal',true,'escalated','Borderline'),
('2026-05-01'::date,'LOT-L-2409-013','Halyard Health','reinforced_sms',14.1,38.9,0.8,'class_ii','class_1_normal',true,true,'passed',false,'approved','Clean'),
('2026-05-01'::date,'LOT-M-2409-014','Local-Vendor-TN','cotton_blend',2.8,102.4,9.1,'exempt','class_3_rapid',false,false,'failed',true,'rejected','Counterfeit suspected'),
('2026-04-01'::date,'LOT-N-2408-015','Mölnlycke','spunbond_meltblown',12.9,37.6,1.0,'class_ii','class_1_normal',true,true,'passed',false,'approved','Older lot, still good'),
('2026-04-01'::date,'LOT-O-2408-016','Medline','polyester',9.2,49.8,2.0,'class_ii','class_1_normal',true,true,'passed',false,'approved','Acceptable'),
('2026-04-01'::date,'LOT-P-2408-017','Cardinal Health','reinforced_sms',13.5,41.3,1.1,'class_ii','class_1_normal',true,true,'passed',false,'approved','Standard'),
('2026-04-01'::date,'LOT-Q-2408-018','Halyard Health','spunbond_meltblown',10.8,43.5,1.6,'class_ii','class_1_normal',true,true,'retest_required',false,'pending','Re-run requested by hospital');

-- Seeds: 20 FDA spot audits
insert into fda_compliance_spot_audits_r3000 (audit_date, device_category, udi_di, fda_510k_number, fda_pma_number, ce_mark_present, cdsco_license_number, expiry_date, sterilization_method, packaging_integrity, compliance_status, corrective_action_due, risk_score, audit_outcome) values
('2026-06-15'::date,'drapes','00382903281235','K201842',null,true,'MD-15-2024-A','2027-12-31'::date,'eo_gas','intact','compliant',null,2,'clean'),
('2026-06-15'::date,'gowns','00382903281236','K198372',null,true,'MD-15-2024-B','2027-06-30'::date,'gamma','intact','compliant',null,3,'clean'),
('2026-06-15'::date,'gloves','00382903281237','K223841',null,true,'MD-15-2024-C','2026-12-31'::date,'eo_gas','intact','observation','2026-07-30'::date,5,'minor_obs'),
('2026-06-15'::date,'sutures','00382903281238',null,'P198473',true,'MD-15-2024-D','2028-03-31'::date,'gamma','intact','compliant',null,2,'clean'),
('2026-06-15'::date,'endoscopes','00382903281239','K215932',null,true,'MD-15-2024-E','2027-09-30'::date,'vhp','intact','compliant',null,4,'clean'),
('2026-06-15'::date,'drapes','00382903281240','K198421',null,false,null,'2026-08-15'::date,'eo_gas','breached','non_compliant','2026-07-15'::date,8,'major_obs'),
('2026-06-15'::date,'ventilators','00382903281241',null,'P201942',true,'MD-15-2024-F','2029-01-31'::date,'none','intact','compliant',null,3,'clean'),
('2026-06-15'::date,'imaging','00382903281242','K223741',null,true,'MD-15-2024-G','2028-06-30'::date,'none','intact','compliant',null,2,'clean'),
('2026-06-15'::date,'drapes','00382903281243',null,null,false,null,'2025-12-31'::date,'eo_gas','expired_seal','critical_finding','2026-06-22'::date,10,'critical'),
('2026-06-15'::date,'gowns','00382903281244','K215321',null,true,'MD-15-2024-H','2027-03-31'::date,'gamma','intact','compliant',null,3,'clean'),
('2026-06-15'::date,'gloves','00382903281245','K198421',null,true,null,'2026-11-30'::date,'eo_gas','marginal','observation','2026-07-30'::date,6,'minor_obs'),
('2026-06-15'::date,'sutures','00382903281246',null,'P215321',true,'MD-15-2024-I','2028-09-30'::date,'gamma','intact','compliant',null,2,'clean'),
('2026-06-15'::date,'endoscopes','00382903281247','K198321',null,true,'MD-15-2024-J','2027-12-31'::date,'vhp','intact','compliant',null,4,'clean'),
('2026-06-15'::date,'drapes','00382903281248','K201842',null,true,'MD-15-2024-K','2027-12-31'::date,'eo_gas','intact','compliant',null,2,'clean'),
('2026-06-15'::date,'gowns','00382903281249',null,null,false,null,'2026-07-15'::date,'gamma','breached','non_compliant','2026-06-30'::date,9,'major_obs'),
('2026-06-15'::date,'gloves','00382903281250','K215932',null,true,'MD-15-2024-L','2028-01-31'::date,'eo_gas','intact','compliant',null,3,'clean'),
('2026-06-15'::date,'sutures','00382903281251',null,'P198432',true,'MD-15-2024-M','2028-06-30'::date,'gamma','intact','compliant',null,2,'clean'),
('2026-06-15'::date,'imaging','00382903281252','K201842',null,true,'MD-15-2024-N','2028-12-31'::date,'none','intact','compliant',null,3,'clean'),
('2026-06-15'::date,'ventilators','00382903281253',null,'P215321',true,'MD-15-2024-O','2029-03-31'::date,'none','intact','observation','2026-08-15'::date,5,'minor_obs'),
('2026-06-15'::date,'drapes','00382903281254','K198321',null,true,'MD-15-2024-P','2027-12-31'::date,'eo_gas','intact','compliant',null,2,'clean');

-- RPC 1: monthly burn test summary
create or replace function r3000_burn_test_monthly_summary()
returns table (test_month date, total_tests int, passed int, failed int, marginal int, retest_required int, pass_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.test_month,
    count(*)::int as total_tests,
    (count(*) filter (where b.test_outcome='passed'))::int as passed,
    (count(*) filter (where b.test_outcome='failed'))::int as failed,
    (count(*) filter (where b.test_outcome='marginal'))::int as marginal,
    (count(*) filter (where b.test_outcome='retest_required'))::int as retest_required,
    round(100.0 * (count(*) filter (where b.test_outcome='passed'))::numeric / nullif(count(*),0), 2) as pass_rate_pct
  from surgical_drape_burn_tests_r3000 b
  group by b.test_month
  order by b.test_month desc;
end; $$;

-- RPC 2: failed lots needing recall
create or replace function r3000_failed_lots_recall_queue()
returns table (drape_lot_code text, drape_manufacturer text, drape_material text, flame_spread_seconds numeric, char_length_mm numeric, afterflame_seconds numeric, fda_class text, founder_signoff text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.drape_lot_code, b.drape_manufacturer, b.drape_material, b.flame_spread_seconds, b.char_length_mm, b.afterflame_seconds, b.fda_class, b.founder_signoff
  from surgical_drape_burn_tests_r3000 b
  where b.test_outcome in ('failed','marginal')
  order by b.afterflame_seconds desc, b.char_length_mm desc;
end; $$;

-- RPC 3: manufacturer pass-rate leaderboard
create or replace function r3000_manufacturer_burn_leaderboard()
returns table (drape_manufacturer text, lots_tested int, lots_passed int, lots_failed int, avg_flame_spread numeric, avg_char_length numeric, pass_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.drape_manufacturer,
    count(*)::int,
    (count(*) filter (where b.test_outcome='passed'))::int,
    (count(*) filter (where b.test_outcome='failed'))::int,
    round(avg(b.flame_spread_seconds)::numeric, 2),
    round(avg(b.char_length_mm)::numeric, 2),
    round(100.0 * (count(*) filter (where b.test_outcome='passed'))::numeric / nullif(count(*),0), 2)
  from surgical_drape_burn_tests_r3000 b
  group by b.drape_manufacturer
  order by pass_rate_pct desc nulls last;
end; $$;

-- RPC 4: FDA spot audit risk roll-up
create or replace function r3000_fda_audit_risk_summary()
returns table (device_category text, total_audited int, compliant int, non_compliant int, critical_findings int, avg_risk_score numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.device_category,
    count(*)::int,
    (count(*) filter (where a.compliance_status='compliant'))::int,
    (count(*) filter (where a.compliance_status='non_compliant'))::int,
    (count(*) filter (where a.compliance_status='critical_finding'))::int,
    round(avg(a.risk_score)::numeric, 2)
  from fda_compliance_spot_audits_r3000 a
  group by a.device_category
  order by avg_risk_score desc;
end; $$;

-- RPC 5: critical findings list (immediate action)
create or replace function r3000_critical_findings_action_list()
returns table (audit_date date, device_category text, udi_di text, packaging_integrity text, expiry_date date, corrective_action_due date, risk_score int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_date, a.device_category, a.udi_di, a.packaging_integrity, a.expiry_date, a.corrective_action_due, a.risk_score
  from fda_compliance_spot_audits_r3000 a
  where a.audit_outcome in ('critical','major_obs')
  order by a.risk_score desc, a.corrective_action_due asc nulls last;
end; $$;

-- RPC 6: expiry watch (90 days)
create or replace function r3000_expiry_watch_90d()
returns table (device_category text, udi_di text, expiry_date date, days_to_expiry int, sterilization_method text, compliance_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.device_category, a.udi_di, a.expiry_date,
    (a.expiry_date - current_date)::int as days_to_expiry,
    a.sterilization_method, a.compliance_status
  from fda_compliance_spot_audits_r3000 a
  where a.expiry_date <= current_date + interval '90 days'
  order by a.expiry_date asc;
end; $$;

-- RPC 7: material burn-test deep dive
create or replace function r3000_material_burn_deep_dive()
returns table (drape_material text, lots_tested int, avg_flame_spread numeric, avg_char_length numeric, avg_afterflame numeric, nfpa701_pass_pct numeric, astm_f1959_pass_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.drape_material,
    count(*)::int,
    round(avg(b.flame_spread_seconds)::numeric, 2),
    round(avg(b.char_length_mm)::numeric, 2),
    round(avg(b.afterflame_seconds)::numeric, 2),
    round(100.0 * (count(*) filter (where b.nfpa701_pass))::numeric / nullif(count(*),0), 2),
    round(100.0 * (count(*) filter (where b.astm_f1959_pass))::numeric / nullif(count(*),0), 2)
  from surgical_drape_burn_tests_r3000 b
  group by b.drape_material
  order by avg_afterflame desc;
end; $$;

-- RPC 8 (bonus): founder signoff queue
create or replace function r3000_founder_signoff_queue()
returns table (drape_lot_code text, drape_manufacturer text, test_outcome text, founder_signoff text, remediation_required boolean, test_month date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.drape_lot_code, b.drape_manufacturer, b.test_outcome, b.founder_signoff, b.remediation_required, b.test_month
  from surgical_drape_burn_tests_r3000 b
  where b.founder_signoff in ('pending','escalated')
  order by b.test_month desc;
end; $$;

revoke all on function r3000_burn_test_monthly_summary() from public, anon;
revoke all on function r3000_failed_lots_recall_queue() from public, anon;
revoke all on function r3000_manufacturer_burn_leaderboard() from public, anon;
revoke all on function r3000_fda_audit_risk_summary() from public, anon;
revoke all on function r3000_critical_findings_action_list() from public, anon;
revoke all on function r3000_expiry_watch_90d() from public, anon;
revoke all on function r3000_material_burn_deep_dive() from public, anon;
revoke all on function r3000_founder_signoff_queue() from public, anon;

grant execute on function r3000_burn_test_monthly_summary() to authenticated;
grant execute on function r3000_failed_lots_recall_queue() to authenticated;
grant execute on function r3000_manufacturer_burn_leaderboard() to authenticated;
grant execute on function r3000_fda_audit_risk_summary() to authenticated;
grant execute on function r3000_critical_findings_action_list() to authenticated;
grant execute on function r3000_expiry_watch_90d() to authenticated;
grant execute on function r3000_material_burn_deep_dive() to authenticated;
grant execute on function r3000_founder_signoff_queue() to authenticated;
