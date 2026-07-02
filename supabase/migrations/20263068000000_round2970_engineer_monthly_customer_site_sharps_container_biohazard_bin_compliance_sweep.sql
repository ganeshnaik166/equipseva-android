-- Round 2970: Engineer Monthly Customer Site Sharps-Container & Biohazard Bin Compliance Sweep
-- HEAVY ★★★★

create table if not exists sharps_biohazard_sweeps_r2970 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  swept_on date not null,
  engineer_name text not null,
  customer_site text not null,
  city text not null,
  container_type text not null check (container_type in ('sharps_box','biohazard_red_bag','biohazard_yellow_bin','biohazard_white_bin','cytotoxic_bin')),
  fill_level_pct int not null check (fill_level_pct between 0 and 100),
  capacity_litres int not null check (capacity_litres > 0),
  compliance_status text not null check (compliance_status in ('compliant','minor_breach','major_breach','critical_breach')),
  bmw_rule_2016_violation text check (bmw_rule_2016_violation in ('none','color_mismatch','overfilled','unlabeled','past_72h','leaking','sharps_in_softbag')),
  cpcb_authorization_valid boolean not null default true,
  fine_risk_rupees int not null default 0 check (fine_risk_rupees >= 0),
  next_pickup_due date not null,
  notes text
);

create table if not exists sharps_biohazard_corrective_actions_r2970 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  sweep_id uuid references sharps_biohazard_sweeps_r2970(id) on delete cascade,
  action_type text not null check (action_type in ('replace_container','arrange_pickup','retrain_staff','escalate_cpcb','issue_warning','swap_color_code','seal_and_quarantine')),
  action_status text not null check (action_status in ('pending','scheduled','in_progress','completed','overdue','cancelled')),
  assigned_to text not null,
  due_on date not null,
  resolved_on date,
  cost_rupees int not null default 0 check (cost_rupees >= 0),
  followup_required boolean not null default false
);

alter table sharps_biohazard_sweeps_r2970 enable row level security;
alter table sharps_biohazard_corrective_actions_r2970 enable row level security;

drop policy if exists sb_sweeps_founder_r2970 on sharps_biohazard_sweeps_r2970;
create policy sb_sweeps_founder_r2970 on sharps_biohazard_sweeps_r2970 for select using (is_founder());

drop policy if exists sb_actions_founder_r2970 on sharps_biohazard_corrective_actions_r2970;
create policy sb_actions_founder_r2970 on sharps_biohazard_corrective_actions_r2970 for select using (is_founder());

