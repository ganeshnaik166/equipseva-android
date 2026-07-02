-- Round 3002 — Engineer Monthly Customer Site Patient-Bath-Lift Sling Inspection & Replacement Audit
-- HEAVY ★★★★

create table if not exists bath_lift_sling_inspections_r3002 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  inspection_code text not null unique,
  customer_site text not null,
  hospital_city text not null,
  engineer_name text not null,
  sling_serial text not null,
  sling_model text not null check (sling_model in ('universal_loop','divided_leg','toileting','hammock','stretcher','standing_aid')),
  sling_size text not null check (sling_size in ('xs','s','m','l','xl','xxl')),
  install_date date not null,
  inspection_date date not null,
  age_months int not null,
  fabric_wear_score int not null check (fabric_wear_score between 0 and 10),
  stitching_score int not null check (stitching_score between 0 and 10),
  loop_strap_score int not null check (loop_strap_score between 0 and 10),
  clip_buckle_score int not null check (clip_buckle_score between 0 and 10),
  label_legibility text not null check (label_legibility in ('clear','faded','illegible','missing')),
  load_test_kg int not null,
  rated_load_kg int not null,
  verdict text not null check (verdict in ('pass','watchlist','fail','condemn')),
  replacement_required boolean not null default false,
  replacement_eta_days int,
  photos_uploaded int not null default 0
);

create table if not exists bath_lift_sling_replacements_r3002 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  replacement_code text not null unique,
  inspection_code text not null,
  customer_site text not null,
  old_serial text not null,
  new_serial text not null,
  sling_model text not null check (sling_model in ('universal_loop','divided_leg','toileting','hammock','stretcher','standing_aid')),
  sling_size text not null check (sling_size in ('xs','s','m','l','xl','xxl')),
  reason text not null check (reason in ('end_of_life','fabric_tear','strap_fray','buckle_broken','label_missing','load_fail','recall','customer_request')),
  status text not null check (status in ('open','in_progress','dispatched','installed','signed_off','cancelled')),
  raised_on date not null,
  installed_on date,
  cost_rupees int not null,
  warranty_months int not null check (warranty_months in (6,12,18,24,36)),
  engineer_name text not null,
  customer_signoff boolean not null default false
);

alter table bath_lift_sling_inspections_r3002 enable row level security;
alter table bath_lift_sling_replacements_r3002 enable row level security;

drop policy if exists r3002_insp_founder_read on bath_lift_sling_inspections_r3002;
create policy r3002_insp_founder_read on bath_lift_sling_inspections_r3002 for select using (is_founder());

drop policy if exists r3002_repl_founder_read on bath_lift_sling_replacements_r3002;
create policy r3002_repl_founder_read on bath_lift_sling_replacements_r3002 for select using (is_founder());

-- Seeds: inspections (20 rows)
insert into bath_lift_sling_inspections_r3002 (inspection_code, customer_site, hospital_city, engineer_name, sling_serial, sling_model, sling_size, install_date, inspection_date, age_months, fabric_wear_score, stitching_score, loop_strap_score, clip_buckle_score, label_legibility, load_test_kg, rated_load_kg, verdict, replacement_required, replacement_eta_days, photos_uploaded) values
('INS-3002-001','Apollo Jubilee Hills','Hyderabad','Ravi Kumar','SLG-A001','universal_loop','l','2024-01-12'::date,'2026-06-02'::date,29,4,6,7,8,'clear',200,180,'watchlist',false,null,6),
('INS-3002-002','Yashoda Secunderabad','Hyderabad','Sneha Reddy','SLG-A002','divided_leg','m','2025-03-10'::date,'2026-06-03'::date,15,7,8,9,9,'clear',180,170,'pass',false,null,5),
('INS-3002-003','Manipal Hebbal','Bengaluru','Arjun Iyer','SLG-A003','toileting','s','2023-08-22'::date,'2026-06-04'::date,34,2,3,4,5,'faded',150,150,'fail',true,7,8),
('INS-3002-004','Fortis Cunningham','Bengaluru','Pooja Nair','SLG-A004','hammock','xl','2024-11-05'::date,'2026-06-05'::date,19,6,7,8,7,'clear',220,200,'watchlist',false,null,4) -- placeholder fix below
on conflict do nothing;

