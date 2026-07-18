-- Round 3141: Founder Investor Data-Room Access & NDA Audit Log
-- Investor data-room access events — firm × fund stage × NDA status × document category × access type × IP geo × watermark × flag × verdict + NDA/access-review CAPA actions

-- =============================================================================
-- TABLE 1: investor_dataroom_r3141 — individual data-room access events
-- =============================================================================
create table if not exists public.investor_dataroom_r3141 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  investor_firm text not null,
  investor_contact text not null,
  event_ref text not null,
  fund_stage text not null check (fund_stage in (
    'angel','seed','series_a','series_b','series_c','growth','pre_ipo','strategic'
  )),
  deal_role text not null check (deal_role in (
    'lead_investor','co_investor','follow_on','prospective','existing_investor','advisor','limited_partner'
  )),
  nda_status text not null check (nda_status in (
    'not_sent','sent_pending','signed','expired','declined','under_negotiation','waived'
  )),
  document_category text not null check (document_category in (
    'financials','cap_table','pitch_deck','product_roadmap','customer_contracts',
    'legal_diligence','hr_compensation','ip_patents','board_minutes','technical_architecture'
  )),
  access_type text not null check (access_type in (
    'view_online','download_pdf','print_export','watermark_export',
    'screen_share','api_export','bulk_download','preview_thumbnail'
  )),
  ip_country text not null check (ip_country in (
    'india','usa','singapore','uae','united_kingdom','germany','japan','china','hong_kong','unknown'
  )),
  session_minutes int,
  pages_viewed int,
  watermarked boolean not null default true,
  flagged boolean not null default false,
  access_date date not null,
  accessed_at timestamptz not null,
  access_verdict text not null check (access_verdict in (
    'approved','allowed','flagged_review','blocked','revoked','pending_review','escalated_legal'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.investor_dataroom_r3141 enable row level security;

create index if not exists idx_investor_dataroom_r3141_org on public.investor_dataroom_r3141(organization_id);
create index if not exists idx_investor_dataroom_r3141_date on public.investor_dataroom_r3141(access_date);
create index if not exists idx_investor_dataroom_r3141_verdict on public.investor_dataroom_r3141(access_verdict);

-- =============================================================================
-- TABLE 2: investor_dataroom_capa_actions_r3141 — NDA/access-review CAPA actions
-- =============================================================================
create table if not exists public.investor_dataroom_capa_actions_r3141 (
  id uuid primary key default gen_random_uuid(),
  event_log_id uuid not null references public.investor_dataroom_r3141(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'nda_missing','unauthorized_download','bulk_exfiltration','expired_nda_access',
    'geolocation_anomaly','watermark_bypass','excessive_session','sensitive_doc_exposure',
    'screenshot_detected','post_deal_access'
  )),
  root_cause text not null check (root_cause in (
    'nda_workflow_gap','permission_misconfiguration','stale_access_grant','vpn_masking',
    'insider_curiosity','competitor_reconnaissance','process_lapse','pending_investigation',
    'legitimate_diligence','system_error'
  )),
  corrective_action text not null check (corrective_action in (
    'revoke_access','re_issue_nda','restrict_download','enable_watermark_only','legal_escalation',
    'tighten_permissions','notify_investor','expire_stale_grants','no_action_required','add_geo_fencing'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'sebi_disclosure_risk','confidentiality_breach','none','internal_only','data_protection_dpdp','board_notifiable'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.investor_dataroom_capa_actions_r3141 enable row level security;

create index if not exists idx_investor_dataroom_capa_r3141_event on public.investor_dataroom_capa_actions_r3141(event_log_id);
create index if not exists idx_investor_dataroom_capa_r3141_status on public.investor_dataroom_capa_actions_r3141(capa_status);

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

  -- 14 data-room access events across real Indian venture / growth investors
  insert into public.investor_dataroom_r3141 (
    organization_id, investor_firm, investor_contact, event_ref,
    fund_stage, deal_role, nda_status, document_category, access_type, ip_country,
    session_minutes, pages_viewed, watermarked, flagged,
    access_date, accessed_at, access_verdict, notes
  )
  select v_org_id, q.firm, q.contact, q.ref,
    q.stage, q.role, q.nda, q.doc, q.acc, q.cty,
    q.smin, q.pages, q.wm, q.flg,
    q.adate::date, q.aat::timestamptz, q.verdict, q.nt
  from (values
    ('Peak XV Partners','Shailendra Singh','DR-PXV-001','series_b','lead_investor','signed','financials','view_online','india',
     42, 38, true, false, '2026-07-16','2026-07-16 10:15:00+05:30','approved','Term-sheet diligence — audited financials review'),
    ('Peak XV Partners','Shailendra Singh','DR-PXV-002','series_b','lead_investor','signed','cap_table','download_pdf','india',
     18, 12, true, false, '2026-07-16','2026-07-16 11:05:00+05:30','allowed','Cap-table PDF export, watermarked'),
    ('Accel India','Prayank Swaroop','DR-ACL-003','series_b','co_investor','signed','pitch_deck','view_online','india',
     25, 20, true, false, '2026-07-16','2026-07-16 14:40:00+05:30','approved','Deck walkthrough for co-investor'),
    ('Tiger Global Management','Scott Shleifer','DR-TGR-004','growth','prospective','sent_pending','financials','bulk_download','usa',
     8, 60, true, true, '2026-07-15','2026-07-15 21:30:00+05:30','flagged_review','Bulk download before NDA countersigned — flagged'),
    ('Blume Ventures','Karthik Reddy','DR-BLM-005','series_a','follow_on','signed','product_roadmap','view_online','india',
     33, 15, true, false, '2026-07-15','2026-07-15 09:20:00+05:30','approved','Follow-on diligence, roadmap review'),
    ('Elevation Capital','Mukul Arora','DR-ELV-006','series_b','co_investor','under_negotiation','legal_diligence','view_online','india',
     55, 40, true, false, '2026-07-15','2026-07-15 16:10:00+05:30','pending_review','Legal DD in progress, NDA terms under negotiation'),
    ('Nexus Venture Partners','Jishnu Bhattacharjee','DR-NXS-007','series_a','existing_investor','signed','board_minutes','download_pdf','india',
     20, 10, true, false, '2026-07-14','2026-07-14 12:00:00+05:30','allowed','Existing-investor board pack download'),
    ('Undisclosed Party','Anonymous','DR-UNK-008','strategic','prospective','not_sent','ip_patents','screen_share','unknown',
     12, 8, false, true, '2026-07-14','2026-07-14 23:55:00+05:30','blocked','IP docs opened over VPN, no NDA on file — blocked'),
    ('SoftBank Vision Fund','Sumer Juneja','DR-SBK-009','pre_ipo','prospective','signed','customer_contracts','api_export','singapore',
     15, 25, true, true, '2026-07-13','2026-07-13 18:45:00+05:30','flagged_review','API bulk export of customer contracts — flagged'),
    ('Kalaari Capital','Vani Kola','DR-KLR-010','series_a','advisor','signed','hr_compensation','view_online','india',
     22, 9, true, false, '2026-07-13','2026-07-13 10:35:00+05:30','approved','Compensation benchmarking review'),
    ('Lightspeed India','Hemant Mohapatra','DR-LSP-011','series_c','co_investor','signed','technical_architecture','view_online','india',
     48, 30, true, false, '2026-07-12','2026-07-12 15:25:00+05:30','approved','Technical DD architecture session'),
    ('Chiratae Ventures','Sudhir Sethi','DR-CHR-012','series_b','prospective','expired','financials','download_pdf','india',
     14, 18, true, true, '2026-07-12','2026-07-12 20:10:00+05:30','revoked','Financials download after NDA expiry — access revoked'),
    ('3one4 Capital','Pranav Pai','DR-3O4-013','seed','existing_investor','signed','pitch_deck','preview_thumbnail','india',
     5, 3, true, false, '2026-07-11','2026-07-11 08:50:00+05:30','approved','Quick refresh preview'),
    ('Prosus Ventures','Ashutosh Sharma','DR-PRS-014','growth','prospective','declined','cap_table','print_export','hong_kong',
     9, 5, false, true, '2026-07-11','2026-07-11 22:15:00+05:30','escalated_legal','Print export from HK after NDA declined — escalated to legal')
  ) as q(firm, contact, ref, stage, role, nda, doc, acc, cty, smin, pages, wm, flg, adate, aat, verdict, nt);

  -- CAPA / access-review actions — attach to specific events by event_ref
  insert into public.investor_dataroom_capa_actions_r3141 (
    event_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('DR-TGR-004','bulk_exfiltration','nda_workflow_gap','restrict_download','2026-07-20',null,'in_progress','confidentiality_breach',250000.00,'Bulk download pre-NDA; download disabled until countersigned NDA on file'),
    ('DR-UNK-008','nda_missing','competitor_reconnaissance','legal_escalation','2026-07-18',null,'escalated','sebi_disclosure_risk',500000.00,'IP access via VPN by undisclosed party — legal notice drafted, IP forum locked'),
    ('DR-SBK-009','unauthorized_download','permission_misconfiguration','tighten_permissions','2026-07-22','2026-07-16','closed','internal_only',40000.00,'API export scope over-provisioned; role permissions tightened and verified'),
    ('DR-CHR-012','expired_nda_access','stale_access_grant','expire_stale_grants','2026-07-19',null,'overdue','data_protection_dpdp',60000.00,'Stale grant not auto-expired; access revoked, retention audit ongoing'),
    ('DR-PRS-014','post_deal_access','process_lapse','add_geo_fencing','2026-07-25',null,'open','board_notifiable',120000.00,'Print from Hong Kong after NDA declined; geo-fencing rule to be added'),
    ('DR-PXV-002','sensitive_doc_exposure','legitimate_diligence','enable_watermark_only','2026-07-21','2026-07-15','closed','none',0.00,'Cap-table download by lead investor; watermark-only confirmed, no breach')
  ) as q(ref_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.investor_dataroom_r3141 e
    on e.organization_id = v_org_id and e.event_ref = q.ref_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Access verdict distribution
create or replace function public.founder_r3141_access_verdict_rollup()
returns table(access_verdict text, events bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.investor_dataroom_r3141)
  select l.access_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.investor_dataroom_r3141 l
  group by l.access_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3141_access_verdict_rollup() from public, anon;
grant execute on function public.founder_r3141_access_verdict_rollup() to authenticated;

-- 2) Investor firm scorecard
create or replace function public.founder_r3141_investor_scorecard()
returns table(
  investor_firm text,
  total_events bigint,
  downloads bigint,
  flagged bigint,
  blocked bigint,
  nda_signed bigint,
  sensitive_views bigint,
  clean_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.investor_firm,
    count(*)::bigint,
    count(*) filter (where l.access_type in ('download_pdf','bulk_download','api_export','watermark_export','print_export'))::bigint,
    count(*) filter (where l.flagged)::bigint,
    count(*) filter (where l.access_verdict in ('blocked','revoked'))::bigint,
    count(*) filter (where l.nda_status = 'signed')::bigint,
    count(*) filter (where l.document_category in ('financials','cap_table','legal_diligence','board_minutes','ip_patents'))::bigint,
    round(100.0 * count(*) filter (where l.access_verdict in ('approved','allowed'))::numeric / nullif(count(*),0), 1)
  from public.investor_dataroom_r3141 l
  group by l.investor_firm
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3141_investor_scorecard() from public, anon;
grant execute on function public.founder_r3141_investor_scorecard() to authenticated;

-- 3) Document category × access type matrix
create or replace function public.founder_r3141_document_access_matrix()
returns table(document_category text, access_type text, events bigint, flagged bigint, avg_session_min numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.document_category, l.access_type, count(*)::bigint,
    count(*) filter (where l.flagged)::bigint,
    round(avg(l.session_minutes), 1)
  from public.investor_dataroom_r3141 l
  group by l.document_category, l.access_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3141_document_access_matrix() from public, anon;
grant execute on function public.founder_r3141_document_access_matrix() to authenticated;

-- 4) Daily access trend
create or replace function public.founder_r3141_access_daily_trend()
returns table(access_date date, events bigint, downloads bigint, flagged bigint, blocked bigint, distinct_firms bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.access_date,
    count(*)::bigint,
    count(*) filter (where l.access_type in ('download_pdf','bulk_download','api_export','watermark_export','print_export'))::bigint,
    count(*) filter (where l.flagged)::bigint,
    count(*) filter (where l.access_verdict in ('blocked','revoked'))::bigint,
    count(distinct l.investor_firm)::bigint
  from public.investor_dataroom_r3141 l
  group by l.access_date
  order by l.access_date desc;
end;
$$;

revoke execute on function public.founder_r3141_access_daily_trend() from public, anon;
grant execute on function public.founder_r3141_access_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3141_capa_status_board()
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
  from public.investor_dataroom_capa_actions_r3141 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3141_capa_status_board() from public, anon;
grant execute on function public.founder_r3141_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3141_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.investor_dataroom_capa_actions_r3141)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.investor_dataroom_capa_actions_r3141 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3141_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3141_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3141_regulatory_impact_digest()
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
  from public.investor_dataroom_capa_actions_r3141 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3141_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3141_regulatory_impact_digest() to authenticated;

-- 8) High-risk access queue (top individual concerns)
create or replace function public.founder_r3141_high_risk_access()
returns table(
  investor_firm text,
  fund_stage text,
  document_category text,
  access_type text,
  ip_country text,
  access_date date,
  nda_status text,
  access_verdict text,
  flagged boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.investor_firm, l.fund_stage, l.document_category, l.access_type, l.ip_country,
    l.access_date, l.nda_status, l.access_verdict, l.flagged, l.notes
  from public.investor_dataroom_r3141 l
  where l.access_verdict in ('flagged_review','blocked','revoked','pending_review','escalated_legal')
     or l.flagged
     or l.nda_status in ('not_sent','expired','declined')
  order by l.access_date desc, l.investor_firm;
end;
$$;

revoke execute on function public.founder_r3141_high_risk_access() from public, anon;
grant execute on function public.founder_r3141_high_risk_access() to authenticated;
