-- r3105 founder personal annual health checkup + cognitive reserve tracker
-- founder-gated. tracks blood panel, cardiac, cognitive battery, sleep, burnout, recovery.

create table if not exists founder_health_checkup_panels_r3105 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  panel_date date not null,
  panel_type text not null check (panel_type in (
    'annual_blood_panel','cardiac_stress','cognitive_battery',
    'sleep_polysomnography','burnout_markers','vo2max_fitness',
    'metabolic_screen','hormone_panel'
  )),
  vendor_lab text not null,
  vendor_city text not null check (vendor_city in (
    'hyderabad','bengaluru','chennai','mumbai','delhi','pune','kolkata'
  )),
  cost_rupees integer not null check (cost_rupees >= 0),
  fasting_required boolean not null default false,
  result_status text not null check (result_status in (
    'green_optimal','yellow_watch','orange_action','red_critical','pending_results'
  )),
  headline_metric text not null,
  headline_value numeric(10,2) not null,
  reference_low numeric(10,2),
  reference_high numeric(10,2),
  unit text not null,
  trend_vs_last_year text not null check (trend_vs_last_year in (
    'improving','stable','declining','first_baseline'
  )),
  doctor_note text,
  follow_up_required boolean not null default false,
  follow_up_by date,
  cognitive_reserve_score integer check (cognitive_reserve_score between 0 and 100),
  created_at timestamptz not null default now()
);

