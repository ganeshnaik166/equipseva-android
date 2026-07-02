-- Round 2946 — Engineer Monthly Customer Site VIP-Hospital Service-Quality Recognition Tracker
-- Two tables suffixed _r2946 + 7 founder-gated RPCs.

create table if not exists engineer_vip_site_recognition_r2946 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  month_label text not null,
  engineer_code text not null,
  engineer_name text not null,
  hospital_name text not null,
  vip_tier text not null check (vip_tier in ('platinum','gold','silver','bronze')),
  site_visits int not null default 0,
  csat_score numeric(4,2) not null default 0,
  first_visit_fix_pct numeric(5,2) not null default 0,
  sla_adherence_pct numeric(5,2) not null default 0,
  uptime_pct numeric(5,2) not null default 0,
  quality_score numeric(6,2) not null default 0,
  recognition_band text not null check (recognition_band in ('elite','excellent','good','watchlist')),
  bonus_rupees int not null default 0,
  status text not null default 'pending' check (status in ('pending','approved','paid','disputed'))
);

create table if not exists vip_recognition_events_r2946 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  recognition_id uuid references engineer_vip_site_recognition_r2946(id) on delete cascade,
  event_type text not null check (event_type in ('praise','complaint','escalation','spot_audit','client_letter')),
  event_date date not null,
  source_hospital text not null,
  weight int not null default 1,
  notes text
);

alter table engineer_vip_site_recognition_r2946 enable row level security;
alter table vip_recognition_events_r2946 enable row level security;

revoke all on engineer_vip_site_recognition_r2946 from public, anon;
revoke all on vip_recognition_events_r2946 from public, anon;
grant select on engineer_vip_site_recognition_r2946 to authenticated;
grant select on vip_recognition_events_r2946 to authenticated;

drop policy if exists vsr_r2946_founder_sel on engineer_vip_site_recognition_r2946;
create policy vsr_r2946_founder_sel on engineer_vip_site_recognition_r2946 for select to authenticated using (is_founder());

drop policy if exists vre_r2946_founder_sel on vip_recognition_events_r2946;
create policy vre_r2946_founder_sel on vip_recognition_events_r2946 for select to authenticated using (is_founder());

insert into engineer_vip_site_recognition_r2946 (month_label, engineer_code, engineer_name, hospital_name, vip_tier, site_visits, csat_score, first_visit_fix_pct, sla_adherence_pct, uptime_pct, quality_score, recognition_band, bonus_rupees, status) values
('2026-06','ENG-001','Ravi Kumar','Apollo Hyderabad','platinum',18,4.92,96.0,99.0,99.5,97.20,'elite',15000,'paid'),
('2026-06','ENG-002','Priya Sharma','Yashoda Secunderabad','platinum',16,4.88,94.5,98.0,99.0,96.10,'elite',14000,'paid'),
('2026-06','ENG-003','Suresh Babu','KIMS Hospitals','gold',14,4.70,90.0,95.5,98.0,93.40,'excellent',9000,'approved'),
('2026-06','ENG-004','Anjali Reddy','Continental Gachibowli','gold',15,4.65,89.0,94.0,97.5,92.10,'excellent',9000,'approved'),
('2026-06','ENG-005','Vikram Singh','Care Banjara','silver',12,4.40,85.0,90.0,95.0,88.30,'good',5000,'approved'),
('2026-06','ENG-006','Deepa Iyer','Star Hospitals','silver',11,4.35,83.0,89.0,94.5,87.20,'good',5000,'pending'),
('2026-06','ENG-007','Manoj Pillai','AIG Hospitals','platinum',17,4.90,95.0,98.5,99.2,96.80,'elite',14500,'paid'),
('2026-06','ENG-008','Kavya Nair','Rainbow Childrens','gold',13,4.55,87.5,93.0,96.5,91.10,'excellent',8500,'approved'),
('2026-06','ENG-009','Rohit Verma','Olive Hospital','bronze',9,4.10,78.0,85.0,92.0,82.50,'good',2500,'pending'),
('2026-06','ENG-010','Sneha Joshi','Sunshine Secunderabad','silver',12,4.30,82.0,88.5,94.0,86.70,'good',4500,'approved'),
('2026-06','ENG-011','Arjun Mehta','Medicover','gold',14,4.60,88.0,93.5,96.8,91.70,'excellent',8800,'paid'),
('2026-06','ENG-012','Lakshmi Rao','Citizens Hospital','bronze',8,3.80,72.0,80.0,89.0,77.10,'watchlist',0,'disputed'),
('2026-06','ENG-013','Pranav Desai','Virinchi','silver',11,4.25,81.0,87.0,93.5,85.60,'good',4200,'approved'),
('2026-06','ENG-014','Divya Pillai','Asian Institute','gold',13,4.50,86.5,92.5,96.0,90.40,'excellent',8200,'approved'),
('2026-06','ENG-015','Karthik Rao','SLG Hospitals','platinum',16,4.85,93.0,97.0,98.5,95.30,'elite',13500,'paid'),
('2026-06','ENG-016','Meera Krishnan','Renova','silver',10,4.20,80.0,86.5,93.0,84.90,'good',4000,'pending'),
('2026-06','ENG-017','Sanjay Gupta','Pranaam','bronze',7,3.60,68.0,76.0,86.0,73.40,'watchlist',0,'pending'),
('2026-06','ENG-018','Aishwarya Menon','Aster Prime','gold',14,4.62,88.5,93.8,96.9,91.90,'excellent',8900,'approved');

