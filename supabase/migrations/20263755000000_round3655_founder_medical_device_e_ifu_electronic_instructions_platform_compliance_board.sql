-- Round 3655: Medical-Device e-IFU (Electronic Instructions) Platform Compliance Board
-- e-IFU platform compliance — device × IFU version × language coverage × platform uptime × download success × paper-copy fulfilment × delivery channel × CAPA

-- =============================================================================
-- TABLE 1: eifu_r3655 — per-device / per-month e-IFU platform compliance records
-- =============================================================================
create table if not exists public.eifu_r3655 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  eifu_ref text not null,
  device_name text not null,
  ifu_version text not null,
  period_month date not null,
  languages_required int not null,
  languages_published int not null,
  platform_uptime_pct numeric(5,2),
  download_success_pct numeric(5,2),
  paper_copy_requests int not null default 0,
  fulfilment_days numeric(5,1),
  last_published date,
  review_due date,
  delivery_channel text not null check (delivery_channel in (
    'web_portal','qr_on_label','app_embedded','usb_media','paper_fallback'
  )),
  eifu_status text not null check (eifu_status in (
    'compliant','version_lag','language_gap','platform_issue','non_compliant'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.eifu_r3655 enable row level security;

create index if not exists idx_eifu_r3655_org on public.eifu_r3655(organization_id);
create index if not exists idx_eifu_r3655_month on public.eifu_r3655(period_month);
create index if not exists idx_eifu_r3655_status on public.eifu_r3655(eifu_status);

-- =============================================================================
-- TABLE 2: eifu_capa_actions_r3655 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.eifu_capa_actions_r3655 (
  id uuid primary key default gen_random_uuid(),
  eifu_id uuid not null references public.eifu_r3655(id) on delete cascade,
  root_cause text not null check (root_cause in (
    'platform_outage','cdn_misconfiguration','translation_vendor_delay',
    'version_control_lapse','qr_code_print_error','regulatory_update_missed',
    'fulfilment_logistics_delay','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'restore_platform_redundancy','fix_cdn_configuration','expedite_translation',
    'republish_current_version','reprint_qr_labels','update_regulatory_watchlist',
    'streamline_paper_fulfilment','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  estimated_cost_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.eifu_capa_actions_r3655 enable row level security;

create index if not exists idx_eifu_capa_r3655_eifu on public.eifu_capa_actions_r3655(eifu_id);
create index if not exists idx_eifu_capa_r3655_status on public.eifu_capa_actions_r3655(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) e-IFU status distribution
create or replace function public.founder_r3655_eifu_status_rollup()
returns table(eifu_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.eifu_r3655)
  select l.eifu_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.eifu_r3655 l
  group by l.eifu_status
  order by count(*) desc;
end;
$$;

-- 2) Delivery-channel scorecard
create or replace function public.founder_r3655_delivery_channel_scorecard()
returns table(
  delivery_channel text,
  total_records bigint,
  compliant bigint,
  language_gap bigint,
  platform_issue bigint,
  non_compliant bigint,
  avg_uptime_pct numeric,
  avg_download_success_pct numeric,
  compliant_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.delivery_channel,
    count(*)::bigint,
    count(*) filter (where l.eifu_status = 'compliant')::bigint,
    count(*) filter (where l.eifu_status = 'language_gap')::bigint,
    count(*) filter (where l.eifu_status = 'platform_issue')::bigint,
    count(*) filter (where l.eifu_status = 'non_compliant')::bigint,
    round(avg(l.platform_uptime_pct), 2),
    round(avg(l.download_success_pct), 2),
    round(100.0 * count(*) filter (where l.eifu_status = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.eifu_r3655 l
  group by l.delivery_channel
  order by count(*) desc;
end;
$$;

-- 3) Delivery-channel × e-IFU status matrix
create or replace function public.founder_r3655_channel_status_matrix()
returns table(delivery_channel text, eifu_status text, records bigint, avg_uptime_pct numeric, avg_download_success_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.delivery_channel, l.eifu_status, count(*)::bigint,
    round(avg(l.platform_uptime_pct), 2),
    round(avg(l.download_success_pct), 2)
  from public.eifu_r3655 l
  group by l.delivery_channel, l.eifu_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly compliance trend
create or replace function public.founder_r3655_monthly_compliance_trend()
returns table(period_month date, records bigint, compliant bigint, language_gap bigint, platform_issue bigint, non_compliant bigint, avg_download_success_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.eifu_status = 'compliant')::bigint,
    count(*) filter (where l.eifu_status = 'language_gap')::bigint,
    count(*) filter (where l.eifu_status = 'platform_issue')::bigint,
    count(*) filter (where l.eifu_status = 'non_compliant')::bigint,
    round(avg(l.download_success_pct), 2)
  from public.eifu_r3655 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3655_capa_status_board()
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
  from public.eifu_capa_actions_r3655 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root-cause pareto
create or replace function public.founder_r3655_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.eifu_capa_actions_r3655)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.eifu_capa_actions_r3655 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Language-gap digest
create or replace function public.founder_r3655_language_gap_digest()
returns table(
  device_name text,
  eifu_ref text,
  ifu_version text,
  delivery_channel text,
  languages_required int,
  languages_published int,
  missing_languages int,
  eifu_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_name, l.eifu_ref, l.ifu_version, l.delivery_channel,
    l.languages_required, l.languages_published,
    (l.languages_required - l.languages_published)::int,
    l.eifu_status, l.notes
  from public.eifu_r3655 l
  where l.languages_published < l.languages_required
  order by (l.languages_required - l.languages_published) desc, l.device_name;
end;
$$;

-- 8) High-risk queue (non_compliant / platform_issue / worsening)
create or replace function public.founder_r3655_high_risk_queue()
returns table(
  device_name text,
  eifu_ref text,
  ifu_version text,
  period_month date,
  delivery_channel text,
  eifu_status text,
  trend_dir text,
  platform_uptime_pct numeric,
  download_success_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_name, l.eifu_ref, l.ifu_version, l.period_month,
    l.delivery_channel, l.eifu_status, l.trend_dir,
    l.platform_uptime_pct, l.download_success_pct, l.notes
  from public.eifu_r3655 l
  where l.eifu_status in ('non_compliant','platform_issue','version_lag')
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.device_name;
end;
$$;

-- =============================================================================
-- GRANTS
-- =============================================================================
revoke all on function public.founder_r3655_eifu_status_rollup() from public, anon;
revoke all on function public.founder_r3655_delivery_channel_scorecard() from public, anon;
revoke all on function public.founder_r3655_channel_status_matrix() from public, anon;
revoke all on function public.founder_r3655_monthly_compliance_trend() from public, anon;
revoke all on function public.founder_r3655_capa_status_board() from public, anon;
revoke all on function public.founder_r3655_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3655_language_gap_digest() from public, anon;
revoke all on function public.founder_r3655_high_risk_queue() from public, anon;

grant execute on function public.founder_r3655_eifu_status_rollup() to authenticated;
grant execute on function public.founder_r3655_delivery_channel_scorecard() to authenticated;
grant execute on function public.founder_r3655_channel_status_matrix() to authenticated;
grant execute on function public.founder_r3655_monthly_compliance_trend() to authenticated;
grant execute on function public.founder_r3655_capa_status_board() to authenticated;
grant execute on function public.founder_r3655_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3655_language_gap_digest() to authenticated;
grant execute on function public.founder_r3655_high_risk_queue() to authenticated;

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

  -- 15 e-IFU platform compliance rows
  insert into public.eifu_r3655 (
    organization_id, eifu_ref, device_name, ifu_version, period_month,
    languages_required, languages_published, platform_uptime_pct, download_success_pct,
    paper_copy_requests, fulfilment_days, last_published, review_due,
    delivery_channel, eifu_status, trend_dir, notes
  )
  select v_org_id, q.eref, q.dname, q.ver, q.pmonth::date,
    q.lreq, q.lpub, q.upt, q.dls,
    q.pcr, q.fdays, q.lastpub::date, q.revdue::date,
    q.chan, q.st, q.trend, q.nt
  from (values
    ('EIFU-VNT-01','ICU Ventilator VS-500 (Skanray)','v4.2','2026-07-01',
     12,12,99.95,99.20,3,2.0,'2026-06-20','2027-06-20','web_portal','compliant','stable','All 12 required languages live; portal uptime within SLA'),
    ('EIFU-INF-02','Volumetric Infusion Pump IP-220 (BPL Medical)','v3.1','2026-07-01',
     10,8,99.90,98.70,5,3.5,'2026-05-14','2026-11-14','qr_on_label','language_gap','improving','Tamil and Marathi translations pending with vendor'),
    ('EIFU-MON-03','Patient Monitor PM-900 (Trivitron)','v5.0','2026-07-01',
     14,14,98.40,96.10,2,2.5,'2026-06-28','2027-06-28','app_embedded','platform_issue','worsening','App CDN outages dropped download success below 97 pct target'),
    ('EIFU-DLY-04','Dialysis Machine DL-4000 (Nipro India)','v2.8','2026-07-01',
     9,9,99.99,99.60,1,1.5,'2026-06-05','2026-12-05','web_portal','compliant','improving','Post-migration portal stable; zero missed downloads in July'),
    ('EIFU-DEF-05','Biphasic Defibrillator DF-300 (Phoenix Medical)','v1.9','2026-07-01',
     12,12,99.80,99.00,8,6.0,'2025-12-10','2026-06-10','usb_media','version_lag','worsening','Review overdue; v2.0 draft stuck in regulatory review'),
    ('EIFU-SYR-06','Syringe Pump SP-110 (Akas Infusions)','v2.2','2026-06-01',
     8,8,99.70,98.90,2,2.0,'2026-05-30','2026-11-30','qr_on_label','compliant','stable','QR-on-label scans resolving correctly across batches'),
    ('EIFU-ANE-07','Anesthesia Workstation AW-700 (Skanray)','v3.6','2026-06-01',
     12,9,99.60,97.80,4,4.0,'2026-04-18','2026-10-18','web_portal','language_gap','stable','Hindi, Bengali and Kannada translations contracted out'),
    ('EIFU-ECG-08','12-Channel ECG Machine EC-12 (BPL Medical)','v4.4','2026-06-01',
     10,10,99.20,95.50,6,5.0,'2026-05-22','2026-11-22','app_embedded','platform_issue','improving','Failover CDN added mid-June; success rate recovering'),
    ('EIFU-OXY-09','Oxygen Concentrator OC-10 (Oshocorp)','v1.4','2026-06-01',
     6,6,99.95,99.40,0,null,'2026-06-01','2026-12-01','web_portal','compliant','stable','No paper-copy requests this cycle; portal metrics clean'),
    ('EIFU-CPAP-10','BiPAP System BP-25 (ResMed India)','v2.5','2026-06-01',
     10,4,98.10,94.20,12,9.5,'2025-11-02','2026-05-02','paper_fallback','non_compliant','worsening','e-IFU withdrawn after audit; paper fallback active with six languages missing'),
    ('EIFU-FET-11','Fetal Monitor FM-40 (Trivitron)','v3.0','2026-05-01',
     8,8,99.85,99.10,1,2.0,'2026-04-25','2026-10-25','qr_on_label','compliant','improving','Label QR reprint completed; access telemetry nominal'),
    ('EIFU-DIA-12','Surgical Diathermy SD-400 (Alan Electronic)','v2.1','2026-05-01',
     9,7,99.75,98.40,3,3.0,'2026-03-15','2026-09-15','web_portal','language_gap','worsening','Gujarati and Telugu files rejected in linguistic QC'),
    ('EIFU-PUL-13','Pulse Oximeter PO-5 (Romsons)','v1.8','2026-05-01',
     6,6,97.60,93.80,2,2.5,'2026-05-05','2026-11-05','app_embedded','platform_issue','stable','Embedded viewer crash on older Android builds under fix'),
    ('EIFU-NEB-14','Ultrasonic Nebulizer NB-2 (Omron India)','v1.2','2026-05-01',
     6,6,99.90,99.30,0,null,'2026-04-12','2026-10-12','usb_media','compliant','stable','USB media verified against published checksum register'),
    ('EIFU-BLW-15','Blood/Fluid Warmer BW-100 (Sarstedt India)','v2.0','2026-05-01',
     8,8,99.40,98.80,9,7.5,'2025-10-20','2026-04-20','web_portal','version_lag','stable','Annual review overdue; v2.1 awaiting notified-body sign-off')
  ) as q(eref, dname, ver, pmonth, lreq, lpub, upt, dls, pcr, fdays, lastpub, revdue, chan, st, trend, nt);

  -- CAPA seed — attach to specific e-IFU records via eifu_ref
  insert into public.eifu_capa_actions_r3655 (
    eifu_id, root_cause, corrective_action, capa_status,
    estimated_cost_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.cost, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('EIFU-INF-02','translation_vendor_delay','expedite_translation','in_progress',180000.00,'Regulatory Affairs - Priya Nair','2026-07-25',null,'Tamil and Marathi files in final linguistic review'),
    ('EIFU-MON-03','cdn_misconfiguration','fix_cdn_configuration','verification_pending',95000.00,'Digital Platform - Arjun Mehta','2026-07-15',null,'CDN edge nodes reconfigured; monitoring download success for two weeks'),
    ('EIFU-DEF-05','regulatory_update_missed','republish_current_version','escalated',240000.00,'QA/RA Head - Sunita Rao','2026-07-10',null,'v2.0 e-IFU stuck in notified-body queue; escalated to management review'),
    ('EIFU-CPAP-10','version_control_lapse','republish_current_version','open',410000.00,'Regulatory Affairs - Priya Nair','2026-08-05',null,'Full re-baseline of language matrix required before e-IFU relisting'),
    ('EIFU-ANE-07','translation_vendor_delay','expedite_translation','open',150000.00,'Labeling Cell - Kavya Iyer','2026-07-30',null,'Hindi, Bengali and Kannada translations moved to new vendor'),
    ('EIFU-ECG-08','platform_outage','restore_platform_redundancy','closed',120000.00,'Digital Platform - Arjun Mehta','2026-06-20','2026-06-18','Failover CDN added; download success back above 98 pct'),
    ('EIFU-PUL-13','platform_outage','restore_platform_redundancy','in_progress',60000.00,'Digital Platform - Arjun Mehta','2026-07-22',null,'App-embedded viewer crash fix rolling out in phases'),
    ('EIFU-BLW-15','regulatory_update_missed','update_regulatory_watchlist','overdue',35000.00,'QA/RA Head - Sunita Rao','2026-06-30',null,'Annual review missed; regulatory watchlist automation being configured')
  ) as q(eref, rc, ca, cst, cost, ownr, tcd, acd, nt)
  join public.eifu_r3655 e
    on e.organization_id = v_org_id and e.eifu_ref = q.eref;
end;
$seed$;
