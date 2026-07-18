-- Round 3149: Founder Monthly Board-KPI Pack Freshness & Distribution Tracker
-- Board pack KPI log — metric × owner × target/actual × variance × freshness × RAG × distribution channel × CAPA

-- =============================================================================
-- TABLE 1: board_kpi_pack_r3149 — one row per board-pack KPI line
-- =============================================================================
create table if not exists public.board_kpi_pack_r3149 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  metric_name text not null,
  metric_category text not null check (metric_category in (
    'financial_revenue','financial_cost','operational_uptime','clinical_quality',
    'growth_pipeline','customer_satisfaction','people_hr','compliance_regulatory','cash_liquidity','service_sla'
  )),
  owner_name text not null,
  owner_function text not null check (owner_function in (
    'ceo_office','finance','operations','sales_growth','clinical_services',
    'engineering_service','people_hr','product','quality_compliance','customer_success'
  )),
  reporting_period text not null check (reporting_period in (
    'monthly','quarterly','trailing_12m','ytd','weekly'
  )),
  unit_of_measure text not null check (unit_of_measure in (
    'inr_lakhs','inr_crores','rupees','percentage','count','days','ratio','nps_score','hours'
  )),
  target_value numeric(14,2) not null,
  actual_value numeric(14,2) not null,
  variance_pct numeric(6,2),
  variance_direction text not null check (variance_direction in (
    'favorable','unfavorable','on_target','marginal_miss','marginal_beat'
  )),
  data_as_of_date date not null,
  sent_to_board_date date,
  freshness_days int,
  freshness_band text not null check (freshness_band in (
    'real_time','fresh','aging','stale','expired'
  )),
  rag_status text not null check (rag_status in (
    'green','amber','red','grey_no_data'
  )),
  trend_direction text not null check (trend_direction in (
    'improving','flat','declining','volatile','new_metric'
  )),
  distribution_channel text not null check (distribution_channel in (
    'board_portal_upload','secure_email_pdf','printed_boardroom_pack','datastudio_dashboard_link',
    'whatsapp_exec_group','physical_courier','investor_data_room'
  )),
  pack_verdict text not null check (pack_verdict in (
    'published_on_time','published_late','withheld_data_gap','restated_correction',
    'draft_pending_review','blocked_source_missing','distributed_partial'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.board_kpi_pack_r3149 enable row level security;

create index if not exists idx_board_kpi_pack_r3149_org on public.board_kpi_pack_r3149(organization_id);
create index if not exists idx_board_kpi_pack_r3149_sent on public.board_kpi_pack_r3149(sent_to_board_date);
create index if not exists idx_board_kpi_pack_r3149_verdict on public.board_kpi_pack_r3149(pack_verdict);

-- =============================================================================
-- TABLE 2: board_kpi_pack_capa_actions_r3149 — follow-up / CAPA actions
-- =============================================================================
create table if not exists public.board_kpi_pack_capa_actions_r3149 (
  id uuid primary key default gen_random_uuid(),
  kpi_pack_id uuid not null references public.board_kpi_pack_r3149(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'stale_data_source','missing_owner_signoff','target_miss_material','variance_unexplained',
    'distribution_delay','data_quality_error','metric_definition_drift','manual_restatement','no_prior_period_baseline'
  )),
  root_cause text not null check (root_cause in (
    'source_system_lag','manual_spreadsheet_bottleneck','owner_unavailable','integration_broken',
    'definition_ambiguity','data_entry_error','approval_workflow_delay','upstream_dependency_missing','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'automate_data_pipeline','reassign_metric_owner','add_source_integration','tighten_signoff_sla',
    'restate_and_reissue','clarify_metric_definition','add_validation_check','escalate_to_ceo','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'board_governance_flag','investor_disclosure_risk','audit_committee_item','none','internal_only','statutory_filing_risk'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.board_kpi_pack_capa_actions_r3149 enable row level security;

create index if not exists idx_board_kpi_capa_r3149_pack on public.board_kpi_pack_capa_actions_r3149(kpi_pack_id);
create index if not exists idx_board_kpi_capa_r3149_status on public.board_kpi_pack_capa_actions_r3149(capa_status);

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

  -- 14 board-pack KPI rows
  insert into public.board_kpi_pack_r3149 (
    organization_id, hospital_name, metric_name, metric_category, owner_name, owner_function,
    reporting_period, unit_of_measure, target_value, actual_value, variance_pct, variance_direction,
    data_as_of_date, sent_to_board_date, freshness_days, freshness_band, rag_status, trend_direction,
    distribution_channel, pack_verdict, notes
  )
  select v_org_id, q.hosp, q.mname, q.mcat, q.owner, q.ofunc,
    q.period, q.unit, q.tgt, q.act, q.vpct, q.vdir,
    q.asof::date, q.sent::date, q.fresh::int, q.fband, q.rag, q.trend,
    q.chan, q.verdict, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','Monthly Recurring AMC Revenue','financial_revenue','Rakesh Menon','finance',
     'monthly','inr_lakhs',85.00,78.50,-7.65,'unfavorable',
     '2026-06-30','2026-07-05','5','fresh','amber','declining',
     'board_portal_upload','published_on_time','Q1 renewal slippage at two accounts'),
    ('Apollo Hyderabad Jubilee Hills','Equipment Uptime Percentage','operational_uptime','Sunita Rao','operations',
     'monthly','percentage',98.00,96.20,-1.84,'marginal_miss',
     '2026-06-30','2026-07-05','5','fresh','amber','flat',
     'board_portal_upload','published_on_time','Two CT downtime events in the month'),
    ('Fortis Bannerghatta Bengaluru','Net Promoter Score','customer_satisfaction','Anil Kapoor','customer_success',
     'quarterly','nps_score',60.00,64.00,6.67,'favorable',
     '2026-06-30','2026-07-12','12','aging','green','improving',
     'secure_email_pdf','published_late','Survey collation lag pushed pack past deadline'),
    ('Fortis Bannerghatta Bengaluru','Service SLA Compliance','service_sla','Deepa Nair','engineering_service',
     'monthly','percentage',95.00,88.00,-7.37,'unfavorable',
     '2026-06-30',null,null,'stale','red','declining',
     'printed_boardroom_pack','withheld_data_gap','SLA feed incomplete — line withheld from pack'),
    ('Manipal Whitefield Bengaluru','Cash Runway Months','cash_liquidity','Vikram Shetty','finance',
     'monthly','count',12.00,9.50,-20.83,'unfavorable',
     '2026-06-30','2026-07-03','3','fresh','amber','declining',
     'investor_data_room','published_on_time','Runway compression from capex draw'),
    ('Manipal Whitefield Bengaluru','New Hospital Logos Signed','growth_pipeline','Priya Menon','sales_growth',
     'monthly','count',4.00,2.00,-50.00,'unfavorable',
     '2026-06-30','2026-07-20','20','expired','red','volatile',
     'whatsapp_exec_group','published_late','Pipeline stalled; pack circulated very late'),
    ('AIIMS New Delhi Ansari Nagar','Preventive Maintenance Coverage','compliance_regulatory','Rohit Sharma','quality_compliance',
     'monthly','percentage',100.00,92.00,-8.00,'unfavorable',
     '2026-06-30','2026-07-06','6','fresh','amber','improving',
     'board_portal_upload','published_on_time','Eight percent of assets missed the PM window'),
    ('AIIMS New Delhi Ansari Nagar','Gross Margin Percentage','financial_cost','Meena Iyer','finance',
     'quarterly','percentage',42.00,44.50,5.95,'favorable',
     '2026-06-30','2026-07-04','4','fresh','green','improving',
     'secure_email_pdf','published_on_time','Cost optimization tracking ahead of plan'),
    ('KIMS Secunderabad','Employee Attrition Percentage','people_hr','Sanjay Gupta','people_hr',
     'trailing_12m','percentage',15.00,22.00,46.67,'unfavorable',
     '2026-05-31','2026-07-10','40','expired','red','declining',
     'printed_boardroom_pack','restated_correction','Restated after HRIS correction; source was stale'),
    ('KIMS Secunderabad','Spare Parts Fill Rate','service_sla','Kavya Reddy','engineering_service',
     'monthly','percentage',90.00,85.50,-5.00,'unfavorable',
     '2026-06-30','2026-07-05','5','fresh','amber','flat',
     'datastudio_dashboard_link','published_on_time','Import delays on three fast-moving SKUs'),
    ('Care Hospitals Banjara Hills','Revenue per Bed','financial_revenue','Arjun Rao','finance',
     'monthly','rupees',45000.00,47200.00,4.89,'favorable',
     '2026-06-30','2026-07-05','5','fresh','green','improving',
     'board_portal_upload','published_on_time','Occupancy and ARPOB both up month on month'),
    ('Yashoda Somajiguda Hyderabad','Critical Asset Downtime Hours','operational_uptime','Lakshmi Prasad','operations',
     'monthly','hours',10.00,18.50,85.00,'unfavorable',
     '2026-06-30',null,null,'stale','red','declining',
     'physical_courier','blocked_source_missing','CMMS export failed; metric blocked from pack'),
    ('St John''s Bengaluru','Board Pack On-Time Delivery','compliance_regulatory','Thomas Varghese','ceo_office',
     'monthly','percentage',100.00,100.00,0.00,'on_target',
     '2026-06-30','2026-07-02','2','real_time','green','flat',
     'board_portal_upload','published_on_time','Pack shipped two days after month close'),
    ('Rainbow Children''s Hyderabad','Pediatric OT Utilization','operational_uptime','Nisha Menon','operations',
     'monthly','percentage',80.00,71.00,-11.25,'unfavorable',
     '2026-06-30','2026-07-08','8','aging','amber','declining',
     'datastudio_dashboard_link','draft_pending_review','Draft under review; not yet distributed')
  ) as q(hosp, mname, mcat, owner, ofunc, period, unit, tgt, act, vpct, vdir,
         asof, sent, fresh, fband, rag, trend, chan, verdict, nt);

  -- CAPA / follow-up seed — attach to specific KPI lines by metric_name
  insert into public.board_kpi_pack_capa_actions_r3149 (
    kpi_pack_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('Service SLA Compliance','stale_data_source','source_system_lag','automate_data_pipeline',
     '2026-07-25',null,'in_progress','board_governance_flag',120000.00,'SLA feed automation in progress'),
    ('New Hospital Logos Signed','distribution_delay','approval_workflow_delay','tighten_signoff_sla',
     '2026-07-30',null,'open','audit_committee_item',15000.00,'Pack circulated twenty days after close'),
    ('Employee Attrition Percentage','manual_restatement','data_entry_error','restate_and_reissue',
     '2026-07-15','2026-07-11','closed','investor_disclosure_risk',8000.00,'HRIS figure restated and reissued'),
    ('Critical Asset Downtime Hours','data_quality_error','integration_broken','add_source_integration',
     '2026-07-22',null,'escalated','board_governance_flag',95000.00,'CMMS export pipeline down; escalated to CEO'),
    ('Pediatric OT Utilization','missing_owner_signoff','owner_unavailable','reassign_metric_owner',
     '2026-07-20',null,'in_progress','internal_only',5000.00,'Owner on leave; draft still unsigned'),
    ('Monthly Recurring AMC Revenue','variance_unexplained','definition_ambiguity','clarify_metric_definition',
     '2026-07-18',null,'overdue','audit_committee_item',12000.00,'Variance bridge not attached; now overdue')
  ) as q(mkey, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.board_kpi_pack_r3149 e
    on e.organization_id = v_org_id and e.metric_name = q.mkey;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Pack verdict / status distribution
create or replace function public.founder_r3149_pack_verdict_rollup()
returns table(pack_verdict text, packs bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.board_kpi_pack_r3149)
  select l.pack_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.board_kpi_pack_r3149 l
  group by l.pack_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3149_pack_verdict_rollup() from public, anon;
grant execute on function public.founder_r3149_pack_verdict_rollup() to authenticated;

-- 2) Entity / hospital freshness scorecard
create or replace function public.founder_r3149_entity_scorecard()
returns table(
  hospital_name text,
  total_kpis bigint,
  green bigint,
  amber bigint,
  red bigint,
  on_time bigint,
  stale_or_expired bigint,
  avg_freshness_days numeric,
  green_pct numeric
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
    count(*) filter (where l.rag_status = 'green')::bigint,
    count(*) filter (where l.rag_status = 'amber')::bigint,
    count(*) filter (where l.rag_status = 'red')::bigint,
    count(*) filter (where l.pack_verdict = 'published_on_time')::bigint,
    count(*) filter (where l.freshness_band in ('stale','expired'))::bigint,
    round(avg(l.freshness_days), 1),
    round(100.0 * count(*) filter (where l.rag_status = 'green')::numeric / nullif(count(*),0), 1)
  from public.board_kpi_pack_r3149 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3149_entity_scorecard() from public, anon;
grant execute on function public.founder_r3149_entity_scorecard() to authenticated;

-- 3) Category × owner-function matrix
create or replace function public.founder_r3149_category_matrix()
returns table(
  metric_category text,
  owner_function text,
  kpis bigint,
  green bigint,
  red bigint,
  avg_variance_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.metric_category, l.owner_function, count(*)::bigint,
    count(*) filter (where l.rag_status = 'green')::bigint,
    count(*) filter (where l.rag_status = 'red')::bigint,
    round(avg(l.variance_pct), 2)
  from public.board_kpi_pack_r3149 l
  group by l.metric_category, l.owner_function
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3149_category_matrix() from public, anon;
grant execute on function public.founder_r3149_category_matrix() to authenticated;

-- 4) Distribution / freshness time trend by sent-to-board date
create or replace function public.founder_r3149_freshness_trend()
returns table(
  sent_to_board_date date,
  packs bigint,
  on_time bigint,
  late bigint,
  avg_freshness_days numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.sent_to_board_date,
    count(*)::bigint,
    count(*) filter (where l.pack_verdict = 'published_on_time')::bigint,
    count(*) filter (where l.pack_verdict = 'published_late')::bigint,
    round(avg(l.freshness_days), 1)
  from public.board_kpi_pack_r3149 l
  where l.sent_to_board_date is not null
  group by l.sent_to_board_date
  order by l.sent_to_board_date desc;
end;
$$;

revoke execute on function public.founder_r3149_freshness_trend() from public, anon;
grant execute on function public.founder_r3149_freshness_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3149_capa_status_board()
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
  from public.board_kpi_pack_capa_actions_r3149 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3149_capa_status_board() from public, anon;
grant execute on function public.founder_r3149_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3149_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.board_kpi_pack_capa_actions_r3149)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.board_kpi_pack_capa_actions_r3149 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3149_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3149_root_cause_pareto() to authenticated;

-- 7) Regulatory / governance impact digest
create or replace function public.founder_r3149_regulatory_impact_digest()
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
  from public.board_kpi_pack_capa_actions_r3149 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3149_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3149_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority KPI queue
create or replace function public.founder_r3149_priority_queue()
returns table(
  hospital_name text,
  metric_name text,
  metric_category text,
  owner_name text,
  rag_status text,
  freshness_band text,
  variance_pct numeric,
  sent_to_board_date date,
  pack_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.metric_name, l.metric_category, l.owner_name,
    l.rag_status, l.freshness_band, l.variance_pct, l.sent_to_board_date, l.pack_verdict, l.notes
  from public.board_kpi_pack_r3149 l
  where l.rag_status = 'red'
     or l.freshness_band in ('stale','expired')
     or l.pack_verdict in ('withheld_data_gap','blocked_source_missing','restated_correction','draft_pending_review','published_late')
  order by l.data_as_of_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3149_priority_queue() from public, anon;
grant execute on function public.founder_r3149_priority_queue() to authenticated;
