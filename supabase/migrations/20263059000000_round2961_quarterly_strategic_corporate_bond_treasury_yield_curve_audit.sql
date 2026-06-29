-- Round 2961: Founder Quarterly Strategic Corporate-Bond Treasury Yield Curve Audit
-- HEAVY ★★★★

create table if not exists treasury_yield_curve_points_r2961 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_quarter text not null check (audit_quarter in ('Q1_FY27','Q2_FY27','Q3_FY27','Q4_FY27','Q1_FY28')),
  curve_segment text not null check (curve_segment in ('short','mid','long','ultra_long')),
  tenor_label text not null check (tenor_label in ('3M','6M','1Y','2Y','3Y','5Y','7Y','10Y','15Y','20Y','30Y')),
  tenor_months int not null check (tenor_months between 3 and 360),
  gsec_yield_bps int not null check (gsec_yield_bps between 0 and 2000),
  aaa_corp_yield_bps int not null check (aaa_corp_yield_bps between 0 and 2500),
  spread_bps int not null check (spread_bps between -100 and 800),
  liquidity_score numeric(5,2) not null check (liquidity_score between 0 and 100),
  recommendation text not null check (recommendation in ('overweight','neutral','underweight','exit')),
  notes text
);

create table if not exists treasury_bond_holdings_r2961 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_quarter text not null check (audit_quarter in ('Q1_FY27','Q2_FY27','Q3_FY27','Q4_FY27','Q1_FY28')),
  issuer_name text not null,
  isin text not null,
  rating text not null check (rating in ('AAA','AA+','AA','AA-','A+','A')),
  sector text not null check (sector in ('psu','nbfc','banking','infra','manufacturing','sovereign')),
  face_value_lakhs numeric(12,2) not null check (face_value_lakhs > 0),
  ytm_bps int not null check (ytm_bps between 0 and 2500),
  duration_years numeric(5,2) not null check (duration_years between 0 and 30),
  maturity_date date not null,
  mark_to_market_lakhs numeric(12,2) not null,
  unrealized_pnl_lakhs numeric(12,2) not null,
  action text not null check (action in ('hold','accumulate','trim','exit','watch'))
);

alter table treasury_yield_curve_points_r2961 enable row level security;
alter table treasury_bond_holdings_r2961 enable row level security;

drop policy if exists yc_founder_r2961 on treasury_yield_curve_points_r2961;
create policy yc_founder_r2961 on treasury_yield_curve_points_r2961
  for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists bh_founder_r2961 on treasury_bond_holdings_r2961;
create policy bh_founder_r2961 on treasury_bond_holdings_r2961
  for all to authenticated using (is_founder()) with check (is_founder());

-- Seed yield curve points
insert into treasury_yield_curve_points_r2961
  (audit_quarter, curve_segment, tenor_label, tenor_months, gsec_yield_bps, aaa_corp_yield_bps, spread_bps, liquidity_score, recommendation, notes)
