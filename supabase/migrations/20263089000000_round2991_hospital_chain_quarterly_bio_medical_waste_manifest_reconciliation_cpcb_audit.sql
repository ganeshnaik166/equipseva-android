-- Round r2991 — Hospital Chain Quarterly Bio-Medical Waste Manifest Reconciliation & CPCB Audit
-- HEAVY ★★★★

create table if not exists hospital_chain_bmw_manifests_r2991 (
  id uuid primary key default gen_random_uuid(),
  chain_code text not null,
  chain_name text not null,
  hospital_branch text not null,
  city text not null,
  state_code text not null,
  quarter text not null check (quarter in ('Q1','Q2','Q3','Q4')),
  fiscal_year text not null,
  manifest_no text not null,
  cpcb_form text not null check (cpcb_form in ('Form-1','Form-2','Form-3','Form-4')),
  yellow_kg numeric(10,2) not null check (yellow_kg between 0 and 50000),
  red_kg numeric(10,2) not null check (red_kg between 0 and 50000),
  white_kg numeric(10,2) not null check (white_kg between 0 and 50000),
  blue_kg numeric(10,2) not null check (blue_kg between 0 and 50000),
  total_kg numeric(10,2) not null check (total_kg between 0 and 200000),
  cbwtf_operator text not null,
  reconciliation_status text not null check (reconciliation_status in ('matched','variance','disputed','missing_collection','pending_review')),
  variance_kg numeric(10,2) not null default 0 check (variance_kg between -10000 and 10000),
  variance_pct numeric(6,2) not null default 0 check (variance_pct between -100 and 100),
  cpcb_audit_score int not null check (cpcb_audit_score between 0 and 100),
  audit_risk_band text not null check (audit_risk_band in ('green','amber','red','critical')),
  spcb_filing_deadline date not null,
  filed_at timestamptz,
  created_at timestamptz not null default now()
);
alter table hospital_chain_bmw_manifests_r2991 enable row level security;
drop policy if exists bmw_manifests_r2991_founder on hospital_chain_bmw_manifests_r2991;
create policy bmw_manifests_r2991_founder on hospital_chain_bmw_manifests_r2991 for select using (is_founder());

create table if not exists hospital_chain_bmw_audit_findings_r2991 (
  id uuid primary key default gen_random_uuid(),
  manifest_id uuid references hospital_chain_bmw_manifests_r2991(id) on delete cascade,
  chain_code text not null,
  finding_code text not null,
  finding_category text not null check (finding_category in ('segregation','documentation','transport','treatment','training','autoclave_log','barcode_scan','spcb_filing')),
  severity text not null check (severity in ('observation','minor','major','critical')),
  cpcb_rule_ref text not null,
  description text not null,
  remediation_status text not null check (remediation_status in ('open','in_progress','closed','escalated','overdue')),
  remediation_owner text not null,
  due_date date not null,
  closed_at timestamptz,
  penalty_risk_rupees int not null check (penalty_risk_rupees between 0 and 2500000),
  created_at timestamptz not null default now()
);
alter table hospital_chain_bmw_audit_findings_r2991 enable row level security;
drop policy if exists bmw_findings_r2991_founder on hospital_chain_bmw_audit_findings_r2991;
create policy bmw_findings_r2991_founder on hospital_chain_bmw_audit_findings_r2991 for select using (is_founder());

