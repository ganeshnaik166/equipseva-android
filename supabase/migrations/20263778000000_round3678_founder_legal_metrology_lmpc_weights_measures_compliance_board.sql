-- Round 3678: Founder Legal-Metrology / LMPC / Weights-Measures Compliance Board
-- Legal metrology — item line × state × period × LMPC registration expiry × packaged declaration % × verification due × stamping % × notices × compliance area/status × CAPA

-- =============================================================================
-- TABLE 1: legal_metrology_r3678 — per item-line/state legal-metrology compliance facts
-- =============================================================================
create table if not exists public.legal_metrology_r3678 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  site_name text not null,
  item_line text not null,
  lmpc_registration_no text not null,
  state_region text not null,
  period_month date not null,
  registration_expiry date,
  days_to_expiry int,
  packages_declared int,
  declaration_compliant_pct numeric(5,2),
  verification_due int,
  stamping_current_pct numeric(5,2),
  notices_open int,
  compliance_area text not null check (compliance_area in (
    'lmpc_import','packaged_declaration','weighing_instrument','measuring_device','dealer_licence'
  )),
  compliance_status text not null check (compliance_status in (
    'compliant','renewal_due','declaration_gap','verification_overdue','notice_received'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.legal_metrology_r3678 enable row level security;

create index if not exists idx_legal_metrology_r3678_org on public.legal_metrology_r3678(organization_id);
create index if not exists idx_legal_metrology_r3678_month on public.legal_metrology_r3678(period_month);
create index if not exists idx_legal_metrology_r3678_status on public.legal_metrology_r3678(compliance_status);

-- =============================================================================
-- TABLE 2: legal_metrology_capa_actions_r3678 — CAPA & metrology-compliance actions
-- =============================================================================
create table if not exists public.legal_metrology_capa_actions_r3678 (
  id uuid primary key default gen_random_uuid(),
  compliance_log_id uuid not null references public.legal_metrology_r3678(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'registration_renewal_lapse','declaration_non_compliance','verification_overdue',
    'stamping_lapse','notice_from_controller','dealer_licence_gap',
    'records_gap','import_declaration_gap'
  )),
  root_cause text not null check (root_cause in (
    'renewal_not_tracked','declaration_artwork_error','verifier_visit_missed',
    'instrument_out_of_service','vendor_stamping_lapse','records_not_maintained',
    'portal_filing_backlog','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'file_renewal_application','revise_pack_declaration','schedule_reverification',
    'recalibrate_and_stamp','engage_metrology_consultant','update_compliance_tracker',
    'respond_to_notice','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  penalty_exposure_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.legal_metrology_capa_actions_r3678 enable row level security;

create index if not exists idx_legal_metrology_capa_r3678_log on public.legal_metrology_capa_actions_r3678(compliance_log_id);
create index if not exists idx_legal_metrology_capa_r3678_status on public.legal_metrology_capa_actions_r3678(capa_status);

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

  -- 16 legal-metrology compliance rows
  insert into public.legal_metrology_r3678 (
    organization_id, site_name, item_line, lmpc_registration_no, state_region,
    period_month, registration_expiry, days_to_expiry, packages_declared,
    declaration_compliant_pct, verification_due, stamping_current_pct, notices_open,
    compliance_area, compliance_status, trend_dir, notes
  )
  select v_org_id, q.site, q.iline, q.lreg, q.streg,
    q.pmon::date, q.rexp::date, q.dexp, q.pkgs,
    q.dpct, q.vdue, q.spct, q.nopen,
    q.area, q.cstat, q.trnd, q.nt
  from (values
    ('Mumbai HQ','Patient Monitors','LMPC/MH/2024/00871','MH','2026-07-01','2027-03-31',
     236,4200,98.60,0,97.50,0,'lmpc_import','compliant','stable','LMPC import registration current; declarations verified across all monitor SKUs'),
    ('Mumbai HQ','Infusion Pumps','LMPC/MH/2023/00412','MH','2026-07-01','2026-09-15',
     38,2600,96.20,1,95.00,0,'lmpc_import','renewal_due','stable','Import registration in renewal window — application drafted for controller filing'),
    ('Mumbai HQ','Consumables Packs','LMPC/MH/2025/01108','MH','2026-07-01','2028-01-31',
     541,8800,88.40,0,100.00,1,'packaged_declaration','declaration_gap','worsening','MRP font-size deviation on two consumable SKUs — notice risk flagged by auditor'),
    ('Chennai Office','BP Monitors','LMPC/TN/2024/00233','TN','2026-07-01','2027-06-30',
     326,3100,97.80,0,96.40,0,'packaged_declaration','compliant','improving','Pack declarations re-verified after TN controller advisory — clean'),
    ('Chennai Office','Weighing Scales','WM/TN/2025/00764','TN','2026-07-01','2026-08-20',
     42,0,100.00,6,71.50,0,'weighing_instrument','verification_overdue','worsening','Six platform scales past state re-verification due date at Chennai store'),
    ('Delhi Warehouse','Consumables Packs','LMPC/DL/2023/00098','DL','2026-07-01','2026-10-05',
     88,7600,91.20,2,93.80,2,'packaged_declaration','notice_received','worsening','LM inspector notice on net-quantity declaration — reply due within 15 days'),
    ('Delhi Warehouse','Digital Thermometers','LMPC/DL/2024/00655','DL','2026-07-01','2027-11-30',
     509,1900,99.10,0,98.20,0,'measuring_device','compliant','stable','Clinical thermometer line verified and stamped — no open observations'),
    ('Bengaluru Refurb Center','Refurb Patient Monitors','DL/KA/2025/00341','KA','2026-07-01','2026-12-31',
     175,650,94.70,1,89.90,0,'dealer_licence','renewal_due','stable','KA dealer licence renewal filing prepared for refurbished monitor sales'),
    ('Bengaluru Refurb Center','Weighing Scales','WM/KA/2024/00512','KA','2026-07-01','2027-04-30',
     264,0,100.00,2,92.10,0,'weighing_instrument','compliant','improving','Refurb line scales re-stamped in June drive — two verifications scheduled'),
    ('Chennai Office','Infusion Pumps','LMPC/TN/2023/00187','TN','2026-06-01','2026-07-25',
     54,2300,95.50,0,94.00,1,'lmpc_import','notice_received','stable','Show-cause on imported pump cartons missing month-of-import declaration'),
    ('Delhi Warehouse','BP Monitors','LMPC/DL/2025/00920','DL','2026-06-01','2027-08-31',
     456,2800,97.20,0,96.80,0,'packaged_declaration','compliant','stable','Warehouse relabelling SOP holding — declarations compliant on audit sample'),
    ('Bengaluru Refurb Center','Measuring Tapes & Gauges','WM/KA/2023/00099','KA','2026-06-01','2026-06-30',
     29,0,100.00,4,78.30,0,'measuring_device','verification_overdue','worsening','Calibration gauges pending re-verification by KA legal metrology dept'),
    ('Mumbai HQ','Digital Thermometers','LMPC/MH/2024/00777','MH','2026-06-01','2027-02-28',
     272,2100,98.90,0,97.70,0,'measuring_device','compliant','improving','Thermometer declarations and stamping current after May relabel batch'),
    ('Chennai Office','Consumables Packs','LMPC/TN/2025/00841','TN','2026-05-01','2027-12-31',
     608,6900,92.60,0,95.50,0,'packaged_declaration','declaration_gap','improving','Legacy artwork lots being relabelled — declaration gap closing month on month'),
    ('Delhi Warehouse','Weighing Scales','WM/DL/2024/00433','DL','2026-05-01','2026-09-30',
     152,0,100.00,3,85.00,0,'weighing_instrument','renewal_due','stable','DL weighing-instrument licence renewal queued; three scales due for stamping'),
    ('Mumbai HQ','Refurb Infusion Pumps','DL/MH/2025/00566','MH','2026-05-01','2026-11-15',
     198,720,93.40,1,90.60,1,'dealer_licence','notice_received','worsening','Dealer records notice — sales register gaps for refurbished pump resale')
  ) as q(site, iline, lreg, streg, pmon, rexp, dexp, pkgs, dpct, vdue, spct, nopen, area, cstat, trnd, nt);

  -- CAPA seed — attach to specific compliance lines via lmpc_registration_no
  insert into public.legal_metrology_capa_actions_r3678 (
    compliance_log_id, finding_category, root_cause, corrective_action,
    capa_status, penalty_exposure_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.pen, q.own,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('WM/TN/2025/00764','verification_overdue','verifier_visit_missed','schedule_reverification','in_progress',120000.00,'S. Raghavan','2026-08-20',null,'State verifier visit booked for all six overdue platform scales'),
    ('LMPC/DL/2023/00098','notice_from_controller','declaration_artwork_error','respond_to_notice','escalated',250000.00,'N. Kapoor','2026-08-10',null,'Notice reply drafted with legal counsel; compounding option under evaluation'),
    ('LMPC/MH/2025/01108','declaration_non_compliance','declaration_artwork_error','revise_pack_declaration','in_progress',80000.00,'A. Deshpande','2026-08-25',null,'Artwork correction for MRP font size rolling out across two SKUs'),
    ('LMPC/MH/2023/00412','registration_renewal_lapse','renewal_not_tracked','file_renewal_application','open',0.00,'A. Deshpande','2026-08-30',null,'LMPC import renewal to be filed 60 days before expiry; tracker updated'),
    ('LMPC/TN/2023/00187','import_declaration_gap','declaration_artwork_error','respond_to_notice','verification_pending',150000.00,'S. Raghavan','2026-08-05',null,'Import declaration stickers applied; evidence pack under controller review'),
    ('WM/KA/2023/00099','stamping_lapse','instrument_out_of_service','recalibrate_and_stamp','closed',18000.00,'K. Hegde','2026-07-15','2026-07-10','Gauges recalibrated and re-stamped by licensed repairer — verified'),
    ('DL/MH/2025/00566','records_gap','records_not_maintained','update_compliance_tracker','overdue',60000.00,'A. Deshpande','2026-07-31',null,'Refurb sales register digitisation slipped past target date'),
    ('WM/DL/2024/00433','registration_renewal_lapse','portal_filing_backlog','file_renewal_application','open',25000.00,'N. Kapoor','2026-09-05',null,'Weighing-instrument licence renewal queued on DL state portal')
  ) as q(lreg, fc, rc, ca, cst, pen, own, tcd, acd, nt)
  join public.legal_metrology_r3678 e
    on e.organization_id = v_org_id and e.lmpc_registration_no = q.lreg;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance status distribution
create or replace function public.founder_r3678_compliance_status_rollup()
returns table(compliance_status text, item_lines bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.legal_metrology_r3678)
  select m.compliance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.legal_metrology_r3678 m
  group by m.compliance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3678_compliance_status_rollup() from public, anon;
grant execute on function public.founder_r3678_compliance_status_rollup() to authenticated;

-- 2) State scorecard
create or replace function public.founder_r3678_state_scorecard()
returns table(
  state_region text,
  total_lines bigint,
  compliant bigint,
  renewal_due bigint,
  declaration_gap bigint,
  verification_overdue bigint,
  notice_received bigint,
  avg_declaration_pct numeric,
  avg_stamping_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.state_region,
    count(*)::bigint,
    count(*) filter (where m.compliance_status = 'compliant')::bigint,
    count(*) filter (where m.compliance_status = 'renewal_due')::bigint,
    count(*) filter (where m.compliance_status = 'declaration_gap')::bigint,
    count(*) filter (where m.compliance_status = 'verification_overdue')::bigint,
    count(*) filter (where m.compliance_status = 'notice_received')::bigint,
    round(avg(m.declaration_compliant_pct), 1),
    round(avg(m.stamping_current_pct), 1)
  from public.legal_metrology_r3678 m
  group by m.state_region
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3678_state_scorecard() from public, anon;
grant execute on function public.founder_r3678_state_scorecard() to authenticated;

-- 3) Compliance area × status matrix
create or replace function public.founder_r3678_area_status_matrix()
returns table(compliance_area text, compliance_status text, item_lines bigint, notices_total bigint, avg_declaration_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.compliance_area, m.compliance_status, count(*)::bigint,
    coalesce(sum(m.notices_open),0)::bigint,
    round(avg(m.declaration_compliant_pct), 1)
  from public.legal_metrology_r3678 m
  group by m.compliance_area, m.compliance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3678_area_status_matrix() from public, anon;
grant execute on function public.founder_r3678_area_status_matrix() to authenticated;

-- 4) Monthly compliance trend
create or replace function public.founder_r3678_monthly_compliance_trend()
returns table(period_month date, item_lines bigint, compliant bigint, notices_total bigint, verification_due_total bigint, avg_declaration_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.period_month,
    count(*)::bigint,
    count(*) filter (where m.compliance_status = 'compliant')::bigint,
    coalesce(sum(m.notices_open),0)::bigint,
    coalesce(sum(m.verification_due),0)::bigint,
    round(avg(m.declaration_compliant_pct), 1)
  from public.legal_metrology_r3678 m
  group by m.period_month
  order by m.period_month desc;
end;
$$;

revoke all on function public.founder_r3678_monthly_compliance_trend() from public, anon;
grant execute on function public.founder_r3678_monthly_compliance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3678_capa_status_board()
returns table(capa_status text, actions bigint, avg_penalty_exposure_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.penalty_exposure_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.legal_metrology_capa_actions_r3678 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3678_capa_status_board() from public, anon;
grant execute on function public.founder_r3678_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3678_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_penalty_exposure_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.legal_metrology_capa_actions_r3678)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.penalty_exposure_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.legal_metrology_capa_actions_r3678 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3678_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3678_root_cause_pareto() to authenticated;

-- 7) Notice-exposure digest
create or replace function public.founder_r3678_notice_exposure_digest()
returns table(compliance_area text, item_lines bigint, notices_total bigint, notice_received_lines bigint, verification_overdue_lines bigint, avg_days_to_expiry numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.compliance_area,
    count(*)::bigint,
    coalesce(sum(m.notices_open),0)::bigint,
    count(*) filter (where m.compliance_status = 'notice_received')::bigint,
    count(*) filter (where m.compliance_status = 'verification_overdue')::bigint,
    round(avg(m.days_to_expiry), 1)
  from public.legal_metrology_r3678 m
  group by m.compliance_area
  order by coalesce(sum(m.notices_open),0) desc, count(*) desc;
end;
$$;

revoke all on function public.founder_r3678_notice_exposure_digest() from public, anon;
grant execute on function public.founder_r3678_notice_exposure_digest() to authenticated;

-- 8) High-risk compliance queue
create or replace function public.founder_r3678_high_risk_queue()
returns table(
  site_name text,
  item_line text,
  lmpc_registration_no text,
  state_region text,
  period_month date,
  compliance_area text,
  compliance_status text,
  days_to_expiry int,
  notices_open int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select m.site_name, m.item_line, m.lmpc_registration_no, m.state_region, m.period_month,
    m.compliance_area, m.compliance_status, m.days_to_expiry, m.notices_open, m.notes
  from public.legal_metrology_r3678 m
  where m.compliance_status in ('notice_received','verification_overdue')
     or m.notices_open > 0
     or m.days_to_expiry < 60
     or m.stamping_current_pct < 90
  order by m.period_month desc, m.notices_open desc, m.days_to_expiry asc;
end;
$$;

revoke all on function public.founder_r3678_high_risk_queue() from public, anon;
grant execute on function public.founder_r3678_high_risk_queue() to authenticated;