values
  ('Q1_FY27','short','3M',3,645,720,75,92.5,'overweight','high liquidity park'),
  ('Q1_FY27','short','6M',6,668,752,84,90.0,'overweight','tactical T-bill ladder'),
  ('Q1_FY27','short','1Y',12,685,780,95,87.5,'overweight','core short-end exposure'),
  ('Q1_FY27','mid','2Y',24,702,815,113,82.0,'neutral','rolldown candidate'),
  ('Q1_FY27','mid','3Y',36,712,840,128,78.5,'neutral','watch RBI path'),
  ('Q1_FY27','mid','5Y',60,725,872,147,72.0,'overweight','best risk-adj carry'),
  ('Q1_FY27','long','7Y',84,738,905,167,65.0,'neutral','duration spike risk'),
  ('Q1_FY27','long','10Y',120,748,938,190,58.5,'underweight','curve steepening'),
  ('Q1_FY27','long','15Y',180,762,985,223,45.0,'underweight','illiquid block'),
  ('Q2_FY27','ultra_long','20Y',240,775,1025,250,38.0,'underweight','insurance bid only'),
  ('Q2_FY27','ultra_long','30Y',360,788,1075,287,28.5,'exit','tail risk concentration'),
  ('Q2_FY27','short','3M',3,632,705,73,93.0,'overweight','rate cut priced in'),
  ('Q2_FY27','mid','5Y',60,718,860,142,73.5,'overweight','sweet spot maintained'),
  ('Q2_FY27','long','10Y',120,742,925,183,60.0,'neutral','range bound'),
  ('Q3_FY27','short','1Y',12,672,765,93,88.0,'overweight','add on dips'),
  ('Q3_FY27','mid','3Y',36,705,832,127,79.0,'overweight','rolldown attractive'),
  ('Q3_FY27','long','10Y',120,738,918,180,61.5,'neutral','hold core'),
  ('Q4_FY27','short','6M',6,655,738,83,91.0,'overweight','quarter-end park'),
  ('Q4_FY27','mid','5Y',60,712,852,140,74.0,'overweight','best in class'),
  ('Q4_FY27','ultra_long','30Y',360,782,1068,286,29.0,'exit','trim aggressively');

-- Seed bond holdings
insert into treasury_bond_holdings_r2961
  (audit_quarter, issuer_name, isin, rating, sector, face_value_lakhs, ytm_bps, duration_years, maturity_date, mark_to_market_lakhs, unrealized_pnl_lakhs, action)
values
  ('Q1_FY27','REC Limited','INE020B08AD8','AAA','psu',250.00,748,3.2,'2028-09-15'::date,253.45,3.45,'hold'),
  ('Q1_FY27','PFC','INE134E08LK5','AAA','psu',300.00,762,4.5,'2030-03-22'::date,305.20,5.20,'accumulate'),
  ('Q1_FY27','NABARD','INE261F08CB5','AAA','psu',200.00,725,2.8,'2027-11-10'::date,202.10,2.10,'hold'),
  ('Q1_FY27','HDFC Ltd','INE001A07TJ5','AAA','nbfc',150.00,785,3.5,'2029-06-30'::date,148.75,-1.25,'watch'),
  ('Q1_FY27','LIC Housing Fin','INE115A07PF7','AAA','nbfc',175.00,792,3.0,'2028-12-05'::date,176.20,1.20,'hold'),
  ('Q1_FY27','SBI Tier II','INE062A08074','AAA','banking',400.00,815,5.5,'2030-08-18'::date,395.50,-4.50,'hold'),
  ('Q1_FY27','Axis Bank AT1','INE238A08534','AA+','banking',100.00,925,4.2,'2099-12-31'::date,98.30,-1.70,'watch'),
  ('Q1_FY27','NHAI','INE906B07HM1','AAA','infra',500.00,742,6.8,'2032-04-15'::date,512.40,12.40,'hold'),
  ('Q2_FY27','IRFC','INE053F07AY3','AAA','infra',350.00,738,5.2,'2031-02-28'::date,358.75,8.75,'hold'),
  ('Q2_FY27','Power Grid','INE752E07KS5','AAA','infra',275.00,732,4.8,'2030-07-22'::date,279.50,4.50,'hold'),
  ('Q2_FY27','Bajaj Finance','INE296A07PH4','AAA','nbfc',125.00,805,2.9,'2028-05-18'::date,124.80,-0.20,'hold'),
  ('Q2_FY27','Tata Capital','INE306N07HV5','AAA','nbfc',150.00,825,3.4,'2029-01-12'::date,148.25,-1.75,'watch'),
  ('Q2_FY27','GAIL India','INE129A08020','AAA','psu',200.00,738,3.8,'2029-11-05'::date,203.50,3.50,'hold'),
  ('Q3_FY27','NTPC','INE733E08106','AAA','psu',450.00,748,5.5,'2031-09-30'::date,461.25,11.25,'accumulate'),
  ('Q3_FY27','Reliance Industries','INE002A08518','AAA','manufacturing',300.00,768,4.2,'2030-06-15'::date,302.40,2.40,'hold'),
  ('Q3_FY27','HDFC Bank Tier II','INE040A08641','AAA','banking',350.00,798,5.0,'2031-03-08'::date,348.75,-1.25,'hold'),
  ('Q3_FY27','ICICI Bank AT1','INE090A08TT0','AA+','banking',100.00,945,4.5,'2099-12-31'::date,96.80,-3.20,'trim'),
  ('Q3_FY27','GOI 7.10% 2034','IN0020230036','AAA','sovereign',1000.00,712,7.2,'2034-04-08'::date,1018.50,18.50,'accumulate'),
  ('Q4_FY27','GOI 7.18% 2037','IN0020220060','AAA','sovereign',750.00,725,9.5,'2037-08-14'::date,762.40,12.40,'hold'),
  ('Q4_FY27','Shriram Finance','INE721A07PM4','AA','nbfc',75.00,945,2.5,'2028-02-20'::date,73.50,-1.50,'trim'),
  ('Q4_FY27','Adani Ports','INE742F08379','AA+','infra',125.00,895,3.2,'2028-10-25'::date,122.75,-2.25,'watch'),
  ('Q4_FY27','L&T Finance','INE498L07992','AAA','nbfc',150.00,812,3.0,'2028-12-30'::date,150.50,0.50,'hold'),
  ('Q4_FY27','Mahindra Finance','INE774D07TT4','AAA','nbfc',125.00,825,2.8,'2028-09-18'::date,124.75,-0.25,'hold'),
  ('Q4_FY27','Cholamandalam','INE121A07PD5','AA+','nbfc',100.00,885,2.6,'2028-06-12'::date,98.50,-1.50,'watch');

