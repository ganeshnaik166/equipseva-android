-- Round 2987 — Hospital Chain Quarterly Equipment OEM Warranty-Claim Recovery Velocity Audit

create table if not exists hospital_chain_oem_warranty_claims_r2987 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  oem_name text not null,
  equipment_category text not null check (equipment_category in ('imaging','ventilator','dialysis','monitoring','surgical','lab_analyzer')),
  claim_reference text not null,
  filed_at timestamptz not null,
  resolved_at timestamptz,
  status text not null check (status in ('filed','acknowledged','in_review','approved','rejected','recovered','escalated')),
  claim_amount_rupees bigint not null check (claim_amount_rupees >= 0),
  recovered_amount_rupees bigint not null default 0 check (recovered_amount_rupees >= 0),
  velocity_days int,
  quarter text not null check (quarter in ('Q1','Q2','Q3','Q4')),
  fiscal_year text not null,
  created_at timestamptz not null default now()
);

create table if not exists hospital_chain_oem_warranty_audits_r2987 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  oem_name text not null,
  audit_quarter text not null check (audit_quarter in ('Q1','Q2','Q3','Q4')),
  fiscal_year text not null,
  total_claims_filed int not null default 0 check (total_claims_filed >= 0),
  total_claims_recovered int not null default 0 check (total_claims_recovered >= 0),
  avg_velocity_days numeric(6,2),
  recovery_rate_pct numeric(5,2) check (recovery_rate_pct >= 0 and recovery_rate_pct <= 100),
  audit_grade text not null check (audit_grade in ('A','B','C','D','F')),
  audit_notes text,
  created_at timestamptz not null default now()
);

alter table hospital_chain_oem_warranty_claims_r2987 enable row level security;
alter table hospital_chain_oem_warranty_audits_r2987 enable row level security;

drop policy if exists hcoemwc_r2987_sel on hospital_chain_oem_warranty_claims_r2987;
create policy hcoemwc_r2987_sel on hospital_chain_oem_warranty_claims_r2987 for select using (is_founder());

drop policy if exists hcoemwa_r2987_sel on hospital_chain_oem_warranty_audits_r2987;
create policy hcoemwa_r2987_sel on hospital_chain_oem_warranty_audits_r2987 for select using (is_founder());

-- Seed claims (18 rows)
insert into hospital_chain_oem_warranty_claims_r2987
(chain_name, oem_name, equipment_category, claim_reference, filed_at, resolved_at, status, claim_amount_rupees, recovered_amount_rupees, velocity_days, quarter, fiscal_year)
values
('Apollo Group','Siemens Healthineers','imaging','WCR-AP-001','2026-04-05'::timestamptz,'2026-04-22'::timestamptz,'recovered',850000,850000,17,'Q1','FY27'),
('Apollo Group','GE Healthcare','ventilator','WCR-AP-002','2026-04-10'::timestamptz,'2026-05-18'::timestamptz,'recovered',420000,395000,38,'Q1','FY27'),
('Apollo Group','Philips','monitoring','WCR-AP-003','2026-05-02'::timestamptz,null,'in_review',180000,0,null,'Q1','FY27'),
('Fortis Healthcare','Siemens Healthineers','imaging','WCR-FT-001','2026-04-12'::timestamptz,'2026-04-30'::timestamptz,'recovered',1250000,1250000,18,'Q1','FY27'),
('Fortis Healthcare','Mindray','dialysis','WCR-FT-002','2026-04-20'::timestamptz,'2026-06-15'::timestamptz,'recovered',680000,610000,56,'Q1','FY27'),
('Fortis Healthcare','GE Healthcare','surgical','WCR-FT-003','2026-05-08'::timestamptz,null,'escalated',2100000,0,null,'Q1','FY27'),
('Manipal Hospitals','Philips','imaging','WCR-MN-001','2026-04-15'::timestamptz,'2026-05-02'::timestamptz,'recovered',920000,920000,17,'Q1','FY27'),
('Manipal Hospitals','Roche','lab_analyzer','WCR-MN-002','2026-04-22'::timestamptz,'2026-05-30'::timestamptz,'rejected',340000,0,38,'Q1','FY27'),
('Manipal Hospitals','GE Healthcare','ventilator','WCR-MN-003','2026-05-10'::timestamptz,'2026-05-28'::timestamptz,'recovered',510000,485000,18,'Q1','FY27'),
('Max Healthcare','Siemens Healthineers','monitoring','WCR-MX-001','2026-04-08'::timestamptz,'2026-04-25'::timestamptz,'recovered',230000,230000,17,'Q1','FY27'),
('Max Healthcare','Philips','dialysis','WCR-MX-002','2026-04-18'::timestamptz,'2026-06-20'::timestamptz,'recovered',790000,720000,63,'Q1','FY27'),
('Max Healthcare','Mindray','surgical','WCR-MX-003','2026-05-15'::timestamptz,null,'acknowledged',1450000,0,null,'Q1','FY27'),
('Narayana Health','GE Healthcare','imaging','WCR-NR-001','2026-04-11'::timestamptz,'2026-04-29'::timestamptz,'recovered',1100000,1100000,18,'Q1','FY27'),
('Narayana Health','Roche','lab_analyzer','WCR-NR-002','2026-04-25'::timestamptz,'2026-05-20'::timestamptz,'recovered',280000,260000,25,'Q1','FY27'),
('Narayana Health','Philips','ventilator','WCR-NR-003','2026-05-12'::timestamptz,null,'filed',390000,0,null,'Q1','FY27'),
('Aster DM Healthcare','Siemens Healthineers','imaging','WCR-AS-001','2026-04-14'::timestamptz,'2026-05-05'::timestamptz,'recovered',980000,950000,21,'Q1','FY27'),
('Aster DM Healthcare','Mindray','monitoring','WCR-AS-002','2026-04-28'::timestamptz,'2026-06-10'::timestamptz,'recovered',310000,285000,43,'Q1','FY27'),
('Aster DM Healthcare','GE Healthcare','dialysis','WCR-AS-003','2026-05-18'::timestamptz,null,'in_review',640000,0,null,'Q1','FY27');

