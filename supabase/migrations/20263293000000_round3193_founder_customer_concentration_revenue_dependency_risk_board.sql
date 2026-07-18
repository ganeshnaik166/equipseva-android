-- Round 3193: Founder Customer-Concentration & Revenue-Dependency Risk Board
-- Concentration risk log — customer × segment × trailing-12m revenue × share % × top-N bucket × contract end × churn × dependency verdict × CAPA

-- =============================================================================
-- TABLE 1: revenue_concentration_r3193 — per-customer revenue-dependency lines
-- =============================================================================
create table if not exists public.revenue_concentration_r3193 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  customer_code text not null,
  customer_segment text not null check (customer_segment in (
    'corporate_chain','government_public','trust_charitable','standalone_private',
    'medical_college','specialty_pediatric','diagnostics_chain','defence_psu'
  )),
  revenue_stream text not null check (revenue_stream in (
    'amc_contracts','cmc_contracts','breakdown_repairs','spare_parts',
    'installation_projects','calibration_services','consumables','equipment_buyback'
  )),
  trailing_12m_revenue_rupees numeric(14,2) not null,
  revenue_share_pct numeric(5,2) not null,
  concentration_bucket text not null check (concentration_bucket in (
    'top_1','top_5','top_10','top_25','long_tail'
  )),
  contract_end_date date,
  contract_status text not null check (contract_status in (
    'active_multi_year','active_annual','renewal_due_90d','renewal_due_30d',
    'month_to_month','expired_holdover','under_negotiation'
  )),
  churn_risk text not null check (churn_risk in (
    'low','moderate','elevated','high','critical'
  )),
  payment_behavior text not null check (payment_behavior in (
    'pays_early','on_time','delayed_30d','delayed_60d','delayed_90d_plus','disputed'
  )),
  relationship_tenure_months int,
  dependency_verdict text not null check (dependency_verdict in (
    'healthy_diversified','watch','concentrated','over_dependent','critical_dependency','exit_risk'
  )),
  as_of_date date not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.revenue_concentration_r3193 enable row level security;

create index if not exists idx_rev_conc_r3193_org on public.revenue_concentration_r3193(organization_id);
create index if not exists idx_rev_conc_r3193_verdict on public.revenue_concentration_r3193(dependency_verdict);
create index if not exists idx_rev_conc_r3193_bucket on public.revenue_concentration_r3193(concentration_bucket);