insert into vip_recognition_events_r2946 (recognition_id, event_type, event_date, source_hospital, weight, notes)
select id, 'praise','2026-06-05'::date,'Apollo Hyderabad',3,'CIO sent thank-you letter' from engineer_vip_site_recognition_r2946 where engineer_code='ENG-001'
union all select id,'spot_audit','2026-06-12'::date,'Apollo Hyderabad',2,'5/5 on tools' from engineer_vip_site_recognition_r2946 where engineer_code='ENG-001'
union all select id,'praise','2026-06-08'::date,'Yashoda Secunderabad',3,'Saved emergency surgery' from engineer_vip_site_recognition_r2946 where engineer_code='ENG-002'
union all select id,'client_letter','2026-06-18'::date,'Yashoda Secunderabad',4,'Director letter of appreciation' from engineer_vip_site_recognition_r2946 where engineer_code='ENG-002'
union all select id,'praise','2026-06-09'::date,'KIMS Hospitals',2,'Polite + on-time' from engineer_vip_site_recognition_r2946 where engineer_code='ENG-003'
union all select id,'praise','2026-06-11'::date,'Continental',2,'Quick MRI fix' from engineer_vip_site_recognition_r2946 where engineer_code='ENG-004'
union all select id,'spot_audit','2026-06-14'::date,'Care Banjara',2,'4/5 audit' from engineer_vip_site_recognition_r2946 where engineer_code='ENG-005'
union all select id,'complaint','2026-06-19'::date,'Star Hospitals',2,'Late by 40 min' from engineer_vip_site_recognition_r2946 where engineer_code='ENG-006'
union all select id,'praise','2026-06-03'::date,'AIG Hospitals',3,'Recommended by GI lead' from engineer_vip_site_recognition_r2946 where engineer_code='ENG-007'
union all select id,'client_letter','2026-06-22'::date,'AIG Hospitals',4,'COO commendation' from engineer_vip_site_recognition_r2946 where engineer_code='ENG-007'
union all select id,'praise','2026-06-07'::date,'Rainbow Childrens',2,'Kid-friendly demeanor' from engineer_vip_site_recognition_r2946 where engineer_code='ENG-008'
union all select id,'escalation','2026-06-16'::date,'Olive Hospital',3,'Missed SLA window' from engineer_vip_site_recognition_r2946 where engineer_code='ENG-009'
union all select id,'praise','2026-06-04'::date,'Medicover',2,'Cleared 3-day backlog' from engineer_vip_site_recognition_r2946 where engineer_code='ENG-011'
union all select id,'complaint','2026-06-13'::date,'Citizens Hospital',3,'Rude with nursing staff' from engineer_vip_site_recognition_r2946 where engineer_code='ENG-012'
union all select id,'escalation','2026-06-20'::date,'Citizens Hospital',4,'CMO escalation' from engineer_vip_site_recognition_r2946 where engineer_code='ENG-012'
union all select id,'praise','2026-06-06'::date,'SLG Hospitals',3,'Trained on-site team' from engineer_vip_site_recognition_r2946 where engineer_code='ENG-015'
union all select id,'spot_audit','2026-06-17'::date,'SLG Hospitals',2,'5/5 audit' from engineer_vip_site_recognition_r2946 where engineer_code='ENG-015'
union all select id,'complaint','2026-06-21'::date,'Pranaam',3,'Tools missing' from engineer_vip_site_recognition_r2946 where engineer_code='ENG-017'
union all select id,'praise','2026-06-10'::date,'Aster Prime',2,'On-call weekend save' from engineer_vip_site_recognition_r2946 where engineer_code='ENG-018';

