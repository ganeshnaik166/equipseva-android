-- Round 3035 — Hospital Chain Quarterly Surgical-Instrument Sterilization Wrapper Integrity Audit
-- 2 tables + 7 RPCs (is_founder gated) + seed rows

create table if not exists hospital_chain_wrapper_audits_r3035 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  hospital_unit text not null,
  quarter text not null check (quarter in ('Q1','Q2','Q3','Q4')),
  fiscal_year text not null,
  wrappers_inspected int,
  wrappers_failed int not null,
  failure_mode text check (failure_mode in ('tear','moisture','seal_break','indicator_fail','expiry','contamination','none')),
  csr_room_grade text check (csr_room_grade in ('A','B','C','D')),
  autoclave_serial text,
  bowie_dick_result text check (bowie_dick_result in ('pass','fail','not_run')),
  biological_indicator_result text check (biological_indicator_result in ('pass','fail','pending')),
  re_sterilization_required boolean default false,
  audit_status text not null check (audit_status in ('scheduled','in_progress','completed','escalated','closed')),
  auditor_name text,
  audited_at timestamptz,
  nabh_compliance_pct numeric,
  remarks text,
  created_at timestamptz default now()
);

alter table hospital_chain_wrapper_audits_r3035 enable row level security;

drop policy if exists wrapper_audits_r3035_founder_select on hospital_chain_wrapper_audits_r3035;
create policy wrapper_audits_r3035_founder_select on hospital_chain_wrapper_audits_r3035
  for select using (is_founder());

create table if not exists wrapper_audit_corrective_actions_r3035 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid references hospital_chain_wrapper_audits_r3035(id) on delete cascade,
  action_code text not null,
  action_description text not null,
  severity text not null check (severity in ('low','medium','high','critical')),
  owner_role text check (owner_role in ('csr_supervisor','infection_control','biomedical','hospital_admin','vendor')),
  due_date date,
  closed_at timestamptz,
  status text not null check (status in ('open','in_progress','blocked','closed','verified')),
  cost_rupees numeric,
  evidence_url text,
  verified_by text,
  created_at timestamptz default now()
);

alter table wrapper_audit_corrective_actions_r3035 enable row level security;

drop policy if exists wrapper_actions_r3035_founder_select on wrapper_audit_corrective_actions_r3035;
create policy wrapper_actions_r3035_founder_select on wrapper_audit_corrective_actions_r3035
  for select using (is_founder());

-- Seed 18 audits
insert into hospital_chain_wrapper_audits_r3035
  (chain_name, hospital_unit, quarter, fiscal_year, wrappers_inspected, wrappers_failed, failure_mode, csr_room_grade, autoclave_serial, bowie_dick_result, biological_indicator_result, re_sterilization_required, audit_status, auditor_name, audited_at, nabh_compliance_pct, remarks)