create table if not exists founder_health_recovery_actions_r3105 (
  id uuid primary key default gen_random_uuid(),
  panel_id uuid not null references founder_health_checkup_panels_r3105(id) on delete cascade,
  action_category text not null check (action_category in (
    'medication','supplement','sleep_hygiene','exercise_rx',
    'diet_change','meditation','therapy','specialist_referral','retest_schedule'
  )),
  action_title text not null,
  prescribed_by text not null,
  priority text not null check (priority in ('p0_now','p1_this_week','p2_this_month','p3_quarterly')),
  start_date date not null,
  target_review_date date not null,
  adherence_percent integer not null default 0 check (adherence_percent between 0 and 100),
  outcome_status text not null check (outcome_status in (
    'not_started','in_progress','on_track','off_track','completed','abandoned'
  )),
  daily_minutes_required integer check (daily_minutes_required >= 0),
  monthly_cost_rupees integer not null default 0 check (monthly_cost_rupees >= 0),
  burnout_impact_score integer check (burnout_impact_score between -10 and 10),
  cognitive_impact_score integer check (cognitive_impact_score between -10 and 10),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_fhcp_r3105_org on founder_health_checkup_panels_r3105(organization_id);
create index if not exists idx_fhcp_r3105_date on founder_health_checkup_panels_r3105(panel_date desc);
create index if not exists idx_fhra_r3105_panel on founder_health_recovery_actions_r3105(panel_id);

-- seed
with org as (select id from organizations order by created_at limit 1)
insert into founder_health_checkup_panels_r3105(
  organization_id, panel_date, panel_type, vendor_lab, vendor_city, cost_rupees,
  fasting_required, result_status, headline_metric, headline_value,
  reference_low, reference_high, unit, trend_vs_last_year,
  doctor_note, follow_up_required, follow_up_by, cognitive_reserve_score
)
select org.id, d.panel_date, d.panel_type, d.vendor_lab, d.vendor_city, d.cost_rupees,
       d.fasting_required, d.result_status, d.headline_metric, d.headline_value,
       d.ref_low, d.ref_high, d.unit, d.trend, d.note, d.follow_up, d.follow_up_by, d.cog
from org, (values
  ('2026-01-15'::date,'annual_blood_panel','Apollo Diagnostics','hyderabad',4500,true,'yellow_watch','LDL Cholesterol',132.0,0,100,'mg/dL','declining','LDL drifting up; start dietary intervention before statin.',true,'2026-04-15'::date,82),
  ('2026-01-20'::date,'cardiac_stress','KIMS Heart Institute','hyderabad',8500,false,'green_optimal','VO2 Max',46.5,40,55,'mL/kg/min','improving','Excellent cardio reserve for 38yr male founder.',false,null,85),
  ('2026-02-05'::date,'cognitive_battery','NIMHANS Cognitive Clinic','bengaluru',12000,false,'green_optimal','Working Memory Index',128.0,90,130,'standard_score','stable','Top 4% for age — protect with sleep + novelty.',false,null,92),
  ('2026-02-18'::date,'sleep_polysomnography','Apollo Sleep Lab','chennai',15500,false,'orange_action','Sleep Efficiency',71.5,85,100,'percent','declining','Mild OSA suspected — AHI 11.2; CPAP trial recommended.',true,'2026-03-18'::date,68),
  ('2026-03-02'::date,'burnout_markers','Practo Wellness Lab','mumbai',6800,true,'orange_action','Morning Cortisol',24.5,5,18,'ug/dL','declining','Cortisol elevated — chronic stress signal; reduce on-call load.',true,'2026-04-02'::date,71),
  ('2026-03-15'::date,'vo2max_fitness','Cult.fit Diagnostics','bengaluru',3500,false,'green_optimal','Resting Heart Rate',58.0,50,70,'bpm','improving','Trained athlete range — keep zone-2 base.',false,null,88),
  ('2026-04-10'::date,'metabolic_screen','Thyrocare','mumbai',2900,true,'yellow_watch','HbA1c',5.6,4.0,5.6,'percent','stable','Upper edge of normal — watch carbs post-dinner.',true,'2026-07-10'::date,80),
  ('2026-04-25'::date,'hormone_panel','Lal PathLabs','delhi',5200,true,'green_optimal','Testosterone Total',612.0,300,1000,'ng/dL','stable','Healthy mid-range; deep sleep is keeping this anchored.',false,null,84),
  ('2026-05-12'::date,'annual_blood_panel','Apollo Diagnostics','hyderabad',4500,true,'yellow_watch','Vitamin D',22.0,30,80,'ng/mL','declining','Deficient — D3 5000IU + 15min sun daily.',true,'2026-08-12'::date,78),
  ('2026-05-28'::date,'cognitive_battery','NIMHANS Cognitive Clinic','bengaluru',12000,false,'yellow_watch','Sustained Attention',104.0,90,130,'standard_score','declining','12pt drop YoY — burnout signal; protect deep work blocks.',true,'2026-08-28'::date,76),
  ('2026-06-05'::date,'sleep_polysomnography','Apollo Sleep Lab','chennai',15500,false,'yellow_watch','REM Percentage',16.5,20,25,'percent','improving','REM still suppressed but trending up with CPAP.',true,'2026-09-05'::date,79),
  ('2026-06-15'::date,'burnout_markers','Practo Wellness Lab','mumbai',6800,true,'green_optimal','Maslach Burnout Inventory',38.0,0,50,'composite','improving','Down from 54 — sabbatical + delegation working.',false,null,86),
  ('2026-06-18'::date,'cardiac_stress','KIMS Heart Institute','hyderabad',8500,false,'green_optimal','Ejection Fraction',62.0,55,70,'percent','stable','Normal LV function; arterial age = 32 (chrono 38).',false,null,87)
) as d(panel_date,panel_type,vendor_lab,vendor_city,cost_rupees,fasting_required,result_status,headline_metric,headline_value,ref_low,ref_high,unit,trend,note,follow_up,follow_up_by,cog);

insert into founder_health_recovery_actions_r3105(
  panel_id, action_category, action_title, prescribed_by, priority,
  start_date, target_review_date, adherence_percent, outcome_status,
  daily_minutes_required, monthly_cost_rupees, burnout_impact_score,
  cognitive_impact_score, notes
)
select p.id, d.cat, d.title, d.doc, d.pri, d.start_d, d.review_d, d.adh, d.outcome,
       d.mins, d.cost, d.burnout, d.cog, d.notes
from founder_health_checkup_panels_r3105 p
join (values
  ('LDL Cholesterol','diet_change','Mediterranean diet + 35g daily fiber','Dr. Ravi Kumar (Apollo)','p1_this_week','2026-01-22'::date,'2026-04-22'::date,78,'on_track',30,8500,2,3,'Tracked via MyPlate; LDL re-check April.'),
  ('VO2 Max','exercise_rx','Zone-2 60min × 4/wk + 1 VO2 interval session','Dr. Sridhar (KIMS)','p2_this_month','2026-01-25'::date,'2026-07-25'::date,92,'on_track',60,2000,4,5,'Garmin HR strap; love it.'),
  ('Working Memory Index','meditation','20min daily Sam Harris Waking Up','Dr. Mathew (NIMHANS)','p2_this_month','2026-02-10'::date,'2026-05-10'::date,65,'in_progress',20,500,5,6,'Streak broken once a week; need to rebuild.'),
  ('Sleep Efficiency','specialist_referral','CPAP titration + ENT consult','Dr. Rao (Apollo Sleep)','p0_now','2026-02-25'::date,'2026-03-25'::date,88,'on_track',null,12000,7,7,'AHI dropped 11.2 -> 3.1 after 3 weeks.'),
  ('Sleep Efficiency','sleep_hygiene','Hard 22:00 lights-out + no screens after 21:00','Dr. Rao (Apollo Sleep)','p1_this_week','2026-02-25'::date,'2026-05-25'::date,71,'on_track',null,0,6,8,'Toughest part: investor calls past 21:00.'),
  ('Morning Cortisol','therapy','Weekly CBT 50min — burnout focus','Dr. Anjali Pillai (Practo)','p1_this_week','2026-03-10'::date,'2026-09-10'::date,85,'on_track',50,8000,9,4,'Delegating on-call to senior engineers helping.'),
  ('Morning Cortisol','sleep_hygiene','Annual 14-day sabbatical Q2 mandatory','Self / Co-founder','p2_this_month','2026-04-15'::date,'2026-05-01'::date,100,'completed',null,75000,10,7,'Coorg sabbatical 2026-04-20 to 2026-05-04 done.'),
  ('Resting Heart Rate','exercise_rx','Maintain base — strength 2/wk added','Dr. Sridhar (KIMS)','p3_quarterly','2026-03-20'::date,'2026-09-20'::date,80,'on_track',45,3500,3,3,'Added kettlebell — grip strength up.'),
  ('HbA1c','diet_change','Drop refined carbs post-19:00','Dr. Ravi Kumar (Apollo)','p2_this_month','2026-04-15'::date,'2026-07-15'::date,58,'off_track',null,0,2,2,'Late investor dinners break this.'),
  ('Testosterone Total','supplement','Zinc 25mg + Mg glycinate 400mg nightly','Dr. Bharti (Lal Path)','p3_quarterly','2026-04-28'::date,'2026-10-28'::date,90,'on_track',null,650,2,3,'Sleep improved too — magnesium helping.'),
  ('Vitamin D','supplement','D3 5000IU daily + K2 100mcg + 15min morning sun','Dr. Ravi Kumar (Apollo)','p1_this_week','2026-05-15'::date,'2026-08-15'::date,95,'on_track',15,400,3,3,'Easy win.'),
  ('Sustained Attention','meditation','Single-tasking block 09:00-11:00 — no Slack','Dr. Mathew (NIMHANS)','p0_now','2026-06-01'::date,'2026-08-30'::date,62,'in_progress',120,0,6,9,'Hardest behavior change — needs ops calendar lock.'),
  ('REM Percentage','medication','Trazodone 25mg PRN max 2/wk','Dr. Rao (Apollo Sleep)','p3_quarterly','2026-06-08'::date,'2026-12-08'::date,40,'in_progress',null,350,4,3,'Use sparingly; not for nightly.'),
  ('Maslach Burnout Inventory','therapy','Continue CBT + add monthly retro w/ exec coach','Dr. Anjali Pillai (Practo)','p2_this_month','2026-06-20'::date,'2026-12-20'::date,75,'on_track',60,15000,8,6,'Down 16 points YoY — sustained.'),
  ('Ejection Fraction','exercise_rx','Annual cardiac MRI added to baseline','Dr. Sridhar (KIMS)','p3_quarterly','2026-06-22'::date,'2027-06-22'::date,100,'completed',null,18500,2,2,'Baseline established for arterial age tracking.')
) as d(metric_match,cat,title,doc,pri,start_d,review_d,adh,outcome,mins,cost,burnout,cog,notes)
  on p.headline_metric = d.metric_match;

-- RPCs
create or replace function r3105_panels_overview()
returns table(panel_type text, panels_count bigint, total_cost_rupees bigint, avg_cog_score numeric, red_or_orange bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.panel_type, count(*)::bigint, sum(p.cost_rupees)::bigint,
         round(avg(p.cognitive_reserve_score)::numeric,1),
         count(*) filter (where p.result_status in ('red_critical','orange_action'))::bigint
  from founder_health_checkup_panels_r3105 p
  group by p.panel_type
  order by sum(p.cost_rupees) desc;
end$$;

create or replace function r3105_status_distribution()
returns table(result_status text, panels_count bigint, share_pct numeric, avg_cog numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
declare total_n bigint;
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  select count(*) into total_n from founder_health_checkup_panels_r3105;
  return query
  select p.result_status, count(*)::bigint,
         round(100.0*count(*)/nullif(total_n,0),1),
         round(avg(p.cognitive_reserve_score)::numeric,1)
  from founder_health_checkup_panels_r3105 p
  group by p.result_status
  order by count(*) desc;
end$$;

create or replace function r3105_trend_breakdown()
returns table(trend_vs_last_year text, panels_count bigint, panel_types text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.trend_vs_last_year, count(*)::bigint,
         string_agg(distinct p.panel_type, ', ' order by p.panel_type)
  from founder_health_checkup_panels_r3105 p
  group by p.trend_vs_last_year
  order by count(*) desc;
end$$;

create or replace function r3105_follow_ups_due()
returns table(panel_date date, panel_type text, headline_metric text, follow_up_by date, days_until integer, result_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.panel_date, p.panel_type, p.headline_metric, p.follow_up_by,
         (p.follow_up_by - current_date)::integer, p.result_status
  from founder_health_checkup_panels_r3105 p
  where p.follow_up_required = true
  order by p.follow_up_by asc;
end$$;

create or replace function r3105_recovery_action_rollup()
returns table(action_category text, actions_count bigint, avg_adherence numeric, monthly_cost_rupees bigint, sum_burnout_impact integer, sum_cog_impact integer)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.action_category, count(*)::bigint,
         round(avg(a.adherence_percent)::numeric,1),
         sum(a.monthly_cost_rupees)::bigint,
         coalesce(sum(a.burnout_impact_score),0)::integer,
         coalesce(sum(a.cognitive_impact_score),0)::integer
  from founder_health_recovery_actions_r3105 a
  group by a.action_category
  order by sum(a.monthly_cost_rupees) desc;
end$$;

create or replace function r3105_priority_actions()
returns table(priority text, actions_count bigint, on_track_count bigint, off_track_count bigint, avg_adherence numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.priority, count(*)::bigint,
         count(*) filter (where a.outcome_status in ('on_track','completed'))::bigint,
         count(*) filter (where a.outcome_status in ('off_track','abandoned'))::bigint,
         round(avg(a.adherence_percent)::numeric,1)
  from founder_health_recovery_actions_r3105 a
  group by a.priority
  order by case a.priority
    when 'p0_now' then 1 when 'p1_this_week' then 2
    when 'p2_this_month' then 3 when 'p3_quarterly' then 4 end;
end$$;

create or replace function r3105_top_at_risk_metrics()
returns table(panel_date date, panel_type text, headline_metric text, headline_value numeric, reference_high numeric, unit text, result_status text, trend text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.panel_date, p.panel_type, p.headline_metric, p.headline_value,
         p.reference_high, p.unit, p.result_status, p.trend_vs_last_year
  from founder_health_checkup_panels_r3105 p
  where p.result_status in ('orange_action','red_critical','yellow_watch')
  order by case p.result_status
    when 'red_critical' then 1 when 'orange_action' then 2
    when 'yellow_watch' then 3 else 4 end, p.panel_date desc
  limit 10;
end$$;

create or replace function r3105_vendor_spend()
returns table(vendor_lab text, vendor_city text, panels_count bigint, total_spend_rupees bigint, last_visit date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.vendor_lab, p.vendor_city, count(*)::bigint,
         sum(p.cost_rupees)::bigint, max(p.panel_date)
  from founder_health_checkup_panels_r3105 p
  group by p.vendor_lab, p.vendor_city
  order by sum(p.cost_rupees) desc;
end$$;

create or replace function r3105_cognitive_reserve_timeline()
returns table(panel_date date, panel_type text, cognitive_reserve_score integer, result_status text, trend text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.panel_date, p.panel_type, p.cognitive_reserve_score,
         p.result_status, p.trend_vs_last_year
  from founder_health_checkup_panels_r3105 p
  order by p.panel_date asc;
end$$;

revoke execute on function r3105_panels_overview() from public, anon;
revoke execute on function r3105_status_distribution() from public, anon;
revoke execute on function r3105_trend_breakdown() from public, anon;
revoke execute on function r3105_follow_ups_due() from public, anon;
revoke execute on function r3105_recovery_action_rollup() from public, anon;
revoke execute on function r3105_priority_actions() from public, anon;
revoke execute on function r3105_top_at_risk_metrics() from public, anon;
revoke execute on function r3105_vendor_spend() from public, anon;
revoke execute on function r3105_cognitive_reserve_timeline() from public, anon;

grant execute on function r3105_panels_overview() to authenticated;
grant execute on function r3105_status_distribution() to authenticated;
grant execute on function r3105_trend_breakdown() to authenticated;
grant execute on function r3105_follow_ups_due() to authenticated;
grant execute on function r3105_recovery_action_rollup() to authenticated;
grant execute on function r3105_priority_actions() to authenticated;
grant execute on function r3105_top_at_risk_metrics() to authenticated;
grant execute on function r3105_vendor_spend() to authenticated;
grant execute on function r3105_cognitive_reserve_timeline() to authenticated;
