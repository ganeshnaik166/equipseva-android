-- Round 3093: Founder Quarterly Strategic Engineer-Founder Family Office Wealth-Concentration Risk Audit

create table if not exists family_office_wealth_positions_r3093 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  quarter text not null,
  engineer_id uuid references engineers(id) on delete set null,
  holder_name text not null,
  asset_class text not null check (asset_class in ('equity_company','equity_listed','real_estate','fixed_income','cash','crypto','private_equity','other')),
  concentration_pct numeric(5,2) not null,
  position_value_rupees bigint not null,
  liquidity_tier text not null check (liquidity_tier in ('t0_cash','t1_liquid','t2_quarterly','t3_illiquid','t4_locked')),
  risk_flag text not null check (risk_flag in ('clean','watch','elevated','critical','blocker')),
  notes text
);

create table if not exists family_office_risk_audit_findings_r3093 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  quarter text not null,
  position_id uuid references family_office_wealth_positions_r3093(id) on delete cascade,
  finding_category text not null check (finding_category in ('concentration','liquidity','succession','tax','governance','counterparty','currency','regulatory')),
  severity text not null check (severity in ('p0','p1','p2','p3')),
  recommendation text not null,
  status text not null check (status in ('open','in_progress','mitigated','accepted','escalated')),
  owner_profile_id uuid references profiles(id) on delete set null,
  target_resolution_at timestamptz
);

alter table family_office_wealth_positions_r3093 enable row level security;
alter table family_office_risk_audit_findings_r3093 enable row level security;

drop policy if exists fowp_r3093_founder_all on family_office_wealth_positions_r3093;
create policy fowp_r3093_founder_all on family_office_wealth_positions_r3093 for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists forf_r3093_founder_all on family_office_risk_audit_findings_r3093;
create policy forf_r3093_founder_all on family_office_risk_audit_findings_r3093 for all to authenticated using (is_founder()) with check (is_founder());

-- Seed positions (16 rows)
insert into family_office_wealth_positions_r3093 (quarter, holder_name, asset_class, concentration_pct, position_value_rupees, liquidity_tier, risk_flag, notes) values
('2026Q2','Founder Primary','equity_company',78.50,185000000,'t4_locked','critical','EquipSeva equity dominates net worth'),
('2026Q2','Founder Primary','real_estate',8.20,19500000,'t3_illiquid','watch','Hyderabad residential'),
('2026Q2','Founder Primary','cash',2.10,5000000,'t0_cash','clean','Operating buffer'),
('2026Q2','Founder Primary','fixed_income',3.80,9000000,'t2_quarterly','clean','GoI bonds 10Y'),
('2026Q2','Founder Primary','equity_listed',4.20,9900000,'t1_liquid','clean','Nifty index fund'),
('2026Q2','Founder Primary','private_equity',1.50,3500000,'t4_locked','watch','Angel positions'),
('2026Q2','Founder Primary','crypto',0.80,1900000,'t1_liquid','elevated','BTC + ETH'),
('2026Q2','Founder Primary','other',0.90,2100000,'t3_illiquid','clean','Art + collectibles'),
('2026Q2','Founder Spouse','equity_company',0.00,0,'t4_locked','clean','No co-position'),
('2026Q2','Founder Spouse','real_estate',45.00,7500000,'t3_illiquid','watch','Inherited property'),
('2026Q2','Founder Spouse','fixed_income',30.00,5000000,'t2_quarterly','clean','PPF + EPF'),
('2026Q2','Founder Spouse','cash',25.00,4200000,'t0_cash','clean','Joint emergency fund'),
('2026Q2','Engineer Co-founder','equity_company',62.00,42000000,'t4_locked','elevated','ESOP-vested + RSUs'),
('2026Q2','Engineer Co-founder','cash',12.00,8100000,'t0_cash','clean','Liquid buffer'),
('2026Q2','Engineer Co-founder','equity_listed',18.00,12200000,'t1_liquid','clean','Mutual funds'),
('2026Q2','Engineer Co-founder','real_estate',8.00,5400000,'t3_illiquid','clean','Bangalore apt');

-- Seed findings (14 rows)
insert into family_office_risk_audit_findings_r3093 (quarter, finding_category, severity, recommendation, status, target_resolution_at) values
('2026Q2','concentration','p0','Reduce founder EquipSeva equity below 65% via secondary or ESOP buyback','open','2026-09-30'::timestamptz),
('2026Q2','liquidity','p1','Increase t0_cash buffer to 9 months personal burn','in_progress','2026-08-15'::timestamptz),
('2026Q2','succession','p1','Execute revocable trust + nominee + will registration','open','2026-07-31'::timestamptz),
('2026Q2','tax','p2','LTCG harvest before March 2027 fiscal close','open','2027-03-15'::timestamptz),
('2026Q2','governance','p1','Family office charter + IPS document','in_progress','2026-08-30'::timestamptz),
('2026Q2','counterparty','p2','Split cash across 3 scheduled banks, none >25%','open','2026-07-15'::timestamptz),
('2026Q2','currency','p3','Consider 5-10% USD exposure for hedging','accepted','2026-12-31'::timestamptz),
('2026Q2','regulatory','p2','LRS quota tracking for outbound investments','open','2026-09-01'::timestamptz),
('2026Q2','concentration','p1','Engineer co-founder equity concentration above 60% threshold','escalated','2026-09-30'::timestamptz),
('2026Q2','liquidity','p2','Crypto position elevated risk — consider partial harvest','open','2026-08-01'::timestamptz),
('2026Q2','succession','p2','Spouse asset protection structure review','open','2026-09-15'::timestamptz),
('2026Q2','tax','p3','HUF structure exploration for tax efficiency','accepted','2027-01-31'::timestamptz),
('2026Q2','governance','p2','Quarterly family office reporting cadence','mitigated','2026-06-30'::timestamptz),
('2026Q2','counterparty','p3','Insurance review — term + health + officers liability','in_progress','2026-08-15'::timestamptz);

