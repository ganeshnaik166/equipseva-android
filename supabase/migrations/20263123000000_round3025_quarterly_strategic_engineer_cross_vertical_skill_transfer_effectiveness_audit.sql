-- Round 3025: Quarterly Strategic Engineer Cross-Vertical Skill Transfer Effectiveness Audit
-- HEAVY ★★★★ · Batch 430 milestone

create table if not exists engineer_cross_vertical_skill_transfers_r3025 (
  id uuid primary key default gen_random_uuid(),
  engineer_name text not null,
  source_vertical text not null check (source_vertical in ('dental','imaging','lab','sterilization','anesthesia','dialysis','ortho','cardio','endoscopy')),
  target_vertical text not null check (target_vertical in ('dental','imaging','lab','sterilization','anesthesia','dialysis','ortho','cardio','endoscopy')),
  transfer_quarter text not null check (transfer_quarter in ('Q1','Q2','Q3','Q4')),
  baseline_proficiency_score numeric(5,2) not null check (baseline_proficiency_score between 0 and 100),
  post_transfer_score numeric(5,2) not null check (post_transfer_score between 0 and 100),
  hours_invested int not null check (hours_invested >= 0),
  first_solo_job_at timestamptz,
  certified_at timestamptz,
  effectiveness_grade text not null check (effectiveness_grade in ('A','B','C','D','F')),
  retention_180d boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists engineer_cross_vertical_skill_transfer_quarterly_summaries_r3025 (
  id uuid primary key default gen_random_uuid(),
  quarter_label text not null check (quarter_label in ('Q1 2026','Q2 2026','Q3 2026','Q4 2026','Q1 2027')),
  vertical_pair text not null,
  transfers_attempted int not null check (transfers_attempted >= 0),
  transfers_certified int not null check (transfers_certified >= 0),
  avg_uplift_points numeric(6,2) not null,
  avg_hours_to_certify numeric(7,2) not null check (avg_hours_to_certify >= 0),
  roi_label text not null check (roi_label in ('excellent','strong','moderate','weak','negative')),
  notes text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table engineer_cross_vertical_skill_transfers_r3025 enable row level security;
alter table engineer_cross_vertical_skill_transfer_quarterly_summaries_r3025 enable row level security;

drop policy if exists ecvst_r3025_founder on engineer_cross_vertical_skill_transfers_r3025;
create policy ecvst_r3025_founder on engineer_cross_vertical_skill_transfers_r3025 for select using (is_founder());

drop policy if exists ecvstqs_r3025_founder on engineer_cross_vertical_skill_transfer_quarterly_summaries_r3025;
create policy ecvstqs_r3025_founder on engineer_cross_vertical_skill_transfer_quarterly_summaries_r3025 for select using (is_founder());

insert into engineer_cross_vertical_skill_transfers_r3025 (engineer_name, source_vertical, target_vertical, transfer_quarter, baseline_proficiency_score, post_transfer_score, hours_invested, first_solo_job_at, certified_at, effectiveness_grade, retention_180d)
select 'Ravi Kumar','dental','imaging','Q1',62.5,88.0,72,'2026-02-12T10:00:00Z'::timestamptz,'2026-03-04T09:00:00Z'::timestamptz,'A',true
union all select 'Priya Sharma','imaging','lab','Q1',55.0,82.5,90,'2026-02-20T11:00:00Z'::timestamptz,'2026-03-10T09:00:00Z'::timestamptz,'A',true
union all select 'Vikram Singh','lab','sterilization','Q1',48.0,71.0,110,'2026-02-25T10:00:00Z'::timestamptz,'2026-03-22T09:00:00Z'::timestamptz,'B',true
union all select 'Anita Desai','sterilization','anesthesia','Q1',60.0,79.5,85,'2026-03-01T10:00:00Z'::timestamptz,'2026-03-28T09:00:00Z'::timestamptz,'B',true
union all select 'Sunil Patel','anesthesia','dialysis','Q1',52.0,68.0,130,null::timestamptz,null::timestamptz,'C',false
union all select 'Meera Iyer','dental','ortho','Q2',70.0,91.0,60,'2026-04-15T10:00:00Z'::timestamptz,'2026-05-02T09:00:00Z'::timestamptz,'A',true
union all select 'Arjun Reddy','imaging','cardio','Q2',58.0,84.0,95,'2026-04-22T10:00:00Z'::timestamptz,'2026-05-14T09:00:00Z'::timestamptz,'A',true
union all select 'Kavita Joshi','lab','endoscopy','Q2',45.0,62.0,140,null::timestamptz,null::timestamptz,'D',false
union all select 'Rohit Mehta','sterilization','dental','Q2',65.0,86.0,70,'2026-05-10T10:00:00Z'::timestamptz,'2026-05-30T09:00:00Z'::timestamptz,'A',true
union all select 'Deepa Nair','anesthesia','imaging','Q2',50.0,74.0,100,'2026-05-18T10:00:00Z'::timestamptz,'2026-06-12T09:00:00Z'::timestamptz,'B',true
union all select 'Manoj Kapoor','dialysis','lab','Q2',42.0,55.0,150,null::timestamptz,null::timestamptz,'F',false
union all select 'Sneha Rao','ortho','sterilization','Q3',68.0,89.0,65,'2026-07-12T10:00:00Z'::timestamptz,'2026-08-01T09:00:00Z'::timestamptz,'A',true
union all select 'Karthik Menon','cardio','anesthesia','Q3',60.0,81.0,88,'2026-07-25T10:00:00Z'::timestamptz,'2026-08-18T09:00:00Z'::timestamptz,'B',true
union all select 'Lakshmi Pillai','endoscopy','dialysis','Q3',54.0,72.0,115,'2026-08-05T10:00:00Z'::timestamptz,'2026-09-02T09:00:00Z'::timestamptz,'B',true
union all select 'Ajay Verma','dental','cardio','Q3',72.0,93.0,55,'2026-08-15T10:00:00Z'::timestamptz,'2026-09-05T09:00:00Z'::timestamptz,'A',true
union all select 'Pooja Bhatia','imaging','endoscopy','Q3',56.0,69.0,135,null::timestamptz,null::timestamptz,'D',false
union all select 'Rahul Khanna','lab','ortho','Q4',58.0,80.0,80,'2026-10-22T10:00:00Z'::timestamptz,'2026-11-15T09:00:00Z'::timestamptz,'B',true
union all select 'Neha Saxena','sterilization','imaging','Q4',64.0,87.0,68,'2026-10-30T10:00:00Z'::timestamptz,'2026-11-22T09:00:00Z'::timestamptz,'A',true
union all select 'Vivek Choudhary','anesthesia','ortho','Q4',50.0,66.0,125,null::timestamptz,null::timestamptz,'C',false
union all select 'Asha Pandey','dialysis','endoscopy','Q4',46.0,58.0,160,null::timestamptz,null::timestamptz,'F',false;

insert into engineer_cross_vertical_skill_transfer_quarterly_summaries_r3025 (quarter_label, vertical_pair, transfers_attempted, transfers_certified, avg_uplift_points, avg_hours_to_certify, roi_label, notes, reviewed_at)
select 'Q1 2026','dental→imaging',4,4,25.5,75.0,'excellent','Strongest pair; visual diagnostic overlap','2026-04-02T10:00:00Z'::timestamptz
union all select 'Q1 2026','imaging→lab',3,2,18.0,92.0,'strong','Good transfer; assay calibration learning curve','2026-04-02T10:00:00Z'::timestamptz
union all select 'Q1 2026','lab→sterilization',3,2,15.5,105.0,'moderate','Workflow change non-trivial','2026-04-02T10:00:00Z'::timestamptz
union all select 'Q2 2026','dental→ortho',5,5,21.0,62.5,'excellent','Mechanical fit excellent','2026-07-04T10:00:00Z'::timestamptz
union all select 'Q2 2026','imaging→cardio',4,3,22.0,90.0,'strong','High value pair; protect investment','2026-07-04T10:00:00Z'::timestamptz
union all select 'Q2 2026','lab→endoscopy',2,0,12.0,140.0,'negative','Skill gap too wide; stop pairing','2026-07-04T10:00:00Z'::timestamptz
union all select 'Q2 2026','anesthesia→imaging',3,3,19.5,98.0,'strong','Anesthesia engineers electronics-savvy','2026-07-04T10:00:00Z'::timestamptz
union all select 'Q3 2026','ortho→sterilization',4,4,20.5,66.5,'excellent','Reverse pairing surprising winner','2026-10-04T10:00:00Z'::timestamptz
union all select 'Q3 2026','cardio→anesthesia',3,2,19.0,87.0,'strong','Critical-care domain overlap','2026-10-04T10:00:00Z'::timestamptz
union all select 'Q3 2026','endoscopy→dialysis',3,2,16.5,118.0,'moderate','Fluid-handling overlap helps','2026-10-04T10:00:00Z'::timestamptz
union all select 'Q4 2026','lab→ortho',3,2,17.0,82.0,'moderate','Limited but workable','2027-01-05T10:00:00Z'::timestamptz
union all select 'Q4 2026','sterilization→imaging',3,3,21.5,70.0,'excellent','High retention; promote pair','2027-01-05T10:00:00Z'::timestamptz
union all select 'Q4 2026','dialysis→endoscopy',2,0,11.0,160.0,'negative','Discontinue this pairing','2027-01-05T10:00:00Z'::timestamptz
union all select 'Q1 2027','dental→cardio',2,2,23.0,58.0,'excellent','Early pilot looking great',null::timestamptz;

revoke all on engineer_cross_vertical_skill_transfers_r3025 from public, anon;
revoke all on engineer_cross_vertical_skill_transfer_quarterly_summaries_r3025 from public, anon;
grant select on engineer_cross_vertical_skill_transfers_r3025 to authenticated;
grant select on engineer_cross_vertical_skill_transfer_quarterly_summaries_r3025 to authenticated;

create or replace function r3025_list_transfers()
returns setof engineer_cross_vertical_skill_transfers_r3025
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select * from engineer_cross_vertical_skill_transfers_r3025 order by created_at desc;
end;
$$;

create or replace function r3025_grade_distribution()
returns table(grade text, transfers int, avg_uplift numeric, retained int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select effectiveness_grade,
           count(*)::int,
           round(avg(post_transfer_score - baseline_proficiency_score)::numeric, 2),
           (count(*) filter (where retention_180d))::int
    from engineer_cross_vertical_skill_transfers_r3025
    group by effectiveness_grade
    order by effectiveness_grade;
end;
$$;

create or replace function r3025_quarter_summary()
returns table(transfer_quarter text, attempts int, certified int, avg_hours numeric, a_grade int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select t.transfer_quarter,
           count(*)::int,
           (count(*) filter (where t.certified_at is not null))::int,
           round(avg(t.hours_invested)::numeric, 1),
           (count(*) filter (where t.effectiveness_grade = 'A'))::int
    from engineer_cross_vertical_skill_transfers_r3025 t
    group by t.transfer_quarter
    order by t.transfer_quarter;
end;
$$;

create or replace function r3025_top_pairings()
returns table(pairing text, attempts int, avg_uplift numeric, cert_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select t.source_vertical || ' -> ' || t.target_vertical,
           count(*)::int,
           round(avg(t.post_transfer_score - t.baseline_proficiency_score)::numeric, 2),
           round((100.0 * (count(*) filter (where t.certified_at is not null))::numeric / nullif(count(*),0))::numeric, 1)
    from engineer_cross_vertical_skill_transfers_r3025 t
    group by t.source_vertical, t.target_vertical
    order by avg(t.post_transfer_score - t.baseline_proficiency_score) desc nulls last
    limit 10;
end;
$$;

create or replace function r3025_quarterly_summaries()
returns setof engineer_cross_vertical_skill_transfer_quarterly_summaries_r3025
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select * from engineer_cross_vertical_skill_transfer_quarterly_summaries_r3025 order by quarter_label, vertical_pair;
end;
$$;

create or replace function r3025_roi_breakdown()
returns table(roi_label text, pairs int, total_attempts int, total_certified int, avg_uplift numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.roi_label,
           count(*)::int,
           sum(s.transfers_attempted)::int,
           sum(s.transfers_certified)::int,
           round(avg(s.avg_uplift_points)::numeric, 2)
    from engineer_cross_vertical_skill_transfer_quarterly_summaries_r3025 s
    group by s.roi_label
    order by case s.roi_label
      when 'excellent' then 1 when 'strong' then 2 when 'moderate' then 3 when 'weak' then 4 when 'negative' then 5
    end;
end;
$$;

create or replace function r3025_kpi_overview()
returns table(metric text, value text)
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_total int; v_cert int; v_retain int; v_avg numeric; v_hours numeric; v_pairs int;
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  select count(*), (count(*) filter (where certified_at is not null)), (count(*) filter (where retention_180d)),
         round(avg(post_transfer_score - baseline_proficiency_score)::numeric, 2),
         round(avg(hours_invested)::numeric, 1)
    into v_total, v_cert, v_retain, v_avg, v_hours
    from engineer_cross_vertical_skill_transfers_r3025;
  select count(distinct vertical_pair) into v_pairs from engineer_cross_vertical_skill_transfer_quarterly_summaries_r3025;
  return query
    select 'Total Transfers'::text, v_total::text
    union all select 'Certified', v_cert::text
    union all select 'Retained 180d', v_retain::text
    union all select 'Avg Uplift (pts)', coalesce(v_avg,0)::text
    union all select 'Avg Hours Invested', coalesce(v_hours,0)::text
    union all select 'Distinct Vertical Pairs', v_pairs::text;
end;
$$;

revoke all on function r3025_list_transfers() from public, anon;
revoke all on function r3025_grade_distribution() from public, anon;
revoke all on function r3025_quarter_summary() from public, anon;
revoke all on function r3025_top_pairings() from public, anon;
revoke all on function r3025_quarterly_summaries() from public, anon;
revoke all on function r3025_roi_breakdown() from public, anon;
revoke all on function r3025_kpi_overview() from public, anon;

grant execute on function r3025_list_transfers() to authenticated;
grant execute on function r3025_grade_distribution() to authenticated;
grant execute on function r3025_quarter_summary() to authenticated;
grant execute on function r3025_top_pairings() to authenticated;
grant execute on function r3025_quarterly_summaries() to authenticated;
grant execute on function r3025_roi_breakdown() to authenticated;
grant execute on function r3025_kpi_overview() to authenticated;
