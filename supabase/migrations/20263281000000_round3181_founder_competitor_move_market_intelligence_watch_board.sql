-- Round 3181: Founder Competitor-Move & Market-Intelligence Watch Board
-- Competitor intel log — competitor × move type × severity × source × response status × moat impact × verdict × CAPA countermoves

-- =============================================================================
-- TABLE 1: competitor_watch_r3181 — individual competitor moves observed in market
-- =============================================================================
create table if not exists public.competitor_watch_r3181 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  move_ref text not null,
  competitor_name text not null,
  hospital_name text not null,
  move_type text not null check (move_type in (
    'pricing_change','hiring_surge','funding_round',
    'product_launch','partnership_deal','geo_expansion','acquisition','marketing_campaign'
  )),
  severity text not null check (severity in ('low','medium','high','critical')),
  source text not null check (source in (
    'field_sales_report','hospital_procurement_tip','news_article','linkedin_activity',
    'job_posting','tender_portal','conference_sighting','partner_channel'
  )),
  observed_on date not null,
  our_response_status text not null check (our_response_status in (
    'not_started','monitoring','response_drafted','countermove_live','deprioritized','escalated_to_board'
  )),
  response_owner text not null,
  moat_impact text not null check (moat_impact in (
    'none','erodes_price_moat','erodes_network_moat','erodes_service_moat','erodes_data_moat','strengthens_us'
  )),
  watch_verdict text not null check (watch_verdict in (
    'ignore','monitor','respond_now','urgent_countermove','pending_review','opportunity'
  )),
  estimated_revenue_at_risk_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.competitor_watch_r3181 enable row level security;

create index if not exists idx_competitor_watch_r3181_org on public.competitor_watch_r3181(organization_id);
create index if not exists idx_competitor_watch_r3181_observed on public.competitor_watch_r3181(observed_on);
create index if not exists idx_competitor_watch_r3181_verdict on public.competitor_watch_r3181(watch_verdict);

