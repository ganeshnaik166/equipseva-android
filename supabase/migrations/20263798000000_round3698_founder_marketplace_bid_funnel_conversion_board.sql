-- Round 3698: Founder Marketplace Bid-Funnel Conversion Board
-- Marketplace bid-funnel stage conversion (job posted -> bids -> accept -> complete) per category/region × month × funnel stage × funnel status × trend × CAPA

-- =============================================================================
-- TABLE 1: bid_funnel_r3698 — per category/region/month bid-funnel conversion cohorts
-- =============================================================================
create table if not exists public.bid_funnel_r3698 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  funnel_code text not null,
  category text not null,
  region text not null,
  period_month date not null,
  jobs_posted int not null,
  jobs_with_bids int not null,
  first_bid_median_hours numeric(6,1),
  bids_per_job_avg numeric(5,2),
  jobs_bid_accepted int not null,
  jobs_completed int not null,
  post_to_bid_pct numeric(5,1),
  bid_to_accept_pct numeric(5,1),
  accept_to_complete_pct numeric(5,1),
  funnel_conversion_pct numeric(5,1),
  funnel_stage text not null check (funnel_stage in (
    'posting','bidding','acceptance','execution','completion'
  )),
  funnel_status text not null check (funnel_status in (
    'healthy','bid_starved','acceptance_drop','execution_drop','broken'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.bid_funnel_r3698 enable row level security;

create index if not exists idx_bid_funnel_r3698_org on public.bid_funnel_r3698(organization_id);
create index if not exists idx_bid_funnel_r3698_month on public.bid_funnel_r3698(period_month);
create index if not exists idx_bid_funnel_r3698_status on public.bid_funnel_r3698(funnel_status);

-- =============================================================================
-- TABLE 2: bid_funnel_capa_actions_r3698 — CAPA actions on funnel drop-offs
-- =============================================================================
create table if not exists public.bid_funnel_capa_actions_r3698 (
  id uuid primary key default gen_random_uuid(),
  funnel_id uuid not null references public.bid_funnel_r3698(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'low_provider_density','pricing_mismatch','slow_first_response','poor_job_description',
    'notification_delivery_gap','provider_capacity_shortage','customer_unresponsive',
    'payment_friction','parts_unavailability','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'recruit_providers_in_region','adjust_pricing_guidance','enable_instant_alerts',
    'improve_job_post_template','fix_notification_channel','expand_provider_capacity',
    'add_customer_reminders','streamline_payment_flow','preposition_spare_parts','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  est_gmv_at_risk_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.bid_funnel_capa_actions_r3698 enable row level security;

create index if not exists idx_bid_funnel_capa_r3698_funnel on public.bid_funnel_capa_actions_r3698(funnel_id);
create index if not exists idx_bid_funnel_capa_r3698_status on public.bid_funnel_capa_actions_r3698(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 16 funnel cohort rows
  insert into public.bid_funnel_r3698 (
    organization_id, funnel_code, category, region, period_month,
    jobs_posted, jobs_with_bids, first_bid_median_hours, bids_per_job_avg,
    jobs_bid_accepted, jobs_completed, post_to_bid_pct, bid_to_accept_pct,
    accept_to_complete_pct, funnel_conversion_pct, funnel_stage, funnel_status, trend_dir, notes
  )
  select v_org_id, q.fcode, q.cat, q.reg, q.pmonth::date,
    q.jposted, q.jbids, q.fbmh, q.bpja,
    q.jacc, q.jcomp, q.ptb, q.bta,
    q.atc, q.fcv, q.fstage, q.fstat, q.tdir, q.nt
  from (values
    ('VNT-MUM-2607','ventilator-repair','Mumbai','2026-07-01',
     42,39,3.2,4.6,33,30,92.9,84.6,90.9,71.4,'completion','healthy','stable','Ventilator repair funnel strong in Mumbai — dense provider pool'),
    ('INF-CHE-2607','infusion-pump-service','Chennai','2026-07-01',
     35,31,5.1,3.8,25,22,88.6,80.6,88.0,62.9,'completion','healthy','improving','Infusion pump funnel improving after Chennai provider onboarding drive'),
    ('DEF-DEL-2607','defibrillator-amc','Delhi','2026-07-01',
     28,17,14.8,1.9,11,9,60.7,64.7,81.8,32.1,'bidding','bid_starved','worsening','Defib AMC jobs starved of bids — few certified providers in Delhi NCR'),
    ('PMI-BLR-2607','patient-monitor-install','Bengaluru','2026-07-01',
     31,29,4.4,4.1,20,18,93.5,69.0,90.0,58.1,'acceptance','acceptance_drop','stable','Acceptance dip — quotes above customer budget on installs'),
    ('DIA-MUM-2607','dialysis-machine-repair','Mumbai','2026-07-01',
     24,22,6.0,3.4,18,13,91.7,81.8,72.2,54.2,'execution','execution_drop','worsening','Completions lag — dialyser spare parts stockouts mid-job'),
    ('XRT-HYD-2607','xray-tube-replacement','Hyderabad','2026-07-01',
     12,5,26.5,1.2,3,2,41.7,60.0,66.7,16.7,'bidding','broken','worsening','X-ray tube funnel broken — no specialist providers bidding in Hyderabad'),
    ('ECG-PUN-2607','ecg-machine-calibration','Pune','2026-07-01',
     19,17,7.9,2.8,14,13,89.5,82.4,92.9,68.4,'completion','healthy','stable','ECG calibration funnel steady in Pune'),
    ('CTS-DEL-2607','ct-scanner-amc','Delhi','2026-07-01',
     9,7,18.2,1.6,4,3,77.8,57.1,75.0,33.3,'acceptance','acceptance_drop','stable','High-value CT AMC quotes stall at acceptance — procurement approvals slow'),
    ('VNT-MUM-2606','ventilator-repair','Mumbai','2026-06-01',
     38,35,3.6,4.3,29,26,92.1,82.9,89.7,68.4,'completion','healthy','stable','June baseline — ventilator funnel healthy'),
    ('INF-CHE-2606','infusion-pump-service','Chennai','2026-06-01',
     33,27,8.3,2.9,20,17,81.8,74.1,85.0,51.5,'completion','healthy','improving','Pre-onboarding June cohort — conversion has since improved'),
    ('DEF-DEL-2606','defibrillator-amc','Delhi','2026-06-01',
     26,18,12.4,2.1,12,10,69.2,66.7,83.3,38.5,'bidding','bid_starved','worsening','Bid starvation onset — provider churn in Delhi defib segment'),
    ('DIA-MUM-2606','dialysis-machine-repair','Mumbai','2026-06-01',
     22,21,5.5,3.6,17,15,95.5,81.0,88.2,68.2,'completion','healthy','worsening','June healthy but parts lead times creeping up'),
    ('XRT-HYD-2606','xray-tube-replacement','Hyderabad','2026-06-01',
     10,6,21.0,1.4,4,3,60.0,66.7,75.0,30.0,'bidding','bid_starved','worsening','Specialist bid coverage thinning in June'),
    ('PMI-BLR-2606','patient-monitor-install','Bengaluru','2026-06-01',
     27,25,4.9,3.9,19,17,92.6,76.0,89.5,63.0,'completion','healthy','stable','Install funnel nominal in June'),
    ('ECG-PUN-2606','ecg-machine-calibration','Pune','2026-06-01',
     17,15,8.8,2.6,12,11,88.2,80.0,91.7,64.7,'completion','healthy','stable','Calibration funnel steady'),
    ('CTS-DEL-2606','ct-scanner-amc','Delhi','2026-06-01',
     8,3,34.6,0.9,1,1,37.5,33.3,100.0,12.5,'bidding','broken','worsening','CT AMC funnel broken — WhatsApp broadcast missed the CT specialist segment')
  ) as q(fcode, cat, reg, pmonth, jposted, jbids, fbmh, bpja, jacc, jcomp, ptb, bta, atc, fcv, fstage, fstat, tdir, nt);

  -- CAPA seed — attach to specific funnel cohorts via funnel_code
  insert into public.bid_funnel_capa_actions_r3698 (
    funnel_id, root_cause, corrective_action, capa_status,
    est_gmv_at_risk_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.gmv, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('DEF-DEL-2607','low_provider_density','recruit_providers_in_region','in_progress',420000.00,'Marketplace Ops - North','2026-08-20',null,'Recruiting 6 certified defib AMC providers in Delhi NCR'),
    ('XRT-HYD-2607','provider_capacity_shortage','recruit_providers_in_region','escalated',610000.00,'Founder Office','2026-08-15',null,'Zero specialist coverage — escalated; OEM partner outreach underway'),
    ('PMI-BLR-2607','pricing_mismatch','adjust_pricing_guidance','open',180000.00,'Pricing Guild','2026-08-25',null,'Publish install rate-card guidance to narrow quote spread'),
    ('DIA-MUM-2607','parts_unavailability','preposition_spare_parts','in_progress',260000.00,'Supply Chain - West','2026-08-18',null,'Dialyser consumable kits prepositioned at Mumbai hub'),
    ('CTS-DEL-2607','payment_friction','streamline_payment_flow','verification_pending',350000.00,'Payments Squad','2026-08-12',null,'Milestone-based payment enabled for high-value AMC — verifying uptake'),
    ('DEF-DEL-2606','notification_delivery_gap','fix_notification_channel','closed',150000.00,'Platform Notifications','2026-07-10','2026-07-08','FCM topic misrouting fixed; SMS fallback added for defib providers'),
    ('CTS-DEL-2606','poor_job_description','improve_job_post_template','closed',90000.00,'Product - Jobs','2026-07-05','2026-07-02','CT AMC post template now captures tube hours and site access details'),
    ('XRT-HYD-2606','slow_first_response','enable_instant_alerts','overdue',210000.00,'Marketplace Ops - South','2026-07-31',null,'WhatsApp instant-alert rollout slipped — vendor API quota issue')
  ) as q(fcode, rc, ca, cst, gmv, ownr, tcd, acd, nt)
  join public.bid_funnel_r3698 e
    on e.organization_id = v_org_id and e.funnel_code = q.fcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Funnel status distribution
create or replace function public.founder_r3698_funnel_status_rollup()
returns table(funnel_status text, cohorts bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.bid_funnel_r3698)
  select l.funnel_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.bid_funnel_r3698 l
  group by l.funnel_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3698_funnel_status_rollup() from public, anon;
grant execute on function public.founder_r3698_funnel_status_rollup() to authenticated;

-- 2) Region funnel scorecard
create or replace function public.founder_r3698_region_scorecard()
returns table(
  region text,
  cohorts bigint,
  healthy bigint,
  bid_starved bigint,
  dropoff bigint,
  broken bigint,
  jobs_posted bigint,
  jobs_completed bigint,
  avg_conversion_pct numeric,
  healthy_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region,
    count(*)::bigint,
    count(*) filter (where l.funnel_status = 'healthy')::bigint,
    count(*) filter (where l.funnel_status = 'bid_starved')::bigint,
    count(*) filter (where l.funnel_status in ('acceptance_drop','execution_drop'))::bigint,
    count(*) filter (where l.funnel_status = 'broken')::bigint,
    coalesce(sum(l.jobs_posted),0)::bigint,
    coalesce(sum(l.jobs_completed),0)::bigint,
    round(avg(l.funnel_conversion_pct), 1),
    round(100.0 * count(*) filter (where l.funnel_status = 'healthy')::numeric / nullif(count(*),0), 1)
  from public.bid_funnel_r3698 l
  group by l.region
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3698_region_scorecard() from public, anon;
grant execute on function public.founder_r3698_region_scorecard() to authenticated;

-- 3) Funnel stage × funnel status matrix
create or replace function public.founder_r3698_stage_status_matrix()
returns table(funnel_stage text, funnel_status text, cohorts bigint, jobs_posted bigint, avg_conversion_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.funnel_stage, l.funnel_status, count(*)::bigint,
    coalesce(sum(l.jobs_posted),0)::bigint,
    round(avg(l.funnel_conversion_pct), 1)
  from public.bid_funnel_r3698 l
  group by l.funnel_stage, l.funnel_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3698_stage_status_matrix() from public, anon;
grant execute on function public.founder_r3698_stage_status_matrix() to authenticated;

-- 4) Monthly conversion trend
create or replace function public.founder_r3698_monthly_conversion_trend()
returns table(
  period_month date,
  cohorts bigint,
  jobs_posted bigint,
  jobs_with_bids bigint,
  jobs_bid_accepted bigint,
  jobs_completed bigint,
  avg_conversion_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.jobs_posted),0)::bigint,
    coalesce(sum(l.jobs_with_bids),0)::bigint,
    coalesce(sum(l.jobs_bid_accepted),0)::bigint,
    coalesce(sum(l.jobs_completed),0)::bigint,
    round(avg(l.funnel_conversion_pct), 1)
  from public.bid_funnel_r3698 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3698_monthly_conversion_trend() from public, anon;
grant execute on function public.founder_r3698_monthly_conversion_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3698_capa_status_board()
returns table(capa_status text, findings bigint, avg_gmv_at_risk_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.est_gmv_at_risk_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.bid_funnel_capa_actions_r3698 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3698_capa_status_board() from public, anon;
grant execute on function public.founder_r3698_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3698_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_gmv_at_risk_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.bid_funnel_capa_actions_r3698)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.est_gmv_at_risk_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.bid_funnel_capa_actions_r3698 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3698_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3698_root_cause_pareto() to authenticated;

-- 7) Stage drop-off digest
create or replace function public.founder_r3698_dropoff_digest()
returns table(
  funnel_stage text,
  cohorts bigint,
  avg_post_to_bid_pct numeric,
  avg_bid_to_accept_pct numeric,
  avg_accept_to_complete_pct numeric,
  avg_conversion_pct numeric,
  worsening bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.funnel_stage,
    count(*)::bigint,
    round(avg(l.post_to_bid_pct), 1),
    round(avg(l.bid_to_accept_pct), 1),
    round(avg(l.accept_to_complete_pct), 1),
    round(avg(l.funnel_conversion_pct), 1),
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.bid_funnel_r3698 l
  group by l.funnel_stage
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3698_dropoff_digest() from public, anon;
grant execute on function public.founder_r3698_dropoff_digest() to authenticated;

-- 8) High-risk funnel queue (broken / bid-starved / worsening)
create or replace function public.founder_r3698_high_risk_queue()
returns table(
  funnel_code text,
  category text,
  region text,
  period_month date,
  jobs_posted int,
  bids_per_job_avg numeric,
  funnel_stage text,
  funnel_status text,
  trend_dir text,
  funnel_conversion_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.funnel_code, l.category, l.region, l.period_month,
    l.jobs_posted, l.bids_per_job_avg, l.funnel_stage, l.funnel_status,
    l.trend_dir, l.funnel_conversion_pct, l.notes
  from public.bid_funnel_r3698 l
  where l.funnel_status in ('broken','bid_starved')
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.funnel_conversion_pct asc;
end;
$$;

revoke all on function public.founder_r3698_high_risk_queue() from public, anon;
grant execute on function public.founder_r3698_high_risk_queue() to authenticated;