-- Seed audits (12 rows)
insert into hospital_chain_oem_warranty_audits_r2987
(chain_name, oem_name, audit_quarter, fiscal_year, total_claims_filed, total_claims_recovered, avg_velocity_days, recovery_rate_pct, audit_grade, audit_notes)
values
('Apollo Group','Siemens Healthineers','Q1','FY27',8,7,19.50,87.50,'A','Fast turnaround OEM partner'),
('Apollo Group','GE Healthcare','Q1','FY27',6,4,32.20,66.67,'B','Slow on ventilator parts'),
('Apollo Group','Philips','Q1','FY27',5,3,28.40,60.00,'B','Acceptable velocity'),
('Fortis Healthcare','Siemens Healthineers','Q1','FY27',7,6,20.10,85.71,'A','Strong recovery rate'),
('Fortis Healthcare','Mindray','Q1','FY27',4,3,55.20,75.00,'C','Velocity needs improvement'),
('Fortis Healthcare','GE Healthcare','Q1','FY27',5,2,48.30,40.00,'D','Multiple escalations'),
('Manipal Hospitals','Philips','Q1','FY27',6,5,22.80,83.33,'A','Good partner'),
('Manipal Hospitals','Roche','Q1','FY27',3,1,42.10,33.33,'F','High rejection rate'),
('Max Healthcare','Siemens Healthineers','Q1','FY27',9,8,18.90,88.89,'A','Best-in-class'),
('Max Healthcare','Philips','Q1','FY27',5,4,58.40,80.00,'C','Slow dialysis claims'),
('Narayana Health','GE Healthcare','Q1','FY27',6,5,21.40,83.33,'A','Reliable OEM'),
('Aster DM Healthcare','Siemens Healthineers','Q1','FY27',7,6,23.50,85.71,'A','Strong partnership');