insert into sharps_biohazard_sweeps_r2970 (swept_on, engineer_name, customer_site, city, container_type, fill_level_pct, capacity_litres, compliance_status, bmw_rule_2016_violation, cpcb_authorization_valid, fine_risk_rupees, next_pickup_due, notes) values
('2026-06-01'::date,'Ravi K','Apollo Jubilee Hills OR-3','Hyderabad','sharps_box',82,5,'minor_breach','none',true,0,'2026-06-04'::date,'Within 90% threshold'),
('2026-06-01'::date,'Ravi K','Apollo Jubilee Hills ICU','Hyderabad','biohazard_red_bag',95,50,'major_breach','overfilled',true,15000,'2026-06-02'::date,'Bag tearing at seam'),
('2026-06-02'::date,'Sneha M','Fortis Bannerghatta Ward-7','Bengaluru','biohazard_yellow_bin',45,25,'compliant','none',true,0,'2026-06-05'::date,'OK'),
('2026-06-02'::date,'Sneha M','Fortis Bannerghatta Path Lab','Bengaluru','sharps_box',100,5,'critical_breach','overfilled',true,50000,'2026-06-02'::date,'Needle protruding - immediate'),
('2026-06-03'::date,'Arjun P','Manipal Whitefield Dialysis','Bengaluru','biohazard_white_bin',60,30,'compliant','none',true,0,'2026-06-06'::date,'Routine'),
('2026-06-03'::date,'Arjun P','Manipal Whitefield Lab','Bengaluru','cytotoxic_bin',30,10,'minor_breach','unlabeled',true,5000,'2026-06-06'::date,'Label faded'),
('2026-06-04'::date,'Priya N','Max Saket OR-1','Delhi','biohazard_red_bag',88,50,'major_breach','color_mismatch',true,25000,'2026-06-05'::date,'Yellow contents in red bag'),
('2026-06-04'::date,'Priya N','Max Saket Recovery','Delhi','sharps_box',55,5,'compliant','none',true,0,'2026-06-07'::date,'OK'),
('2026-06-05'::date,'Vikram T','AIIMS Rishikesh Burn Unit','Rishikesh','biohazard_yellow_bin',72,25,'minor_breach','past_72h',true,8000,'2026-06-05'::date,'Bin in ward 4 days'),
('2026-06-05'::date,'Vikram T','AIIMS Rishikesh OR-2','Rishikesh','biohazard_white_bin',40,30,'compliant','none',true,0,'2026-06-08'::date,'Clean swap'),
('2026-06-06'::date,'Anita S','KEM Mumbai Ward-12','Mumbai','sharps_box',92,5,'major_breach','sharps_in_softbag',true,30000,'2026-06-06'::date,'Found scalpels in red bag'),
('2026-06-06'::date,'Anita S','KEM Mumbai ICU-A','Mumbai','biohazard_red_bag',68,50,'compliant','none',true,0,'2026-06-09'::date,'OK'),
('2026-06-07'::date,'Rohan G','Christian Medical Vellore OR-5','Vellore','cytotoxic_bin',85,10,'major_breach','overfilled',true,20000,'2026-06-07'::date,'Chemo waste over line'),
('2026-06-07'::date,'Rohan G','Christian Medical Vellore Lab','Vellore','sharps_box',38,5,'compliant','none',true,0,'2026-06-10'::date,'OK'),
('2026-06-08'::date,'Meera D','SGPGI Lucknow Path','Lucknow','biohazard_yellow_bin',91,25,'major_breach','leaking','false'::boolean,18000,'2026-06-08'::date,'CPCB cert expired Mar 2026'),
('2026-06-08'::date,'Meera D','SGPGI Lucknow OR','Lucknow','biohazard_red_bag',55,50,'compliant','none',true,0,'2026-06-11'::date,'OK'),
('2026-06-09'::date,'Karan B','Tata Memorial Mumbai OR-A','Mumbai','cytotoxic_bin',78,10,'minor_breach','unlabeled',true,7000,'2026-06-12'::date,'Cyto label peeled'),
('2026-06-09'::date,'Karan B','Tata Memorial Mumbai Onco-IPD','Mumbai','sharps_box',65,5,'compliant','none',true,0,'2026-06-12'::date,'OK'),
('2026-06-10'::date,'Divya R','NIMHANS Bengaluru Ward-3','Bengaluru','biohazard_white_bin',49,30,'compliant','none',true,0,'2026-06-13'::date,'OK'),
('2026-06-10'::date,'Divya R','NIMHANS Bengaluru Lab','Bengaluru','sharps_box',98,5,'critical_breach','overfilled',true,75000,'2026-06-10'::date,'Lab full - inspection due'),
('2026-06-11'::date,'Suresh I','PGIMER Chandigarh OR-3','Chandigarh','biohazard_red_bag',52,50,'compliant','none',true,0,'2026-06-14'::date,'OK'),
('2026-06-11'::date,'Suresh I','PGIMER Chandigarh Dialysis','Chandigarh','biohazard_yellow_bin',83,25,'minor_breach','past_72h',true,9000,'2026-06-11'::date,'4-day-old'),
('2026-06-12'::date,'Lakshmi V','Apollo Chennai OR-7','Chennai','sharps_box',45,5,'compliant','none',true,0,'2026-06-15'::date,'OK'),
('2026-06-12'::date,'Lakshmi V','Apollo Chennai Cath Lab','Chennai','cytotoxic_bin',62,10,'compliant','none',true,0,'2026-06-15'::date,'OK');

