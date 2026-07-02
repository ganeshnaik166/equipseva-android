-- Round 2953: Founder Quarterly Strategic India HQ Office Real-Estate Lease Renewal Audit
-- HEAVY ★★★★

create table if not exists hq_lease_renewal_candidates_r2953 (
  id uuid primary key default gen_random_uuid(),
  property_code text not null unique,
  property_name text not null,
  city text not null check (city in ('Hyderabad','Bengaluru','Mumbai','Delhi NCR','Chennai','Pune')),
  zone text not null check (zone in ('cbd','tech_park','suburb','outskirts')),
  total_sqft int not null check (total_sqft > 0),
  monthly_rent_rupees bigint not null check (monthly_rent_rupees >= 0),
  current_rate_per_sqft numeric(10,2) not null check (current_rate_per_sqft >= 0),
  market_rate_per_sqft numeric(10,2) not null check (market_rate_per_sqft >= 0),
  renewal_window_start date not null,
  renewal_window_end date not null,
  landlord_ask_hike_pct numeric(5,2) not null check (landlord_ask_hike_pct >= 0),
  founder_target_hike_pct numeric(5,2) not null check (founder_target_hike_pct >= 0),
  status text not null check (status in ('upcoming','negotiating','agreed','renewed','walking_away','terminated')),
  strategic_priority text not null check (strategic_priority in ('p0','p1','p2','p3')),
  notes text,
  created_at timestamptz not null default now()
);

alter table hq_lease_renewal_candidates_r2953 enable row level security;

drop policy if exists pol_hq_lease_r2953_select on hq_lease_renewal_candidates_r2953;
create policy pol_hq_lease_r2953_select on hq_lease_renewal_candidates_r2953 for select to authenticated using (is_founder());

create table if not exists hq_lease_audit_findings_r2953 (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references hq_lease_renewal_candidates_r2953(id) on delete cascade,
  finding_code text not null,
  category text not null check (category in ('financial','legal','operational','strategic','compliance')),
  severity text not null check (severity in ('low','medium','high','critical')),
  estimated_savings_rupees bigint not null default 0,
  status text not null check (status in ('open','in_review','resolved','accepted_risk')),
  owner_role text not null check (owner_role in ('founder','cfo','ops_head','legal','admin')),
  due_date date not null,
  detail text,
  created_at timestamptz not null default now()
);

alter table hq_lease_audit_findings_r2953 enable row level security;

drop policy if exists pol_hq_findings_r2953_select on hq_lease_audit_findings_r2953;
create policy pol_hq_findings_r2953_select on hq_lease_audit_findings_r2953 for select to authenticated using (is_founder());

