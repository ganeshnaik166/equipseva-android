-- Round r2899 — Hospital Chain Quarterly Vendor Consolidation Savings Tracker

create table if not exists hospital_chain_consolidation_quarters_r2899 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  quarter_label text not null,
  branches_count int not null,
  vendors_before int not null,
  vendors_after int not null,
  spend_before_rupees bigint not null,
  spend_after_rupees bigint not null,
  savings_rupees bigint not null,
  savings_pct numeric(5,2) not null,
  status text not null check (status in ('planning','executing','realized','locked')),
  created_at timestamptz not null default now()
);
alter table hospital_chain_consolidation_quarters_r2899 enable row level security;

create table if not exists hospital_chain_vendor_consolidation_lines_r2899 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  branch_name text not null,
  vendor_category text not null,
  vendor_name text not null,
  monthly_spend_before_rupees bigint not null,
  monthly_spend_after_rupees bigint not null,
  monthly_savings_rupees bigint not null,
  contract_status text not null check (contract_status in ('active','negotiating','migrated','terminated')),
  migration_quarter text not null,
  created_at timestamptz not null default now()
);
alter table hospital_chain_vendor_consolidation_lines_r2899 enable row level security;

-- seed quarters (14 rows)
insert into hospital_chain_consolidation_quarters_r2899 (chain_name, quarter_label, branches_count, vendors_before, vendors_after, spend_before_rupees, spend_after_rupees, savings_rupees, savings_pct, status) values
('Apollo Hospitals','Q1-FY26',12,48,18,18500000,14200000,4300000,23.24,'realized'),
('Fortis Healthcare','Q1-FY26',9,36,14,12400000,9100000,3300000,26.61,'realized'),
('Manipal Hospitals','Q1-FY26',8,32,13,10800000,8200000,2600000,24.07,'realized'),
('Max Healthcare','Q1-FY26',7,28,11,9200000,7000000,2200000,23.91,'realized'),
('Narayana Health','Q1-FY26',6,24,10,7800000,5900000,1900000,24.36,'realized'),
('Apollo Hospitals','Q2-FY26',12,18,15,14200000,12800000,1400000,9.86,'executing'),
('Fortis Healthcare','Q2-FY26',9,14,12,9100000,8200000,900000,9.89,'executing'),
('Manipal Hospitals','Q2-FY26',8,13,11,8200000,7400000,800000,9.76,'executing'),
('Max Healthcare','Q2-FY26',7,11,9,7000000,6300000,700000,10.00,'planning'),
('Narayana Health','Q2-FY26',6,10,8,5900000,5300000,600000,10.17,'planning'),
('KIMS Hospitals','Q1-FY26',5,20,9,6500000,4900000,1600000,24.62,'realized'),
('Aster DM','Q1-FY26',4,16,7,5200000,3900000,1300000,25.00,'realized'),
('Medanta','Q1-FY26',3,12,6,4100000,3100000,1000000,24.39,'locked'),
('Yashoda Hospitals','Q1-FY26',4,16,8,5400000,4100000,1300000,24.07,'realized');

-- seed lines (24 rows)
insert into hospital_chain_vendor_consolidation_lines_r2899 (chain_name, branch_name, vendor_category, vendor_name, monthly_spend_before_rupees, monthly_spend_after_rupees, monthly_savings_rupees, contract_status, migration_quarter) values
('Apollo Hospitals','Apollo Hyderabad','Imaging AMC','Siemens India',420000,310000,110000,'migrated','Q1-FY26'),
('Apollo Hospitals','Apollo Chennai','Lab Reagents','Roche Diagnostics',380000,290000,90000,'migrated','Q1-FY26'),
('Apollo Hospitals','Apollo Bangalore','Ventilator AMC','Hamilton Medical',290000,220000,70000,'migrated','Q1-FY26'),
('Apollo Hospitals','Apollo Mumbai','Dialysis Consumables','Fresenius',340000,260000,80000,'negotiating','Q2-FY26'),
('Fortis Healthcare','Fortis Gurgaon','OT Equipment','Karl Storz',410000,310000,100000,'migrated','Q1-FY26'),
('Fortis Healthcare','Fortis Noida','Patient Monitors','Mindray',280000,210000,70000,'migrated','Q1-FY26'),
('Fortis Healthcare','Fortis Mumbai','Imaging AMC','GE Healthcare',390000,300000,90000,'negotiating','Q2-FY26'),
('Manipal Hospitals','Manipal Bangalore','Anesthesia AMC','Drager',310000,235000,75000,'migrated','Q1-FY26'),
('Manipal Hospitals','Manipal Jaipur','Lab Reagents','Beckman Coulter',270000,205000,65000,'migrated','Q1-FY26'),
('Manipal Hospitals','Manipal Pune','Cath Lab AMC','Philips Healthcare',430000,330000,100000,'negotiating','Q2-FY26'),
('Max Healthcare','Max Saket','ICU Beds AMC','Hill-Rom',220000,165000,55000,'migrated','Q1-FY26'),
('Max Healthcare','Max Patparganj','Endoscopy AMC','Olympus',310000,235000,75000,'migrated','Q1-FY26'),
('Max Healthcare','Max Vaishali','Imaging AMC','Canon Medical',360000,275000,85000,'active','Q2-FY26'),
('Narayana Health','NH Bangalore','Cardiac Consumables','Medtronic',390000,295000,95000,'migrated','Q1-FY26'),
('Narayana Health','NH Kolkata','Lab Reagents','Sysmex',260000,195000,65000,'migrated','Q1-FY26'),
('KIMS Hospitals','KIMS Secunderabad','Imaging AMC','Siemens India',340000,255000,85000,'migrated','Q1-FY26'),
('KIMS Hospitals','KIMS Kondapur','Ventilator AMC','Hamilton Medical',230000,175000,55000,'migrated','Q1-FY26'),
('Aster DM','Aster Kochi','OT Equipment','Stryker',290000,220000,70000,'migrated','Q1-FY26'),
('Aster DM','Aster Bangalore','Patient Monitors','Mindray',240000,180000,60000,'migrated','Q1-FY26'),
('Medanta','Medanta Gurgaon','Cath Lab AMC','Philips Healthcare',460000,345000,115000,'migrated','Q1-FY26'),
('Medanta','Medanta Lucknow','Imaging AMC','GE Healthcare',380000,290000,90000,'migrated','Q1-FY26'),
('Yashoda Hospitals','Yashoda Somajiguda','Imaging AMC','Siemens India',330000,250000,80000,'migrated','Q1-FY26'),
('Yashoda Hospitals','Yashoda Hitech City','Lab Reagents','Roche Diagnostics',270000,205000,65000,'migrated','Q1-FY26'),
('Yashoda Hospitals','Yashoda Malakpet','Ventilator AMC','Drager',220000,165000,55000,'negotiating','Q2-FY26');

