-- Round r3060: Stretcher Side-Rail Latch & Drop-Test Compliance
-- Two tables + seven RPCs, founder-gated.

create table if not exists stretcher_latch_inspections_r3060 (
  id uuid primary key default gen_random_uuid(),
  hospital_name text not null,
  stretcher_asset_tag text not null,
  inspection_month date not null,
  engineer_name text not null,
  side_rail_position text not null check (side_rail_position in ('head_left','head_right','foot_left','foot_right')),
  latch_engagement_force_n numeric(6,2) not null check (latch_engagement_force_n >= 0 and latch_engagement_force_n <= 200),
  latch_release_force_n numeric(6,2) not null check (latch_release_force_n >= 0 and latch_release_force_n <= 200),
  rail_deflection_mm numeric(5,2) not null check (rail_deflection_mm >= 0 and rail_deflection_mm <= 50),
  outcome text not null check (outcome in ('pass','marginal','fail','retest_required')),
  iec_60601_2_52_clause text not null,
  remediation_notes text,
  created_at timestamptz not null default now()
);

alter table stretcher_latch_inspections_r3060 enable row level security;
drop policy if exists sli_r3060_founder_select on stretcher_latch_inspections_r3060;
create policy sli_r3060_founder_select on stretcher_latch_inspections_r3060 for select using (is_founder());

create table if not exists stretcher_drop_tests_r3060 (
  id uuid primary key default gen_random_uuid(),
  hospital_name text not null,
  stretcher_asset_tag text not null,
  test_date date not null,
  engineer_name text not null,
  drop_height_cm numeric(5,2) not null check (drop_height_cm >= 0 and drop_height_cm <= 150),
  load_kg numeric(5,2) not null check (load_kg >= 0 and load_kg <= 250),
  surface_type text not null check (surface_type in ('concrete','vinyl','tile','rubber_mat')),
  frame_integrity text not null check (frame_integrity in ('intact','minor_dent','crack','fracture')),
  wheel_alignment_pass boolean not null,
  brake_functional boolean not null,
  cycles_completed int not null check (cycles_completed >= 0 and cycles_completed <= 500),
  verdict text not null check (verdict in ('pass','conditional_pass','fail','recall')),
  remediation_cost_rupees int check (remediation_cost_rupees >= 0),
  created_at timestamptz not null default now()
);

alter table stretcher_drop_tests_r3060 enable row level security;
drop policy if exists sdt_r3060_founder_select on stretcher_drop_tests_r3060;
create policy sdt_r3060_founder_select on stretcher_drop_tests_r3060 for select using (is_founder());

-- Seeds: latch inspections (16 rows)
insert into stretcher_latch_inspections_r3060 (hospital_name, stretcher_asset_tag, inspection_month, engineer_name, side_rail_position, latch_engagement_force_n, latch_release_force_n, rail_deflection_mm, outcome, iec_60601_2_52_clause, remediation_notes) values
('Apollo Jubilee Hills','STR-AJH-001','2026-06-01'::date,'Ravi Kumar','head_left',42.50,18.20,3.40,'pass','201.9.2.2','none'),
('Apollo Jubilee Hills','STR-AJH-001','2026-06-01'::date,'Ravi Kumar','head_right',44.10,19.00,3.60,'pass','201.9.2.2',null),
('KIMS Secunderabad','STR-KIM-014','2026-06-02'::date,'Priya N','foot_left',38.20,16.40,4.10,'marginal','201.9.2.3','spring replaced'),
('KIMS Secunderabad','STR-KIM-014','2026-06-02'::date,'Priya N','foot_right',22.10,9.80,8.20,'fail','201.9.2.3','full assembly swap'),
('Yashoda Somajiguda','STR-YSG-007','2026-06-03'::date,'Anil V','head_left',46.00,20.10,3.10,'pass','201.9.2.2',null),
('Yashoda Somajiguda','STR-YSG-007','2026-06-03'::date,'Anil V','head_right',45.80,20.40,3.20,'pass','201.9.2.2','none'),
('Continental Hospitals','STR-CON-022','2026-06-04'::date,'Meera S','foot_left',31.20,14.20,5.40,'marginal','201.9.2.4','lubrication scheduled'),
('Continental Hospitals','STR-CON-022','2026-06-04'::date,'Meera S','foot_right',29.80,13.50,5.80,'marginal','201.9.2.4',null),
('Care Banjara','STR-CAR-009','2026-06-05'::date,'Suresh R','head_left',48.20,21.00,2.90,'pass','201.9.2.2',null),
('Care Banjara','STR-CAR-009','2026-06-05'::date,'Suresh R','head_right',47.90,20.80,3.00,'pass','201.9.2.2','none'),
('Sunshine Paradise','STR-SUN-031','2026-06-06'::date,'Kavya P','foot_left',18.40,7.20,12.80,'fail','201.9.2.5','recall flagged'),
('Sunshine Paradise','STR-SUN-031','2026-06-06'::date,'Kavya P','foot_right',19.10,7.80,11.20,'fail','201.9.2.5','recall flagged'),
('Rainbow Childrens','STR-RBC-018','2026-06-07'::date,'Deepak J','head_left',40.10,17.80,3.80,'retest_required','201.9.2.3','calibration drift'),
('Rainbow Childrens','STR-RBC-018','2026-06-07'::date,'Deepak J','head_right',41.20,18.00,3.70,'retest_required','201.9.2.3',null),
('AIG Gachibowli','STR-AIG-025','2026-06-08'::date,'Ravi Kumar','foot_left',43.50,19.20,3.30,'pass','201.9.2.2',null),
('AIG Gachibowli','STR-AIG-025','2026-06-08'::date,'Ravi Kumar','foot_right',44.20,19.60,3.20,'pass','201.9.2.2','none');