-- Seeds
insert into hq_lease_renewal_candidates_r2953 (property_code, property_name, city, zone, total_sqft, monthly_rent_rupees, current_rate_per_sqft, market_rate_per_sqft, renewal_window_start, renewal_window_end, landlord_ask_hike_pct, founder_target_hike_pct, status, strategic_priority, notes) values
('HQ-HYD-01','Hitec City HQ Tower-A','Hyderabad','tech_park',12500,2125000,170.00,165.00,'2026-08-01'::date,'2026-09-30'::date,15.0,5.0,'negotiating','p0','primary HQ floor'),
('HQ-HYD-02','Madhapur Annex','Hyderabad','tech_park',4200,672000,160.00,158.00,'2026-09-15'::date,'2026-11-15'::date,12.0,4.0,'upcoming','p1','engineering team'),
('HQ-BLR-01','Whitefield Outpost','Bengaluru','tech_park',6800,1224000,180.00,175.00,'2026-10-01'::date,'2026-12-01'::date,18.0,6.0,'negotiating','p0','BLR satellite'),
('HQ-BLR-02','Indiranagar Studio','Bengaluru','cbd',2400,576000,240.00,230.00,'2026-11-01'::date,'2027-01-15'::date,20.0,8.0,'upcoming','p2','design studio'),
('HQ-MUM-01','BKC Founders Suite','Mumbai','cbd',1800,720000,400.00,385.00,'2026-12-01'::date,'2027-02-01'::date,22.0,7.0,'upcoming','p1','investor meets'),
('HQ-DEL-01','Gurugram Sales','Delhi NCR','tech_park',3600,540000,150.00,148.00,'2027-01-15'::date,'2027-03-15'::date,10.0,5.0,'upcoming','p2','north sales'),
('HQ-CHE-01','OMR Operations','Chennai','tech_park',5400,702000,130.00,128.00,'2026-08-20'::date,'2026-10-20'::date,8.0,3.0,'agreed','p1','ops backbone'),
('HQ-PUN-01','Hinjewadi Lab','Pune','tech_park',4800,624000,130.00,135.00,'2026-09-10'::date,'2026-11-10'::date,14.0,6.0,'negotiating','p1','hardware lab'),
('HQ-HYD-03','Gachibowli Warehouse','Hyderabad','suburb',8000,560000,70.00,72.00,'2026-10-05'::date,'2026-12-05'::date,9.0,4.0,'renewed','p2','spares warehouse'),
('HQ-BLR-03','Electronic City Backup','Bengaluru','outskirts',9200,736000,80.00,76.00,'2026-11-20'::date,'2027-01-20'::date,11.0,2.0,'walking_away','p3','underused'),
('HQ-MUM-02','Andheri Field Hub','Mumbai','suburb',3200,544000,170.00,168.00,'2027-02-01'::date,'2027-04-01'::date,13.0,5.0,'upcoming','p2','field engineers'),
('HQ-DEL-02','Noida Training Center','Delhi NCR','suburb',2800,392000,140.00,138.00,'2026-12-15'::date,'2027-02-15'::date,12.0,5.0,'upcoming','p2','engineer training'),
('HQ-HYD-04','Banjara Hills CXO','Hyderabad','cbd',1600,640000,400.00,380.00,'2027-03-01'::date,'2027-05-01'::date,18.0,6.0,'upcoming','p1','founder office'),
('HQ-CHE-02','T Nagar Sales Kiosk','Chennai','cbd',900,225000,250.00,240.00,'2026-08-15'::date,'2026-10-15'::date,16.0,4.0,'terminated','p3','closing down'),
('HQ-PUN-02','Koregaon Park Lounge','Pune','cbd',1400,420000,300.00,290.00,'2027-01-10'::date,'2027-03-10'::date,17.0,7.0,'upcoming','p2','client lounge'),
('HQ-BLR-04','Koramangala Innovation','Bengaluru','cbd',3800,950000,250.00,245.00,'2026-09-25'::date,'2026-11-25'::date,15.0,6.0,'negotiating','p1','innovation lab');