-- 1
create or replace function vip_recognition_overview_r2946()
returns table(total_engineers int, elite_count int, watchlist_count int, avg_quality numeric, total_bonus_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select count(*)::int,
           (count(*) filter (where recognition_band='elite'))::int,
           (count(*) filter (where recognition_band='watchlist'))::int,
           round(avg(quality_score)::numeric, 2),
           sum(bonus_rupees)::bigint
    from engineer_vip_site_recognition_r2946;
end; $$;

-- 2
create or replace function vip_recognition_top_engineers_r2946()
returns table(engineer_code text, engineer_name text, hospital_name text, vip_tier text, quality_score numeric, bonus_rupees int, recognition_band text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select r.engineer_code, r.engineer_name, r.hospital_name, r.vip_tier, r.quality_score, r.bonus_rupees, r.recognition_band
    from engineer_vip_site_recognition_r2946 r
    order by r.quality_score desc
    limit 10;
end; $$;

-- 3
create or replace function vip_recognition_band_breakdown_r2946()
returns table(recognition_band text, n int, avg_quality numeric, total_bonus bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select r.recognition_band, count(*)::int, round(avg(r.quality_score)::numeric,2), sum(r.bonus_rupees)::bigint
    from engineer_vip_site_recognition_r2946 r
    group by r.recognition_band
    order by avg(r.quality_score) desc;
end; $$;

-- 4
create or replace function vip_recognition_tier_breakdown_r2946()
returns table(vip_tier text, engineers int, avg_csat numeric, avg_fvfr numeric, avg_uptime numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select r.vip_tier, count(*)::int, round(avg(r.csat_score)::numeric,2), round(avg(r.first_visit_fix_pct)::numeric,2), round(avg(r.uptime_pct)::numeric,2)
    from engineer_vip_site_recognition_r2946 r
    group by r.vip_tier
    order by avg(r.csat_score) desc;
end; $$;

-- 5
create or replace function vip_recognition_event_summary_r2946()
returns table(event_type text, events int, total_weight int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select e.event_type, count(*)::int, sum(e.weight)::int
    from vip_recognition_events_r2946 e
    group by e.event_type
    order by count(*) desc;
end; $$;

-- 6
create or replace function vip_recognition_watchlist_r2946()
returns table(engineer_code text, engineer_name text, hospital_name text, quality_score numeric, complaints int, escalations int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select r.engineer_code, r.engineer_name, r.hospital_name, r.quality_score,
           (count(e.*) filter (where e.event_type='complaint'))::int,
           (count(e.*) filter (where e.event_type='escalation'))::int
    from engineer_vip_site_recognition_r2946 r
    left join vip_recognition_events_r2946 e on e.recognition_id = r.id
    where r.recognition_band in ('watchlist','good')
    group by r.engineer_code, r.engineer_name, r.hospital_name, r.quality_score
    order by r.quality_score asc
    limit 12;
end; $$;

-- 7
create or replace function vip_recognition_payout_status_r2946()
returns table(status text, n int, total_bonus bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select r.status, count(*)::int, sum(r.bonus_rupees)::bigint
    from engineer_vip_site_recognition_r2946 r
    group by r.status
    order by sum(r.bonus_rupees) desc;
end; $$;

revoke all on function vip_recognition_overview_r2946() from public, anon;
revoke all on function vip_recognition_top_engineers_r2946() from public, anon;
revoke all on function vip_recognition_band_breakdown_r2946() from public, anon;
revoke all on function vip_recognition_tier_breakdown_r2946() from public, anon;
revoke all on function vip_recognition_event_summary_r2946() from public, anon;
revoke all on function vip_recognition_watchlist_r2946() from public, anon;
revoke all on function vip_recognition_payout_status_r2946() from public, anon;

grant execute on function vip_recognition_overview_r2946() to authenticated;
grant execute on function vip_recognition_top_engineers_r2946() to authenticated;
grant execute on function vip_recognition_band_breakdown_r2946() to authenticated;
grant execute on function vip_recognition_tier_breakdown_r2946() to authenticated;
grant execute on function vip_recognition_event_summary_r2946() to authenticated;
grant execute on function vip_recognition_watchlist_r2946() to authenticated;
grant execute on function vip_recognition_payout_status_r2946() to authenticated;