insert into sharps_biohazard_corrective_actions_r2970 (sweep_id, action_type, action_status, assigned_to, due_on, resolved_on, cost_rupees, followup_required) values
((select id from sharps_biohazard_sweeps_r2970 where customer_site='Apollo Jubilee Hills ICU' limit 1),'replace_container','completed','Ravi K','2026-06-02'::date,'2026-06-02'::date,1200,false),
((select id from sharps_biohazard_sweeps_r2970 where customer_site='Apollo Jubilee Hills ICU' limit 1),'retrain_staff','scheduled','Hospital BMW Officer','2026-06-15'::date,null,3500,true),
((select id from sharps_biohazard_sweeps_r2970 where customer_site='Fortis Bannerghatta Path Lab' limit 1),'seal_and_quarantine','completed','Sneha M','2026-06-02'::date,'2026-06-02'::date,800,true),
((select id from sharps_biohazard_sweeps_r2970 where customer_site='Fortis Bannerghatta Path Lab' limit 1),'escalate_cpcb','in_progress','Compliance Team','2026-06-09'::date,null,0,true),
((select id from sharps_biohazard_sweeps_r2970 where customer_site='Manipal Whitefield Lab' limit 1),'swap_color_code','completed','Arjun P','2026-06-06'::date,'2026-06-05'::date,600,false),
((select id from sharps_biohazard_sweeps_r2970 where customer_site='Max Saket OR-1' limit 1),'swap_color_code','completed','Priya N','2026-06-05'::date,'2026-06-05'::date,900,false),
((select id from sharps_biohazard_sweeps_r2970 where customer_site='Max Saket OR-1' limit 1),'issue_warning','completed','Compliance Team','2026-06-06'::date,'2026-06-06'::date,0,false),
((select id from sharps_biohazard_sweeps_r2970 where customer_site='AIIMS Rishikesh Burn Unit' limit 1),'arrange_pickup','completed','Vikram T','2026-06-05'::date,'2026-06-05'::date,1500,false),
((select id from sharps_biohazard_sweeps_r2970 where customer_site='KEM Mumbai Ward-12' limit 1),'retrain_staff','overdue','Hospital BMW Officer','2026-06-13'::date,null,4000,true),
((select id from sharps_biohazard_sweeps_r2970 where customer_site='KEM Mumbai Ward-12' limit 1),'seal_and_quarantine','completed','Anita S','2026-06-06'::date,'2026-06-06'::date,1100,true),
((select id from sharps_biohazard_sweeps_r2970 where customer_site='Christian Medical Vellore OR-5' limit 1),'replace_container','completed','Rohan G','2026-06-07'::date,'2026-06-07'::date,1800,true),
((select id from sharps_biohazard_sweeps_r2970 where customer_site='SGPGI Lucknow Path' limit 1),'escalate_cpcb','pending','Compliance Team','2026-06-15'::date,null,0,true),
((select id from sharps_biohazard_sweeps_r2970 where customer_site='SGPGI Lucknow Path' limit 1),'replace_container','in_progress','Meera D','2026-06-10'::date,null,1400,true),
((select id from sharps_biohazard_sweeps_r2970 where customer_site='Tata Memorial Mumbai OR-A' limit 1),'swap_color_code','completed','Karan B','2026-06-12'::date,'2026-06-12'::date,500,false),
((select id from sharps_biohazard_sweeps_r2970 where customer_site='NIMHANS Bengaluru Lab' limit 1),'arrange_pickup','completed','Divya R','2026-06-10'::date,'2026-06-10'::date,2000,true),
((select id from sharps_biohazard_sweeps_r2970 where customer_site='NIMHANS Bengaluru Lab' limit 1),'retrain_staff','scheduled','Hospital BMW Officer','2026-06-20'::date,null,3500,true),
((select id from sharps_biohazard_sweeps_r2970 where customer_site='PGIMER Chandigarh Dialysis' limit 1),'arrange_pickup','completed','Suresh I','2026-06-11'::date,'2026-06-11'::date,1200,false),
((select id from sharps_biohazard_sweeps_r2970 where customer_site='Apollo Jubilee Hills OR-3' limit 1),'arrange_pickup','scheduled','Ravi K','2026-06-04'::date,null,1000,false);

-- Fix the false boolean cast above (PG syntax)
update sharps_biohazard_sweeps_r2970 set cpcb_authorization_valid=false where customer_site='SGPGI Lucknow Path';

