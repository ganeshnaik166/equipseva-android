-- Round 3572: Engineer OEM Service-Contract Back-to-Back SLA / Margin Tracker
-- OEM back-to-back service contracts (we resell OEM support) — SLA alignment (customer vs OEM) ×
-- coverage alignment × contract status × pricing/margin × sla-gap exposure × CAPA closure

-- =============================================================================
-- TABLE 1: oem_back_to_back_r3572 — per-contract back-to-back SLA / margin fact
-- =============================================================================
create table if not exists public.oem_back_to_back_r3572 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  customer_name text not null,
  device_model text not null,
  oem_name text not null,
  contract_code text not null,
  customer_sla_hrs int not null,
  oem_sla_hrs int not null,
  sla_gap_hrs int not null,
  customer_price_rupees numeric(12,2) not null,
  oem_cost_rupees numeric(12,2) not null,
  margin_pct numeric(6,2) not null,
  coverage_alignment text not null check (coverage_alignment in (
    'fully_aligned','minor_gap','major_gap','uncovered','over_covered'
  )),
  contract_status text not null check (contract_status in (
    'active','renewal_due','expired','at_risk','disputed'
  )),
  period_month date not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.oem_back_to_back_r3572 enable row level security;

create index if not exists idx_oem_back_to_back_r3572_org on public.oem_back_to_back_r3572(organization_id);
create index if not exists idx_oem_back_to_back_r3572_month on public.oem_back_to_back_r3572(period_month);
create index if not exists idx_oem_back_to_back_r3572_status on public.oem_back_to_back_r3572(contract_status);