-- Seeds: drop tests (14 rows)
insert into stretcher_drop_tests_r3060 (hospital_name, stretcher_asset_tag, test_date, engineer_name, drop_height_cm, load_kg, surface_type, frame_integrity, wheel_alignment_pass, brake_functional, cycles_completed, verdict, remediation_cost_rupees) values
('Apollo Jubilee Hills','STR-AJH-001','2026-06-10'::date,'Ravi Kumar',50.00,135.00,'concrete','intact',true,true,200,'pass',0),
('Apollo Jubilee Hills','STR-AJH-002','2026-06-10'::date,'Ravi Kumar',50.00,135.00,'concrete','minor_dent',true,true,180,'conditional_pass',4500),
('KIMS Secunderabad','STR-KIM-014','2026-06-11'::date,'Priya N',50.00,135.00,'vinyl','crack',false,true,90,'fail',28000),
('KIMS Secunderabad','STR-KIM-015','2026-06-11'::date,'Priya N',50.00,135.00,'vinyl','intact',true,true,200,'pass',0),
('Yashoda Somajiguda','STR-YSG-007','2026-06-12'::date,'Anil V',50.00,135.00,'tile','intact',true,true,200,'pass',0),
('Continental Hospitals','STR-CON-022','2026-06-13'::date,'Meera S',50.00,135.00,'concrete','minor_dent',true,false,150,'conditional_pass',6200),
('Care Banjara','STR-CAR-009','2026-06-14'::date,'Suresh R',50.00,135.00,'rubber_mat','intact',true,true,200,'pass',0),
('Sunshine Paradise','STR-SUN-031','2026-06-15'::date,'Kavya P',50.00,135.00,'concrete','fracture',false,false,40,'recall',95000),
('Sunshine Paradise','STR-SUN-032','2026-06-15'::date,'Kavya P',50.00,135.00,'concrete','crack',false,true,60,'fail',42000),
('Rainbow Childrens','STR-RBC-018','2026-06-16'::date,'Deepak J',50.00,90.00,'tile','minor_dent',true,true,170,'conditional_pass',3800),
('AIG Gachibowli','STR-AIG-025','2026-06-17'::date,'Ravi Kumar',50.00,135.00,'concrete','intact',true,true,200,'pass',0),
('AIG Gachibowli','STR-AIG-026','2026-06-17'::date,'Ravi Kumar',50.00,135.00,'concrete','intact',true,true,200,'pass',0),
('Apollo Jubilee Hills','STR-AJH-003','2026-06-18'::date,'Ravi Kumar',50.00,135.00,'vinyl','minor_dent',true,true,175,'conditional_pass',5100),
('KIMS Secunderabad','STR-KIM-016','2026-06-18'::date,'Priya N',50.00,135.00,'rubber_mat','intact',true,true,200,'pass',0);

