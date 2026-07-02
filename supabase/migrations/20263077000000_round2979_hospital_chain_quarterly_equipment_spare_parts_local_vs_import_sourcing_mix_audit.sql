-- Round 2979: Hospital Chain Quarterly Equipment Spare-Parts Local-vs-Import Sourcing Mix Audit
-- HEAVY ★★★★ — 2 tables + 7 RPCs + seeds

create table if not exists chain_sparepart_sourcing_quarters_r2979 (
  id uuid primary key default gen_random_uuid(),
  chain_code text not null,
  chain_name text not null,
  quarter_label text not null,
  quarter_start date not null,
  quarter_end date not null,
  total_orders int not null check (total_orders >= 0),
  local_orders int not null check (local_orders >= 0),
  import_orders int not null check (import_orders >= 0),
  local_spend_rupees bigint not null check (local_spend_rupees >= 0),
  import_spend_rupees bigint not null check (import_spend_rupees >= 0),
  local_share_pct numeric(5,2) not null check (local_share_pct >= 0 and local_share_pct <= 100),
  target_local_share_pct numeric(5,2) not null check (target_local_share_pct >= 0 and target_local_share_pct <= 100),
  avg_local_lead_days numeric(6,2) not null check (avg_local_lead_days >= 0),
  avg_import_lead_days numeric(6,2) not null check (avg_import_lead_days >= 0),
  forex_impact_rupees bigint not null default 0,
  audit_status text not null check (audit_status in ('green','amber','red','review')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists chain_sparepart_sourcing_lines_r2979 (
  id uuid primary key default gen_random_uuid(),
  quarter_id uuid not null references chain_sparepart_sourcing_quarters_r2979(id) on delete cascade,
  part_category text not null,
  modality text not null,
  origin text not null check (origin in ('local','import')),
  origin_country text not null,
  unit_count int not null check (unit_count > 0),
  unit_price_rupees bigint not null check (unit_price_rupees > 0),
  lead_time_days int not null check (lead_time_days >= 0),
  defect_rate_pct numeric(5,2) not null check (defect_rate_pct >= 0 and defect_rate_pct <= 100),
  substitutable boolean not null default false,
  preferred_vendor text not null,
  risk_flag text not null check (risk_flag in ('none','single_source','sanction_risk','price_volatile','obsolete')),
  created_at timestamptz not null default now()
);

alter table chain_sparepart_sourcing_quarters_r2979 enable row level security;
alter table chain_sparepart_sourcing_lines_r2979 enable row level security;

drop policy if exists p_r2979_q_founder on chain_sparepart_sourcing_quarters_r2979;
create policy p_r2979_q_founder on chain_sparepart_sourcing_quarters_r2979
  for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists p_r2979_l_founder on chain_sparepart_sourcing_lines_r2979;
create policy p_r2979_l_founder on chain_sparepart_sourcing_lines_r2979
  for all to authenticated using (is_founder()) with check (is_founder());

-- Seeds: 18 quarters
insert into chain_sparepart_sourcing_quarters_r2979
  (chain_code, chain_name, quarter_label, quarter_start, quarter_end, total_orders, local_orders, import_orders, local_spend_rupees, import_spend_rupees, local_share_pct, target_local_share_pct, avg_local_lead_days, avg_import_lead_days, forex_impact_rupees, audit_status, notes)
values
  ('APOLLO','Apollo Hospitals','Q1 FY26','2026-04-01'::date,'2026-06-30'::date, 142, 86, 56, 4200000, 9800000, 60.56, 65.00, 4.5, 22.0, 320000, 'amber', 'CT tube imports lagging'),
  ('APOLLO','Apollo Hospitals','Q4 FY25','2026-01-01'::date,'2026-03-31'::date, 138, 78, 60, 3800000, 10500000, 56.52, 65.00, 5.1, 24.0, 410000, 'red', 'Forex spike Feb'),
  ('FORTIS','Fortis Healthcare','Q1 FY26','2026-04-01'::date,'2026-06-30'::date, 96, 70, 26, 3100000, 4200000, 72.92, 70.00, 3.8, 19.0, 120000, 'green', 'Localisation drive working'),
  ('FORTIS','Fortis Healthcare','Q4 FY25','2026-01-01'::date,'2026-03-31'::date, 92, 64, 28, 2900000, 4500000, 69.57, 70.00, 4.0, 21.0, 145000, 'amber', 'Borderline target'),
  ('MAX','Max Healthcare','Q1 FY26','2026-04-01'::date,'2026-06-30'::date, 78, 41, 37, 2200000, 6600000, 52.56, 60.00, 5.5, 26.0, 280000, 'red', 'MRI coils all imported'),
  ('MAX','Max Healthcare','Q4 FY25','2026-01-01'::date,'2026-03-31'::date, 74, 38, 36, 2050000, 6300000, 51.35, 60.00, 5.8, 27.0, 305000, 'red', 'Persistent gap'),
  ('MANIPAL','Manipal Hospitals','Q1 FY26','2026-04-01'::date,'2026-06-30'::date, 110, 74, 36, 3400000, 5500000, 67.27, 65.00, 4.2, 20.0, 180000, 'green', 'On target'),
  ('MANIPAL','Manipal Hospitals','Q4 FY25','2026-01-01'::date,'2026-03-31'::date, 108, 69, 39, 3200000, 5700000, 63.89, 65.00, 4.5, 22.0, 210000, 'amber', 'Slight slip'),
  ('NARAYANA','Narayana Health','Q1 FY26','2026-04-01'::date,'2026-06-30'::date, 88, 60, 28, 2600000, 4100000, 68.18, 70.00, 4.0, 21.0, 140000, 'amber', 'Cath lab imports'),
  ('NARAYANA','Narayana Health','Q4 FY25','2026-01-01'::date,'2026-03-31'::date, 84, 55, 29, 2400000, 4300000, 65.48, 70.00, 4.3, 22.0, 160000, 'amber', 'Catching up'),
  ('AIIMS','AIIMS Network','Q1 FY26','2026-04-01'::date,'2026-06-30'::date, 156, 105, 51, 4800000, 7900000, 67.31, 75.00, 4.8, 23.0, 250000, 'amber', 'Govt push localisation'),
  ('AIIMS','AIIMS Network','Q4 FY25','2026-01-01'::date,'2026-03-31'::date, 150, 98, 52, 4500000, 8200000, 65.33, 75.00, 5.0, 24.0, 290000, 'red', 'Below target'),
  ('MEDANTA','Medanta','Q1 FY26','2026-04-01'::date,'2026-06-30'::date, 64, 38, 26, 1900000, 4800000, 59.38, 60.00, 4.7, 25.0, 195000, 'amber', 'On edge'),
  ('MEDANTA','Medanta','Q4 FY25','2026-01-01'::date,'2026-03-31'::date, 62, 35, 27, 1800000, 5000000, 56.45, 60.00, 5.2, 26.0, 220000, 'red', 'Cardiac imports heavy'),
  ('KIMS','KIMS Hospitals','Q1 FY26','2026-04-01'::date,'2026-06-30'::date, 72, 51, 21, 2200000, 3300000, 70.83, 70.00, 3.9, 20.0, 110000, 'green', 'Steady'),
  ('KIMS','KIMS Hospitals','Q4 FY25','2026-01-01'::date,'2026-03-31'::date, 70, 47, 23, 2100000, 3500000, 67.14, 70.00, 4.1, 21.0, 125000, 'amber', 'Near target'),
  ('RAINBOW','Rainbow Childrens','Q1 FY26','2026-04-01'::date,'2026-06-30'::date, 48, 33, 15, 1400000, 2100000, 68.75, 65.00, 4.0, 19.0, 80000, 'green', 'Paediatric specialised'),
  ('RAINBOW','Rainbow Childrens','Q4 FY25','2026-01-01'::date,'2026-03-31'::date, 46, 30, 16, 1300000, 2200000, 65.22, 65.00, 4.2, 20.0, 95000, 'green', 'Hit target');

-- Seed lines (~24 rows) — reference quarters by chain+label
insert into chain_sparepart_sourcing_lines_r2979
  (quarter_id, part_category, modality, origin, origin_country, unit_count, unit_price_rupees, lead_time_days, defect_rate_pct, substitutable, preferred_vendor, risk_flag)
select q.id, x.part_category, x.modality, x.origin, x.origin_country, x.unit_count, x.unit_price_rupees, x.lead_time_days, x.defect_rate_pct, x.substitutable, x.preferred_vendor, x.risk_flag
from chain_sparepart_sourcing_quarters_r2979 q
join (values
  ('APOLLO','Q1 FY26','CT X-ray Tube','CT','import','USA', 4, 1800000, 35, 1.20, false, 'Varian','single_source'),
  ('APOLLO','Q1 FY26','HV Cable','CT','local','India', 18, 45000, 5, 0.80, true, 'Trivitron','none'),
  ('APOLLO','Q1 FY26','MRI Gradient Coil','MRI','import','Germany', 2, 2400000, 42, 0.50, false, 'Siemens','single_source'),
  ('FORTIS','Q1 FY26','Ventilator Sensor','Ventilator','local','India', 30, 12000, 3, 1.50, true, 'Skanray','none'),
  ('FORTIS','Q1 FY26','Defibrillator Battery','Defib','local','India', 22, 8500, 4, 0.90, true, 'BPL Medical','none'),
  ('FORTIS','Q1 FY26','Cath Lab Detector','Cath','import','Japan', 1, 3800000, 55, 0.30, false, 'Canon','sanction_risk'),
  ('MAX','Q1 FY26','MRI RF Coil','MRI','import','USA', 3, 1500000, 40, 0.80, false, 'GE','single_source'),
  ('MAX','Q1 FY26','Anesthesia Vaporiser','Anesthesia','import','UK', 5, 280000, 30, 1.10, true, 'Penlon','price_volatile'),
  ('MAX','Q1 FY26','Patient Monitor Probe','Monitor','local','India', 40, 6500, 2, 1.80, true, 'Nidek','none'),
  ('MANIPAL','Q1 FY26','Ultrasound Transducer','USG','local','India', 12, 95000, 6, 1.20, true, 'Sonosite India','none'),
  ('MANIPAL','Q1 FY26','C-arm Image Intensifier','C-arm','import','Germany', 1, 2100000, 38, 0.40, false, 'Ziehm','single_source'),
  ('NARAYANA','Q1 FY26','Cath Lab Catheter Set','Cath','import','Ireland', 60, 18000, 25, 0.70, true, 'Medtronic','price_volatile'),
  ('NARAYANA','Q1 FY26','ECG Lead Wires','ECG','local','India', 80, 1200, 2, 2.10, true, 'BPL Medical','none'),
  ('AIIMS','Q1 FY26','Dialysis Dialyzer','Dialysis','local','India', 200, 4500, 3, 1.40, true, 'Nipro India','none'),
  ('AIIMS','Q1 FY26','PET-CT Detector Module','PET-CT','import','Netherlands', 1, 4500000, 60, 0.20, false, 'Philips','single_source'),
  ('AIIMS','Q1 FY26','Linac Magnetron','Linac','import','UK', 2, 2800000, 50, 0.60, false, 'e2v','sanction_risk'),
  ('MEDANTA','Q1 FY26','Heart-Lung Machine Pump','Cardiac','import','Germany', 1, 3200000, 45, 0.30, false, 'Sorin','single_source'),
  ('MEDANTA','Q1 FY26','Pulse Oximeter Probe','Monitor','local','India', 50, 3200, 2, 1.60, true, 'Skanray','none'),
  ('KIMS','Q1 FY26','Endoscope Light Source','Endoscopy','local','India', 8, 145000, 7, 1.00, true, 'Trivitron','none'),
  ('KIMS','Q1 FY26','Surgical Drill Bit','Surgical','local','India', 120, 2500, 2, 1.30, true, 'Sushrut','none'),
  ('RAINBOW','Q1 FY26','Infant Incubator Sensor','NICU','local','India', 24, 8800, 4, 1.10, true, 'Phoenix Medical','none'),
  ('RAINBOW','Q1 FY26','Paediatric Ventilator Hose','Ventilator','local','India', 36, 1800, 2, 1.40, true, 'Skanray','none'),
  ('APOLLO','Q4 FY25','CT Slip Ring','CT','import','Germany', 1, 1950000, 48, 0.50, false, 'Siemens','single_source'),
  ('FORTIS','Q4 FY25','Ventilator Flow Sensor','Ventilator','local','India', 28, 11500, 3, 1.60, true, 'Skanray','none')
) as x(chain_code, quarter_label, part_category, modality, origin, origin_country, unit_count, unit_price_rupees, lead_time_days, defect_rate_pct, substitutable, preferred_vendor, risk_flag)
  on q.chain_code = x.chain_code and q.quarter_label = x.quarter_label;

-- RPC 1: chain rollup current quarter
create or replace function r2979_chain_rollup_current()
returns table (
  chain_code text,
  chain_name text,
  total_orders int,
  local_share_pct numeric,
  target_local_share_pct numeric,
  gap_pct numeric,
  forex_impact_rupees bigint,
  audit_status text
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select q.chain_code, q.chain_name, q.total_orders, q.local_share_pct,
           q.target_local_share_pct,
           (q.local_share_pct - q.target_local_share_pct)::numeric as gap_pct,
           q.forex_impact_rupees, q.audit_status
      from chain_sparepart_sourcing_quarters_r2979 q
     where q.quarter_label = 'Q1 FY26'
     order by gap_pct asc;
end $$;

-- RPC 2: quarter over quarter delta
create or replace function r2979_qoq_delta()
returns table (
  chain_code text,
  prev_share numeric,
  curr_share numeric,
  delta_pp numeric,
  trend text
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select p.chain_code,
           p.local_share_pct as prev_share,
           c.local_share_pct as curr_share,
           (c.local_share_pct - p.local_share_pct)::numeric as delta_pp,
           case when c.local_share_pct > p.local_share_pct then 'up'
                when c.local_share_pct < p.local_share_pct then 'down'
                else 'flat' end as trend
      from chain_sparepart_sourcing_quarters_r2979 p
      join chain_sparepart_sourcing_quarters_r2979 c
        on p.chain_code = c.chain_code
     where p.quarter_label = 'Q4 FY25' and c.quarter_label = 'Q1 FY26'
     order by delta_pp asc;
end $$;

-- RPC 3: import concentration risk by line
create or replace function r2979_import_risk_lines()
returns table (
  chain_code text,
  part_category text,
  origin_country text,
  unit_count int,
  unit_price_rupees bigint,
  lead_time_days int,
  risk_flag text,
  substitutable boolean
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select q.chain_code, l.part_category, l.origin_country, l.unit_count,
           l.unit_price_rupees, l.lead_time_days, l.risk_flag, l.substitutable
      from chain_sparepart_sourcing_lines_r2979 l
      join chain_sparepart_sourcing_quarters_r2979 q on q.id = l.quarter_id
     where l.origin = 'import'
       and l.risk_flag in ('single_source','sanction_risk','price_volatile')
     order by l.unit_count * l.unit_price_rupees desc;
end $$;

-- RPC 4: substitution opportunities
create or replace function r2979_substitution_opportunities()
returns table (
  chain_code text,
  part_category text,
  origin_country text,
  annualised_spend_rupees bigint,
  lead_time_days int,
  defect_rate_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select q.chain_code, l.part_category, l.origin_country,
           (l.unit_count * l.unit_price_rupees * 4)::bigint as annualised_spend_rupees,
           l.lead_time_days, l.defect_rate_pct
      from chain_sparepart_sourcing_lines_r2979 l
      join chain_sparepart_sourcing_quarters_r2979 q on q.id = l.quarter_id
     where l.origin = 'import' and l.substitutable = true
     order by annualised_spend_rupees desc;
end $$;

-- RPC 5: lead time pressure
create or replace function r2979_lead_time_pressure()
returns table (
  chain_code text,
  avg_local_lead_days numeric,
  avg_import_lead_days numeric,
  lead_gap_days numeric,
  audit_status text
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select q.chain_code, q.avg_local_lead_days, q.avg_import_lead_days,
           (q.avg_import_lead_days - q.avg_local_lead_days)::numeric as lead_gap_days,
           q.audit_status
      from chain_sparepart_sourcing_quarters_r2979 q
     where q.quarter_label = 'Q1 FY26'
     order by lead_gap_days desc;
end $$;

-- RPC 6: modality mix
create or replace function r2979_modality_mix()
returns table (
  modality text,
  local_lines int,
  import_lines int,
  local_spend_rupees bigint,
  import_spend_rupees bigint,
  local_share_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select l.modality,
           (count(*) filter (where l.origin = 'local'))::int as local_lines,
           (count(*) filter (where l.origin = 'import'))::int as import_lines,
           coalesce(sum(case when l.origin = 'local' then l.unit_count * l.unit_price_rupees else 0 end),0)::bigint as local_spend_rupees,
           coalesce(sum(case when l.origin = 'import' then l.unit_count * l.unit_price_rupees else 0 end),0)::bigint as import_spend_rupees,
           case when sum(l.unit_count * l.unit_price_rupees) > 0
                then round(100.0 * sum(case when l.origin = 'local' then l.unit_count * l.unit_price_rupees else 0 end) / sum(l.unit_count * l.unit_price_rupees), 2)
                else 0 end as local_share_pct
      from chain_sparepart_sourcing_lines_r2979 l
     group by l.modality
     order by import_spend_rupees desc;
end $$;

-- RPC 7: audit status board
create or replace function r2979_audit_board()
returns table (
  audit_status text,
  chain_count int,
  total_orders int,
  total_forex_impact_rupees bigint
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select q.audit_status,
           (count(*))::int as chain_count,
           coalesce(sum(q.total_orders),0)::int as total_orders,
           coalesce(sum(q.forex_impact_rupees),0)::bigint as total_forex_impact_rupees
      from chain_sparepart_sourcing_quarters_r2979 q
     where q.quarter_label = 'Q1 FY26'
     group by q.audit_status
     order by total_forex_impact_rupees desc;
end $$;

-- RPC 8: defect rate by origin
create or replace function r2979_defect_by_origin()
returns table (
  origin text,
  line_count int,
  avg_defect_rate_pct numeric,
  max_defect_rate_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select l.origin,
           (count(*))::int as line_count,
           round(avg(l.defect_rate_pct), 2) as avg_defect_rate_pct,
           max(l.defect_rate_pct) as max_defect_rate_pct
      from chain_sparepart_sourcing_lines_r2979 l
     group by l.origin
     order by avg_defect_rate_pct desc;
end $$;

revoke all on function r2979_chain_rollup_current() from public, anon;
revoke all on function r2979_qoq_delta() from public, anon;
revoke all on function r2979_import_risk_lines() from public, anon;
revoke all on function r2979_substitution_opportunities() from public, anon;
revoke all on function r2979_lead_time_pressure() from public, anon;
revoke all on function r2979_modality_mix() from public, anon;
revoke all on function r2979_audit_board() from public, anon;
revoke all on function r2979_defect_by_origin() from public, anon;

grant execute on function r2979_chain_rollup_current() to authenticated;
grant execute on function r2979_qoq_delta() to authenticated;
grant execute on function r2979_import_risk_lines() to authenticated;
grant execute on function r2979_substitution_opportunities() to authenticated;
grant execute on function r2979_lead_time_pressure() to authenticated;
grant execute on function r2979_modality_mix() to authenticated;
grant execute on function r2979_audit_board() to authenticated;
grant execute on function r2979_defect_by_origin() to authenticated;

revoke all on table chain_sparepart_sourcing_quarters_r2979 from public, anon;
revoke all on table chain_sparepart_sourcing_lines_r2979 from public, anon;
grant select on chain_sparepart_sourcing_quarters_r2979 to authenticated;
grant select on chain_sparepart_sourcing_lines_r2979 to authenticated;
