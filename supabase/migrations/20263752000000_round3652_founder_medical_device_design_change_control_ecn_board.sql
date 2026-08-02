-- Round 3652: Medical-Device Design-Change Control / ECN Board
-- Design-change / ECN lifecycle — change class × status × risk assessment × regulatory notification × V&V × days open × affected documents × implementation % × trend × CAPA

-- =============================================================================
-- TABLE 1: design_change_r3652 — per-change design-change control / ECN records
-- =============================================================================
create table if not exists public.design_change_r3652 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  change_ref text not null,
  device_name text not null,
  period_month date not null,
  change_description text not null,
  risk_assessment_done boolean not null,
  regulatory_notification_needed boolean not null,
  vv_required boolean not null,
  days_open int not null,
  affected_documents int not null,
  implementation_pct numeric(5,1) not null,
  initiated_date date not null,
  target_close_date date not null,
  change_class text not null check (change_class in (
    'design','process','supplier','labeling','software'
  )),
  change_status text not null check (change_status in (
    'implemented','in_progress','awaiting_approval','on_hold','overdue'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.design_change_r3652 enable row level security;

create index if not exists idx_design_change_r3652_org on public.design_change_r3652(organization_id);
create index if not exists idx_design_change_r3652_month on public.design_change_r3652(period_month);
create index if not exists idx_design_change_r3652_status on public.design_change_r3652(change_status);

-- =============================================================================
-- TABLE 2: design_change_capa_actions_r3652 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.design_change_capa_actions_r3652 (
  id uuid primary key default gen_random_uuid(),
  change_id uuid not null references public.design_change_r3652(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'incomplete_impact_assessment','document_update_backlog','supplier_qualification_delay',
    'vv_resource_shortage','regulatory_review_pending','software_regression_found',
    'training_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'expedite_document_updates','allocate_vv_resources','requalify_supplier',
    'file_regulatory_notification','revise_change_procedure','retrain_change_owners',
    'rollback_change','escalate_to_cft','add_regression_tests','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  estimated_cost_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.design_change_capa_actions_r3652 enable row level security;

create index if not exists idx_design_change_capa_r3652_change on public.design_change_capa_actions_r3652(change_id);
create index if not exists idx_design_change_capa_r3652_status on public.design_change_capa_actions_r3652(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Change status distribution
create or replace function public.founder_r3652_change_status_rollup()
returns table(change_status text, changes bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.design_change_r3652)
  select l.change_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.design_change_r3652 l
  group by l.change_status
  order by count(*) desc;
end;
$$;

-- 2) Change-class scorecard
create or replace function public.founder_r3652_change_class_scorecard()
returns table(
  change_class text,
  total_changes bigint,
  implemented bigint,
  in_progress bigint,
  awaiting_approval bigint,
  on_hold bigint,
  overdue_changes bigint,
  avg_days_open numeric,
  avg_implementation_pct numeric,
  implemented_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.change_class,
    count(*)::bigint,
    count(*) filter (where l.change_status = 'implemented')::bigint,
    count(*) filter (where l.change_status = 'in_progress')::bigint,
    count(*) filter (where l.change_status = 'awaiting_approval')::bigint,
    count(*) filter (where l.change_status = 'on_hold')::bigint,
    count(*) filter (where l.change_status = 'overdue')::bigint,
    round(avg(l.days_open)::numeric, 1),
    round(avg(l.implementation_pct)::numeric, 1),
    round(100.0 * count(*) filter (where l.change_status = 'implemented')::numeric / nullif(count(*),0), 1)
  from public.design_change_r3652 l
  group by l.change_class
  order by count(*) desc;
end;
$$;

-- 3) Change-class × change-status matrix
create or replace function public.founder_r3652_class_status_matrix()
returns table(change_class text, change_status text, changes bigint, avg_days_open numeric, avg_implementation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.change_class, l.change_status, count(*)::bigint,
    round(avg(l.days_open)::numeric, 1),
    round(avg(l.implementation_pct)::numeric, 1)
  from public.design_change_r3652 l
  group by l.change_class, l.change_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly change trend
create or replace function public.founder_r3652_monthly_change_trend()
returns table(period_month date, changes bigint, implemented bigint, overdue_changes bigint, vv_required_cnt bigint, reg_notifications bigint, avg_days_open numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.change_status = 'implemented')::bigint,
    count(*) filter (where l.change_status = 'overdue')::bigint,
    count(*) filter (where l.vv_required = true)::bigint,
    count(*) filter (where l.regulatory_notification_needed = true)::bigint,
    round(avg(l.days_open)::numeric, 1)
  from public.design_change_r3652 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3652_capa_status_board()
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
  from public.design_change_capa_actions_r3652 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3652_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.design_change_capa_actions_r3652)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.design_change_capa_actions_r3652 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Aging-impact digest
create or replace function public.founder_r3652_aging_impact_digest()
returns table(age_bucket text, changes bigint, avg_implementation_pct numeric, overdue_changes bigint, on_hold_changes bigint, reg_notifications bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.bucket, count(*)::bigint,
    round(avg(b.impl_pct)::numeric, 1),
    count(*) filter (where b.cstatus = 'overdue')::bigint,
    count(*) filter (where b.cstatus = 'on_hold')::bigint,
    count(*) filter (where b.regn = true)::bigint
  from (
    select case
      when l.days_open <= 30 then '0-30 days'
      when l.days_open <= 60 then '31-60 days'
      when l.days_open <= 90 then '61-90 days'
      else '90+ days'
    end as bucket,
    l.implementation_pct as impl_pct,
    l.change_status as cstatus,
    l.regulatory_notification_needed as regn
    from public.design_change_r3652 l
  ) b
  group by b.bucket
  order by b.bucket;
end;
$$;

-- 8) High-risk change queue (overdue / on-hold / worsening / reg-pending)
create or replace function public.founder_r3652_high_risk_queue()
returns table(
  change_ref text,
  device_name text,
  change_class text,
  change_status text,
  trend_dir text,
  days_open int,
  implementation_pct numeric,
  regulatory_notification_needed boolean,
  target_close_date date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.change_ref, l.device_name, l.change_class, l.change_status, l.trend_dir,
    l.days_open, l.implementation_pct, l.regulatory_notification_needed,
    l.target_close_date, l.notes
  from public.design_change_r3652 l
  where l.change_status in ('overdue','on_hold')
     or l.trend_dir = 'worsening'
     or (l.regulatory_notification_needed = true and l.change_status <> 'implemented')
     or l.days_open > 90
     or l.risk_assessment_done = false
  order by l.days_open desc, l.change_ref;
end;
$$;

-- =============================================================================
-- GRANTS — founder RPCs restricted to authenticated
-- =============================================================================
revoke all on function public.founder_r3652_change_status_rollup() from public, anon;
revoke all on function public.founder_r3652_change_class_scorecard() from public, anon;
revoke all on function public.founder_r3652_class_status_matrix() from public, anon;
revoke all on function public.founder_r3652_monthly_change_trend() from public, anon;
revoke all on function public.founder_r3652_capa_status_board() from public, anon;
revoke all on function public.founder_r3652_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3652_aging_impact_digest() from public, anon;
revoke all on function public.founder_r3652_high_risk_queue() from public, anon;

grant execute on function public.founder_r3652_change_status_rollup() to authenticated;
grant execute on function public.founder_r3652_change_class_scorecard() to authenticated;
grant execute on function public.founder_r3652_class_status_matrix() to authenticated;
grant execute on function public.founder_r3652_monthly_change_trend() to authenticated;
grant execute on function public.founder_r3652_capa_status_board() to authenticated;
grant execute on function public.founder_r3652_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3652_aging_impact_digest() to authenticated;
grant execute on function public.founder_r3652_high_risk_queue() to authenticated;

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

  -- 16 design-change / ECN rows
  insert into public.design_change_r3652 (
    organization_id, change_ref, device_name, period_month, change_description,
    risk_assessment_done, regulatory_notification_needed, vv_required,
    days_open, affected_documents, implementation_pct, initiated_date, target_close_date,
    change_class, change_status, trend_dir, notes
  )
  select v_org_id, q.cref, q.dev, q.pmon::date, q.cdesc,
    q.ra, q.regn, q.vv,
    q.dopen, q.adocs, q.impct, q.idate::date, q.tdate::date,
    q.ccls, q.cst, q.trd, q.nt
  from (values
    ('ECN-2026-001','ICU Ventilator VX-500','2026-07-01','O2 sensor supplier change from Make-A to Make-B',
     true,true,true,18,6,65.0,'2026-06-24','2026-07-30','supplier','in_progress','improving','Supplier qualification report awaited'),
    ('ECN-2026-002','Infusion Pump IP-230','2026-07-01','Occlusion alarm threshold firmware update',
     true,true,true,42,9,40.0,'2026-05-31','2026-07-15','software','awaiting_approval','stable','CFT approval pending on V&V protocol'),
    ('ECN-2026-003','Patient Monitor PM-12','2026-07-01','SpO2 cable connector redesign for strain relief',
     true,false,true,12,4,80.0,'2026-06-30','2026-07-25','design','in_progress','improving','DFMEA updated; tooling trial pending'),
    ('ECN-2026-004','Dialysis Machine DM-800','2026-06-01','Conductivity cell cleaning process change',
     true,false,false,75,3,100.0,'2026-04-17','2026-06-20','process','implemented','improving','Process validated; batch records updated'),
    ('ECN-2026-005','Defibrillator DF-Pro','2026-06-01','IFU labeling update for pediatric pad energy',
     true,true,false,95,11,55.0,'2026-03-28','2026-06-10','labeling','overdue','worsening','CDSCO notification draft stuck in review'),
    ('ECN-2026-006','C-Arm CA-9 HD','2026-06-01','Collimator assembly design tolerance revision',
     true,false,true,38,7,70.0,'2026-05-24','2026-07-05','design','in_progress','stable','Prototype tolerance study complete'),
    ('ECN-2026-007','Syringe Pump SP-50','2026-06-01','Drug library software v3.2 update',
     true,true,true,110,14,25.0,'2026-03-13','2026-05-30','software','on_hold','worsening','Held for regression failure in bolus module'),
    ('ECN-2026-008','ECG Machine EC-300','2026-05-01','Electrode gel supplier requalification',
     true,false,false,20,2,100.0,'2026-04-11','2026-05-15','supplier','implemented','improving','Supplier audit closed with no findings'),
    ('ECN-2026-009','ICU Ventilator VX-500','2026-05-01','Battery pack vendor change due to EOL',
     true,true,true,66,8,50.0,'2026-03-26','2026-06-01','supplier','awaiting_approval','stable','Awaiting RA sign-off on notification package'),
    ('ECN-2026-010','Patient Monitor PM-12','2026-05-01','Alarm audio label multilingual update',
     true,false,false,15,5,100.0,'2026-04-16','2026-05-10','labeling','implemented','improving','Hindi and Tamil labels released'),
    ('ECN-2026-011','Dialysis Machine DM-800','2026-05-01','Blood pump motor driver board redesign',
     true,true,true,88,12,35.0,'2026-02-06','2026-05-20','design','overdue','worsening','EMC retest slot delayed at NABL lab'),
    ('ECN-2026-012','Infusion Pump IP-230','2026-04-01','Assembly line torque process change',
     true,false,false,30,3,100.0,'2026-03-02','2026-04-10','process','implemented','stable','Torque validation IQ/OQ/PQ complete'),
    ('ECN-2026-013','Defibrillator DF-Pro','2026-04-01','Capacitor charging firmware fix',
     true,true,true,52,10,60.0,'2026-02-08','2026-04-25','software','in_progress','improving','V&V 60 pct complete; unit tests passed'),
    ('ECN-2026-014','C-Arm CA-9 HD','2026-04-01','X-ray tube housing gasket material change',
     false,false,true,44,6,20.0,'2026-02-16','2026-04-30','design','on_hold','worsening','Risk assessment not completed - held by QA'),
    ('ECN-2026-015','ECG Machine EC-300','2026-04-01','Carton artwork barcode correction',
     true,false,false,10,2,100.0,'2026-03-22','2026-04-05','labeling','implemented','improving','GS1 barcode corrected and verified'),
    ('ECN-2026-016','Syringe Pump SP-50','2026-07-01','Keypad membrane supplier dual-sourcing',
     true,false,true,25,5,45.0,'2026-06-17','2026-08-05','supplier','in_progress','stable','Second-source samples under IQC testing')
  ) as q(cref, dev, pmon, cdesc, ra, regn, vv, dopen, adocs, impct, idate, tdate, ccls, cst, trd, nt);

  -- 8 CAPA rows — attach to specific changes via change_ref
  insert into public.design_change_capa_actions_r3652 (
    change_id, root_cause, corrective_action, capa_status,
    estimated_cost_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.cost, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('ECN-2026-005','regulatory_review_pending','file_regulatory_notification','escalated',85000.00,'Priya Nair - RA Lead','2026-07-10',null,'Pediatric pad labeling notification escalated to RA head'),
    ('ECN-2026-007','software_regression_found','add_regression_tests','in_progress',140000.00,'Arjun Mehta - SW QA','2026-07-20',null,'Bolus module regression suite being expanded'),
    ('ECN-2026-011','vv_resource_shortage','allocate_vv_resources','overdue',220000.00,'Kavitha Rao - V&V Manager','2026-06-25',null,'EMC retest booking delayed - NABL slot in August'),
    ('ECN-2026-014','incomplete_impact_assessment','revise_change_procedure','open',30000.00,'Rohit Sharma - QA Head','2026-07-25',null,'Risk assessment checklist made mandatory at ECN initiation'),
    ('ECN-2026-001','supplier_qualification_delay','requalify_supplier','in_progress',60000.00,'Sneha Iyer - SQE','2026-07-18',null,'Make-B O2 sensor supplier audit scheduled'),
    ('ECN-2026-009','regulatory_review_pending','file_regulatory_notification','verification_pending',45000.00,'Priya Nair - RA Lead','2026-07-12',null,'Battery vendor notification filed - awaiting acknowledgement'),
    ('ECN-2026-004','document_update_backlog','expedite_document_updates','closed',12000.00,'Vikram Singh - Doc Control','2026-06-15','2026-06-12','All 3 SOPs and batch records updated and released'),
    ('ECN-2026-002','training_gap','retrain_change_owners','open',18000.00,'Deepa Kulkarni - Training','2026-07-22',null,'Change owners to be retrained on alarm V&V protocol')
  ) as q(cref, rc, ca, cst, cost, ownr, tcd, acd, nt)
  join public.design_change_r3652 e
    on e.organization_id = v_org_id and e.change_ref = q.cref;
end;
$seed$;
