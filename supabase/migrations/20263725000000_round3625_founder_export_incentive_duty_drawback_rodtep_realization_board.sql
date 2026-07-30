-- Round 3625: Founder Export-Incentive / Duty-Drawback / RODTEP Realization Board
-- Export-incentive finance — scheme × business unit × eligibility-vs-realization × pending × aging × realization status × trend × CAPA

-- =============================================================================
-- TABLE 1: export_incentive_r3625 — per-scheme export-incentive realization fact
-- =============================================================================
create table if not exists public.export_incentive_r3625 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  claim_ref text not null,
  scheme_name text not null,
  business_unit text not null,
  period_month date not null,
  export_value_rupees numeric(14,2),
  eligible_incentive_rupees numeric(14,2),
  claimed_rupees numeric(14,2),
  realized_rupees numeric(14,2),
  pending_rupees numeric(14,2),
  realization_pct numeric(6,2),
  aging_days int,
  scheme_type text not null check (scheme_type in (
    'duty_drawback','rodtep','epcg','advance_authorization','meis_seis'
  )),
  realization_status text not null check (realization_status in (
    'realized','on_track','delayed','stuck','lapsed_risk'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.export_incentive_r3625 enable row level security;

create index if not exists idx_export_incentive_r3625_org on public.export_incentive_r3625(organization_id);
create index if not exists idx_export_incentive_r3625_month on public.export_incentive_r3625(period_month);
create index if not exists idx_export_incentive_r3625_status on public.export_incentive_r3625(realization_status);

-- =============================================================================
-- TABLE 2: export_incentive_capa_actions_r3625 — CAPA & recovery actions
-- =============================================================================
create table if not exists public.export_incentive_capa_actions_r3625 (
  id uuid primary key default gen_random_uuid(),
  incentive_id uuid not null references public.export_incentive_r3625(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'drawback_short_realized','rodtep_scrip_delay','epcg_obligation_gap','advance_auth_pending',
    'claim_rejected','documentation_gap','bank_realization_pending','scheme_rate_reduction'
  )),
  root_cause text not null check (root_cause in (
    'shipping_bill_error','brc_pending','icegate_mismatch','hs_code_misclassification',
    'drawback_rate_dispute','scrip_utilization_delay','dgft_processing_backlog','bank_efirc_delay',
    'vendor_invoice_mismatch','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'file_amendment','followup_dgft','obtain_brc','reclassify_hs_code','submit_supporting_docs',
    'escalate_to_bank','utilize_scrip','engage_consultant','write_off','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.export_incentive_capa_actions_r3625 enable row level security;

create index if not exists idx_export_incentive_capa_r3625_link on public.export_incentive_capa_actions_r3625(incentive_id);
create index if not exists idx_export_incentive_capa_r3625_status on public.export_incentive_capa_actions_r3625(capa_status);

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

  -- 16 export-incentive claim rows
  insert into public.export_incentive_r3625 (
    organization_id, claim_ref, scheme_name, business_unit, period_month,
    export_value_rupees, eligible_incentive_rupees, claimed_rupees, realized_rupees, pending_rupees,
    realization_pct, aging_days, scheme_type, realization_status, trend_dir, notes
  )
  select v_org_id, q.cref, q.sname, q.bu, q.pmonth::date,
    q.expval, q.elig, q.claimed, q.realized, q.pending,
    q.rpct, q.aging, q.stype, q.rstatus, q.trend, q.nt
  from (values
    ('EXIM-3625-01','Duty Drawback FY26 Q1','spare_parts','2026-04-01',
     8500000,170000,170000,170000,0,100.00,12,'duty_drawback','realized','stable','Drawback fully realized within cycle'),
    ('EXIM-3625-02','RODTEP Diagnostics Q1','diagnostics','2026-04-01',
     12000000,240000,240000,180000,60000,75.00,38,'rodtep','on_track','improving','RODTEP scrip partly utilized, balance in process'),
    ('EXIM-3625-03','EPCG Capital Import','projects','2026-05-01',
     30000000,600000,600000,120000,480000,20.00,95,'epcg','delayed','worsening','EPCG export obligation lagging, realization slow'),
    ('EXIM-3625-04','Advance Auth Inputs','spare_parts','2026-05-01',
     6500000,130000,130000,0,130000,0.00,120,'advance_authorization','stuck','worsening','Advance authorization inputs pending BRC'),
    ('EXIM-3625-05','MEIS Legacy Claim','amc_services','2026-03-01',
     4200000,84000,84000,0,84000,0.00,210,'meis_seis','lapsed_risk','worsening','MEIS legacy scrip near expiry, lapse risk'),
    ('EXIM-3625-06','Duty Drawback Q2','spare_parts','2026-06-01',
     9100000,182000,182000,150000,32000,82.42,25,'duty_drawback','on_track','improving','Drawback largely realized, small pending'),
    ('EXIM-3625-07','RODTEP Projects Q2','projects','2026-06-01',
     18000000,360000,360000,360000,0,100.00,15,'rodtep','realized','stable','RODTEP fully realized on projects exports'),
    ('EXIM-3625-08','EPCG Second Tranche','projects','2026-04-01',
     22000000,440000,300000,90000,350000,20.45,88,'epcg','delayed','stable','Partial claim filed, obligation gap remains'),
    ('EXIM-3625-09','Advance Auth Q2','diagnostics','2026-06-01',
     7800000,156000,156000,110000,46000,70.51,42,'advance_authorization','on_track','improving','Advance auth realization progressing'),
    ('EXIM-3625-10','MEIS Balance Claim','amc_services','2026-02-01',
     3100000,62000,62000,0,62000,0.00,240,'meis_seis','lapsed_risk','worsening','MEIS balance unrealized, scrip validity critical'),
    ('EXIM-3625-11','Duty Drawback Diagnostics','diagnostics','2026-05-01',
     5400000,108000,108000,108000,0,100.00,18,'duty_drawback','realized','stable','Diagnostics drawback realized fully'),
    ('EXIM-3625-12','RODTEP Spares Q1','spare_parts','2026-04-01',
     10500000,210000,210000,63000,147000,30.00,70,'rodtep','delayed','worsening','RODTEP scrip issuance delayed by icegate mismatch'),
    ('EXIM-3625-13','EPCG Diagnostics Line','diagnostics','2026-05-01',
     16000000,320000,320000,0,320000,0.00,105,'epcg','stuck','worsening','EPCG obligation stuck, no realization yet'),
    ('EXIM-3625-14','Advance Auth Projects','projects','2026-06-01',
     14200000,284000,284000,200000,84000,70.42,35,'advance_authorization','on_track','improving','Advance auth projects on track'),
    ('EXIM-3625-15','Duty Drawback AMC','amc_services','2026-06-01',
     3900000,78000,78000,78000,0,100.00,10,'duty_drawback','realized','stable','AMC exports drawback realized'),
    ('EXIM-3625-16','RODTEP Balance Q1','spare_parts','2026-03-01',
     6700000,134000,134000,40000,94000,29.85,150,'rodtep','stuck','worsening','RODTEP balance stuck, documentation gap')
  ) as q(cref, sname, bu, pmonth, expval, elig, claimed, realized, pending, rpct, aging, stype, rstatus, trend, nt);

  -- CAPA seed — attach to specific claims via claim_ref
  insert into public.export_incentive_capa_actions_r3625 (
    incentive_id, finding_category, root_cause, corrective_action,
    capa_status, impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('EXIM-3625-03','epcg_obligation_gap','dgft_processing_backlog','followup_dgft','in_progress',480000,'Ravi Menon','2026-08-15',null,'EPCG obligation follow-up with DGFT ongoing'),
    ('EXIM-3625-04','advance_auth_pending','brc_pending','obtain_brc','open',130000,'Sunita Rao','2026-08-20',null,'Awaiting bank realization certificate for advance auth'),
    ('EXIM-3625-05','scheme_rate_reduction','scrip_utilization_delay','utilize_scrip','escalated',84000,'Arjun Nair','2026-08-05',null,'MEIS scrip near expiry escalated to utilize before lapse'),
    ('EXIM-3625-08','epcg_obligation_gap','vendor_invoice_mismatch','submit_supporting_docs','open',350000,'Ravi Menon','2026-08-25',null,'Vendor invoice mismatch on EPCG tranche'),
    ('EXIM-3625-10','scheme_rate_reduction','scrip_utilization_delay','write_off','overdue',62000,'Arjun Nair','2026-07-15',null,'MEIS balance likely write-off, scrip validity expired'),
    ('EXIM-3625-12','rodtep_scrip_delay','icegate_mismatch','file_amendment','in_progress',147000,'Priya Shah','2026-08-10',null,'RODTEP scrip delayed by ICEGATE mismatch, amendment filed'),
    ('EXIM-3625-13','epcg_obligation_gap','hs_code_misclassification','reclassify_hs_code','verification_pending',320000,'Kiran Kumar','2026-08-18',null,'HS code reclassification submitted for EPCG line'),
    ('EXIM-3625-16','documentation_gap','shipping_bill_error','file_amendment','closed',94000,'Priya Shah','2026-07-20','2026-07-18','Shipping bill amendment filed and RODTEP claim resolved')
  ) as q(cref, fc, rc, ca, cst, impact, ownr, tcd, acd, nt)
  join public.export_incentive_r3625 e
    on e.organization_id = v_org_id and e.claim_ref = q.cref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Realization-status distribution
create or replace function public.founder_r3625_realization_status_rollup()
returns table(realization_status text, claims bigint, pending_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.export_incentive_r3625)
  select l.realization_status, count(*)::bigint,
         coalesce(sum(l.pending_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.export_incentive_r3625 l
  group by l.realization_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3625_realization_status_rollup() from public, anon;
grant execute on function public.founder_r3625_realization_status_rollup() to authenticated;

-- 2) Business-unit scorecard
create or replace function public.founder_r3625_business_unit_scorecard()
returns table(
  business_unit text,
  total_claims bigint,
  realized bigint,
  on_track bigint,
  at_risk bigint,
  eligible_rupees numeric,
  realized_rupees numeric,
  pending_rupees numeric,
  realization_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit,
    count(*)::bigint,
    count(*) filter (where l.realization_status = 'realized')::bigint,
    count(*) filter (where l.realization_status = 'on_track')::bigint,
    count(*) filter (where l.realization_status in ('delayed','stuck','lapsed_risk'))::bigint,
    coalesce(sum(l.eligible_incentive_rupees),0)::numeric,
    coalesce(sum(l.realized_rupees),0)::numeric,
    coalesce(sum(l.pending_rupees),0)::numeric,
    round(100.0 * coalesce(sum(l.realized_rupees),0) / nullif(sum(l.eligible_incentive_rupees),0), 1)
  from public.export_incentive_r3625 l
  group by l.business_unit
  order by coalesce(sum(l.pending_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3625_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3625_business_unit_scorecard() to authenticated;

-- 3) Scheme-type × realization-status matrix
create or replace function public.founder_r3625_scheme_status_matrix()
returns table(scheme_type text, realization_status text, claims bigint, eligible_rupees numeric, realized_rupees numeric, pending_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.scheme_type, l.realization_status, count(*)::bigint,
    coalesce(sum(l.eligible_incentive_rupees),0)::numeric,
    coalesce(sum(l.realized_rupees),0)::numeric,
    coalesce(sum(l.pending_rupees),0)::numeric
  from public.export_incentive_r3625 l
  group by l.scheme_type, l.realization_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3625_scheme_status_matrix() from public, anon;
grant execute on function public.founder_r3625_scheme_status_matrix() to authenticated;

-- 4) Monthly realization trend
create or replace function public.founder_r3625_monthly_realization_trend()
returns table(period_month date, claims bigint, eligible_rupees numeric, claimed_rupees numeric, realized_rupees numeric, pending_rupees numeric, realization_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.eligible_incentive_rupees),0)::numeric,
    coalesce(sum(l.claimed_rupees),0)::numeric,
    coalesce(sum(l.realized_rupees),0)::numeric,
    coalesce(sum(l.pending_rupees),0)::numeric,
    round(100.0 * coalesce(sum(l.realized_rupees),0) / nullif(sum(l.eligible_incentive_rupees),0), 1)
  from public.export_incentive_r3625 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3625_monthly_realization_trend() from public, anon;
grant execute on function public.founder_r3625_monthly_realization_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3625_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.export_incentive_capa_actions_r3625 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3625_capa_status_board() from public, anon;
grant execute on function public.founder_r3625_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3625_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.export_incentive_capa_actions_r3625)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.export_incentive_capa_actions_r3625 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3625_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3625_root_cause_pareto() to authenticated;

-- 7) Pending-incentive digest by scheme type
create or replace function public.founder_r3625_pending_incentive_digest()
returns table(scheme_type text, claims bigint, pending_rupees numeric, eligible_rupees numeric, avg_aging_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.scheme_type, count(*)::bigint,
    coalesce(sum(l.pending_rupees),0)::numeric,
    coalesce(sum(l.eligible_incentive_rupees),0)::numeric,
    round(avg(l.aging_days)::numeric, 1)
  from public.export_incentive_r3625 l
  group by l.scheme_type
  order by coalesce(sum(l.pending_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3625_pending_incentive_digest() from public, anon;
grant execute on function public.founder_r3625_pending_incentive_digest() to authenticated;

-- 8) High-risk realization queue (stuck / lapsed_risk / delayed)
create or replace function public.founder_r3625_high_risk_queue()
returns table(
  claim_ref text,
  scheme_name text,
  business_unit text,
  scheme_type text,
  period_month date,
  realization_status text,
  export_value_rupees numeric,
  eligible_incentive_rupees numeric,
  pending_rupees numeric,
  aging_days int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.claim_ref, l.scheme_name, l.business_unit, l.scheme_type, l.period_month,
    l.realization_status, l.export_value_rupees, l.eligible_incentive_rupees, l.pending_rupees,
    l.aging_days, l.notes
  from public.export_incentive_r3625 l
  where l.realization_status in ('stuck','lapsed_risk','delayed')
     or l.aging_days >= 90
  order by l.pending_rupees desc, l.aging_days desc;
end;
$$;

revoke execute on function public.founder_r3625_high_risk_queue() from public, anon;
grant execute on function public.founder_r3625_high_risk_queue() to authenticated;