-- RPC 1: hospital pass rate summary
create or replace function fc_r3060_hospital_pass_rate()
returns table(hospital_name text, total_inspections int, passes int, fails int, pass_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.hospital_name,
    count(*)::int as total_inspections,
    (count(*) filter (where s.outcome = 'pass'))::int as passes,
    (count(*) filter (where s.outcome = 'fail'))::int as fails,
    round(100.0 * (count(*) filter (where s.outcome = 'pass'))::numeric / nullif(count(*),0), 1) as pass_rate_pct
  from stretcher_latch_inspections_r3060 s
  group by s.hospital_name
  order by pass_rate_pct asc nulls last;
end; $$;
revoke all on function fc_r3060_hospital_pass_rate() from public, anon;
grant execute on function fc_r3060_hospital_pass_rate() to authenticated;

-- RPC 2: engineer scorecard
create or replace function fc_r3060_engineer_scorecard()
returns table(engineer_name text, inspections int, marginal int, fails int, avg_engagement_force numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.engineer_name,
    count(*)::int as inspections,
    (count(*) filter (where s.outcome = 'marginal'))::int as marginal,
    (count(*) filter (where s.outcome = 'fail'))::int as fails,
    round(avg(s.latch_engagement_force_n)::numeric, 2) as avg_engagement_force
  from stretcher_latch_inspections_r3060 s
  group by s.engineer_name
  order by fails desc, marginal desc;
end; $$;
revoke all on function fc_r3060_engineer_scorecard() from public, anon;
grant execute on function fc_r3060_engineer_scorecard() to authenticated;

-- RPC 3: failed rail positions
create or replace function fc_r3060_failed_rail_positions()
returns table(side_rail_position text, fails int, avg_deflection_mm numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.side_rail_position,
    (count(*) filter (where s.outcome = 'fail'))::int as fails,
    round(avg(s.rail_deflection_mm)::numeric, 2) as avg_deflection_mm
  from stretcher_latch_inspections_r3060 s
  group by s.side_rail_position
  order by fails desc;
end; $$;
revoke all on function fc_r3060_failed_rail_positions() from public, anon;
grant execute on function fc_r3060_failed_rail_positions() to authenticated;

-- RPC 4: drop test verdict distribution
create or replace function fc_r3060_drop_verdict_breakdown()
returns table(verdict text, units int, total_remediation_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.verdict,
    count(*)::int as units,
    coalesce(sum(d.remediation_cost_rupees),0)::bigint as total_remediation_rupees
  from stretcher_drop_tests_r3060 d
  group by d.verdict
  order by total_remediation_rupees desc;
end; $$;
revoke all on function fc_r3060_drop_verdict_breakdown() from public, anon;
grant execute on function fc_r3060_drop_verdict_breakdown() to authenticated;

-- RPC 5: surface type fail rate
create or replace function fc_r3060_surface_fail_rate()
returns table(surface_type text, tests int, fails_or_recalls int, fail_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.surface_type,
    count(*)::int as tests,
    (count(*) filter (where d.verdict in ('fail','recall')))::int as fails_or_recalls,
    round(100.0 * (count(*) filter (where d.verdict in ('fail','recall')))::numeric / nullif(count(*),0), 1) as fail_rate_pct
  from stretcher_drop_tests_r3060 d
  group by d.surface_type
  order by fail_rate_pct desc nulls last;
end; $$;
revoke all on function fc_r3060_surface_fail_rate() from public, anon;
grant execute on function fc_r3060_surface_fail_rate() to authenticated;

-- RPC 6: recall watchlist
create or replace function fc_r3060_recall_watchlist()
returns table(hospital_name text, stretcher_asset_tag text, verdict text, frame_integrity text, remediation_cost_rupees int, test_date date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.hospital_name, d.stretcher_asset_tag, d.verdict, d.frame_integrity, d.remediation_cost_rupees, d.test_date
  from stretcher_drop_tests_r3060 d
  where d.verdict in ('fail','recall')
  order by d.remediation_cost_rupees desc nulls last, d.test_date desc;
end; $$;
revoke all on function fc_r3060_recall_watchlist() from public, anon;
grant execute on function fc_r3060_recall_watchlist() to authenticated;

-- RPC 7: monthly compliance trend
create or replace function fc_r3060_monthly_compliance()
returns table(inspection_month date, total int, passes int, retest_required int, compliance_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.inspection_month,
    count(*)::int as total,
    (count(*) filter (where s.outcome = 'pass'))::int as passes,
    (count(*) filter (where s.outcome = 'retest_required'))::int as retest_required,
    round(100.0 * (count(*) filter (where s.outcome = 'pass'))::numeric / nullif(count(*),0), 1) as compliance_pct
  from stretcher_latch_inspections_r3060 s
  group by s.inspection_month
  order by s.inspection_month asc;
end; $$;
revoke all on function fc_r3060_monthly_compliance() from public, anon;
grant execute on function fc_r3060_monthly_compliance() to authenticated;