-- =============================================================================
-- TABLE 2: revenue_concentration_capa_actions_r3193 — mitigation / CAPA actions
-- =============================================================================
create table if not exists public.revenue_concentration_capa_actions_r3193 (
  id uuid primary key default gen_random_uuid(),
  concentration_id uuid not null references public.revenue_concentration_r3193(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'single_customer_over_20pct','top5_over_60pct','contract_expiry_cluster',
    'churn_signal_detected','payment_delay_worsening','segment_over_weighted',
    'key_account_rfp_open','pricing_pressure'
  )),
  root_cause text not null check (root_cause in (
    'sales_focus_large_accounts','weak_smb_pipeline','geographic_cluster',
    'service_line_gap','legacy_founder_relationship','competitor_underpricing',
    'no_account_diversification_target','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'launch_smb_acquisition_drive','negotiate_multi_year_renewal','diversify_service_lines',
    'add_second_account_owner','escalate_collections_review','tier_pricing_lock_in',
    'expand_new_geography','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'board_reportable','investor_covenant','lender_notification','auditor_flag','internal_only','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.revenue_concentration_capa_actions_r3193 enable row level security;

create index if not exists idx_rev_conc_capa_r3193_conc on public.revenue_concentration_capa_actions_r3193(concentration_id);
create index if not exists idx_rev_conc_capa_r3193_status on public.revenue_concentration_capa_actions_r3193(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only (per rule 8)
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 14 concentration lines
  insert into public.revenue_concentration_r3193 (
    organization_id, hospital_name, customer_code, customer_segment, revenue_stream,
    trailing_12m_revenue_rupees, revenue_share_pct, concentration_bucket,
    contract_end_date, contract_status, churn_risk, payment_behavior,
    relationship_tenure_months, dependency_verdict, as_of_date, notes
  )
  select v_org_id, q.hosp, q.code, q.seg, q.rs,
    q.rev, q.share, q.bucket,
    q.ced::date, q.cst, q.cr, q.pb,
    q.ten, q.dv, q.aod::date, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','CUST-APL-HYD-AMC','corporate_chain','amc_contracts',18400000.00,22.40,'top_1','2027-03-31','active_multi_year','moderate','on_time',54,'critical_dependency','2026-07-15','Single largest account at 22.4% of trailing-12m revenue'),
    ('Fortis Bannerghatta Bengaluru','CUST-FRT-BLR-CMC','corporate_chain','cmc_contracts',9800000.00,11.90,'top_5','2026-09-30','renewal_due_90d','elevated','delayed_30d',38,'concentrated','2026-07-15','Renewal inside 90 days and procurement has opened an RFP'),
    ('Manipal Whitefield Bengaluru','CUST-MNP-BLR-REP','corporate_chain','breakdown_repairs',7200000.00,8.80,'top_5','2026-12-31','active_annual','moderate','on_time',41,'concentrated','2026-07-15','Breakdown repair volume steady across 4 departments'),
    ('AIIMS New Delhi Ansari Nagar','CUST-AIM-DEL-INS','government_public','installation_projects',6500000.00,7.90,'top_5','2027-01-31','active_annual','low','delayed_60d',29,'watch','2026-07-15','GeM tender-driven; slow payment but sticky relationship'),
    ('KIMS Secunderabad','CUST-KIM-SEC-SPR','corporate_chain','spare_parts',5100000.00,6.20,'top_5','2026-08-31','renewal_due_30d','high','delayed_60d',22,'exit_risk','2026-07-15','Renewal due in 30 days; competitor underquoting spares basket'),
    ('Care Hospitals Banjara Hills','CUST-CAR-HYD-AMC','corporate_chain','amc_contracts',4300000.00,5.20,'top_10','2027-05-31','active_multi_year','low','pays_early',47,'healthy_diversified','2026-07-15','Three-year AMC signed 2025; pays before due date'),
    ('Yashoda Somajiguda Hyderabad','CUST-YSH-HYD-CAL','standalone_private','calibration_services',3600000.00,4.40,'top_10','2026-10-31','renewal_due_90d','moderate','on_time',33,'watch','2026-07-15','NABL calibration bundle up for renewal in October'),
    ('St John''s Medical College Bengaluru','CUST-STJ-BLR-CMC','medical_college','cmc_contracts',3100000.00,3.80,'top_10','2027-02-28','active_annual','low','on_time',26,'healthy_diversified','2026-07-15','Teaching hospital CMC; stable multi-department coverage'),
    ('Rainbow Children''s Hyderabad','CUST-RBW-HYD-CON','specialty_pediatric','consumables',2700000.00,3.30,'top_10','2026-11-30','active_annual','moderate','delayed_30d',19,'watch','2026-07-15','Consumables reorders trending down 8% QoQ'),
    ('Apollo Hyderabad Jubilee Hills','CUST-APL-HYD-SPR','corporate_chain','spare_parts',2400000.00,2.90,'top_10',null,'month_to_month','moderate','on_time',54,'over_dependent','2026-07-15','Ad hoc spares under same parent as the top-1 AMC account'),
    ('Manipal Whitefield Bengaluru','CUST-MNP-BLR-CAL','corporate_chain','calibration_services',1900000.00,2.30,'top_25','2026-09-15','under_negotiation','elevated','disputed',41,'watch','2026-07-15','Calibration rate card disputed since May billing cycle'),
    ('KIMS Secunderabad','CUST-KIM-SEC-INS','corporate_chain','installation_projects',1600000.00,1.90,'top_25',null,'expired_holdover','critical','delayed_90d_plus',22,'exit_risk','2026-07-15','Holdover since March; receivables at 94 days outstanding'),
    ('AIIMS New Delhi Ansari Nagar','CUST-AIM-DEL-CAL','government_public','calibration_services',1400000.00,1.70,'top_25','2027-03-31','active_annual','low','delayed_60d',29,'healthy_diversified','2026-07-15','Annual NABL calibration rate contract; renews on GeM'),
    ('Care Hospitals Banjara Hills','CUST-CAR-HYD-CON','corporate_chain','consumables',900000.00,1.10,'long_tail',null,'month_to_month','low','on_time',47,'healthy_diversified','2026-07-15','Low-value consumable reorders; negligible dependency')
  ) as q(hosp, code, seg, rs, rev, share, bucket, ced, cst, cr, pb, ten, dv, aod, nt);

  -- CAPA seed — attach to specific concentration lines by customer_code
  insert into public.revenue_concentration_capa_actions_r3193 (
    concentration_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('CUST-APL-HYD-AMC','single_customer_over_20pct','sales_focus_large_accounts','launch_smb_acquisition_drive','2026-09-30',null,'in_progress','board_reportable',250000.00,'New-logo drive targets Apollo below 18% share by Q3'),
    ('CUST-FRT-BLR-CMC','key_account_rfp_open','competitor_underpricing','negotiate_multi_year_renewal','2026-08-15',null,'escalated','investor_covenant',80000.00,'Three-year CMC proposal with 6% multi-year discount submitted'),
    ('CUST-KIM-SEC-SPR','churn_signal_detected','competitor_underpricing','tier_pricing_lock_in','2026-08-05',null,'open','internal_only',40000.00,'Loyalty spares pricing tier drafted for renewal meeting'),
    ('CUST-KIM-SEC-INS','payment_delay_worsening','pending_investigation','escalate_collections_review','2026-07-31',null,'overdue','lender_notification',0,'Receivables at 94 days; credit hold decision pending'),
    ('CUST-MNP-BLR-CAL','pricing_pressure','competitor_underpricing','tier_pricing_lock_in','2026-08-20','2026-07-10','closed','internal_only',15000.00,'Revised calibration rate card accepted; dispute withdrawn'),
    ('CUST-YSH-HYD-CAL','contract_expiry_cluster','no_account_diversification_target','add_second_account_owner','2026-09-01',null,'verification_pending','none',10000.00,'Second account owner assigned; renewal plan under review')
  ) as q(code_key, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.revenue_concentration_r3193 e
    on e.organization_id = v_org_id and e.customer_code = q.code_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Dependency verdict distribution (revenue-weighted)
create or replace function public.founder_r3193_dependency_verdict_rollup()
returns table(dependency_verdict text, customers bigint, revenue_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select coalesce(sum(t.trailing_12m_revenue_rupees),0)::numeric as n from public.revenue_concentration_r3193 t)
  select e.dependency_verdict, count(*)::bigint,
    coalesce(sum(e.trailing_12m_revenue_rupees),0)::numeric,
    round(coalesce(sum(e.trailing_12m_revenue_rupees),0) / nullif((select n from tot),0) * 100.0, 1)
  from public.revenue_concentration_r3193 e
  group by e.dependency_verdict
  order by coalesce(sum(e.trailing_12m_revenue_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3193_dependency_verdict_rollup() from public, anon;
grant execute on function public.founder_r3193_dependency_verdict_rollup() to authenticated;

-- 2) Customer / hospital dependency scorecard
create or replace function public.founder_r3193_customer_scorecard()
returns table(
  hospital_name text,
  revenue_lines bigint,
  total_revenue_rupees numeric,
  revenue_share_pct numeric,
  high_churn_lines bigint,
  at_risk_lines bigint,
  avg_tenure_months numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.hospital_name,
    count(*)::bigint,
    coalesce(sum(e.trailing_12m_revenue_rupees),0)::numeric,
    round(coalesce(sum(e.revenue_share_pct),0), 2),
    count(*) filter (where e.churn_risk in ('high','critical'))::bigint,
    count(*) filter (where e.dependency_verdict in ('over_dependent','critical_dependency','exit_risk'))::bigint,
    round(avg(e.relationship_tenure_months)::numeric, 1)
  from public.revenue_concentration_r3193 e
  group by e.hospital_name
  order by coalesce(sum(e.trailing_12m_revenue_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3193_customer_scorecard() from public, anon;
grant execute on function public.founder_r3193_customer_scorecard() to authenticated;

-- 3) Segment × revenue-stream matrix
create or replace function public.founder_r3193_segment_stream_matrix()
returns table(customer_segment text, revenue_stream text, customers bigint, total_revenue_rupees numeric, avg_share_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.customer_segment, e.revenue_stream, count(*)::bigint,
    coalesce(sum(e.trailing_12m_revenue_rupees),0)::numeric,
    round(avg(e.revenue_share_pct), 2)
  from public.revenue_concentration_r3193 e
  group by e.customer_segment, e.revenue_stream
  order by coalesce(sum(e.trailing_12m_revenue_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3193_segment_stream_matrix() from public, anon;
grant execute on function public.founder_r3193_segment_stream_matrix() to authenticated;

-- 4) Contract expiry timeline — revenue at risk by end date
create or replace function public.founder_r3193_contract_expiry_timeline()
returns table(contract_end_date date, contracts bigint, revenue_at_risk_rupees numeric, share_at_risk_pct numeric, high_churn_contracts bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select coalesce(sum(t.trailing_12m_revenue_rupees),0)::numeric as n from public.revenue_concentration_r3193 t)
  select e.contract_end_date, count(*)::bigint,
    coalesce(sum(e.trailing_12m_revenue_rupees),0)::numeric,
    round(coalesce(sum(e.trailing_12m_revenue_rupees),0) / nullif((select n from tot),0) * 100.0, 1),
    count(*) filter (where e.churn_risk in ('high','critical'))::bigint
  from public.revenue_concentration_r3193 e
  where e.contract_end_date is not null
  group by e.contract_end_date
  order by e.contract_end_date asc;
end;
$$;

revoke execute on function public.founder_r3193_contract_expiry_timeline() from public, anon;
grant execute on function public.founder_r3193_contract_expiry_timeline() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3193_capa_status_board()
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
  from public.revenue_concentration_capa_actions_r3193 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3193_capa_status_board() from public, anon;
grant execute on function public.founder_r3193_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3193_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.revenue_concentration_capa_actions_r3193)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.revenue_concentration_capa_actions_r3193 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3193_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3193_root_cause_pareto() to authenticated;

-- 7) Regulatory / governance impact digest
create or replace function public.founder_r3193_regulatory_impact_digest()
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
  from public.revenue_concentration_capa_actions_r3193 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3193_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3193_regulatory_impact_digest() to authenticated;

-- 8) High-risk accounts queue (top individual concerns)
create or replace function public.founder_r3193_high_risk_accounts()
returns table(
  hospital_name text,
  customer_code text,
  revenue_stream text,
  trailing_12m_revenue_rupees numeric,
  revenue_share_pct numeric,
  concentration_bucket text,
  contract_end_date date,
  churn_risk text,
  dependency_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.hospital_name, e.customer_code, e.revenue_stream,
    e.trailing_12m_revenue_rupees, e.revenue_share_pct, e.concentration_bucket,
    e.contract_end_date, e.churn_risk, e.dependency_verdict, e.notes
  from public.revenue_concentration_r3193 e
  where e.dependency_verdict in ('over_dependent','critical_dependency','exit_risk')
     or e.churn_risk in ('high','critical')
     or e.contract_status in ('renewal_due_30d','expired_holdover')
     or e.payment_behavior in ('delayed_90d_plus','disputed')
  order by e.revenue_share_pct desc, e.hospital_name;
end;
$$;

revoke execute on function public.founder_r3193_high_risk_accounts() from public, anon;
grant execute on function public.founder_r3193_high_risk_accounts() to authenticated;