select 'Apollo','Hyderabad Jubilee','Q1','FY26',420,8,'tear','A','AC-APL-001','pass','pass',true,'completed','Dr Rao','2026-04-12'::timestamptz,98.1,'minor tear lot'
union all select 'Apollo','Chennai Greams','Q1','FY26',380,3,'seal_break','A','AC-APL-002','pass','pass',false,'completed','Dr Iyer','2026-04-14'::timestamptz,99.2,null
union all select 'Fortis','Mumbai Mulund','Q1','FY26',510,22,'moisture','B','AC-FOR-101','fail','pass',true,'escalated','Dr Shah','2026-04-18'::timestamptz,91.5,'autoclave drying cycle short'
union all select 'Fortis','Delhi Vasant Kunj','Q1','FY26',460,11,'indicator_fail','A','AC-FOR-102','pass','pass',true,'completed','Dr Khan','2026-04-20'::timestamptz,96.4,null
union all select 'Manipal','Bangalore HAL','Q1','FY26',390,5,'tear','A','AC-MAN-201','pass','pass',false,'completed','Dr Nair','2026-04-22'::timestamptz,98.7,null
union all select 'Manipal','Vijayawada','Q1','FY26',280,18,'contamination','C','AC-MAN-202','fail','fail',true,'escalated','Dr Reddy','2026-04-25'::timestamptz,87.2,'CSR ventilation issue'
union all select 'Max','Saket','Q2','FY26',520,4,'none','A','AC-MAX-301','pass','pass',false,'completed','Dr Bose','2026-07-10'::timestamptz,99.6,null
union all select 'Max','Patparganj','Q2','FY26',410,9,'expiry','B','AC-MAX-302','pass','pending',true,'in_progress','Dr Verma','2026-07-12'::timestamptz,95.1,'expired stock rotation'
union all select 'Narayana','Bommasandra','Q2','FY26',600,14,'seal_break','A','AC-NAR-401','pass','pass',true,'completed','Dr Krishnan','2026-07-15'::timestamptz,97.0,null
union all select 'Narayana','Howrah','Q2','FY26',330,21,'moisture','C','AC-NAR-402','fail','pass',true,'escalated','Dr Sen','2026-07-17'::timestamptz,89.4,'monsoon humidity'
union all select 'Medanta','Gurugram','Q2','FY26',480,6,'tear','A','AC-MED-501','pass','pass',false,'completed','Dr Trehan','2026-07-19'::timestamptz,98.3,null
union all select 'Medanta','Lucknow','Q2','FY26',290,12,'indicator_fail','B','AC-MED-502','pass','fail',true,'in_progress','Dr Singh','2026-07-21'::timestamptz,94.2,'TST strip lot recall'
union all select 'AIIMS','New Delhi','Q3','FY26',720,16,'tear','A','AC-AII-601','pass','pass',true,'completed','Dr Guleria','2026-10-08'::timestamptz,97.8,null
union all select 'AIIMS','Jodhpur','Q3','FY26',410,25,'contamination','C','AC-AII-602','fail','fail',true,'escalated','Dr Misra','2026-10-10'::timestamptz,86.5,'water quality fail'
union all select 'KIMS','Secunderabad','Q3','FY26',380,7,'seal_break','A','AC-KIM-701','pass','pass',false,'completed','Dr Bhupal','2026-10-12'::timestamptz,98.0,null
union all select 'KIMS','Kondapur','Q3','FY26',310,4,'none','A','AC-KIM-702','pass','pass',false,'closed','Dr Bhupal','2026-10-14'::timestamptz,99.4,null
union all select 'Yashoda','Somajiguda','Q3','FY26',350,19,'moisture','B','AC-YAS-801','fail','pass',true,'escalated','Dr Mohan','2026-10-16'::timestamptz,90.1,'steam quality'
union all select 'Yashoda','Malakpet','Q3','FY26',null::int,0,'none','D','AC-YAS-802','not_run','pending',false,'scheduled',null,null::timestamptz,null,'audit scheduled';

-- Wait — wrappers_inspected is NOT NULL. Fix last row.
update hospital_chain_wrapper_audits_r3035 set wrappers_inspected = 0 where wrappers_inspected is null;

-- Seed 22 corrective actions
insert into wrapper_audit_corrective_actions_r3035
  (audit_id, action_code, action_description, severity, owner_role, due_date, closed_at, status, cost_rupees, evidence_url, verified_by)
