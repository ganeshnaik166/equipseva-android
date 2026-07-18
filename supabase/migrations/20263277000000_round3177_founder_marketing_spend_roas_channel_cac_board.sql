-- Round 3177: Founder Marketing-Spend ROAS & Channel-CAC Board
-- Channel marketing performance log — spend × leads/qualified/customers × revenue attributed × CAC × ROAS × LTV:CAC × verdict + optimization CAPA

-- =============================================================================
-- TABLE 1: marketing_roas_r3177 — per-campaign channel performance rows
-- =============================================================================
create table if not exists public.marketing_roas_r3177 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  campaign_name text not null,
  campaign_code text not null,
  period_month date not null,
  channel text not null check (channel in (
    'google_ads','meta_ads','referral','field_sales','events',
    'linkedin_ads','content_seo','email_nurture'
  )),
  campaign_objective text not null check (campaign_objective in (
    'lead_gen','brand_awareness','demo_booking','account_based',
    'reactivation','event_signup','webinar_reg'
  )),
  region text not null check (region in (
    'south_india','north_india','west_india','east_india','central_india','pan_india'
  )),
  spend_rupees numeric(12,2) not null,
  leads int not null,
  qualified_leads int not null,
  customers_won int not null,
  revenue_attributed_rupees numeric(14,2) not null,
  cac_rupees numeric(12,2),
  roas numeric(6,2),
  ltv_cac_ratio numeric(6,2),
  verdict text not null check (verdict in (
    'scale_up','maintain','optimize','watch','pause','cut','under_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.marketing_roas_r3177 enable row level security;

create index if not exists idx_marketing_roas_r3177_org on public.marketing_roas_r3177(organization_id);
create index if not exists idx_marketing_roas_r3177_channel on public.marketing_roas_r3177(channel);
create index if not exists idx_marketing_roas_r3177_verdict on public.marketing_roas_r3177(verdict);

-- =============================================================================
-- TABLE 2: marketing_roas_capa_actions_r3177 — optimization / CAPA actions
-- =============================================================================
create table if not exists public.marketing_roas_capa_actions_r3177 (
  id uuid primary key default gen_random_uuid(),
  roas_log_id uuid not null references public.marketing_roas_r3177(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'low_roas','high_cac','poor_lead_quality','weak_conversion','budget_overspend',
    'creative_fatigue','landing_page_drop','attribution_gap','channel_saturation','low_ltv_cac'
  )),
  root_cause text not null check (root_cause in (
    'targeting_mismatch','creative_stale','landing_page_slow','bid_strategy_wrong',
    'audience_saturated','offer_weak','sales_followup_slow','tracking_broken',
    'seasonality','budget_misallocation','under_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'refresh_creative','retarget_audience','optimize_landing_page','adjust_bid_strategy',
    'reallocate_budget','pause_channel','improve_lead_scoring','fix_tracking',
    'strengthen_offer','accelerate_sales_followup','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'board_review','budget_reallocation','none','internal_only','margin_alert','growth_blocker'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.marketing_roas_capa_actions_r3177 enable row level security;

create index if not exists idx_marketing_roas_capa_r3177_log on public.marketing_roas_capa_actions_r3177(roas_log_id);
create index if not exists idx_marketing_roas_capa_r3177_status on public.marketing_roas_capa_actions_r3177(capa_status);

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

  -- 14 channel-performance rows
  insert into public.marketing_roas_r3177 (
    organization_id, hospital_name, campaign_name, campaign_code, period_month,
    channel, campaign_objective, region,
    spend_rupees, leads, qualified_leads, customers_won, revenue_attributed_rupees,
    cac_rupees, roas, ltv_cac_ratio, verdict, notes
  )
  select v_org_id, q.hosp, q.camp, q.code, q.pm::date,
    q.ch, q.obj, q.reg,
    q.spend, q.leads, q.ql, q.cust, q.rev,
    q.cac, q.roas, q.ltv, q.verdict, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','Google Search — OT & CSSD South','MKT-GA-APL-01','2026-06-01',
     'google_ads','demo_booking','south_india',185000.00,240,96,12,2160000.00,15416.67,11.68,6.20,'scale_up','Highest intent — CSSD keyword cluster converting'),
    ('Fortis Bannerghatta Bengaluru','Meta Retargeting — Biomedical Leads','MKT-MT-FRT-02','2026-06-01',
     'meta_ads','lead_gen','south_india',142000.00,380,76,6,720000.00,23666.67,5.07,2.90,'optimize','Lead volume high but quality slipping'),
    ('Manipal Whitefield Bengaluru','Referral — Existing AMC Accounts','MKT-RF-MNP-03','2026-06-01',
     'referral','account_based','south_india',45000.00,60,42,9,1620000.00,5000.00,36.00,14.50,'scale_up','Referral flywheel off AMC base — best unit economics'),
    ('AIIMS New Delhi Ansari Nagar','Field Sales — Govt Tender Push','MKT-FS-AIM-04','2026-06-01',
     'field_sales','account_based','north_india',320000.00,45,30,4,2800000.00,80000.00,8.75,3.40,'maintain','High CAC govt cycle but large ticket size'),
    ('KIMS Secunderabad','Events — Healthcare Expo Hyderabad','MKT-EV-KIM-05','2026-06-01',
     'events','event_signup','south_india',95000.00,110,33,3,450000.00,31666.67,4.74,2.10,'watch','Expo footfall soft this quarter'),
    ('Care Hospitals Banjara Hills','LinkedIn — Biomedical Heads ABM','MKT-LI-CAR-06','2026-06-01',
     'linkedin_ads','account_based','south_india',78000.00,55,28,5,900000.00,15600.00,11.54,5.60,'scale_up','ABM to biomedical decision makers converting well'),
    ('Yashoda Somajiguda Hyderabad','Content SEO — Autoclave Maintenance','MKT-SEO-YSH-07','2026-06-01',
     'content_seo','brand_awareness','south_india',32000.00,210,40,4,640000.00,8000.00,20.00,9.10,'scale_up','Organic compounding — lowest cost per lead'),
    ('St John''s Bengaluru','Email Nurture — Dormant Demos','MKT-EM-STJ-08','2026-06-01',
     'email_nurture','reactivation','south_india',12000.00,90,22,2,260000.00,6000.00,21.67,8.00,'maintain','Cheap reactivation of stale demo pipeline'),
    ('Rainbow Children''s Hyderabad','Google Search — Pediatric NICU','MKT-GA-RBW-09','2026-06-01',
     'google_ads','demo_booking','south_india',88000.00,70,18,1,95000.00,88000.00,1.08,0.60,'pause','Niche NICU keywords — negative unit economics'),
    ('Apollo Hyderabad Jubilee Hills','Meta Awareness — Brand South','MKT-MT-APL-10','2026-05-01',
     'meta_ads','brand_awareness','south_india',60000.00,300,24,2,180000.00,30000.00,3.00,1.40,'cut','Awareness spend not converting — reallocate'),
    ('Fortis Bannerghatta Bengaluru','Field Sales — West Expansion','MKT-FS-FRT-11','2026-05-01',
     'field_sales','lead_gen','west_india',210000.00,65,34,5,1750000.00,42000.00,8.33,3.80,'maintain','West India pilot — promising early cohort'),
    ('Manipal Whitefield Bengaluru','Events — CSSD Conference Delhi','MKT-EV-MNP-12','2026-05-01',
     'events','webinar_reg','north_india',130000.00,85,25,2,360000.00,65000.00,2.77,1.20,'watch','National conference — long sales cycle'),
    ('AIIMS New Delhi Ansari Nagar','Referral — KOL Introductions','MKT-RF-AIM-13','2026-05-01',
     'referral','account_based','north_india',28000.00,30,22,6,2100000.00,4666.67,75.00,18.00,'scale_up','KOL referrals — flagship ROAS channel'),
    ('KIMS Secunderabad','LinkedIn — Procurement ABM','MKT-LI-KIM-14','2026-05-01',
     'linkedin_ads','lead_gen','south_india',54000.00,48,19,2,240000.00,27000.00,4.44,2.00,'optimize','Procurement titles costly — refine targeting'),
    ('Care Hospitals Banjara Hills','Content SEO — Biomedical Compliance','MKT-SEO-CAR-15','2026-05-01',
     'content_seo','brand_awareness','south_india',26000.00,160,34,3,510000.00,8666.67,19.62,8.40,'scale_up','Compliance guides ranking — steady organic pipeline')
  ) as q(hosp, camp, code, pm, ch, obj, reg, spend, leads, ql, cust, rev, cac, roas, ltv, verdict, nt)
  where q.code is not null;

  -- CAPA / optimization actions — attach to specific campaigns by code
  insert into public.marketing_roas_capa_actions_r3177 (
    roas_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('MKT-GA-RBW-09','low_roas','targeting_mismatch','pause_channel','2026-07-10',null,'in_progress','growth_blocker',5000.00,'NICU keywords too niche — pause & shift budget to referral'),
    ('MKT-MT-APL-10','weak_conversion','creative_stale','refresh_creative','2026-07-08','2026-07-06','closed','budget_reallocation',18000.00,'Refreshed creatives, moved 40% of budget to SEO'),
    ('MKT-MT-FRT-02','poor_lead_quality','audience_saturated','retarget_audience','2026-07-12',null,'open','internal_only',12000.00,'Lead quality dropping — rebuild lookalike seed list'),
    ('MKT-EV-KIM-05','high_cac','seasonality','reallocate_budget','2026-07-15',null,'verification_pending','margin_alert',9000.00,'Expo season soft — shift spend to Q3 events'),
    ('MKT-EV-MNP-12','low_ltv_cac','sales_followup_slow','accelerate_sales_followup','2026-06-30',null,'overdue','board_review',15000.00,'Long conference sales cycle — followup SLA breached'),
    ('MKT-LI-KIM-14','high_cac','budget_misallocation','adjust_bid_strategy','2026-07-11',null,'escalated','margin_alert',7000.00,'Procurement titles expensive — tighten bid caps')
  ) as q(code, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.marketing_roas_r3177 e
    on e.organization_id = v_org_id and e.campaign_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Verdict / status rollup (+pct)
create or replace function public.founder_r3177_verdict_rollup()
returns table(verdict text, campaigns bigint, total_spend numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.marketing_roas_r3177)
  select l.verdict, count(*)::bigint,
         coalesce(sum(l.spend_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.marketing_roas_r3177 l
  group by l.verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3177_verdict_rollup() from public, anon;
grant execute on function public.founder_r3177_verdict_rollup() to authenticated;

-- 2) Hospital-account scorecard
create or replace function public.founder_r3177_hospital_scorecard()
returns table(
  hospital_name text,
  campaigns bigint,
  total_spend numeric,
  total_revenue numeric,
  customers bigint,
  avg_roas numeric,
  avg_cac numeric,
  avg_ltv_cac numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    coalesce(sum(l.spend_rupees),0)::numeric,
    coalesce(sum(l.revenue_attributed_rupees),0)::numeric,
    coalesce(sum(l.customers_won),0)::bigint,
    round(avg(l.roas), 2),
    round(avg(l.cac_rupees), 0),
    round(avg(l.ltv_cac_ratio), 2)
  from public.marketing_roas_r3177 l
  group by l.hospital_name
  order by coalesce(sum(l.spend_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3177_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3177_hospital_scorecard() to authenticated;

-- 3) Channel × objective matrix
create or replace function public.founder_r3177_channel_matrix()
returns table(
  channel text,
  campaign_objective text,
  campaigns bigint,
  total_spend numeric,
  customers bigint,
  avg_roas numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.channel, l.campaign_objective, count(*)::bigint,
    coalesce(sum(l.spend_rupees),0)::numeric,
    coalesce(sum(l.customers_won),0)::bigint,
    round(avg(l.roas), 2)
  from public.marketing_roas_r3177 l
  group by l.channel, l.campaign_objective
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3177_channel_matrix() from public, anon;
grant execute on function public.founder_r3177_channel_matrix() to authenticated;

-- 4) Period (month) trend
create or replace function public.founder_r3177_period_trend()
returns table(
  period_month date,
  campaigns bigint,
  total_spend numeric,
  total_revenue numeric,
  customers bigint,
  avg_roas numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month, count(*)::bigint,
    coalesce(sum(l.spend_rupees),0)::numeric,
    coalesce(sum(l.revenue_attributed_rupees),0)::numeric,
    coalesce(sum(l.customers_won),0)::bigint,
    round(avg(l.roas), 2)
  from public.marketing_roas_r3177 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3177_period_trend() from public, anon;
grant execute on function public.founder_r3177_period_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3177_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_flag bigint)
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
  from public.marketing_roas_capa_actions_r3177 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3177_capa_status_board() from public, anon;
grant execute on function public.founder_r3177_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3177_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.marketing_roas_capa_actions_r3177)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.marketing_roas_capa_actions_r3177 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3177_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3177_root_cause_pareto() to authenticated;

-- 7) Regulatory / impact digest
create or replace function public.founder_r3177_regulatory_impact_digest()
returns table(regulatory_impact text, actions bigint, open_actions bigint, total_cost_rupees numeric)
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
  from public.marketing_roas_capa_actions_r3177 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3177_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3177_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority queue (underperforming campaigns)
create or replace function public.founder_r3177_priority_queue()
returns table(
  hospital_name text,
  campaign_name text,
  channel text,
  period_month date,
  spend_rupees numeric,
  roas numeric,
  cac_rupees numeric,
  ltv_cac_ratio numeric,
  verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.campaign_name, l.channel, l.period_month,
    l.spend_rupees, l.roas, l.cac_rupees, l.ltv_cac_ratio, l.verdict, l.notes
  from public.marketing_roas_r3177 l
  where l.verdict in ('pause','cut','watch','optimize','under_review')
     or l.roas < 5.0
     or l.ltv_cac_ratio < 3.0
  order by l.roas asc, l.spend_rupees desc;
end;
$$;

revoke execute on function public.founder_r3177_priority_queue() from public, anon;
grant execute on function public.founder_r3177_priority_queue() to authenticated;