-- Seed manifests (20 rows)
insert into hospital_chain_bmw_manifests_r2991 (chain_code, chain_name, hospital_branch, city, state_code, quarter, fiscal_year, manifest_no, cpcb_form, yellow_kg, red_kg, white_kg, blue_kg, total_kg, cbwtf_operator, reconciliation_status, variance_kg, variance_pct, cpcb_audit_score, audit_risk_band, spcb_filing_deadline, filed_at) values
('APOLLO','Apollo Hospitals','Jubilee Hills','Hyderabad','TS','Q1','FY26','MN-AP-J1-0001','Form-3',1240.50,820.30,180.20,95.10,2336.10,'Maridi Eco','matched',12.10,0.52,92,'green','2026-04-30'::date,'2026-04-22'::timestamptz),
('APOLLO','Apollo Hospitals','Greams Road','Chennai','TN','Q1','FY26','MN-AP-CH-0014','Form-3',1580.20,990.40,210.50,118.20,2899.30,'Tamilnadu Waste','variance',-145.20,-4.77,78,'amber','2026-04-30'::date,'2026-04-29'::timestamptz),
('FORTIS','Fortis Healthcare','Bannerghatta','Bengaluru','KA','Q1','FY26','MN-FT-BG-0202','Form-3',880.10,610.20,140.30,72.40,1703.00,'Maridi Eco','matched',5.20,0.31,88,'green','2026-04-30'::date,'2026-04-25'::timestamptz),
('FORTIS','Fortis Healthcare','Mulund','Mumbai','MH','Q1','FY26','MN-FT-MU-0309','Form-3',1320.40,840.10,195.20,102.30,2458.00,'SMS Envoclean','disputed',-380.40,-13.39,52,'red','2026-04-30'::date,null),
('MAX','Max Healthcare','Saket','New Delhi','DL','Q1','FY26','MN-MX-SK-0451','Form-3',1450.20,920.30,210.10,108.50,2689.10,'SMS Water Grace','matched',8.30,0.31,90,'green','2026-04-30'::date,'2026-04-20'::timestamptz),
('MANIPAL','Manipal Hospitals','HAL Old Airport','Bengaluru','KA','Q1','FY26','MN-MN-HA-0511','Form-3',1180.20,750.40,170.20,88.30,2189.10,'Maridi Eco','variance',92.10,4.39,76,'amber','2026-04-30'::date,'2026-04-28'::timestamptz),
('NARAYANA','Narayana Health','Bommasandra','Bengaluru','KA','Q1','FY26','MN-NH-BM-0612','Form-3',2240.30,1380.50,310.20,158.40,4089.40,'Maridi Eco','matched',18.20,0.45,94,'green','2026-04-30'::date,'2026-04-18'::timestamptz),
('AIIMS','AIIMS New Delhi','Ansari Nagar','New Delhi','DL','Q1','FY26','MN-AI-AN-0708','Form-3',3120.40,1980.20,420.30,210.50,5731.40,'SMS Water Grace','matched',25.10,0.44,96,'green','2026-04-30'::date,'2026-04-15'::timestamptz),
('KIMS','KIMS Hospitals','Secunderabad','Hyderabad','TS','Q1','FY26','MN-KM-SC-0812','Form-3',980.30,640.10,142.20,76.30,1838.90,'Maridi Eco','missing_collection',-220.30,-10.69,48,'critical','2026-04-30'::date,null),
('CARE','Care Hospitals','Banjara Hills','Hyderabad','TS','Q1','FY26','MN-CR-BH-0902','Form-3',880.20,560.30,130.20,68.40,1639.10,'Maridi Eco','matched',6.10,0.37,86,'green','2026-04-30'::date,'2026-04-24'::timestamptz),
('APOLLO','Apollo Hospitals','Jubilee Hills','Hyderabad','TS','Q2','FY26','MN-AP-J1-0091','Form-3',1310.20,860.40,188.30,99.20,2458.10,'Maridi Eco','matched',9.40,0.38,93,'green','2026-07-30'::date,'2026-07-22'::timestamptz),
('FORTIS','Fortis Healthcare','Mulund','Mumbai','MH','Q2','FY26','MN-FT-MU-0398','Form-3',1280.30,820.20,190.40,98.10,2389.00,'SMS Envoclean','variance',-180.20,-7.01,68,'amber','2026-07-30'::date,'2026-07-29'::timestamptz),
('MAX','Max Healthcare','Patparganj','New Delhi','DL','Q2','FY26','MN-MX-PP-0511','Form-3',1090.40,720.30,162.20,82.50,2055.40,'SMS Water Grace','matched',11.20,0.55,89,'green','2026-07-30'::date,'2026-07-19'::timestamptz),
('MEDANTA','Medanta','Gurugram','Gurugram','HR','Q2','FY26','MN-MD-GR-0612','Form-3',2120.30,1340.20,290.40,148.20,3899.10,'SMS Water Grace','matched',14.20,0.36,95,'green','2026-07-30'::date,'2026-07-12'::timestamptz),
('AIIMS','AIIMS New Delhi','Ansari Nagar','New Delhi','DL','Q2','FY26','MN-AI-AN-0788','Form-3',3210.20,2010.30,430.40,215.20,5866.10,'SMS Water Grace','matched',28.20,0.48,97,'green','2026-07-30'::date,'2026-07-10'::timestamptz),
('KIMS','KIMS Hospitals','Secunderabad','Hyderabad','TS','Q2','FY26','MN-KM-SC-0892','Form-3',1010.40,650.30,148.20,79.20,1888.10,'Maridi Eco','disputed',-310.20,-14.13,42,'critical','2026-07-30'::date,null),
('CMC','CMC Vellore','Vellore Main','Vellore','TN','Q2','FY26','MN-CV-VL-0903','Form-3',2890.20,1820.30,395.20,198.40,5304.10,'Tamilnadu Waste','matched',22.30,0.42,93,'green','2026-07-30'::date,'2026-07-16'::timestamptz),
('SANKARA','Sankara Nethralaya','Nungambakkam','Chennai','TN','Q2','FY26','MN-SN-NK-1011','Form-3',420.30,280.10,68.20,38.40,807.00,'Tamilnadu Waste','pending_review',0,0,72,'amber','2026-07-30'::date,null),
('PD','PD Hinduja','Mahim','Mumbai','MH','Q2','FY26','MN-PD-MH-1108','Form-3',1280.20,820.30,182.40,96.20,2379.10,'SMS Envoclean','matched',7.40,0.31,91,'green','2026-07-30'::date,'2026-07-21'::timestamptz),
('TATA','Tata Memorial','Parel','Mumbai','MH','Q2','FY26','MN-TM-PR-1208','Form-3',2480.30,1560.40,340.20,170.50,4551.40,'SMS Envoclean','matched',19.20,0.42,96,'green','2026-07-30'::date,'2026-07-14'::timestamptz);