insert into hq_lease_audit_findings_r2953 (candidate_id, finding_code, category, severity, estimated_savings_rupees, status, owner_role, due_date, detail)
select id, 'FIN-001-'||property_code, 'financial', 'high', 320000, 'open', 'cfo', '2026-08-15'::date, 'above market rate by 5%' from hq_lease_renewal_candidates_r2953 where property_code='HQ-HYD-01'
union all select id, 'LEG-002-'||property_code, 'legal', 'critical', 0, 'in_review', 'legal', '2026-08-10'::date, 'arbitration clause missing' from hq_lease_renewal_candidates_r2953 where property_code='HQ-HYD-01'
union all select id, 'OPS-003-'||property_code, 'operational', 'medium', 80000, 'open', 'ops_head', '2026-09-01'::date, 'parking shortage' from hq_lease_renewal_candidates_r2953 where property_code='HQ-HYD-02'
union all select id, 'STR-004-'||property_code, 'strategic', 'high', 450000, 'open', 'founder', '2026-09-20'::date, 'consider co-location' from hq_lease_renewal_candidates_r2953 where property_code='HQ-BLR-01'
union all select id, 'COM-005-'||property_code, 'compliance', 'high', 0, 'open', 'legal', '2026-10-01'::date, 'fire NOC expiring' from hq_lease_renewal_candidates_r2953 where property_code='HQ-BLR-02'
union all select id, 'FIN-006-'||property_code, 'financial', 'critical', 720000, 'open', 'cfo', '2026-10-15'::date, 'BKC premium unjustified' from hq_lease_renewal_candidates_r2953 where property_code='HQ-MUM-01'
union all select id, 'OPS-007-'||property_code, 'operational', 'low', 40000, 'resolved', 'ops_head', '2026-08-25'::date, 'HVAC upgrade done' from hq_lease_renewal_candidates_r2953 where property_code='HQ-DEL-01'
union all select id, 'STR-008-'||property_code, 'strategic', 'medium', 180000, 'in_review', 'founder', '2026-09-10'::date, 'consolidate Chennai' from hq_lease_renewal_candidates_r2953 where property_code='HQ-CHE-01'
union all select id, 'FIN-009-'||property_code, 'financial', 'medium', 110000, 'open', 'cfo', '2026-09-15'::date, 'maintenance double-billed' from hq_lease_renewal_candidates_r2953 where property_code='HQ-PUN-01'
union all select id, 'LEG-010-'||property_code, 'legal', 'medium', 0, 'open', 'legal', '2026-10-05'::date, 'lock-in 24mo unfavorable' from hq_lease_renewal_candidates_r2953 where property_code='HQ-HYD-03'
union all select id, 'STR-011-'||property_code, 'strategic', 'critical', 880000, 'open', 'founder', '2026-11-01'::date, 'exit electronic city' from hq_lease_renewal_candidates_r2953 where property_code='HQ-BLR-03'
union all select id, 'OPS-012-'||property_code, 'operational', 'high', 60000, 'open', 'ops_head', '2027-01-15'::date, 'security audit pending' from hq_lease_renewal_candidates_r2953 where property_code='HQ-MUM-02'
union all select id, 'COM-013-'||property_code, 'compliance', 'medium', 0, 'open', 'admin', '2026-11-30'::date, 'GST address update' from hq_lease_renewal_candidates_r2953 where property_code='HQ-DEL-02'
union all select id, 'FIN-014-'||property_code, 'financial', 'high', 240000, 'in_review', 'cfo', '2027-02-01'::date, 'banjara CXO downsizing' from hq_lease_renewal_candidates_r2953 where property_code='HQ-HYD-04'
union all select id, 'STR-015-'||property_code, 'strategic', 'low', 0, 'accepted_risk', 'founder', '2026-10-10'::date, 'kiosk closure accepted' from hq_lease_renewal_candidates_r2953 where property_code='HQ-CHE-02'
union all select id, 'OPS-016-'||property_code, 'operational', 'medium', 70000, 'open', 'ops_head', '2027-01-25'::date, 'koregaon lounge ROI weak' from hq_lease_renewal_candidates_r2953 where property_code='HQ-PUN-02'
union all select id, 'FIN-017-'||property_code, 'financial', 'high', 360000, 'open', 'cfo', '2026-10-20'::date, 'koramangala 4% above mkt' from hq_lease_renewal_candidates_r2953 where property_code='HQ-BLR-04';

