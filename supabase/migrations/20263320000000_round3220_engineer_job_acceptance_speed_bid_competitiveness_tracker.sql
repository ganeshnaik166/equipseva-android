-- Round 3220: Engineer Job-Acceptance Speed & Bid-Competitiveness Analytics Tracker
-- Bid analytics — engineer × job category × time-to-first-bid × bid rank × win flag × bid-vs-winning delta % × response-time percentile × CAPA coaching

-- =============================================================================
-- TABLE 1: bid_analytics_r3220 — individual engineer bid events
-- =============================================================================
create table if not exists public.bid_analytics_r3220 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  engineer_name text not null,
  job_reference text not null,
  job_category text not null check (job_category in (
    'ventilator_repair','anesthesia_workstation','ct_scanner','mri_scanner','defibrillator',
    'infusion_pump','patient_monitor','autoclave_sterilizer','dialysis_machine','xray_c_arm'
  )),
  job_date date not null,
  job_posted_at timestamptz not null,
  first_bid_at timestamptz,
  bid_placed_at timestamptz,
  time_to_bid_minutes numeric(8,2),
  total_competing_bids int not null default 0,
  bid_rank int,
  bid_amount_rupees numeric(12,2),
  winning_bid_rupees numeric(12,2),
  bid_vs_winning_delta_pct numeric(6,2),
  won_job boolean not null default false,
  response_time_percentile text check (response_time_percentile in (
    'top_10','top_25','median_band','bottom_25','bottom_10'
  )),
  competitiveness_verdict text not null check (competitiveness_verdict in (
    'highly_competitive','competitive','average','slow_responder','overpriced','underpriced_risky'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.bid_analytics_r3220 enable row level security;

create index if not exists idx_bid_analytics_r3220_org on public.bid_analytics_r3220(organization_id);
create index if not exists idx_bid_analytics_r3220_date on public.bid_analytics_r3220(job_date);
create index if not exists idx_bid_analytics_r3220_verdict on public.bid_analytics_r3220(competitiveness_verdict);

-- =============================================================================
-- TABLE 2: bid_analytics_capa_actions_r3220 — coaching & CAPA actions
-- =============================================================================
create table if not exists public.bid_analytics_capa_actions_r3220 (
  id uuid primary key default gen_random_uuid(),
  bid_analytics_id uuid not null references public.bid_analytics_r3220(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'slow_first_response','consistently_outbid','overpricing_pattern','underpricing_pattern',
    'low_win_rate','category_mismatch','stale_notification','no_show_after_win','quote_quality_poor','coaching_due'
  )),
  root_cause text not null check (root_cause in (
    'notification_delay','app_not_updated','engineer_overloaded','pricing_benchmark_missing',
    'skill_gap_category','coverage_area_too_wide','parts_cost_estimation_error','competitor_undercutting',
    'profile_incomplete','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'enable_push_priority_alerts','pricing_benchmark_coaching','category_skill_training','narrow_service_radius',
    'update_rate_card','pair_with_senior_engineer','fix_app_notification_settings','profile_completion_drive',
    'weekly_bid_review_call','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'sla_breach_risk','marketplace_policy','none','internal_only','customer_experience','contract_penalty_risk'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.bid_analytics_capa_actions_r3220 enable row level security;

create index if not exists idx_bid_capa_r3220_bid on public.bid_analytics_capa_actions_r3220(bid_analytics_id);
create index if not exists idx_bid_capa_r3220_status on public.bid_analytics_capa_actions_r3220(capa_status);

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

  -- 13 bid analytics rows
  insert into public.bid_analytics_r3220 (
    organization_id, hospital_name, engineer_name, job_reference, job_category,
    job_date, job_posted_at, first_bid_at, bid_placed_at,
    time_to_bid_minutes, total_competing_bids, bid_rank,
    bid_amount_rupees, winning_bid_rupees, bid_vs_winning_delta_pct, won_job,
    response_time_percentile, competitiveness_verdict, notes
  )
  select v_org_id, q.hosp, q.eng, q.jref, q.cat,
    q.jd::date, q.jp::timestamptz, q.fb::timestamptz, q.bp::timestamptz,
    q.ttb, q.cb, q.br,
    q.amt, q.win, q.delta, q.won,
    q.pct, q.cv, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','Ravi Teja','JOB-3220-001','ventilator_repair','2026-07-10','2026-07-10 09:00:00+05:30','2026-07-10 09:08:00+05:30','2026-07-10 09:08:00+05:30',
     8.00,5,1,18500.00,18500.00,0.00,true,'top_10','highly_competitive','First to bid and won at par pricing'),
    ('Apollo Hyderabad Jubilee Hills','Sandeep Rao','JOB-3220-002','patient_monitor','2026-07-10','2026-07-10 11:30:00+05:30','2026-07-10 11:42:00+05:30','2026-07-10 12:55:00+05:30',
     85.00,6,4,9200.00,7800.00,17.95,false,'bottom_25','overpriced','Bid 18 pct above winner, ranked 4 of 6'),
    ('Fortis Bannerghatta Bengaluru','Priya Nair','JOB-3220-003','ct_scanner','2026-07-11','2026-07-11 08:00:00+05:30','2026-07-11 08:05:00+05:30','2026-07-11 08:05:00+05:30',
     5.00,3,1,145000.00,145000.00,0.00,true,'top_10','highly_competitive','CT tube swap — fastest response of the week'),
    ('Fortis Bannerghatta Bengaluru','Amit Shah','JOB-3220-004','infusion_pump','2026-07-11','2026-07-11 14:00:00+05:30','2026-07-11 14:20:00+05:30','2026-07-11 16:30:00+05:30',
     150.00,8,7,4500.00,3200.00,40.63,false,'bottom_10','overpriced','2.5 hours to bid and 41 pct above winner'),
    ('Manipal Whitefield Bengaluru','Kiran Kumar','JOB-3220-005','mri_scanner','2026-07-12','2026-07-12 07:30:00+05:30','2026-07-12 07:45:00+05:30','2026-07-12 07:45:00+05:30',
     15.00,4,2,98000.00,92000.00,6.52,false,'top_25','competitive','Lost chiller repair by 6.5 pct'),
    ('Manipal Whitefield Bengaluru','Kiran Kumar','JOB-3220-006','dialysis_machine','2026-07-12','2026-07-12 10:00:00+05:30','2026-07-12 10:12:00+05:30','2026-07-12 10:12:00+05:30',
     12.00,5,1,12800.00,12800.00,0.00,true,'top_10','highly_competitive','Repeat client — conductivity sensor swap'),
    ('AIIMS New Delhi Ansari Nagar','Vikram Singh','JOB-3220-007','anesthesia_workstation','2026-07-13','2026-07-13 06:45:00+05:30','2026-07-13 06:52:00+05:30','2026-07-13 07:10:00+05:30',
     25.00,7,3,22500.00,21000.00,7.14,false,'median_band','average','Mid-pack rank on vaporizer service'),
    ('AIIMS New Delhi Ansari Nagar','Vikram Singh','JOB-3220-008','defibrillator','2026-07-13','2026-07-13 12:00:00+05:30','2026-07-13 12:03:00+05:30','2026-07-13 12:03:00+05:30',
     3.00,6,1,6800.00,6800.00,0.00,true,'top_10','highly_competitive','Battery plus patch cable, same-day fix'),
    ('KIMS Secunderabad','Mohammed Irfan','JOB-3220-009','autoclave_sterilizer','2026-07-14','2026-07-14 09:15:00+05:30','2026-07-14 09:40:00+05:30','2026-07-14 13:45:00+05:30',
     270.00,4,4,15500.00,11000.00,40.91,false,'bottom_10','slow_responder','4.5 hours late, last rank of 4'),
    ('Care Hospitals Banjara Hills','Lakshmi Devi','JOB-3220-010','xray_c_arm','2026-07-14','2026-07-14 15:30:00+05:30','2026-07-14 15:38:00+05:30','2026-07-14 15:38:00+05:30',
     8.00,5,2,32000.00,30500.00,4.92,false,'top_10','competitive','Fast bid, narrowly outpriced by rival'),
    ('Yashoda Somajiguda Hyderabad','Ravi Teja','JOB-3220-011','ventilator_repair','2026-07-15','2026-07-15 08:30:00+05:30','2026-07-15 08:41:00+05:30','2026-07-15 08:41:00+05:30',
     11.00,6,1,17200.00,17200.00,0.00,true,'top_25','highly_competitive','Won flow-sensor replacement job'),
    ('St John''s Bengaluru','Priya Nair','JOB-3220-012','patient_monitor','2026-07-15','2026-07-15 10:00:00+05:30','2026-07-15 10:55:00+05:30','2026-07-15 11:20:00+05:30',
     80.00,3,2,7400.00,8100.00,-8.64,false,'bottom_25','underpriced_risky','Bid 8.6 pct below winner yet lost on rating'),
    ('Rainbow Children''s Hyderabad','Anita Joseph','JOB-3220-013','infusion_pump','2026-07-16','2026-07-16 09:00:00+05:30','2026-07-16 09:06:00+05:30','2026-07-16 09:50:00+05:30',
     50.00,5,3,5100.00,null,null,false,'median_band','average','Job still open — no award decision yet')
  ) as q(hosp, eng, jref, cat, jd, jp, fb, bp, ttb, cb, br, amt, win, delta, won, pct, cv, nt);

  -- CAPA seed — attach to specific bid events by job reference
  insert into public.bid_analytics_capa_actions_r3220 (
    bid_analytics_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('JOB-3220-002','overpricing_pattern','pricing_benchmark_missing','pricing_benchmark_coaching','2026-07-20',null,'in_progress','customer_experience',0.00,'Shared category rate-card benchmarks with engineer'),
    ('JOB-3220-004','slow_first_response','notification_delay','fix_app_notification_settings','2026-07-18','2026-07-16','closed','internal_only',0.00,'Push notifications were disabled after OS update'),
    ('JOB-3220-009','slow_first_response','engineer_overloaded','narrow_service_radius','2026-07-22',null,'open','sla_breach_risk',1500.00,'Covers 60 km radius — trimming to 25 km'),
    ('JOB-3220-009','overpricing_pattern','parts_cost_estimation_error','update_rate_card','2026-07-25',null,'in_progress','customer_experience',2000.00,'Autoclave gasket parts priced off outdated list'),
    ('JOB-3220-012','underpricing_pattern','competitor_undercutting','weekly_bid_review_call','2026-07-24',null,'verification_pending','marketplace_policy',0.00,'Below-cost bid flagged — margin review scheduled'),
    ('JOB-3220-007','low_win_rate','skill_gap_category','category_skill_training','2026-08-01',null,'escalated','contract_penalty_risk',18000.00,'Anesthesia workstation OEM training nominated')
  ) as q(jref, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.bid_analytics_r3220 e
    on e.organization_id = v_org_id and e.job_reference = q.jref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Competitiveness verdict distribution
create or replace function public.founder_r3220_verdict_rollup()
returns table(competitiveness_verdict text, bids bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.bid_analytics_r3220)
  select l.competitiveness_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.bid_analytics_r3220 l
  group by l.competitiveness_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3220_verdict_rollup() from public, anon;
grant execute on function public.founder_r3220_verdict_rollup() to authenticated;

-- 2) Engineer bid-speed & win-rate scorecard
create or replace function public.founder_r3220_engineer_scorecard()
returns table(
  engineer_name text,
  total_bids bigint,
  wins bigint,
  win_rate_pct numeric,
  avg_time_to_bid_min numeric,
  avg_bid_rank numeric,
  avg_delta_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name,
    count(*)::bigint,
    count(*) filter (where l.won_job)::bigint,
    round(100.0 * count(*) filter (where l.won_job)::numeric / nullif(count(*),0), 1),
    round(avg(l.time_to_bid_minutes), 1),
    round(avg(l.bid_rank), 1),
    round(avg(l.bid_vs_winning_delta_pct), 2)
  from public.bid_analytics_r3220 l
  group by l.engineer_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3220_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3220_engineer_scorecard() to authenticated;

-- 3) Job-category competitiveness matrix
create or replace function public.founder_r3220_category_matrix()
returns table(job_category text, bids bigint, wins bigint, avg_bid_rupees numeric, avg_delta_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.job_category, count(*)::bigint,
    count(*) filter (where l.won_job)::bigint,
    round(avg(l.bid_amount_rupees), 0),
    round(avg(l.bid_vs_winning_delta_pct), 2)
  from public.bid_analytics_r3220 l
  group by l.job_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3220_category_matrix() from public, anon;
grant execute on function public.founder_r3220_category_matrix() to authenticated;

-- 4) Daily bid-speed trend
create or replace function public.founder_r3220_daily_trend()
returns table(job_date date, bids bigint, wins bigint, avg_time_to_bid_min numeric, fast_responses bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.job_date,
    count(*)::bigint,
    count(*) filter (where l.won_job)::bigint,
    round(avg(l.time_to_bid_minutes), 1),
    count(*) filter (where l.response_time_percentile in ('top_10','top_25'))::bigint
  from public.bid_analytics_r3220 l
  group by l.job_date
  order by l.job_date desc;
end;
$$;

revoke execute on function public.founder_r3220_daily_trend() from public, anon;
grant execute on function public.founder_r3220_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3220_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.bid_analytics_capa_actions_r3220 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3220_capa_status_board() from public, anon;
grant execute on function public.founder_r3220_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3220_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.bid_analytics_capa_actions_r3220)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.bid_analytics_capa_actions_r3220 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3220_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3220_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3220_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.bid_analytics_capa_actions_r3220 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3220_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3220_regulatory_impact_digest() to authenticated;

-- 8) High-risk bids queue (slow, outbid, mispriced)
create or replace function public.founder_r3220_high_risk_bids()
returns table(
  hospital_name text,
  engineer_name text,
  job_reference text,
  job_category text,
  job_date date,
  bid_rank int,
  time_to_bid_minutes numeric,
  bid_vs_winning_delta_pct numeric,
  competitiveness_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.job_reference, l.job_category, l.job_date,
    l.bid_rank, l.time_to_bid_minutes, l.bid_vs_winning_delta_pct, l.competitiveness_verdict, l.notes
  from public.bid_analytics_r3220 l
  where l.competitiveness_verdict in ('slow_responder','overpriced','underpriced_risky')
     or l.bid_rank >= 4
     or l.time_to_bid_minutes > 120
  order by l.job_date desc, l.engineer_name;
end;
$$;

revoke execute on function public.founder_r3220_high_risk_bids() from public, anon;
grant execute on function public.founder_r3220_high_risk_bids() to authenticated;