select id,'CA-001','Replace defective wrapper lot batch L-2204','high','csr_supervisor','2026-05-15'::date,'2026-05-10'::timestamptz,'closed',24500,'https://ev/ca001','Dr Rao' from hospital_chain_wrapper_audits_r3035 where chain_name='Apollo' and hospital_unit='Hyderabad Jubilee'
union all select id,'CA-002','Recalibrate autoclave drying cycle','critical','biomedical','2026-05-20'::date,null::timestamptz,'in_progress',180000,null,null from hospital_chain_wrapper_audits_r3035 where chain_name='Fortis' and hospital_unit='Mumbai Mulund'
union all select id,'CA-003','Retrain CSR staff on wrap technique','medium','infection_control','2026-05-25'::date,'2026-05-22'::timestamptz,'verified',12000,'https://ev/ca003','Dr Khan' from hospital_chain_wrapper_audits_r3035 where chain_name='Fortis' and hospital_unit='Delhi Vasant Kunj'
union all select id,'CA-004','Audit HVAC HEPA filter CSR room','high','hospital_admin','2026-05-30'::date,null::timestamptz,'open',95000,null,null from hospital_chain_wrapper_audits_r3035 where chain_name='Manipal' and hospital_unit='Vijayawada'
union all select id,'CA-005','Replace expired indicator strips','low','csr_supervisor','2026-08-12'::date,'2026-08-10'::timestamptz,'closed',3200,'https://ev/ca005','Dr Verma' from hospital_chain_wrapper_audits_r3035 where chain_name='Max' and hospital_unit='Patparganj'
union all select id,'CA-006','Install dehumidifier CSR','high','biomedical','2026-08-20'::date,null::timestamptz,'blocked',220000,null,null from hospital_chain_wrapper_audits_r3035 where chain_name='Narayana' and hospital_unit='Howrah'
union all select id,'CA-007','TST strip lot recall and replace','critical','vendor','2026-08-25'::date,'2026-08-23'::timestamptz,'closed',45000,'https://ev/ca007','Dr Singh' from hospital_chain_wrapper_audits_r3035 where chain_name='Medanta' and hospital_unit='Lucknow'
union all select id,'CA-008','Water RO system replacement','critical','biomedical','2026-11-10'::date,null::timestamptz,'in_progress',650000,null,null from hospital_chain_wrapper_audits_r3035 where chain_name='AIIMS' and hospital_unit='Jodhpur'
union all select id,'CA-009','SOP revision sterile barrier','medium','infection_control','2026-11-15'::date,'2026-11-12'::timestamptz,'verified',8000,'https://ev/ca009','Dr Bhupal' from hospital_chain_wrapper_audits_r3035 where chain_name='KIMS' and hospital_unit='Secunderabad'
union all select id,'CA-010','Steam line trap replacement','high','biomedical','2026-11-20'::date,null::timestamptz,'open',75000,null,null from hospital_chain_wrapper_audits_r3035 where chain_name='Yashoda' and hospital_unit='Somajiguda'
union all select id,'CA-011','Vendor wrapper quality audit','medium','vendor','2026-05-18'::date,null::timestamptz,'in_progress',null,null,null from hospital_chain_wrapper_audits_r3035 where chain_name='Apollo' and hospital_unit='Hyderabad Jubilee'
union all select id,'CA-012','Bowie Dick test daily mandate','low','csr_supervisor','2026-05-22'::date,'2026-05-20'::timestamptz,'closed',null,null,'Dr Shah' from hospital_chain_wrapper_audits_r3035 where chain_name='Fortis' and hospital_unit='Mumbai Mulund'
union all select id,'CA-013','BI incubator replacement','medium','biomedical','2026-08-15'::date,null::timestamptz,'open',55000,null,null from hospital_chain_wrapper_audits_r3035 where chain_name='Medanta' and hospital_unit='Lucknow'
union all select id,'CA-014','CSR pass-box airflow validation','high','biomedical','2026-11-08'::date,'2026-11-05'::timestamptz,'verified',32000,'https://ev/ca014','Dr Misra' from hospital_chain_wrapper_audits_r3035 where chain_name='AIIMS' and hospital_unit='Jodhpur'
union all select id,'CA-015','Wrap-pack expiry sticker upgrade','low','csr_supervisor','2026-08-30'::date,null::timestamptz,'in_progress',5500,null,null from hospital_chain_wrapper_audits_r3035 where chain_name='Max' and hospital_unit='Patparganj'
union all select id,'CA-016','Monsoon humidity SOP','medium','infection_control','2026-08-18'::date,'2026-08-16'::timestamptz,'closed',null,'https://ev/ca016','Dr Sen' from hospital_chain_wrapper_audits_r3035 where chain_name='Narayana' and hospital_unit='Howrah'
union all select id,'CA-017','CSR room A grade re-certification','high','hospital_admin','2026-05-28'::date,null::timestamptz,'open',null,null,null from hospital_chain_wrapper_audits_r3035 where chain_name='Manipal' and hospital_unit='Vijayawada'
union all select id,'CA-018','NABH evidence pack upload','low','hospital_admin','2026-05-12'::date,'2026-05-10'::timestamptz,'verified',null,'https://ev/ca018','Dr Iyer' from hospital_chain_wrapper_audits_r3035 where chain_name='Apollo' and hospital_unit='Chennai Greams'
union all select id,'CA-019','Engineer dispatch quote','medium','vendor','2026-11-25'::date,null::timestamptz,'blocked',null,null,null from hospital_chain_wrapper_audits_r3035 where chain_name='Yashoda' and hospital_unit='Somajiguda'
union all select id,'CA-020','SOP refresher town hall','low','infection_control','2026-11-30'::date,'2026-11-28'::timestamptz,'closed',15000,'https://ev/ca020','Dr Mohan' from hospital_chain_wrapper_audits_r3035 where chain_name='AIIMS' and hospital_unit='New Delhi'
union all select id,'CA-021','Sterile storage rack replacement','medium','hospital_admin','2026-08-10'::date,null::timestamptz,'in_progress',42000,null,null from hospital_chain_wrapper_audits_r3035 where chain_name='Narayana' and hospital_unit='Bommasandra'
union all select id,'CA-022','Annual external audit booking','low','hospital_admin','2026-11-29'::date,null::timestamptz,'open',null,null,null from hospital_chain_wrapper_audits_r3035 where chain_name='KIMS' and hospital_unit='Kondapur';