-- =============================================================================
-- TABLE 2: competitor_watch_capa_actions_r3181 — response / CAPA countermove actions
-- =============================================================================
create table if not exists public.competitor_watch_capa_actions_r3181 (
  id uuid primary key default gen_random_uuid(),
  watch_id uuid not null references public.competitor_watch_r3181(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'price_undercut','key_account_poach','engineer_poach','feature_gap',
    'coverage_gap','channel_conflict','brand_attack','regulatory_lever'
  )),
  root_cause text not null check (root_cause in (
    'our_pricing_rigid','slow_feature_velocity','thin_service_coverage',
    'weak_key_account_love','no_partner_moat','talent_comp_gap',
    'pending_investigation','competitor_capital_advantage'
  )),
  corrective_action text not null check (corrective_action in (
    'targeted_discount_program','accelerate_roadmap_item','expand_engineer_coverage',
    'key_account_save_plan','sign_exclusive_partnership','retention_bonus_program',
    'counter_pr_campaign','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'none','internal_only','tender_compliance_risk','antitrust_sensitivity','cdsco_notifiable','data_privacy_review'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.competitor_watch_capa_actions_r3181 enable row level security;

create index if not exists idx_competitor_capa_r3181_watch on public.competitor_watch_capa_actions_r3181(watch_id);
create index if not exists idx_competitor_capa_r3181_status on public.competitor_watch_capa_actions_r3181(capa_status);

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

  -- 13 competitor-move rows
  insert into public.competitor_watch_r3181 (
    organization_id, move_ref, competitor_name, hospital_name,
    move_type, severity, source, observed_on,
    our_response_status, response_owner, moat_impact, watch_verdict,
    estimated_revenue_at_risk_rupees, notes
  )
  select v_org_id, q.ref, q.comp, q.hosp,
    q.mt, q.sev, q.src, q.obs::date,
    q.rs, q.own, q.mi, q.wv,
    q.risk, q.nt
  from (values
    ('CMP-001','MedGrid Services','Apollo Hyderabad Jubilee Hills','pricing_change','high','tender_portal','2026-07-14',
     'response_drafted','Ganesh','erodes_price_moat','respond_now',850000.00,'Undercut our AMC quote by 18% on Apollo imaging tender'),
    ('CMP-002','MedGrid Services','Fortis Bannerghatta Bengaluru','hiring_surge','medium','job_posting','2026-07-12',
     'monitoring','Priya','erodes_service_moat','monitor',0.00,'Posted 6 biomedical engineer roles in Bengaluru in one week'),
    ('CMP-003','CalibreMed','Manipal Whitefield Bengaluru','product_launch','high','conference_sighting','2026-07-10',
     'not_started','Ganesh','erodes_data_moat','respond_now',400000.00,'Calibration-report mobile app demoed at Manipal biomedical meet'),
    ('CMP-004','ServQ Biomedical','AIIMS New Delhi Ansari Nagar','funding_round','critical','news_article','2026-07-08',
     'escalated_to_board','Ganesh','erodes_network_moat','urgent_countermove',2500000.00,'Raised Series A of 40 crore, explicitly targeting govt hospital AMC contracts'),
    ('CMP-005','ServQ Biomedical','KIMS Secunderabad','geo_expansion','high','field_sales_report','2026-07-07',
     'response_drafted','Arjun','erodes_service_moat','respond_now',600000.00,'Opened Hyderabad service hub 3 km from KIMS campus'),
    ('CMP-006','EquipCare India','Care Hospitals Banjara Hills','partnership_deal','medium','hospital_procurement_tip','2026-07-05',
     'monitoring','Priya','erodes_network_moat','monitor',350000.00,'Signed preferred-vendor MoU with Care group purchasing cell'),
    ('CMP-007','CalibreMed','Yashoda Somajiguda Hyderabad','pricing_change','low','field_sales_report','2026-07-03',
     'deprioritized','Arjun','none','ignore',50000.00,'One-off discount on a single ventilator PM visit'),
    ('CMP-008','BioMedix Network','St John''s Bengaluru','hiring_surge','medium','linkedin_activity','2026-07-01',
     'monitoring','Priya','erodes_service_moat','monitor',0.00,'Poached two dialysis technicians from the local vendor pool'),
    ('CMP-009','EquipCare India','Rainbow Children''s Hyderabad','product_launch','high','news_article','2026-06-28',
     'countermove_live','Ganesh','erodes_price_moat','opportunity',300000.00,'Flat-fee pediatric equipment AMC bundle — our NICU bundle counter is live'),
    ('CMP-010','MedGrid Services','Apollo Hyderabad Jubilee Hills','partnership_deal','critical','hospital_procurement_tip','2026-06-25',
     'escalated_to_board','Ganesh','erodes_network_moat','urgent_countermove',1800000.00,'Exclusive OEM spare-parts tie-up rumored with imaging vendor'),
    ('CMP-011','BioMedix Network','Manipal Whitefield Bengaluru','geo_expansion','medium','tender_portal','2026-06-22',
     'not_started','Arjun','erodes_service_moat','pending_review',450000.00,'Bid on Manipal multi-site calibration rate contract'),
    ('CMP-012','ServQ Biomedical','Fortis Bannerghatta Bengaluru','funding_round','low','news_article','2026-06-20',
     'monitoring','Priya','none','monitor',0.00,'Bridge round chatter, amount unconfirmed'),
    ('CMP-013','CalibreMed','AIIMS New Delhi Ansari Nagar','pricing_change','high','tender_portal','2026-06-18',
     'countermove_live','Ganesh','erodes_price_moat','opportunity',950000.00,'Lowball GEM portal bid; we matched with a better SLA and won')
  ) as q(ref, comp, hosp, mt, sev, src, obs, rs, own, mi, wv, risk, nt);

  -- CAPA / countermove seed — attach to specific moves via move_ref
  insert into public.competitor_watch_capa_actions_r3181 (
    watch_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.tcd::date, q.acd::date, q.cs, q.ri,
    q.cost, q.nt
  from (values
    ('CMP-001','price_undercut','our_pricing_rigid','targeted_discount_program','2026-07-20',null,'in_progress','tender_compliance_risk',120000.00,'Approval matrix for tactical AMC discounts up to 12%'),
    ('CMP-004','key_account_poach','competitor_capital_advantage','key_account_save_plan','2026-07-25',null,'escalated','none',500000.00,'Board-level save plan for top 10 govt accounts'),
    ('CMP-005','coverage_gap','thin_service_coverage','expand_engineer_coverage','2026-07-30',null,'open','internal_only',350000.00,'Hire 3 engineers for Hyderabad west cluster'),
    ('CMP-003','feature_gap','slow_feature_velocity','accelerate_roadmap_item','2026-07-18','2026-07-15','closed','none',80000.00,'Calibration-certificate PDF share shipped ahead of plan'),
    ('CMP-010','channel_conflict','no_partner_moat','sign_exclusive_partnership','2026-08-05',null,'verification_pending','antitrust_sensitivity',250000.00,'Legal reviewing exclusivity clause with two OEMs'),
    ('CMP-008','engineer_poach','talent_comp_gap','retention_bonus_program','2026-07-10',null,'overdue','internal_only',200000.00,'Retention bonus for senior dialysis engineers pending CFO signoff')
  ) as q(ref_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.competitor_watch_r3181 e
    on e.organization_id = v_org_id and e.move_ref = q.ref_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Watch verdict distribution
create or replace function public.founder_r3181_verdict_rollup()
returns table(watch_verdict text, moves bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.competitor_watch_r3181)
  select w.watch_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.competitor_watch_r3181 w
  group by w.watch_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3181_verdict_rollup() from public, anon;
grant execute on function public.founder_r3181_verdict_rollup() to authenticated;

-- 2) Competitor-level threat scorecard
create or replace function public.founder_r3181_competitor_scorecard()
returns table(
  competitor_name text,
  total_moves bigint,
  critical_moves bigint,
  urgent_countermoves bigint,
  live_countermoves bigint,
  revenue_at_risk_rupees numeric,
  responded_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select w.competitor_name,
    count(*)::bigint,
    count(*) filter (where w.severity = 'critical')::bigint,
    count(*) filter (where w.watch_verdict = 'urgent_countermove')::bigint,
    count(*) filter (where w.our_response_status = 'countermove_live')::bigint,
    coalesce(sum(w.estimated_revenue_at_risk_rupees),0)::numeric,
    round(100.0 * count(*) filter (where w.our_response_status in ('response_drafted','countermove_live','escalated_to_board'))::numeric / nullif(count(*),0), 1)
  from public.competitor_watch_r3181 w
  group by w.competitor_name
  order by coalesce(sum(w.estimated_revenue_at_risk_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3181_competitor_scorecard() from public, anon;
grant execute on function public.founder_r3181_competitor_scorecard() to authenticated;

-- 3) Move type × severity matrix
create or replace function public.founder_r3181_move_severity_matrix()
returns table(move_type text, severity text, moves bigint, urgent bigint, revenue_at_risk_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select w.move_type, w.severity, count(*)::bigint,
    count(*) filter (where w.watch_verdict in ('respond_now','urgent_countermove'))::bigint,
    coalesce(sum(w.estimated_revenue_at_risk_rupees),0)::numeric
  from public.competitor_watch_r3181 w
  group by w.move_type, w.severity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3181_move_severity_matrix() from public, anon;
grant execute on function public.founder_r3181_move_severity_matrix() to authenticated;

-- 4) Daily observed-move trend
create or replace function public.founder_r3181_daily_move_trend()
returns table(observed_on date, moves bigint, critical_moves bigint, urgent_verdicts bigint, revenue_at_risk_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select w.observed_on,
    count(*)::bigint,
    count(*) filter (where w.severity = 'critical')::bigint,
    count(*) filter (where w.watch_verdict in ('respond_now','urgent_countermove'))::bigint,
    coalesce(sum(w.estimated_revenue_at_risk_rupees),0)::numeric
  from public.competitor_watch_r3181 w
  group by w.observed_on
  order by w.observed_on desc;
end;
$$;

revoke execute on function public.founder_r3181_daily_move_trend() from public, anon;
grant execute on function public.founder_r3181_daily_move_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3181_capa_status_board()
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
  from public.competitor_watch_capa_actions_r3181 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3181_capa_status_board() from public, anon;
grant execute on function public.founder_r3181_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3181_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.competitor_watch_capa_actions_r3181)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.competitor_watch_capa_actions_r3181 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3181_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3181_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3181_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','escalated','overdue'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.competitor_watch_capa_actions_r3181 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3181_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3181_regulatory_impact_digest() to authenticated;

-- 8) High-priority response queue (moves needing action now)
create or replace function public.founder_r3181_high_priority_queue()
returns table(
  competitor_name text,
  hospital_name text,
  move_type text,
  severity text,
  observed_on date,
  our_response_status text,
  response_owner text,
  watch_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select w.competitor_name, w.hospital_name, w.move_type, w.severity, w.observed_on,
    w.our_response_status, w.response_owner, w.watch_verdict, w.notes
  from public.competitor_watch_r3181 w
  where w.watch_verdict in ('respond_now','urgent_countermove','pending_review')
     or w.severity = 'critical'
  order by w.observed_on desc, w.competitor_name;
end;
$$;

revoke execute on function public.founder_r3181_high_priority_queue() from public, anon;
grant execute on function public.founder_r3181_high_priority_queue() to authenticated;