-- RPCs
create or replace function rpc_r2953_renewal_pipeline()
returns table (status text, candidates int, total_monthly_rent_rupees bigint, total_sqft int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select c.status, count(*)::int, sum(c.monthly_rent_rupees)::bigint, sum(c.total_sqft)::int
    from hq_lease_renewal_candidates_r2953 c group by c.status order by c.status;
end $$;

create or replace function rpc_r2953_above_market_properties()
returns table (property_code text, city text, current_rate numeric, market_rate numeric, premium_pct numeric, monthly_rent_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select c.property_code, c.city, c.current_rate_per_sqft, c.market_rate_per_sqft,
    round(((c.current_rate_per_sqft - c.market_rate_per_sqft)/nullif(c.market_rate_per_sqft,0))*100, 2),
    c.monthly_rent_rupees
    from hq_lease_renewal_candidates_r2953 c
    where c.current_rate_per_sqft > c.market_rate_per_sqft
    order by (c.current_rate_per_sqft - c.market_rate_per_sqft) desc;
end $$;

create or replace function rpc_r2953_landlord_ask_vs_target()
returns table (property_code text, landlord_ask_hike_pct numeric, founder_target_hike_pct numeric, gap_pct numeric, priority text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select c.property_code, c.landlord_ask_hike_pct, c.founder_target_hike_pct,
    (c.landlord_ask_hike_pct - c.founder_target_hike_pct), c.strategic_priority
    from hq_lease_renewal_candidates_r2953 c
    where c.status in ('upcoming','negotiating')
    order by (c.landlord_ask_hike_pct - c.founder_target_hike_pct) desc;
end $$;

create or replace function rpc_r2953_findings_by_severity()
returns table (severity text, category text, open_count int, total_savings_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select f.severity, f.category,
    (count(*) filter (where f.status='open'))::int,
    sum(f.estimated_savings_rupees)::bigint
    from hq_lease_audit_findings_r2953 f group by f.severity, f.category
    order by f.severity, f.category;
end $$;

create or replace function rpc_r2953_savings_by_owner()
returns table (owner_role text, open_findings int, savings_at_stake_rupees bigint, overdue_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select f.owner_role,
    (count(*) filter (where f.status in ('open','in_review')))::int,
    sum(f.estimated_savings_rupees) filter (where f.status in ('open','in_review'))::bigint,
    (count(*) filter (where f.due_date < current_date and f.status in ('open','in_review')))::int
    from hq_lease_audit_findings_r2953 f group by f.owner_role order by f.owner_role;
end $$;

create or replace function rpc_r2953_renewal_calendar()
returns table (property_code text, city text, renewal_window_start date, days_until_start int, status text, strategic_priority text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select c.property_code, c.city, c.renewal_window_start,
    (c.renewal_window_start - current_date)::int, c.status, c.strategic_priority
    from hq_lease_renewal_candidates_r2953 c
    where c.status in ('upcoming','negotiating','agreed')
    order by c.renewal_window_start;
end $$;

create or replace function rpc_r2953_city_portfolio()
returns table (city text, properties int, total_sqft int, total_monthly_rent_rupees bigint, avg_rate numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select c.city, count(*)::int, sum(c.total_sqft)::int, sum(c.monthly_rent_rupees)::bigint,
    round(avg(c.current_rate_per_sqft), 2)
    from hq_lease_renewal_candidates_r2953 c group by c.city order by sum(c.monthly_rent_rupees) desc;
end $$;

create or replace function rpc_r2953_p0_critical_actions()
returns table (property_code text, finding_code text, severity text, estimated_savings_rupees bigint, due_date date, owner_role text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select c.property_code, f.finding_code, f.severity, f.estimated_savings_rupees, f.due_date, f.owner_role
    from hq_lease_audit_findings_r2953 f
    join hq_lease_renewal_candidates_r2953 c on c.id = f.candidate_id
    where (c.strategic_priority = 'p0' or f.severity = 'critical') and f.status in ('open','in_review')
    order by f.due_date;
end $$;

revoke all on function rpc_r2953_renewal_pipeline() from public, anon;
revoke all on function rpc_r2953_above_market_properties() from public, anon;
revoke all on function rpc_r2953_landlord_ask_vs_target() from public, anon;
revoke all on function rpc_r2953_findings_by_severity() from public, anon;
revoke all on function rpc_r2953_savings_by_owner() from public, anon;
revoke all on function rpc_r2953_renewal_calendar() from public, anon;
revoke all on function rpc_r2953_city_portfolio() from public, anon;
revoke all on function rpc_r2953_p0_critical_actions() from public, anon;

grant execute on function rpc_r2953_renewal_pipeline() to authenticated;
grant execute on function rpc_r2953_above_market_properties() to authenticated;
grant execute on function rpc_r2953_landlord_ask_vs_target() to authenticated;
grant execute on function rpc_r2953_findings_by_severity() to authenticated;
grant execute on function rpc_r2953_savings_by_owner() to authenticated;
grant execute on function rpc_r2953_renewal_calendar() to authenticated;
grant execute on function rpc_r2953_city_portfolio() to authenticated;
grant execute on function rpc_r2953_p0_critical_actions() to authenticated;
