-- Round 3464: Engineer Spare-Part Pricing / Markup / Quote-Margin Tracker
-- Service-quote pricing governance — engineer × part × device model × cost/quoted price × markup × margin ×
-- pricing tier × margin status × approval × CAPA closure

-- =============================================================================
-- TABLE 1: part_pricing_markup_r3464 — per-quote spare-part pricing / margin log
-- =============================================================================
create table if not exists public.part_pricing_markup_r3464 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  quote_ref text not null,
  part_name text not null,
  part_code text not null,
  device_model text not null,
  cost_price_rupees numeric(12,2) not null,
  quoted_price_rupees numeric(12,2) not null,
  markup_pct numeric(6,2),
  margin_pct numeric(6,2),
  pricing_tier text not null check (pricing_tier in (
    'list','contract','amc_bundled','goodwill','emergency'
  )),
  margin_status text not null check (margin_status in (
    'above_target','on_target','below_target','below_floor'
  )),
  quote_date date not null,
  approved boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.part_pricing_markup_r3464 enable row level security;

create index if not exists idx_part_pricing_markup_r3464_org on public.part_pricing_markup_r3464(organization_id);
create index if not exists idx_part_pricing_markup_r3464_date on public.part_pricing_markup_r3464(quote_date);
create index if not exists idx_part_pricing_markup_r3464_status on public.part_pricing_markup_r3464(margin_status);