-- Re-do row 4 cleanly (replace placeholder)
delete from bath_lift_sling_inspections_r3002 where inspection_code='INS-3002-004';
insert into bath_lift_sling_inspections_r3002 (inspection_code, customer_site, hospital_city, engineer_name, sling_serial, sling_model, sling_size, install_date, inspection_date, age_months, fabric_wear_score, stitching_score, loop_strap_score, clip_buckle_score, label_legibility, load_test_kg, rated_load_kg, verdict, replacement_required, replacement_eta_days, photos_uploaded) values
('INS-3002-004','Fortis Cunningham','Bengaluru','Pooja Nair','SLG-A004','hammock','xl','2024-11-05'::date,'2026-06-05'::date,19,6,7,8,7,'clear',220,200,'watchlist',false,null,4),
('INS-3002-005','Max Saket','Delhi','Vikram Singh','SLG-A005','stretcher','xxl','2023-02-14'::date,'2026-06-06'::date,40,1,2,2,3,'illegible',140,160,'condemn',true,3,12),
('INS-3002-006','BLK Pusa','Delhi','Anita Sharma','SLG-A006','standing_aid','m','2025-06-19'::date,'2026-06-07'::date,12,9,9,9,9,'clear',170,160,'pass',false,null,3),
('INS-3002-007','Kokilaben','Mumbai','Rohit Mehta','SLG-A007','universal_loop','l','2024-09-30'::date,'2026-06-08'::date,21,5,6,7,7,'faded',195,180,'watchlist',false,null,5),
('INS-3002-008','Hinduja Mahim','Mumbai','Priya Joshi','SLG-A008','divided_leg','s','2024-04-04'::date,'2026-06-09'::date,26,3,4,5,6,'faded',160,170,'fail',true,10,9),
('INS-3002-009','AIIMS','Delhi','Mohit Verma','SLG-A009','toileting','m','2025-01-20'::date,'2026-06-10'::date,17,8,8,9,8,'clear',165,160,'pass',false,null,4),
('INS-3002-010','CMC Vellore','Vellore','Sundar Pillai','SLG-A010','hammock','l','2023-05-11'::date,'2026-06-11'::date,37,2,3,3,4,'missing',155,180,'condemn',true,2,11),
('INS-3002-011','Christian Medical','Ludhiana','Harpreet Kaur','SLG-A011','universal_loop','xl','2025-09-01'::date,'2026-06-12'::date,9,9,9,10,9,'clear',210,200,'pass',false,null,3),
('INS-3002-012','PGI Chandigarh','Chandigarh','Inderjit Singh','SLG-A012','standing_aid','l','2024-07-17'::date,'2026-06-13'::date,23,6,6,7,7,'clear',185,180,'watchlist',false,null,5),
('INS-3002-013','KIMS Kurnool','Kurnool','Lakshmi Devi','SLG-A013','divided_leg','m','2023-10-08'::date,'2026-06-14'::date,32,3,4,4,5,'faded',155,170,'fail',true,14,8),
('INS-3002-014','Rainbow Banjara','Hyderabad','Kiran Babu','SLG-A014','toileting','xs','2025-04-28'::date,'2026-06-15'::date,14,8,9,9,9,'clear',95,90,'pass',false,null,4),
('INS-3002-015','Narayana Health City','Bengaluru','Madhav Rao','SLG-A015','stretcher','xxl','2024-02-02'::date,'2026-06-16'::date,28,4,5,6,6,'faded',225,220,'watchlist',false,null,6),
('INS-3002-016','Medanta Gurugram','Gurugram','Naveen Yadav','SLG-A016','universal_loop','m','2023-11-22'::date,'2026-06-17'::date,30,2,3,3,4,'illegible',150,170,'condemn',true,5,10),
('INS-3002-017','Artemis','Gurugram','Riya Gupta','SLG-A017','hammock','l','2025-07-09'::date,'2026-06-18'::date,11,9,9,9,9,'clear',195,190,'pass',false,null,3),
('INS-3002-018','Sankara Nethralaya','Chennai','Murugan S','SLG-A018','standing_aid','s','2024-06-05'::date,'2026-06-19'::date,24,5,6,6,7,'faded',135,140,'watchlist',false,null,5),
('INS-3002-019','Apollo Greams','Chennai','Karthik V','SLG-A019','divided_leg','l','2023-12-30'::date,'2026-06-20'::date,29,3,4,4,5,'faded',170,180,'fail',true,9,7),
('INS-3002-020','Tata Memorial','Mumbai','Deepa Iyer','SLG-A020','universal_loop','xl','2025-02-14'::date,'2026-06-21'::date,16,7,8,8,8,'clear',210,200,'pass',false,null,4);