-- RPC 1: chain rollup
create or replace function rpc_r2899_chain_rollup()
returns table(chain_name text, branches int, vendors_before bigint, vendors_after bigint, total_savings bigint, avg_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select q.chain_name, max(q.branches_count), sum(q.vendors_before)::bigint, sum(q.vendors_after)::bigint,
         sum(q.savings_rupees)::bigint, round(avg(q.savings_pct),2)
  from hospital_chain_consolidation_quarters_r2899 q
  group by q.chain_name
  order by sum(q.savings_rupees) desc;
end; $$;

-- RPC 2: quarterly summary
create or replace function rpc_r2899_quarterly_summary()
returns table(quarter_label text, chains int, total_branches bigint, total_savings bigint, avg_savings_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select q.quarter_label, count(distinct q.chain_name)::int, sum(q.branches_count)::bigint,
         sum(q.savings_rupees)::bigint, round(avg(q.savings_pct),2)
  from hospital_chain_consolidation_quarters_r2899 q
  group by q.quarter_label
  order by q.quarter_label;
end; $$;

-- RPC 3: top categories
create or replace function rpc_r2899_top_categories()
returns table(vendor_category text, lines int, monthly_savings bigint, annualized_savings bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.vendor_category, count(*)::int, sum(l.monthly_savings_rupees)::bigint, (sum(l.monthly_savings_rupees)*12)::bigint
  from hospital_chain_vendor_consolidation_lines_r2899 l
  group by l.vendor_category
  order by sum(l.monthly_savings_rupees) desc;
end; $$;

-- RPC 4: status mix
create or replace function rpc_r2899_status_mix()
returns table(status text, quarters int, savings bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select q.status, count(*)::int, sum(q.savings_rupees)::bigint
  from hospital_chain_consolidation_quarters_r2899 q
  group by q.status
  order by sum(q.savings_rupees) desc;
end; $$;

-- RPC 5: vendor migrations in flight
create or replace function rpc_r2899_migrations_in_flight()
returns table(chain_name text, branch_name text, vendor_category text, vendor_name text, monthly_savings bigint, contract_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.chain_name, l.branch_name, l.vendor_category, l.vendor_name, l.monthly_savings_rupees, l.contract_status
  from hospital_chain_vendor_consolidation_lines_r2899 l
  where l.contract_status in ('negotiating','active')
  order by l.monthly_savings_rupees desc;
end; $$;

-- RPC 6: top branches by savings
create or replace function rpc_r2899_top_branches()
returns table(chain_name text, branch_name text, lines int, monthly_savings bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.chain_name, l.branch_name, count(*)::int, sum(l.monthly_savings_rupees)::bigint
  from hospital_chain_vendor_consolidation_lines_r2899 l
  group by l.chain_name, l.branch_name
  order by sum(l.monthly_savings_rupees) desc
  limit 15;
end; $$;

-- RPC 7: kpi snapshot
create or replace function rpc_r2899_kpi_snapshot()
returns table(total_chains int, total_branches bigint, total_savings_realized bigint, total_savings_planned bigint, avg_pct numeric, vendors_eliminated bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select count(distinct q.chain_name)::int,
         sum(q.branches_count)::bigint,
         coalesce(sum(q.savings_rupees) filter (where q.status in ('realized','locked')),0)::bigint,
         coalesce(sum(q.savings_rupees) filter (where q.status in ('planning','executing')),0)::bigint,
         round(avg(q.savings_pct),2),
         coalesce(sum(q.vendors_before - q.vendors_after),0)::bigint
  from hospital_chain_consolidation_quarters_r2899 q;
end; $$;

revoke execute on function rpc_r2899_chain_rollup() from public, anon;
revoke execute on function rpc_r2899_quarterly_summary() from public, anon;
revoke execute on function rpc_r2899_top_categories() from public, anon;
revoke execute on function rpc_r2899_status_mix() from public, anon;
revoke execute on function rpc_r2899_migrations_in_flight() from public, anon;
revoke execute on function rpc_r2899_top_branches() from public, anon;
revoke execute on function rpc_r2899_kpi_snapshot() from public, anon;

grant execute on function rpc_r2899_chain_rollup() to authenticated;
grant execute on function rpc_r2899_quarterly_summary() to authenticated;
grant execute on function rpc_r2899_top_categories() to authenticated;
grant execute on function rpc_r2899_status_mix() to authenticated;
grant execute on function rpc_r2899_migrations_in_flight() to authenticated;
grant execute on function rpc_r2899_top_branches() to authenticated;
grant execute on function rpc_r2899_kpi_snapshot() to authenticated;