-- RPC 1
create or replace function r3035_chain_failure_summary()
returns table(chain_name text, audits int, wrappers_inspected bigint, wrappers_failed bigint, failure_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.chain_name,
           count(*)::int as audits,
           sum(a.wrappers_inspected)::bigint,
           sum(a.wrappers_failed)::bigint,
           round( (sum(a.wrappers_failed)::numeric / nullif(sum(a.wrappers_inspected),0)::numeric) * 100, 2) as failure_rate_pct
    from hospital_chain_wrapper_audits_r3035 a
    group by a.chain_name
    order by failure_rate_pct desc nulls last;
end; $$;

-- RPC 2
create or replace function r3035_quarter_status_breakdown()
returns table(quarter text, fiscal_year text, completed int, escalated int, in_progress int, scheduled int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.quarter, a.fiscal_year,
      (count(*) filter (where a.audit_status='completed'))::int,
      (count(*) filter (where a.audit_status='escalated'))::int,
      (count(*) filter (where a.audit_status='in_progress'))::int,
      (count(*) filter (where a.audit_status='scheduled'))::int
    from hospital_chain_wrapper_audits_r3035 a
    group by a.quarter, a.fiscal_year
    order by a.fiscal_year, a.quarter;
end; $$;

-- RPC 3
create or replace function r3035_failure_mode_distribution()
returns table(failure_mode text, occurrences int, total_failed bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select coalesce(a.failure_mode,'unknown') as failure_mode,
           count(*)::int as occurrences,
           sum(a.wrappers_failed)::bigint
    from hospital_chain_wrapper_audits_r3035 a
    group by a.failure_mode
    order by total_failed desc nulls last;
end; $$;

-- RPC 4
create or replace function r3035_escalated_audits()
returns table(chain_name text, hospital_unit text, quarter text, failure_mode text, nabh_compliance_pct numeric, auditor_name text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.chain_name, a.hospital_unit, a.quarter, a.failure_mode, a.nabh_compliance_pct, a.auditor_name
    from hospital_chain_wrapper_audits_r3035 a
    where a.audit_status = 'escalated'
    order by a.nabh_compliance_pct asc nulls last;
end; $$;

-- RPC 5
create or replace function r3035_corrective_action_status()
returns table(status text, total int, critical_count int, high_count int, total_cost_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.status,
           count(*)::int as total,
           (count(*) filter (where c.severity='critical'))::int,
           (count(*) filter (where c.severity='high'))::int,
           coalesce(sum(c.cost_rupees),0)::numeric
    from wrapper_audit_corrective_actions_r3035 c
    group by c.status
    order by total desc;
end; $$;

-- RPC 6
create or replace function r3035_overdue_actions()
returns table(action_code text, action_description text, severity text, owner_role text, due_date date, status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.action_code, c.action_description, c.severity, c.owner_role, c.due_date, c.status
    from wrapper_audit_corrective_actions_r3035 c
    where c.status in ('open','in_progress','blocked')
      and c.due_date < current_date
    order by c.due_date asc;
end; $$;

-- RPC 7
create or replace function r3035_nabh_low_compliance()
returns table(chain_name text, hospital_unit text, quarter text, nabh_compliance_pct numeric, csr_room_grade text, bowie_dick_result text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.chain_name, a.hospital_unit, a.quarter, a.nabh_compliance_pct, a.csr_room_grade, a.bowie_dick_result
    from hospital_chain_wrapper_audits_r3035 a
    where a.nabh_compliance_pct is not null
      and a.nabh_compliance_pct < 95
    order by a.nabh_compliance_pct asc;
end; $$;

revoke all on function r3035_chain_failure_summary() from public, anon;
revoke all on function r3035_quarter_status_breakdown() from public, anon;
revoke all on function r3035_failure_mode_distribution() from public, anon;
revoke all on function r3035_escalated_audits() from public, anon;
revoke all on function r3035_corrective_action_status() from public, anon;
revoke all on function r3035_overdue_actions() from public, anon;
revoke all on function r3035_nabh_low_compliance() from public, anon;

grant execute on function r3035_chain_failure_summary() to authenticated;
grant execute on function r3035_quarter_status_breakdown() to authenticated;
grant execute on function r3035_failure_mode_distribution() to authenticated;
grant execute on function r3035_escalated_audits() to authenticated;
grant execute on function r3035_corrective_action_status() to authenticated;
grant execute on function r3035_overdue_actions() to authenticated;
grant execute on function r3035_nabh_low_compliance() to authenticated;