-- Seeds: replacements (16 rows)
insert into bath_lift_sling_replacements_r3002 (replacement_code, inspection_code, customer_site, old_serial, new_serial, sling_model, sling_size, reason, status, raised_on, installed_on, cost_rupees, warranty_months, engineer_name, customer_signoff) values
('RPL-3002-001','INS-3002-003','Manipal Hebbal','SLG-A003','SLG-N003','toileting','s','fabric_tear','installed','2026-06-04'::date,'2026-06-11'::date,8400,12,'Arjun Iyer',true),
('RPL-3002-002','INS-3002-005','Max Saket','SLG-A005','SLG-N005','stretcher','xxl','load_fail','signed_off','2026-06-06'::date,'2026-06-09'::date,18500,24,'Vikram Singh',true),
('RPL-3002-003','INS-3002-008','Hinduja Mahim','SLG-A008','SLG-N008','divided_leg','s','strap_fray','in_progress','2026-06-09'::date,null,7900,12,'Priya Joshi',false),
('RPL-3002-004','INS-3002-010','CMC Vellore','SLG-A010','SLG-N010','hammock','l','end_of_life','installed','2026-06-11'::date,'2026-06-13'::date,9600,18,'Sundar Pillai',true),
('RPL-3002-005','INS-3002-013','KIMS Kurnool','SLG-A013','SLG-N013','divided_leg','m','fabric_tear','dispatched','2026-06-14'::date,null,8200,12,'Lakshmi Devi',false),
('RPL-3002-006','INS-3002-016','Medanta Gurugram','SLG-A016','SLG-N016','universal_loop','m','label_missing','installed','2026-06-17'::date,'2026-06-22'::date,7600,12,'Naveen Yadav',true),
('RPL-3002-007','INS-3002-019','Apollo Greams','SLG-A019','SLG-N019','divided_leg','l','strap_fray','open','2026-06-20'::date,null,8300,12,'Karthik V',false),
('RPL-3002-008','INS-3002-005','Max Saket','SLG-A005-B','SLG-N005-B','stretcher','xl','recall','installed','2026-05-20'::date,'2026-05-27'::date,17800,24,'Vikram Singh',true),
('RPL-3002-009','INS-3002-003','Manipal Hebbal','SLG-A003-B','SLG-N003-B','toileting','m','buckle_broken','signed_off','2026-05-12'::date,'2026-05-18'::date,8500,12,'Arjun Iyer',true),
('RPL-3002-010','INS-3002-010','CMC Vellore','SLG-A010-B','SLG-N010-B','hammock','xl','customer_request','cancelled','2026-04-05'::date,null,0,12,'Sundar Pillai',false),
('RPL-3002-011','INS-3002-016','Medanta Gurugram','SLG-A016-C','SLG-N016-C','universal_loop','l','end_of_life','installed','2026-05-30'::date,'2026-06-04'::date,7900,18,'Naveen Yadav',true),
('RPL-3002-012','INS-3002-013','KIMS Kurnool','SLG-A013-B','SLG-N013-B','divided_leg','m','load_fail','installed','2026-05-08'::date,'2026-05-14'::date,8600,24,'Lakshmi Devi',true),
('RPL-3002-013','INS-3002-008','Hinduja Mahim','SLG-A008-B','SLG-N008-B','divided_leg','m','fabric_tear','signed_off','2026-04-22'::date,'2026-04-29'::date,8000,12,'Priya Joshi',true),
('RPL-3002-014','INS-3002-019','Apollo Greams','SLG-A019-B','SLG-N019-B','divided_leg','l','recall','installed','2026-05-15'::date,'2026-05-20'::date,8400,24,'Karthik V',true),
('RPL-3002-015','INS-3002-003','Manipal Hebbal','SLG-A003-C','SLG-N003-C','toileting','s','strap_fray','dispatched','2026-06-18'::date,null,8200,12,'Arjun Iyer',false),
('RPL-3002-016','INS-3002-010','CMC Vellore','SLG-A010-C','SLG-N010-C','hammock','l','end_of_life','open','2026-06-21'::date,null,9500,18,'Sundar Pillai',false);

revoke all on bath_lift_sling_inspections_r3002 from public, anon;
revoke all on bath_lift_sling_replacements_r3002 from public, anon;
grant select on bath_lift_sling_inspections_r3002 to authenticated;
grant select on bath_lift_sling_replacements_r3002 to authenticated;