revoke all on treasury_yield_curve_points_r2961 from public, anon;
revoke all on treasury_bond_holdings_r2961 from public, anon;
grant select, insert, update, delete on treasury_yield_curve_points_r2961 to authenticated;
grant select, insert, update, delete on treasury_bond_holdings_r2961 to authenticated;

-- RPC 1: curve summary by quarter
create or replace function rpc_r2961_curve_summary_by_quarter()
returns table(audit_quarter text, points int, avg_gsec_bps numeric, avg_corp_bps numeric, avg_spread_bps numeric, overweight_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select y.audit_quarter,
           count(*)::int,
           round(avg(y.gsec_yield_bps)::numeric, 1),
           round(avg(y.aaa_corp_yield_bps)::numeric, 1),
           round(avg(y.spread_bps)::numeric, 1),
           (count(*) filter (where y.recommendation = 'overweight'))::int
    from treasury_yield_curve_points_r2961 y
    group by y.audit_quarter
    order by y.audit_quarter;
end$$;

-- RPC 2: spread by segment
create or replace function rpc_r2961_spread_by_segment()
returns table(curve_segment text, points int, min_spread int, max_spread int, avg_spread numeric, avg_liquidity numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select y.curve_segment,
           count(*)::int,
           min(y.spread_bps),
           max(y.spread_bps),
           round(avg(y.spread_bps)::numeric, 1),
           round(avg(y.liquidity_score)::numeric, 2)
    from treasury_yield_curve_points_r2961 y
    group by y.curve_segment
    order by avg(y.spread_bps);
end$$;

-- RPC 3: tenor recommendations
create or replace function rpc_r2961_tenor_recommendations()
returns table(tenor_label text, tenor_months int, latest_gsec_bps int, latest_corp_bps int, latest_spread int, recommendation text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select distinct on (y.tenor_label)
           y.tenor_label, y.tenor_months, y.gsec_yield_bps, y.aaa_corp_yield_bps, y.spread_bps, y.recommendation
    from treasury_yield_curve_points_r2961 y
    order by y.tenor_label, y.created_at desc;
end$$;

-- RPC 4: holdings by sector
create or replace function rpc_r2961_holdings_by_sector()
returns table(sector text, positions int, total_face_lakhs numeric, total_mtm_lakhs numeric, total_pnl_lakhs numeric, avg_ytm_bps numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select h.sector,
           count(*)::int,
           round(sum(h.face_value_lakhs)::numeric, 2),
           round(sum(h.mark_to_market_lakhs)::numeric, 2),
           round(sum(h.unrealized_pnl_lakhs)::numeric, 2),
           round(avg(h.ytm_bps)::numeric, 1)
    from treasury_bond_holdings_r2961 h
    group by h.sector
    order by sum(h.face_value_lakhs) desc;
end$$;

-- RPC 5: holdings by rating
create or replace function rpc_r2961_holdings_by_rating()
returns table(rating text, positions int, total_face_lakhs numeric, total_pnl_lakhs numeric, avg_duration numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select h.rating,
           count(*)::int,
           round(sum(h.face_value_lakhs)::numeric, 2),
           round(sum(h.unrealized_pnl_lakhs)::numeric, 2),
           round(avg(h.duration_years)::numeric, 2)
    from treasury_bond_holdings_r2961 h
    group by h.rating
    order by h.rating;
end$$;

-- RPC 6: action breakdown
create or replace function rpc_r2961_action_breakdown()
returns table(action text, positions int, total_mtm_lakhs numeric, total_pnl_lakhs numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select h.action,
           count(*)::int,
           round(sum(h.mark_to_market_lakhs)::numeric, 2),
           round(sum(h.unrealized_pnl_lakhs)::numeric, 2)
    from treasury_bond_holdings_r2961 h
    group by h.action
    order by sum(h.mark_to_market_lakhs) desc;
end$$;

-- RPC 7: top movers (largest pnl swings)
create or replace function rpc_r2961_top_pnl_movers()
returns table(issuer_name text, rating text, sector text, face_lakhs numeric, mtm_lakhs numeric, pnl_lakhs numeric, action text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select h.issuer_name, h.rating, h.sector, h.face_value_lakhs, h.mark_to_market_lakhs, h.unrealized_pnl_lakhs, h.action
    from treasury_bond_holdings_r2961 h
    order by abs(h.unrealized_pnl_lakhs) desc
    limit 12;
end$$;

-- RPC 8: maturity ladder
create or replace function rpc_r2961_maturity_ladder()
returns table(maturity_bucket text, positions int, total_face_lakhs numeric, avg_ytm_bps numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select case
             when h.duration_years < 3 then 'short_under_3y'
             when h.duration_years < 5 then 'mid_3_to_5y'
             when h.duration_years < 7 then 'long_5_to_7y'
             else 'ultra_over_7y'
           end as maturity_bucket,
           count(*)::int,
           round(sum(h.face_value_lakhs)::numeric, 2),
           round(avg(h.ytm_bps)::numeric, 1)
    from treasury_bond_holdings_r2961 h
    group by 1
    order by 1;
end$$;

revoke all on function rpc_r2961_curve_summary_by_quarter() from public, anon;
revoke all on function rpc_r2961_spread_by_segment() from public, anon;
revoke all on function rpc_r2961_tenor_recommendations() from public, anon;
revoke all on function rpc_r2961_holdings_by_sector() from public, anon;
revoke all on function rpc_r2961_holdings_by_rating() from public, anon;
revoke all on function rpc_r2961_action_breakdown() from public, anon;
revoke all on function rpc_r2961_top_pnl_movers() from public, anon;
revoke all on function rpc_r2961_maturity_ladder() from public, anon;

grant execute on function rpc_r2961_curve_summary_by_quarter() to authenticated;
grant execute on function rpc_r2961_spread_by_segment() to authenticated;
grant execute on function rpc_r2961_tenor_recommendations() to authenticated;
grant execute on function rpc_r2961_holdings_by_sector() to authenticated;
grant execute on function rpc_r2961_holdings_by_rating() to authenticated;
grant execute on function rpc_r2961_action_breakdown() to authenticated;
grant execute on function rpc_r2961_top_pnl_movers() to authenticated;
grant execute on function rpc_r2961_maturity_ladder() to authenticated;