-- =============================================================================
-- TABLE 2: oem_back_to_back_capa_actions_r3572 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.oem_back_to_back_capa_actions_r3572 (
  id uuid primary key default gen_random_uuid(),
  contract_link_id uuid not null references public.oem_back_to_back_r3572(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'sla_gap_exposure','negative_margin','uncovered_scope','renewal_overdue',
    'price_below_cost','coverage_mismatch','contract_dispute','oem_sla_slower_than_customer'
  )),
  root_cause text not null check (root_cause in (
    'oem_sla_longer_than_customer','underpriced_contract','oem_cost_escalation','scope_not_mapped',
    'renewal_not_actioned','currency_fx_impact','pending_investigation','discount_over_committed'
  )),
  corrective_action text not null check (corrective_action in (
    'renegotiate_oem_sla','reprice_customer_contract','align_coverage_scope','escalate_to_oem',
    'initiate_renewal','add_sla_buffer_clause','terminate_contract','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  margin_impact_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.oem_back_to_back_capa_actions_r3572 enable row level security;

create index if not exists idx_oem_back_to_back_capa_r3572_link on public.oem_back_to_back_capa_actions_r3572(contract_link_id);
create index if not exists idx_oem_back_to_back_capa_r3572_status on public.oem_back_to_back_capa_actions_r3572(capa_status);

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

  -- 16 back-to-back contract rows
  insert into public.oem_back_to_back_r3572 (
    organization_id, customer_name, device_model, oem_name, contract_code,
    customer_sla_hrs, oem_sla_hrs, sla_gap_hrs,
    customer_price_rupees, oem_cost_rupees, margin_pct,
    coverage_alignment, contract_status, period_month, notes
  )
  select v_org_id, q.cust, q.dmodel, q.oem, q.ccode,
    q.cshr, q.oshr, q.gap,
    q.cprice, q.ocost, q.mpct,
    q.cov, q.cstat, q.pmon::date, q.nt
  from (values
    ('Apollo Chennai','Revolution CT','GE Healthcare','OEM-APL-CT-01',
     24,24,0,480000,360000,25.00,'fully_aligned','active','2026-07-01','CT back-to-back AMC fully aligned with OEM SLA'),
    ('Apollo Chennai','Optima MR360','GE Healthcare','OEM-APL-MR-02',
     24,48,24,700000,610000,12.86,'major_gap','at_risk','2026-07-01','OEM MRI SLA 48h vs 24h promised — 24h exposure gap'),
    ('Fortis Gurgaon','Ingenia 1.5T','Philips','OEM-FRT-MR-03',
     24,72,48,760000,720000,5.26,'major_gap','disputed','2026-06-01','OEM 72h SLA far exceeds 24h commit; margin thin, dispute open'),
    ('Fortis Gurgaon','Azurion 7','Philips','OEM-FRT-CL-04',
     12,24,12,950000,720000,24.21,'minor_gap','renewal_due','2026-06-01','Cath-lab 12h vs OEM 24h minor gap; renewal due next cycle'),
    ('Manipal Bengaluru','SAVINA 300','Draeger','OEM-MNP-VN-05',
     8,8,0,180000,120000,33.33,'fully_aligned','active','2026-07-01','ICU ventilator contract fully aligned, healthy margin'),
    ('Manipal Bengaluru','Evita V600','Draeger','OEM-MNP-VN-06',
     8,12,4,200000,150000,25.00,'minor_gap','active','2026-06-01','Ventilator OEM 12h vs 8h commit — 4h minor gap'),
    ('AIIMS Delhi','Somatom go.Top','Siemens','OEM-AIM-CT-07',
     24,24,0,520000,390000,25.00,'fully_aligned','active','2026-07-01','CT contract aligned, margin on target'),
    ('AIIMS Delhi','Artis Q','Siemens','OEM-AIM-CL-08',
     12,48,36,900000,920000,-2.22,'major_gap','at_risk','2026-06-01','Cath-lab OEM 48h vs 12h; contract running at a loss'),
    ('CMC Vellore','LOGIQ E10','GE Healthcare','OEM-CMC-US-09',
     24,24,0,260000,175000,32.69,'fully_aligned','active','2026-07-01','Ultrasound contract aligned, strong margin'),
    ('CMC Vellore','ACUSON Sequoia','Siemens','OEM-CMC-US-10',
     24,36,12,240000,230000,4.17,'minor_gap','renewal_due','2026-06-01','USG OEM 36h vs 24h; thin margin, scope mapping pending'),
    ('KIMS Hyderabad','BeneVision N22','Mindray','OEM-KIM-PM-11',
     12,12,0,210000,240000,-14.29,'fully_aligned','disputed','2026-06-01','Monitor OEM cost exceeds customer price — negative margin'),
    ('KIMS Hyderabad','Resona 7','Mindray','OEM-KIM-US-12',
     48,24,-24,230000,150000,34.78,'over_covered','active','2026-07-01','OEM 24h faster than 48h customer need — over-covered'),
    ('Yashoda Hyderabad','Carescape B650','GE Healthcare','OEM-YSH-PM-13',
     12,12,0,190000,130000,31.58,'fully_aligned','active','2026-07-01','Patient-monitor contract aligned, margin healthy'),
    ('Kokilaben Mumbai','MAGNETOM Sola','Siemens','OEM-KKB-MR-14',
     24,24,0,780000,560000,28.21,'fully_aligned','renewal_due','2026-06-01','MRI contract aligned; renewal quote in progress'),
    ('Kokilaben Mumbai','Aquilion Lightning','Canon Medical','OEM-KKB-CT-15',
     24,72,48,500000,510000,-2.00,'uncovered','expired','2026-05-01','Contract expired, scope uncovered, running at a loss'),
    ('Medanta Gurgaon','HeartStart XL+','Philips','OEM-MDT-DF-16',
     24,24,0,90000,55000,38.89,'fully_aligned','active','2026-07-01','Defibrillator contract aligned, best-in-class margin')
  ) as q(cust, dmodel, oem, ccode, cshr, oshr, gap, cprice, ocost, mpct, cov, cstat, pmon, nt);

  -- CAPA seed — attach to specific contracts via contract_code
  insert into public.oem_back_to_back_capa_actions_r3572 (
    contract_link_id, finding_category, root_cause, corrective_action,
    capa_status, margin_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('OEM-FRT-MR-03','sla_gap_exposure','oem_sla_longer_than_customer','renegotiate_oem_sla','in_progress',40000.00,'Rahul Menon','2026-08-15',null,'OEM MRI SLA 72h; renegotiating down to 24h back-to-back'),
    ('OEM-APL-MR-02','sla_gap_exposure','oem_sla_longer_than_customer','add_sla_buffer_clause','open',90000.00,'Priya Nair','2026-08-20',null,'Add penalty-buffer clause to customer MRI contract'),
    ('OEM-AIM-CL-08','negative_margin','underpriced_contract','reprice_customer_contract','escalated',20000.00,'Vikram Rao','2026-08-10',null,'Cath-lab contract at a loss — repricing escalated to leadership'),
    ('OEM-KIM-PM-11','negative_margin','oem_cost_escalation','escalate_to_oem','in_progress',30000.00,'Anjali Gupta','2026-08-05',null,'Monitor OEM cost hiked above customer price — escalated to OEM'),
    ('OEM-KKB-CT-15','uncovered_scope','renewal_not_actioned','initiate_renewal','overdue',10000.00,'Suresh Iyer','2026-07-20',null,'Expired CT contract, scope uncovered — renewal overdue'),
    ('OEM-FRT-CL-04','renewal_overdue','renewal_not_actioned','initiate_renewal','closed',0.00,'Priya Nair','2026-07-10','2026-07-08','Cath-lab renewal signed and margin re-baselined'),
    ('OEM-CMC-US-10','coverage_mismatch','scope_not_mapped','align_coverage_scope','verification_pending',5000.00,'Deepa Krishnan','2026-08-12',null,'USG scope mapping updated — awaiting verification'),
    ('OEM-AIM-CL-08','contract_dispute','discount_over_committed','escalate_to_oem','open',15000.00,'Vikram Rao','2026-08-18',null,'Discount over-committed vs OEM cost — dispute raised with OEM')
  ) as q(ccode, fc, rc, ca, cst, impact, ownr, tcd, acd, nt)
  join public.oem_back_to_back_r3572 e
    on e.organization_id = v_org_id and e.contract_code = q.ccode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Contract-status distribution
create or replace function public.founder_r3572_contract_status_rollup()
returns table(contract_status text, contracts bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.oem_back_to_back_r3572)
  select l.contract_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.oem_back_to_back_r3572 l
  group by l.contract_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3572_contract_status_rollup() from public, anon;
grant execute on function public.founder_r3572_contract_status_rollup() to authenticated;

-- 2) OEM scorecard
create or replace function public.founder_r3572_oem_scorecard()
returns table(
  oem_name text,
  contracts bigint,
  fully_aligned bigint,
  major_gap bigint,
  uncovered bigint,
  negative_margin bigint,
  avg_margin_pct numeric,
  avg_sla_gap_hrs numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.oem_name,
    count(*)::bigint,
    count(*) filter (where l.coverage_alignment = 'fully_aligned')::bigint,
    count(*) filter (where l.coverage_alignment = 'major_gap')::bigint,
    count(*) filter (where l.coverage_alignment = 'uncovered')::bigint,
    count(*) filter (where l.margin_pct < 0)::bigint,
    round(avg(l.margin_pct), 2),
    round(avg(l.sla_gap_hrs), 1)
  from public.oem_back_to_back_r3572 l
  group by l.oem_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3572_oem_scorecard() from public, anon;
grant execute on function public.founder_r3572_oem_scorecard() to authenticated;

-- 3) Coverage-alignment × contract-status matrix
create or replace function public.founder_r3572_coverage_status_matrix()
returns table(coverage_alignment text, contract_status text, contracts bigint, avg_margin_pct numeric, avg_sla_gap_hrs numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.coverage_alignment, l.contract_status, count(*)::bigint,
    round(avg(l.margin_pct), 2),
    round(avg(l.sla_gap_hrs), 1)
  from public.oem_back_to_back_r3572 l
  group by l.coverage_alignment, l.contract_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3572_coverage_status_matrix() from public, anon;
grant execute on function public.founder_r3572_coverage_status_matrix() to authenticated;

-- 4) Monthly margin trend
create or replace function public.founder_r3572_monthly_margin_trend()
returns table(
  period_month date,
  contracts bigint,
  total_customer_price_rupees numeric,
  total_oem_cost_rupees numeric,
  avg_margin_pct numeric,
  negative_margin bigint
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
    coalesce(sum(l.customer_price_rupees),0)::numeric,
    coalesce(sum(l.oem_cost_rupees),0)::numeric,
    round(avg(l.margin_pct), 2),
    count(*) filter (where l.margin_pct < 0)::bigint
  from public.oem_back_to_back_r3572 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3572_monthly_margin_trend() from public, anon;
grant execute on function public.founder_r3572_monthly_margin_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3572_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.margin_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.oem_back_to_back_capa_actions_r3572 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3572_capa_status_board() from public, anon;
grant execute on function public.founder_r3572_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3572_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.oem_back_to_back_capa_actions_r3572)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.margin_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.oem_back_to_back_capa_actions_r3572 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3572_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3572_root_cause_pareto() to authenticated;

-- 7) SLA-gap impact digest (by coverage alignment)
create or replace function public.founder_r3572_sla_gap_impact_digest()
returns table(
  coverage_alignment text,
  contracts bigint,
  avg_sla_gap_hrs numeric,
  max_sla_gap_hrs int,
  total_customer_price_rupees numeric,
  total_oem_cost_rupees numeric,
  avg_margin_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.coverage_alignment,
    count(*)::bigint,
    round(avg(l.sla_gap_hrs), 1),
    max(l.sla_gap_hrs)::int,
    coalesce(sum(l.customer_price_rupees),0)::numeric,
    coalesce(sum(l.oem_cost_rupees),0)::numeric,
    round(avg(l.margin_pct), 2)
  from public.oem_back_to_back_r3572 l
  group by l.coverage_alignment
  order by avg(l.sla_gap_hrs) desc nulls last;
end;
$$;

revoke execute on function public.founder_r3572_sla_gap_impact_digest() from public, anon;
grant execute on function public.founder_r3572_sla_gap_impact_digest() to authenticated;

-- 8) High-risk contract queue (uncovered / major-gap / negative-margin / at-risk)
create or replace function public.founder_r3572_high_risk_queue()
returns table(
  customer_name text,
  contract_code text,
  device_model text,
  oem_name text,
  period_month date,
  coverage_alignment text,
  contract_status text,
  sla_gap_hrs int,
  margin_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_name, l.contract_code, l.device_model, l.oem_name, l.period_month,
    l.coverage_alignment, l.contract_status, l.sla_gap_hrs, l.margin_pct, l.notes
  from public.oem_back_to_back_r3572 l
  where l.coverage_alignment in ('uncovered','major_gap')
     or l.margin_pct < 0
     or l.contract_status in ('at_risk','disputed','expired')
  order by l.margin_pct asc, l.sla_gap_hrs desc;
end;
$$;

revoke execute on function public.founder_r3572_high_risk_queue() from public, anon;
grant execute on function public.founder_r3572_high_risk_queue() to authenticated;