-- =============================================================================
-- TABLE 2: part_pricing_markup_capa_actions_r3464 — CAPA & margin-recovery actions
-- =============================================================================
create table if not exists public.part_pricing_markup_capa_actions_r3464 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  quote_id uuid not null references public.part_pricing_markup_r3464(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'below_floor_margin','below_target_margin','unapproved_quote','cost_price_stale',
    'markup_error','wrong_pricing_tier','competitor_price_gap','discount_unauthorized'
  )),
  root_cause text not null check (root_cause in (
    'stale_cost_master','manual_pricing_error','aggressive_discount','wrong_tier_applied',
    'emergency_sourcing_premium','goodwill_concession','fx_import_cost_spike','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'update_cost_master','reprice_quote','seek_approval','apply_correct_tier',
    'renegotiate_supplier','escalate_to_manager','absorb_as_goodwill','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  pricing_impact_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.part_pricing_markup_capa_actions_r3464 enable row level security;

create index if not exists idx_part_pricing_markup_capa_r3464_quote on public.part_pricing_markup_capa_actions_r3464(quote_id);
create index if not exists idx_part_pricing_markup_capa_r3464_status on public.part_pricing_markup_capa_actions_r3464(capa_status);

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

  -- 16 pricing / margin quote rows
  insert into public.part_pricing_markup_r3464 (
    organization_id, engineer_name, quote_ref, part_name, part_code, device_model,
    cost_price_rupees, quoted_price_rupees, markup_pct, margin_pct,
    pricing_tier, margin_status, quote_date, approved, notes
  )
  select v_org_id, q.eng, q.qref, q.pname, q.pcode, q.dmodel,
    q.cost, q.quoted, q.markup, q.margin,
    q.tier, q.mstat, q.qdate::date, q.appr, q.nt
  from (values
    ('Ramesh Kumar','QT-BLR-3001','Ventilator O2 Sensor','O2-CELL-7','Draeger Savina 300',
     3200.00,5400.00,68.75,40.74,'list','above_target','2026-07-05',true,'Standard list pricing, healthy margin'),
    ('Ramesh Kumar','QT-BLR-3002','ECG Module Board','ECG-BRD-12','Philips IntelliVue MX450',
     18500.00,24500.00,32.43,24.49,'contract','on_target','2026-07-05',true,'AMC contract-rate board replacement'),
    ('Suresh Nair','QT-CHN-3003','Infusion Pump Battery','BAT-INF-3','BD Alaris',
     2100.00,2600.00,23.81,19.23,'contract','below_target','2026-07-04',true,'Contract discount squeezed margin below target'),
    ('Suresh Nair','QT-CHN-3004','X-Ray Tube Assembly','XR-TUBE-9','Siemens Multix',
     145000.00,152000.00,4.83,4.61,'emergency','below_floor','2026-07-04',false,'Emergency import; supplier premium wiped out margin, unapproved'),
    ('Priya Sharma','QT-DEL-3005','Dialysis Blood Pump','DLY-PMP-5','Fresenius 4008S',
     26000.00,38000.00,46.15,31.58,'list','above_target','2026-07-03',true,'List pricing dialysis pump head'),
    ('Priya Sharma','QT-DEL-3006','Patient Monitor Screen','MON-LCD-15','Mindray uMEC12',
     9500.00,11200.00,17.89,15.18,'amc_bundled','below_target','2026-07-03',true,'Bundled into AMC, thin margin by design'),
    ('Anil Gupta','QT-HYD-3007','Ultrasound Probe Linear','US-PRB-L38','GE Logiq P9',
     88000.00,132000.00,50.00,33.33,'list','above_target','2026-07-02',true,'High-value probe, strong list margin'),
    ('Anil Gupta','QT-HYD-3008','Anesthesia Vaporizer','ANS-VAP-2','GE Aisys CS2',
     42000.00,44000.00,4.76,4.55,'goodwill','below_floor','2026-07-02',false,'Goodwill concession to retain account, below floor, pending approval'),
    ('Deepak Verma','QT-PUN-3009','Centrifuge Rotor','CEN-ROT-4','Remi R-8C',
     6800.00,9200.00,35.29,26.09,'list','on_target','2026-07-01',true,'Lab centrifuge rotor, on target'),
    ('Deepak Verma','QT-PUN-3010','Autoclave Gasket Set','ACL-GKT-6','Getinge HS66',
     1400.00,2100.00,50.00,33.33,'list','above_target','2026-07-01',true,'Consumable gasket set, good margin'),
    ('Kavita Rao','QT-MUM-3011','CT Cooling Pump','CT-COOL-8','Philips Ingenuity',
     62000.00,66500.00,7.26,6.77,'contract','below_target','2026-06-30',true,'Contract capped margin on CT cooling pump'),
    ('Kavita Rao','QT-MUM-3012','Defibrillator Paddle Set','DEF-PAD-3','Zoll R Series',
     15500.00,15900.00,2.58,2.52,'emergency','below_floor','2026-06-30',false,'Emergency same-day; near cost, unapproved margin'),
    ('Rajesh Iyer','QT-KOL-3013','Endoscope Light Guide','ENDO-LG-11','Karl Storz',
     34000.00,49000.00,44.12,30.61,'list','above_target','2026-06-29',true,'Endoscopy light guide list pricing'),
    ('Rajesh Iyer','QT-KOL-3014','Suction Regulator','SUC-REG-2','Ohio Medical',
     2600.00,3300.00,26.92,21.21,'amc_bundled','on_target','2026-06-29',true,'AMC-bundled suction regulator at target'),
    ('Meena Joshi','QT-AHM-3015','MRI Chiller Compressor','MRI-CMP-1','Siemens Magnetom',
     210000.00,218000.00,3.81,3.67,'goodwill','below_floor','2026-06-28',false,'Goodwill on MRI chiller to save relationship, below floor'),
    ('Meena Joshi','QT-AHM-3016','Nebulizer Compressor Kit','NEB-CMP-7','Philips InnoSpire',
     1800.00,2900.00,61.11,37.93,'list','above_target','2026-06-28',true,'Standard nebulizer kit, strong margin')
  ) as q(eng, qref, pname, pcode, dmodel, cost, quoted, markup, margin, tier, mstat, qdate, appr, nt);

  -- CAPA seed — attach to specific quotes via quote_ref
  insert into public.part_pricing_markup_capa_actions_r3464 (
    organization_id, quote_id, finding_category, root_cause, corrective_action,
    capa_status, pricing_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.organization_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.owner, q.tcd::date, q.acd::date, q.nt
  from (values
    ('QT-CHN-3004','below_floor_margin','emergency_sourcing_premium','renegotiate_supplier','in_progress',6800.00,'Vikram Menon','2026-07-10',null,'Emergency X-ray tube; renegotiate supplier premium and reprice'),
    ('QT-HYD-3008','below_floor_margin','goodwill_concession','escalate_to_manager','open',2000.00,'Vikram Menon','2026-07-09',null,'Vaporizer goodwill concession pending manager sign-off'),
    ('QT-MUM-3012','unapproved_quote','manual_pricing_error','seek_approval','open',400.00,'Sunita Desai','2026-07-08',null,'Defib paddle quoted near cost without approval'),
    ('QT-AHM-3015','below_floor_margin','goodwill_concession','absorb_as_goodwill','verification_pending',8000.00,'Sunita Desai','2026-07-07',null,'MRI chiller goodwill absorbed; verifying account retention value'),
    ('QT-CHN-3003','below_target_margin','aggressive_discount','apply_correct_tier','closed',500.00,'Vikram Menon','2026-07-06','2026-07-05','Reclassified to correct contract tier; margin restored'),
    ('QT-DEL-3006','below_target_margin','wrong_tier_applied','reprice_quote','closed',300.00,'Sunita Desai','2026-07-05','2026-07-04','Monitor screen AMC bundle margin accepted as by-design'),
    ('QT-MUM-3011','below_target_margin','stale_cost_master','update_cost_master','overdue',900.00,'Vikram Menon','2026-07-02',null,'CT cooling pump cost master stale; update overdue'),
    ('QT-CHN-3004','markup_error','manual_pricing_error','update_cost_master','escalated',1200.00,'Sunita Desai','2026-07-11',null,'Second finding on X-ray tube: markup formula error in quote tool')
  ) as q(qref, fc, rc, ca, cst, impact, owner, tcd, acd, nt)
  join public.part_pricing_markup_r3464 e
    on e.organization_id = v_org_id and e.quote_ref = q.qref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Margin-status distribution
create or replace function public.founder_r3464_margin_status_rollup()
returns table(margin_status text, quotes bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.part_pricing_markup_r3464)
  select l.margin_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.part_pricing_markup_r3464 l
  group by l.margin_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3464_margin_status_rollup() from public, anon;
grant execute on function public.founder_r3464_margin_status_rollup() to authenticated;

-- 2) Pricing-tier scorecard
create or replace function public.founder_r3464_pricing_tier_scorecard()
returns table(
  pricing_tier text,
  total_quotes bigint,
  above_target bigint,
  on_target bigint,
  below_target bigint,
  below_floor bigint,
  approved bigint,
  avg_margin_pct numeric,
  avg_markup_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.pricing_tier,
    count(*)::bigint,
    count(*) filter (where l.margin_status = 'above_target')::bigint,
    count(*) filter (where l.margin_status = 'on_target')::bigint,
    count(*) filter (where l.margin_status = 'below_target')::bigint,
    count(*) filter (where l.margin_status = 'below_floor')::bigint,
    count(*) filter (where l.approved = true)::bigint,
    round(avg(l.margin_pct), 2),
    round(avg(l.markup_pct), 2)
  from public.part_pricing_markup_r3464 l
  group by l.pricing_tier
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3464_pricing_tier_scorecard() from public, anon;
grant execute on function public.founder_r3464_pricing_tier_scorecard() to authenticated;

-- 3) Pricing-tier × margin-status matrix
create or replace function public.founder_r3464_tier_margin_matrix()
returns table(
  pricing_tier text,
  margin_status text,
  quotes bigint,
  avg_margin_pct numeric,
  avg_markup_pct numeric,
  total_quoted_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.pricing_tier, l.margin_status, count(*)::bigint,
    round(avg(l.margin_pct), 2),
    round(avg(l.markup_pct), 2),
    coalesce(sum(l.quoted_price_rupees),0)::numeric
  from public.part_pricing_markup_r3464 l
  group by l.pricing_tier, l.margin_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3464_tier_margin_matrix() from public, anon;
grant execute on function public.founder_r3464_tier_margin_matrix() to authenticated;

-- 4) Monthly margin trend
create or replace function public.founder_r3464_monthly_margin_trend()
returns table(
  month text,
  quotes bigint,
  avg_margin_pct numeric,
  avg_markup_pct numeric,
  below_floor bigint,
  total_quoted_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(date_trunc('month', l.quote_date), 'YYYY-MM'),
    count(*)::bigint,
    round(avg(l.margin_pct), 2),
    round(avg(l.markup_pct), 2),
    count(*) filter (where l.margin_status = 'below_floor')::bigint,
    coalesce(sum(l.quoted_price_rupees),0)::numeric
  from public.part_pricing_markup_r3464 l
  group by to_char(date_trunc('month', l.quote_date), 'YYYY-MM')
  order by to_char(date_trunc('month', l.quote_date), 'YYYY-MM') desc;
end;
$$;

revoke execute on function public.founder_r3464_monthly_margin_trend() from public, anon;
grant execute on function public.founder_r3464_monthly_margin_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3464_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.pricing_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.part_pricing_markup_capa_actions_r3464 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3464_capa_status_board() from public, anon;
grant execute on function public.founder_r3464_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3464_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.part_pricing_markup_capa_actions_r3464)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.pricing_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.part_pricing_markup_capa_actions_r3464 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3464_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3464_root_cause_pareto() to authenticated;

-- 7) Margin-impact digest (per engineer)
create or replace function public.founder_r3464_margin_impact_digest()
returns table(
  engineer_name text,
  quotes bigint,
  total_cost_rupees numeric,
  total_quoted_rupees numeric,
  total_margin_rupees numeric,
  avg_margin_pct numeric,
  below_floor bigint
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
    coalesce(sum(l.cost_price_rupees),0)::numeric,
    coalesce(sum(l.quoted_price_rupees),0)::numeric,
    coalesce(sum(l.quoted_price_rupees - l.cost_price_rupees),0)::numeric,
    round(avg(l.margin_pct), 2),
    count(*) filter (where l.margin_status = 'below_floor')::bigint
  from public.part_pricing_markup_r3464 l
  group by l.engineer_name
  order by coalesce(sum(l.quoted_price_rupees - l.cost_price_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3464_margin_impact_digest() from public, anon;
grant execute on function public.founder_r3464_margin_impact_digest() to authenticated;

-- 8) High-risk quote queue (below-floor / below-target / unapproved)
create or replace function public.founder_r3464_high_risk_queue()
returns table(
  engineer_name text,
  quote_ref text,
  part_name text,
  part_code text,
  device_model text,
  pricing_tier text,
  cost_price_rupees numeric,
  quoted_price_rupees numeric,
  margin_pct numeric,
  margin_status text,
  approved boolean,
  quote_date date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.quote_ref, l.part_name, l.part_code, l.device_model,
    l.pricing_tier, l.cost_price_rupees, l.quoted_price_rupees, l.margin_pct,
    l.margin_status, l.approved, l.quote_date, l.notes
  from public.part_pricing_markup_r3464 l
  where l.margin_status in ('below_target','below_floor')
     or l.approved = false
  order by
    case l.margin_status when 'below_floor' then 0 when 'below_target' then 1 else 2 end,
    l.quote_date desc, l.engineer_name;
end;
$$;

revoke execute on function public.founder_r3464_high_risk_queue() from public, anon;
grant execute on function public.founder_r3464_high_risk_queue() to authenticated;