-- Seed findings (18 rows)
insert into hospital_chain_bmw_audit_findings_r2991 (chain_code, finding_code, finding_category, severity, cpcb_rule_ref, description, remediation_status, remediation_owner, due_date, penalty_risk_rupees) values
('FORTIS','F-001','segregation','critical','BMW Rules 2016 Sch-I','Red bag found mixed with yellow autoclave-required waste at Mulund OT block','open','Mulund Plant Manager','2026-05-15'::date,1500000),
('KIMS','F-002','autoclave_log','critical','BMW Rules 2016 R-13','Autoclave temperature log gap 14 days — sterilization unverified','escalated','KIMS Compliance Head','2026-05-10'::date,2200000),
('KIMS','F-003','spcb_filing','major','BMW Rules 2016 R-18(2)','Quarterly Form-4 not filed to TSPCB within 30 days post-quarter','in_progress','KIMS Legal','2026-05-20'::date,500000),
('APOLLO','F-004','documentation','minor','BMW Rules 2016 R-6(1)','Manifest serial gap at Jubilee Hills — MN-AP-J1-0006 missing','closed','Jubilee Compliance','2026-04-20'::date,80000),
('FORTIS','F-005','transport','major','BMW Rules 2016 R-8','CBWTF pickup delayed beyond 48h on 6 occasions in Q1','in_progress','SMS Envoclean SPOC','2026-05-25'::date,650000),
('APOLLO','F-006','barcode_scan','minor','BMW Rules 2016 R-7(3)','Barcode scanner offline for 11h in Chennai Greams — manual fallback used','closed','Greams IT','2026-04-28'::date,40000),
('MAX','F-007','training','observation','BMW Rules 2016 Sch-IV','Annual refresher training overdue for 14 housekeeping staff','open','Patparganj HR','2026-06-10'::date,150000),
('MANIPAL','F-008','segregation','major','BMW Rules 2016 Sch-I','HAL Old Airport ICU — sharps in red bag instead of white translucent','in_progress','HAL Plant','2026-05-30'::date,750000),
('FORTIS','F-009','treatment','critical','BMW Rules 2016 R-13','Mulund CBWTF treatment certificate missing for 380kg disputed pickup','open','Mulund Compliance','2026-05-12'::date,1800000),
('KIMS','F-010','documentation','critical','BMW Rules 2016 R-6','Secunderabad — manifest signature mismatch on 9 trip sheets vs CBWTF copy','escalated','KIMS Audit Lead','2026-05-08'::date,1200000),
('SANKARA','F-011','spcb_filing','major','BMW Rules 2016 R-18','TNPCB Form-4 pending — Q2 manifest data still under reconciliation','in_progress','Sankara Legal','2026-08-15'::date,400000),
('NARAYANA','F-012','autoclave_log','observation','BMW Rules 2016 R-13','Bommasandra — autoclave validation cycle log entries in Kannada only','closed','Bommasandra Plant','2026-04-30'::date,30000),
('CARE','F-013','training','minor','BMW Rules 2016 Sch-IV','Banjara Hills — needle-stick protocol drill not conducted in Q1','closed','Care HR','2026-05-05'::date,90000),
('MEDANTA','F-014','barcode_scan','observation','BMW Rules 2016 R-7','Gurugram — 3.2% scan-miss rate vs CPCB target of less than 1%','in_progress','Medanta IT','2026-08-20'::date,120000),
('CMC','F-015','transport','minor','BMW Rules 2016 R-8','Vellore — 2 trips exceeded 12h between collection and CBWTF gate-in','closed','CMC Logistics','2026-07-30'::date,70000),
('AIIMS','F-016','documentation','observation','BMW Rules 2016 R-6','Ansari Nagar — manifest digitization lag of 4 days vs 24h SLA','in_progress','AIIMS BMW Cell','2026-08-12'::date,60000),
('TATA','F-017','treatment','observation','BMW Rules 2016 R-13','Parel — incinerator stack monitoring data gap of 6h on 2026-07-09','closed','Parel EHS','2026-07-25'::date,50000),
('PD','F-018','spcb_filing','minor','BMW Rules 2016 R-18','MPCB Form-4 filed 3 days late for FY25-Q4 — written advisory received','closed','PD Legal','2026-04-10'::date,180000);