-- RPC 1: Verdict distribution
create or replace function r3002_verdict_distribution()
returns table(verdict text, inspections int, replacement_required int, share_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select i.verdict,
         count(*)::int as inspections,
         (count(*) filter (where i.replacement_required))::int as replacement_required,
         round(100.0 * count(*) / nullif((select count(*) from bath_lift_sling_inspections_r3002),0), 2) as share_pct
  from bath_lift_sling_inspections_r3002 i
  group by i.verdict
  order by inspections desc;
end;$$;

-- RPC 2: City risk heatmap
create or replace function r3002_city_risk_heatmap()
returns table(hospital_city text, inspections int, fails int, condemns int, avg_fabric_wear numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select i.hospital_city,
         count(*)::int,
         (count(*) filter (where i.verdict='fail'))::int,
         (count(*) filter (where i.verdict='condemn'))::int,
         round(avg(i.fabric_wear_score)::numeric, 2)
  from bath_lift_sling_inspections_r3002 i
  group by i.hospital_city
  order by condemns desc, fails desc;
end;$$;

-- RPC 3: Engineer scorecard
create or replace function r3002_engineer_scorecard()
returns table(engineer_name text, inspections int, photos_avg numeric, pass_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select i.engineer_name,
         count(*)::int,
         round(avg(i.photos_uploaded)::numeric, 2),
         round(100.0 * (count(*) filter (where i.verdict='pass')) / nullif(count(*),0), 2)
  from bath_lift_sling_inspections_r3002 i
  group by i.engineer_name
  order by inspections desc;
end;$$;

-- RPC 4: Model fleet wear
create or replace function r3002_model_fleet_wear()
returns table(sling_model text, units int, avg_age_months numeric, avg_wear numeric, condemned int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select i.sling_model,
         count(*)::int,
         round(avg(i.age_months)::numeric, 1),
         round(avg(i.fabric_wear_score)::numeric, 2),
         (count(*) filter (where i.verdict='condemn'))::int
  from bath_lift_sling_inspections_r3002 i
  group by i.sling_model
  order by condemned desc;
end;$$;

-- RPC 5: Replacement pipeline
create or replace function r3002_replacement_pipeline()
returns table(status text, replacements int, cost_rupees_total bigint, avg_warranty_months numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select r.status,
         count(*)::int,
         sum(r.cost_rupees)::bigint,
         round(avg(r.warranty_months)::numeric, 1)
  from bath_lift_sling_replacements_r3002 r
  group by r.status
  order by replacements desc;
end;$$;

-- RPC 6: Reason breakdown
create or replace function r3002_replacement_reason_breakdown()
returns table(reason text, replacements int, signed_off int, open_or_progress int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select r.reason,
         count(*)::int,
         (count(*) filter (where r.status in ('signed_off','installed')))::int,
         (count(*) filter (where r.status in ('open','in_progress','dispatched')))::int
  from bath_lift_sling_replacements_r3002 r
  group by r.reason
  order by replacements desc;
end;$$;

-- RPC 7: Recent fails feed
create or replace function r3002_recent_fails_feed()
returns table(inspection_date date, customer_site text, sling_model text, verdict text, fabric_wear_score int, engineer_name text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select i.inspection_date, i.customer_site, i.sling_model, i.verdict, i.fabric_wear_score, i.engineer_name
  from bath_lift_sling_inspections_r3002 i
  where i.verdict in ('fail','condemn')
  order by i.inspection_date desc
  limit 30;
end;$$;

-- RPC 8: Load margin watch
create or replace function r3002_load_margin_watch()
returns table(customer_site text, sling_serial text, rated_load_kg int, load_test_kg int, margin_kg int, verdict text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select i.customer_site, i.sling_serial, i.rated_load_kg, i.load_test_kg,
         (i.load_test_kg - i.rated_load_kg)::int as margin_kg, i.verdict
  from bath_lift_sling_inspections_r3002 i
  order by margin_kg asc
  limit 25;
end;$$;

revoke all on function r3002_verdict_distribution() from public, anon;
revoke all on function r3002_city_risk_heatmap() from public, anon;
revoke all on function r3002_engineer_scorecard() from public, anon;
revoke all on function r3002_model_fleet_wear() from public, anon;
revoke all on function r3002_replacement_pipeline() from public, anon;
revoke all on function r3002_replacement_reason_breakdown() from public, anon;
revoke all on function r3002_recent_fails_feed() from public, anon;
revoke all on function r3002_load_margin_watch() from public, anon;

grant execute on function r3002_verdict_distribution() to authenticated;
grant execute on function r3002_city_risk_heatmap() to authenticated;
grant execute on function r3002_engineer_scorecard() to authenticated;
grant execute on function r3002_model_fleet_wear() to authenticated;
grant execute on function r3002_replacement_pipeline() to authenticated;
grant execute on function r3002_replacement_reason_breakdown() to authenticated;
grant execute on function r3002_recent_fails_feed() to authenticated;
grant execute on function r3002_load_margin_watch() to authenticated;