-- RPC 1: concentration overview
create or replace function r3093_concentration_overview()
returns table(holder_name text, asset_class text, concentration_pct numeric, position_value_rupees bigint, risk_flag text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select p.holder_name, p.asset_class, p.concentration_pct, p.position_value_rupees, p.risk_flag
    from family_office_wealth_positions_r3093 p
    order by p.holder_name, p.concentration_pct desc;
end; $$;

-- RPC 2: risk flag summary
create or replace function r3093_risk_flag_summary()
returns table(risk_flag text, position_count int, total_value_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select p.risk_flag, count(*)::int, coalesce(sum(p.position_value_rupees),0)::bigint
    from family_office_wealth_positions_r3093 p
    group by p.risk_flag
    order by p.risk_flag;
end; $$;

-- RPC 3: liquidity tier breakdown
create or replace function r3093_liquidity_tier_breakdown()
returns table(liquidity_tier text, position_count int, total_value_rupees bigint, critical_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select p.liquidity_tier,
           count(*)::int,
           coalesce(sum(p.position_value_rupees),0)::bigint,
           (count(*) filter (where p.risk_flag = 'critical'))::int
    from family_office_wealth_positions_r3093 p
    group by p.liquidity_tier
    order by p.liquidity_tier;
end; $$;

-- RPC 4: findings by severity
create or replace function r3093_findings_by_severity()
returns table(severity text, open_count int, in_progress_count int, mitigated_count int, total_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select f.severity,
           (count(*) filter (where f.status = 'open'))::int,
           (count(*) filter (where f.status = 'in_progress'))::int,
           (count(*) filter (where f.status = 'mitigated'))::int,
           count(*)::int
    from family_office_risk_audit_findings_r3093 f
    group by f.severity
    order by f.severity;
end; $$;

-- RPC 5: top concentration risks
create or replace function r3093_top_concentration_risks()
returns table(holder_name text, asset_class text, concentration_pct numeric, position_value_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select p.holder_name, p.asset_class, p.concentration_pct, p.position_value_rupees
    from family_office_wealth_positions_r3093 p
    where p.concentration_pct >= 50
    order by p.concentration_pct desc;
end; $$;

-- RPC 6: open findings
create or replace function r3093_open_findings()
returns table(finding_category text, severity text, recommendation text, status text, target_resolution_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select f.finding_category, f.severity, f.recommendation, f.status, f.target_resolution_at
    from family_office_risk_audit_findings_r3093 f
    where f.status in ('open','in_progress','escalated')
    order by f.severity, f.target_resolution_at nulls last;
end; $$;

-- RPC 7: quarterly headline
create or replace function r3093_quarterly_headline()
returns table(quarter text, total_positions int, total_value_rupees bigint, critical_positions int, open_p0_p1 int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select p.quarter,
           count(*)::int,
           coalesce(sum(p.position_value_rupees),0)::bigint,
           (count(*) filter (where p.risk_flag = 'critical'))::int,
           (select (count(*) filter (where f.status in ('open','in_progress','escalated') and f.severity in ('p0','p1')))::int
              from family_office_risk_audit_findings_r3093 f where f.quarter = p.quarter)
    from family_office_wealth_positions_r3093 p
    group by p.quarter
    order by p.quarter desc;
end; $$;

-- RPC 8: category mitigation rate
create or replace function r3093_category_mitigation_rate()
returns table(finding_category text, total int, mitigated int, mitigation_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select f.finding_category,
           count(*)::int,
           (count(*) filter (where f.status = 'mitigated'))::int,
           round(100.0 * (count(*) filter (where f.status = 'mitigated'))::numeric / nullif(count(*),0), 2)
    from family_office_risk_audit_findings_r3093 f
    group by f.finding_category
    order by f.finding_category;
end; $$;

revoke all on family_office_wealth_positions_r3093 from public, anon;
revoke all on family_office_risk_audit_findings_r3093 from public, anon;
grant select, insert, update, delete on family_office_wealth_positions_r3093 to authenticated;
grant select, insert, update, delete on family_office_risk_audit_findings_r3093 to authenticated;

revoke all on function r3093_concentration_overview() from public, anon;
revoke all on function r3093_risk_flag_summary() from public, anon;
revoke all on function r3093_liquidity_tier_breakdown() from public, anon;
revoke all on function r3093_findings_by_severity() from public, anon;
revoke all on function r3093_top_concentration_risks() from public, anon;
revoke all on function r3093_open_findings() from public, anon;
revoke all on function r3093_quarterly_headline() from public, anon;
revoke all on function r3093_category_mitigation_rate() from public, anon;

grant execute on function r3093_concentration_overview() to authenticated;
grant execute on function r3093_risk_flag_summary() to authenticated;
grant execute on function r3093_liquidity_tier_breakdown() to authenticated;
grant execute on function r3093_findings_by_severity() to authenticated;
grant execute on function r3093_top_concentration_risks() to authenticated;
grant execute on function r3093_open_findings() to authenticated;
grant execute on function r3093_quarterly_headline() to authenticated;
grant execute on function r3093_category_mitigation_rate() to authenticated;