create or replace function founder_r2970_overall_compliance_summary()
returns table(total_sweeps int, compliant int, minor int, major int, critical int, total_fine_risk_rupees bigint, expired_cpcb_sites int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select
      count(*)::int as total_sweeps,
      (count(*) filter (where compliance_status='compliant'))::int as compliant,
      (count(*) filter (where compliance_status='minor_breach'))::int as minor,
      (count(*) filter (where compliance_status='major_breach'))::int as major,
      (count(*) filter (where compliance_status='critical_breach'))::int as critical,
      coalesce(sum(fine_risk_rupees),0)::bigint as total_fine_risk_rupees,
      (count(*) filter (where cpcb_authorization_valid=false))::int as expired_cpcb_sites
    from sharps_biohazard_sweeps_r2970;
end $$;

create or replace function founder_r2970_violation_breakdown()
returns table(violation text, occurrences int, total_fine_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select coalesce(bmw_rule_2016_violation,'none') as violation,
      count(*)::int as occurrences,
      coalesce(sum(fine_risk_rupees),0)::bigint as total_fine_rupees
    from sharps_biohazard_sweeps_r2970
    group by bmw_rule_2016_violation
    order by total_fine_rupees desc;
end $$;

create or replace function founder_r2970_engineer_leaderboard()
returns table(engineer_name text, sweeps_done int, breaches_found int, fine_risk_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select s.engineer_name,
      count(*)::int as sweeps_done,
      (count(*) filter (where s.compliance_status <> 'compliant'))::int as breaches_found,
      coalesce(sum(s.fine_risk_rupees),0)::bigint as fine_risk_rupees
    from sharps_biohazard_sweeps_r2970 s
    group by s.engineer_name
    order by sweeps_done desc;
end $$;

create or replace function founder_r2970_city_hotspots()
returns table(city text, sites_swept int, criticals int, fine_risk_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select s.city,
      count(*)::int as sites_swept,
      (count(*) filter (where s.compliance_status='critical_breach'))::int as criticals,
      coalesce(sum(s.fine_risk_rupees),0)::bigint as fine_risk_rupees
    from sharps_biohazard_sweeps_r2970 s
    group by s.city
    order by fine_risk_rupees desc;
end $$;

create or replace function founder_r2970_container_type_mix()
returns table(container_type text, count_sites int, avg_fill_pct numeric, total_capacity_litres bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select s.container_type,
      count(*)::int as count_sites,
      round(avg(s.fill_level_pct)::numeric,1) as avg_fill_pct,
      coalesce(sum(s.capacity_litres),0)::bigint as total_capacity_litres
    from sharps_biohazard_sweeps_r2970 s
    group by s.container_type
    order by count_sites desc;
end $$;

create or replace function founder_r2970_corrective_action_status()
returns table(action_status text, action_count int, total_cost_rupees bigint, followups int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select a.action_status,
      count(*)::int as action_count,
      coalesce(sum(a.cost_rupees),0)::bigint as total_cost_rupees,
      (count(*) filter (where a.followup_required=true))::int as followups
    from sharps_biohazard_corrective_actions_r2970 a
    group by a.action_status
    order by action_count desc;
end $$;

create or replace function founder_r2970_top_offender_sites()
returns table(customer_site text, city text, breaches int, fine_risk_rupees bigint, last_swept date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select s.customer_site, s.city,
      (count(*) filter (where s.compliance_status <> 'compliant'))::int as breaches,
      coalesce(sum(s.fine_risk_rupees),0)::bigint as fine_risk_rupees,
      max(s.swept_on) as last_swept
    from sharps_biohazard_sweeps_r2970 s
    group by s.customer_site, s.city
    having (count(*) filter (where s.compliance_status <> 'compliant')) > 0
    order by fine_risk_rupees desc
    limit 15;
end $$;

revoke all on function founder_r2970_overall_compliance_summary() from public, anon;
revoke all on function founder_r2970_violation_breakdown() from public, anon;
revoke all on function founder_r2970_engineer_leaderboard() from public, anon;
revoke all on function founder_r2970_city_hotspots() from public, anon;
revoke all on function founder_r2970_container_type_mix() from public, anon;
revoke all on function founder_r2970_corrective_action_status() from public, anon;
revoke all on function founder_r2970_top_offender_sites() from public, anon;

grant execute on function founder_r2970_overall_compliance_summary() to authenticated;
grant execute on function founder_r2970_violation_breakdown() to authenticated;
grant execute on function founder_r2970_engineer_leaderboard() to authenticated;
grant execute on function founder_r2970_city_hotspots() to authenticated;
grant execute on function founder_r2970_container_type_mix() to authenticated;
grant execute on function founder_r2970_corrective_action_status() to authenticated;
grant execute on function founder_r2970_top_offender_sites() to authenticated;