-- RPC 1: Chain-quarter portfolio
create or replace function rpc_r2991_chain_quarter_portfolio()
returns table(chain_name text, quarter text, branches int, total_kg numeric, avg_audit int, red_count int, critical_findings int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.chain_name, m.quarter,
    count(distinct m.hospital_branch)::int,
    round(sum(m.total_kg)::numeric, 2),
    avg(m.cpcb_audit_score)::int,
    (count(*) filter (where m.audit_risk_band in ('red','critical')))::int,
    coalesce((select count(*) from hospital_chain_bmw_audit_findings_r2991 f where f.chain_code = m.chain_code and f.severity = 'critical'), 0)::int
  from hospital_chain_bmw_manifests_r2991 m
  group by m.chain_name, m.quarter, m.chain_code
  order by m.chain_name, m.quarter;
end; $$;
revoke all on function rpc_r2991_chain_quarter_portfolio() from public, anon;
grant execute on function rpc_r2991_chain_quarter_portfolio() to authenticated;

-- RPC 2: Reconciliation variance leaderboard
create or replace function rpc_r2991_variance_leaderboard()
returns table(chain_name text, hospital_branch text, quarter text, total_kg numeric, variance_kg numeric, variance_pct numeric, status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.chain_name, m.hospital_branch, m.quarter, m.total_kg, m.variance_kg, m.variance_pct, m.reconciliation_status
  from hospital_chain_bmw_manifests_r2991 m
  where m.reconciliation_status <> 'matched'
  order by abs(m.variance_pct) desc nulls last
  limit 20;
end; $$;
revoke all on function rpc_r2991_variance_leaderboard() from public, anon;
grant execute on function rpc_r2991_variance_leaderboard() to authenticated;

-- RPC 3: CPCB audit risk band counts
create or replace function rpc_r2991_audit_risk_bands()
returns table(audit_risk_band text, manifests int, avg_score int, total_kg numeric, branches int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.audit_risk_band,
    count(*)::int,
    avg(m.cpcb_audit_score)::int,
    round(sum(m.total_kg)::numeric, 2),
    count(distinct m.hospital_branch)::int
  from hospital_chain_bmw_manifests_r2991 m
  group by m.audit_risk_band
  order by case m.audit_risk_band when 'critical' then 1 when 'red' then 2 when 'amber' then 3 else 4 end;
end; $$;
revoke all on function rpc_r2991_audit_risk_bands() from public, anon;
grant execute on function rpc_r2991_audit_risk_bands() to authenticated;

-- RPC 4: SPCB filing status board
create or replace function rpc_r2991_spcb_filing_board()
returns table(chain_name text, hospital_branch text, quarter text, deadline date, filed_at timestamptz, days_to_deadline int, status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.chain_name, m.hospital_branch, m.quarter, m.spcb_filing_deadline, m.filed_at,
    (m.spcb_filing_deadline - current_date)::int,
    case when m.filed_at is not null then 'filed'
         when m.spcb_filing_deadline < current_date then 'overdue'
         when m.spcb_filing_deadline - current_date <= 7 then 'due_soon'
         else 'on_track' end
  from hospital_chain_bmw_manifests_r2991 m
  order by m.spcb_filing_deadline asc;
end; $$;
revoke all on function rpc_r2991_spcb_filing_board() from public, anon;
grant execute on function rpc_r2991_spcb_filing_board() to authenticated;

-- RPC 5: Findings by category and severity
create or replace function rpc_r2991_findings_matrix()
returns table(finding_category text, observations int, minors int, majors int, criticals int, open_count int, penalty_at_risk_rupees int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.finding_category,
    (count(*) filter (where f.severity = 'observation'))::int,
    (count(*) filter (where f.severity = 'minor'))::int,
    (count(*) filter (where f.severity = 'major'))::int,
    (count(*) filter (where f.severity = 'critical'))::int,
    (count(*) filter (where f.remediation_status in ('open','in_progress','escalated','overdue')))::int,
    sum(f.penalty_risk_rupees)::int
  from hospital_chain_bmw_audit_findings_r2991 f
  group by f.finding_category
  order by sum(f.penalty_risk_rupees) desc;
end; $$;
revoke all on function rpc_r2991_findings_matrix() from public, anon;
grant execute on function rpc_r2991_findings_matrix() to authenticated;

-- RPC 6: Critical open findings list
create or replace function rpc_r2991_critical_findings()
returns table(chain_code text, finding_code text, finding_category text, severity text, description text, remediation_owner text, due_date date, penalty_risk_rupees int, remediation_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.chain_code, f.finding_code, f.finding_category, f.severity, f.description, f.remediation_owner, f.due_date, f.penalty_risk_rupees, f.remediation_status
  from hospital_chain_bmw_audit_findings_r2991 f
  where f.severity in ('critical','major') and f.remediation_status in ('open','in_progress','escalated','overdue')
  order by case f.severity when 'critical' then 1 else 2 end, f.due_date asc;
end; $$;
revoke all on function rpc_r2991_critical_findings() from public, anon;
grant execute on function rpc_r2991_critical_findings() to authenticated;

-- RPC 7: CBWTF operator performance
create or replace function rpc_r2991_cbwtf_operator_perf()
returns table(cbwtf_operator text, manifests int, total_kg numeric, avg_audit int, disputed_count int, missing_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.cbwtf_operator,
    count(*)::int,
    round(sum(m.total_kg)::numeric, 2),
    avg(m.cpcb_audit_score)::int,
    (count(*) filter (where m.reconciliation_status = 'disputed'))::int,
    (count(*) filter (where m.reconciliation_status = 'missing_collection'))::int
  from hospital_chain_bmw_manifests_r2991 m
  group by m.cbwtf_operator
  order by avg(m.cpcb_audit_score) desc;
end; $$;
revoke all on function rpc_r2991_cbwtf_operator_perf() from public, anon;
grant execute on function rpc_r2991_cbwtf_operator_perf() to authenticated;

-- RPC 8: Color-stream tonnage by state
create or replace function rpc_r2991_state_color_stream()
returns table(state_code text, manifests int, yellow_kg numeric, red_kg numeric, white_kg numeric, blue_kg numeric, total_kg numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.state_code,
    count(*)::int,
    round(sum(m.yellow_kg)::numeric, 2),
    round(sum(m.red_kg)::numeric, 2),
    round(sum(m.white_kg)::numeric, 2),
    round(sum(m.blue_kg)::numeric, 2),
    round(sum(m.total_kg)::numeric, 2)
  from hospital_chain_bmw_manifests_r2991 m
  group by m.state_code
  order by sum(m.total_kg) desc;
end; $$;
revoke all on function rpc_r2991_state_color_stream() from public, anon;
grant execute on function rpc_r2991_state_color_stream() to authenticated;