-- RPC 1: chain velocity summary
create or replace function founder_r2987_chain_velocity_summary()
returns table(chain_name text, claims_count int, recovered_count int, avg_velocity numeric, recovery_rate numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.chain_name,
         count(*)::int as claims_count,
         (count(*) filter (where c.status = 'recovered'))::int as recovered_count,
         round(avg(c.velocity_days) filter (where c.velocity_days is not null), 2) as avg_velocity,
         round((count(*) filter (where c.status = 'recovered'))::numeric * 100.0 / nullif(count(*),0), 2) as recovery_rate
  from hospital_chain_oem_warranty_claims_r2987 c
  group by c.chain_name
  order by recovery_rate desc nulls last;
end;
$$;

-- RPC 2: OEM scorecard
create or replace function founder_r2987_oem_scorecard()
returns table(oem_name text, total_claims int, recovered int, rejected int, escalated int, avg_velocity numeric, total_recovered_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.oem_name,
         count(*)::int,
         (count(*) filter (where c.status = 'recovered'))::int,
         (count(*) filter (where c.status = 'rejected'))::int,
         (count(*) filter (where c.status = 'escalated'))::int,
         round(avg(c.velocity_days) filter (where c.velocity_days is not null), 2),
         sum(c.recovered_amount_rupees)::bigint
  from hospital_chain_oem_warranty_claims_r2987 c
  group by c.oem_name
  order by total_recovered_rupees desc;
end;
$$;

-- RPC 3: category velocity
create or replace function founder_r2987_category_velocity()
returns table(equipment_category text, claims_count int, avg_velocity_days numeric, recovery_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.equipment_category,
         count(*)::int,
         round(avg(c.velocity_days) filter (where c.velocity_days is not null), 2),
         round((count(*) filter (where c.status = 'recovered'))::numeric * 100.0 / nullif(count(*),0), 2)
  from hospital_chain_oem_warranty_claims_r2987 c
  group by c.equipment_category
  order by avg_velocity_days nulls last;
end;
$$;

-- RPC 4: open claims aging
create or replace function founder_r2987_open_claims_aging()
returns table(claim_reference text, chain_name text, oem_name text, status text, days_open int, claim_amount_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.claim_reference, c.chain_name, c.oem_name, c.status,
         extract(day from (now() - c.filed_at))::int as days_open,
         c.claim_amount_rupees
  from hospital_chain_oem_warranty_claims_r2987 c
  where c.resolved_at is null
  order by days_open desc;
end;
$$;

-- RPC 5: recovery shortfall
create or replace function founder_r2987_recovery_shortfall()
returns table(chain_name text, oem_name text, claim_total_rupees bigint, recovered_total_rupees bigint, shortfall_rupees bigint, shortfall_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.chain_name, c.oem_name,
         sum(c.claim_amount_rupees)::bigint as claim_total_rupees,
         sum(c.recovered_amount_rupees)::bigint as recovered_total_rupees,
         (sum(c.claim_amount_rupees) - sum(c.recovered_amount_rupees))::bigint as shortfall_rupees,
         round(((sum(c.claim_amount_rupees) - sum(c.recovered_amount_rupees))::numeric * 100.0) / nullif(sum(c.claim_amount_rupees),0), 2)
  from hospital_chain_oem_warranty_claims_r2987 c
  group by c.chain_name, c.oem_name
  having sum(c.claim_amount_rupees) > sum(c.recovered_amount_rupees)
  order by shortfall_rupees desc;
end;
$$;

-- RPC 6: audit grade roll-up
create or replace function founder_r2987_audit_grade_rollup()
returns table(audit_grade text, partnership_count int, avg_recovery_rate numeric, avg_velocity_days numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.audit_grade,
         count(*)::int,
         round(avg(a.recovery_rate_pct), 2),
         round(avg(a.avg_velocity_days), 2)
  from hospital_chain_oem_warranty_audits_r2987 a
  group by a.audit_grade
  order by a.audit_grade;
end;
$$;

-- RPC 7: top recoveries
create or replace function founder_r2987_top_recoveries()
returns table(claim_reference text, chain_name text, oem_name text, equipment_category text, recovered_amount_rupees bigint, velocity_days int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.claim_reference, c.chain_name, c.oem_name, c.equipment_category, c.recovered_amount_rupees, c.velocity_days
  from hospital_chain_oem_warranty_claims_r2987 c
  where c.status = 'recovered'
  order by c.recovered_amount_rupees desc
  limit 10;
end;
$$;

revoke all on hospital_chain_oem_warranty_claims_r2987 from public, anon;
revoke all on hospital_chain_oem_warranty_audits_r2987 from public, anon;
grant select on hospital_chain_oem_warranty_claims_r2987 to authenticated;
grant select on hospital_chain_oem_warranty_audits_r2987 to authenticated;

revoke all on function founder_r2987_chain_velocity_summary() from public, anon;
revoke all on function founder_r2987_oem_scorecard() from public, anon;
revoke all on function founder_r2987_category_velocity() from public, anon;
revoke all on function founder_r2987_open_claims_aging() from public, anon;
revoke all on function founder_r2987_recovery_shortfall() from public, anon;
revoke all on function founder_r2987_audit_grade_rollup() from public, anon;
revoke all on function founder_r2987_top_recoveries() from public, anon;

grant execute on function founder_r2987_chain_velocity_summary() to authenticated;
grant execute on function founder_r2987_oem_scorecard() to authenticated;
grant execute on function founder_r2987_category_velocity() to authenticated;
grant execute on function founder_r2987_open_claims_aging() to authenticated;
grant execute on function founder_r2987_recovery_shortfall() to authenticated;
grant execute on function founder_r2987_audit_grade_rollup() to authenticated;
grant execute on function founder_r2987_top_recoveries() to authenticated;
