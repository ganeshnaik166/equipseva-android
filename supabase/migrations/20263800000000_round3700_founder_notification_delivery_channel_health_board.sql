-- Round 3700: Founder Notification-Delivery / Channel-Health Board
-- Platform notification health — notif type × channel × period × sent × delivered × opened × latency × failures × opt-outs × DND blocks × provider cost × CAPA

-- =============================================================================
-- TABLE 1: notif_delivery_r3700 — per-channel monthly notification delivery health
-- =============================================================================
create table if not exists public.notif_delivery_r3700 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  notif_code text not null,
  notif_type text not null,
  channel text not null,
  period_month date not null,
  sent int not null,
  delivered int not null,
  delivery_pct numeric(5,2),
  opened int not null,
  open_pct numeric(5,2),
  avg_latency_seconds numeric(8,2),
  failures int not null,
  opt_outs int not null,
  provider_cost_rupees numeric(12,2),
  dnd_blocked int not null,
  channel_class text not null check (channel_class in (
    'push_fcm','sms','whatsapp','email','otp_transactional'
  )),
  delivery_status text not null check (delivery_status in (
    'healthy','degraded','provider_issue','high_failure','blocked'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.notif_delivery_r3700 enable row level security;

create index if not exists idx_notif_delivery_r3700_org on public.notif_delivery_r3700(organization_id);
create index if not exists idx_notif_delivery_r3700_month on public.notif_delivery_r3700(period_month);
create index if not exists idx_notif_delivery_r3700_status on public.notif_delivery_r3700(delivery_status);

-- =============================================================================
-- TABLE 2: notif_delivery_capa_actions_r3700 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.notif_delivery_capa_actions_r3700 (
  id uuid primary key default gen_random_uuid(),
  delivery_log_id uuid not null references public.notif_delivery_r3700(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'fcm_token_expiry','dlt_template_mismatch','provider_route_degraded',
    'meta_template_paused','stale_recipient_list','dnd_scrub_gap',
    'content_spam_flagged','sender_id_blocked','template_quality_rating_drop',
    'pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'refresh_device_tokens','refile_dlt_template','switch_provider_route',
    'appeal_template_review','clean_recipient_list','enforce_dnd_scrub',
    'rewrite_notification_copy','migrate_to_whatsapp_utility','add_fallback_channel',
    'none_required'
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

alter table public.notif_delivery_capa_actions_r3700 enable row level security;

create index if not exists idx_notif_delivery_capa_r3700_log on public.notif_delivery_capa_actions_r3700(delivery_log_id);
create index if not exists idx_notif_delivery_capa_r3700_status on public.notif_delivery_capa_actions_r3700(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Delivery status distribution
create or replace function public.founder_r3700_delivery_status_rollup()
returns table(delivery_status text, cells bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.notif_delivery_r3700)
  select l.delivery_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.notif_delivery_r3700 l
  group by l.delivery_status
  order by count(*) desc;
end;
$$;

-- 2) Channel scorecard
create or replace function public.founder_r3700_channel_scorecard()
returns table(
  channel text,
  cells bigint,
  total_sent bigint,
  total_delivered bigint,
  avg_delivery_pct numeric,
  avg_open_pct numeric,
  total_failures bigint,
  total_opt_outs bigint,
  total_cost_rupees numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.channel,
    count(*)::bigint,
    sum(l.sent)::bigint,
    sum(l.delivered)::bigint,
    round(avg(l.delivery_pct), 1),
    round(avg(l.open_pct), 1),
    sum(l.failures)::bigint,
    sum(l.opt_outs)::bigint,
    coalesce(sum(l.provider_cost_rupees),0)::numeric
  from public.notif_delivery_r3700 l
  group by l.channel
  order by sum(l.sent) desc;
end;
$$;

-- 3) Channel-class × delivery-status matrix
create or replace function public.founder_r3700_class_status_matrix()
returns table(channel_class text, delivery_status text, cells bigint, total_sent bigint, total_failures bigint, avg_latency_seconds numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.channel_class, l.delivery_status, count(*)::bigint,
    sum(l.sent)::bigint,
    sum(l.failures)::bigint,
    round(avg(l.avg_latency_seconds), 2)
  from public.notif_delivery_r3700 l
  group by l.channel_class, l.delivery_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly delivery trend
create or replace function public.founder_r3700_monthly_delivery_trend()
returns table(period_month date, cells bigint, total_sent bigint, total_delivered bigint, avg_delivery_pct numeric, total_failures bigint, total_dnd_blocked bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    sum(l.sent)::bigint,
    sum(l.delivered)::bigint,
    round(avg(l.delivery_pct), 1),
    sum(l.failures)::bigint,
    sum(l.dnd_blocked)::bigint
  from public.notif_delivery_r3700 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3700_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.notif_delivery_capa_actions_r3700 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3700_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.notif_delivery_capa_actions_r3700)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.notif_delivery_capa_actions_r3700 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Failure / latency digest by channel class
create or replace function public.founder_r3700_failure_latency_digest()
returns table(channel_class text, cells bigint, total_failures bigint, avg_latency_seconds numeric, total_dnd_blocked bigint, total_opt_outs bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.channel_class, count(*)::bigint,
    sum(l.failures)::bigint,
    round(avg(l.avg_latency_seconds), 2),
    sum(l.dnd_blocked)::bigint,
    sum(l.opt_outs)::bigint,
    coalesce(sum(l.provider_cost_rupees),0)::numeric
  from public.notif_delivery_r3700 l
  group by l.channel_class
  order by sum(l.failures) desc;
end;
$$;

-- 8) High-risk queue (blocked / high-failure / provider-issue channels)
create or replace function public.founder_r3700_high_risk_queue()
returns table(
  notif_code text,
  notif_type text,
  channel text,
  period_month date,
  channel_class text,
  delivery_status text,
  trend_dir text,
  delivery_pct numeric,
  failures int,
  dnd_blocked int,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.notif_code, l.notif_type, l.channel, l.period_month, l.channel_class,
    l.delivery_status, l.trend_dir, l.delivery_pct, l.failures, l.dnd_blocked, l.notes
  from public.notif_delivery_r3700 l
  where l.delivery_status in ('blocked','high_failure','provider_issue')
     or l.trend_dir = 'worsening'
     or l.delivery_pct < 90.0
  order by l.period_month desc, l.failures desc;
end;
$$;

-- =============================================================================
-- GRANTS — founder RPCs are authenticated-only
-- =============================================================================
revoke all on function public.founder_r3700_delivery_status_rollup() from public, anon;
revoke all on function public.founder_r3700_channel_scorecard() from public, anon;
revoke all on function public.founder_r3700_class_status_matrix() from public, anon;
revoke all on function public.founder_r3700_monthly_delivery_trend() from public, anon;
revoke all on function public.founder_r3700_capa_status_board() from public, anon;
revoke all on function public.founder_r3700_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3700_failure_latency_digest() from public, anon;
revoke all on function public.founder_r3700_high_risk_queue() from public, anon;

grant execute on function public.founder_r3700_delivery_status_rollup() to authenticated;
grant execute on function public.founder_r3700_channel_scorecard() to authenticated;
grant execute on function public.founder_r3700_class_status_matrix() to authenticated;
grant execute on function public.founder_r3700_monthly_delivery_trend() to authenticated;
grant execute on function public.founder_r3700_capa_status_board() to authenticated;
grant execute on function public.founder_r3700_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3700_failure_latency_digest() to authenticated;
grant execute on function public.founder_r3700_high_risk_queue() to authenticated;

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

  -- 16 delivery-health rows
  insert into public.notif_delivery_r3700 (
    organization_id, notif_code, notif_type, channel, period_month,
    sent, delivered, delivery_pct, opened, open_pct, avg_latency_seconds,
    failures, opt_outs, provider_cost_rupees, dnd_blocked,
    channel_class, delivery_status, trend_dir, notes
  )
  select v_org_id, q.nc, q.ntype, q.chan, q.pm::date,
    q.snt, q.dlv, q.dpct, q.opn, q.opct, q.lat,
    q.fl, q.oo, q.cost, q.dnd,
    q.cls, q.st, q.td, q.nt
  from (values
    ('NTF-PUSH-BID-05','bid_received','FCM','2026-05-01',
     48200,46850,97.2,21300,45.5,2.1,1350,0,0.00,0,'push_fcm','healthy','stable','Bid push fan-out nominal — FCM priority high channel'),
    ('NTF-PUSH-BID-06','bid_received','FCM','2026-06-01',
     52600,50900,96.8,22400,44.0,2.4,1700,0,0.00,0,'push_fcm','healthy','stable','Bid pushes steady month-over-month, latency flat'),
    ('NTF-PUSH-JOB-07','job_assigned','FCM','2026-07-01',
     31450,28100,89.3,11900,42.3,6.8,3350,0,0.00,0,'push_fcm','degraded','worsening','Token-expiry spike after app update — delivery dipped below 90'),
    ('NTF-PUSH-PROMO-06','marketing_promo','FCM','2026-06-01',
     60500,57200,94.5,9100,15.9,3.6,3300,0,0.00,0,'push_fcm','degraded','stable','Promo push underdelivers on dormant devices — fallback pending'),
    ('NTF-SMS-OTP-07','otp_login','MSG91','2026-07-01',
     88400,86200,97.5,0,0.0,4.2,2200,0,17680.00,0,'otp_transactional','healthy','improving','OTP route healthy on priority transactional sender'),
    ('NTF-OTP-WA-07','otp_login','Meta Cloud API','2026-07-01',
     26400,25900,98.1,0,0.0,1.9,500,0,13200.00,0,'otp_transactional','healthy','stable','WhatsApp authentication-template OTP fast, cheap fallback for SMS'),
    ('NTF-SMS-PAY-06','payment_reminder','MSG91','2026-06-01',
     15800,13100,82.9,900,6.9,9.5,2700,140,3160.00,2100,'sms','high_failure','worsening','DND scrub gap — heavy operator blocks on promo sender ID'),
    ('NTF-SMS-PAY-07','payment_reminder','Gupshup','2026-07-01',
     14900,13650,91.6,1050,7.7,7.3,1250,95,2980.00,850,'sms','degraded','improving','Moved to Gupshup transactional route — DND blocks easing'),
    ('NTF-SMS-KYC-07','kyc_status','MSG91','2026-07-01',
     4200,1300,31.0,150,11.5,26.5,2900,10,840.00,0,'sms','blocked','worsening','Sender ID blocked by operator — DLT template mismatch on KYC copy'),
    ('NTF-WA-QUOTE-06','quote_ready','Meta Cloud API','2026-06-01',
     12400,12050,97.2,8600,71.4,3.1,350,60,9920.00,0,'whatsapp','healthy','stable','Quote-ready utility template performing well, high opens'),
    ('NTF-WA-QUOTE-07','quote_ready','Meta Cloud API','2026-07-01',
     13650,11200,82.1,7400,66.1,11.8,2450,75,10920.00,0,'whatsapp','provider_issue','worsening','Meta paused utility template on quality-rating drop — appeal filed'),
    ('NTF-WA-DISP-07','engineer_dispatch','Meta Cloud API','2026-07-01',
     9800,9520,97.1,7350,77.2,2.8,280,20,7840.00,0,'whatsapp','healthy','improving','Engineer-dispatch alerts land fast — best open rate on platform'),
    ('NTF-WA-PAY-05','payment_reminder','WhatsApp BSP','2026-05-01',
     11800,11350,96.2,8200,72.2,3.4,450,85,9440.00,0,'whatsapp','healthy','stable','Payment reminders on BSP route stable before Meta migration'),
    ('NTF-EML-INV-06','invoice_ready','AWS SES','2026-06-01',
     18200,17650,97.0,5100,28.9,15.6,550,110,364.00,0,'email','healthy','stable','Invoice emails clean — SES reputation high, bounces low'),
    ('NTF-EML-AMC-07','amc_renewal','AWS SES','2026-07-01',
     7600,6100,80.3,1450,23.8,18.2,1500,240,152.00,0,'email','high_failure','worsening','Bounce spike — stale hospital procurement mailboxes on AMC list'),
    ('NTF-EML-PROMO-07','marketing_promo','AWS SES','2026-07-01',
     22400,20900,93.3,3800,18.2,21.4,1500,620,448.00,0,'email','degraded','stable','Weekly digest opt-outs rising — copy flagged spammy by seed tests')
  ) as q(nc, ntype, chan, pm, snt, dlv, dpct, opn, opct, lat, fl, oo, cost, dnd, cls, st, td, nt);

  -- CAPA seed — attach to specific delivery rows via notif_code
  insert into public.notif_delivery_capa_actions_r3700 (
    delivery_log_id, root_cause, corrective_action, capa_status,
    estimated_cost_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.cost, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('NTF-PUSH-JOB-07','fcm_token_expiry','refresh_device_tokens','in_progress',18500.00,'Platform Eng','2026-08-14',null,'Silent-push token refresh job rolling out to stale installs'),
    ('NTF-SMS-KYC-07','sender_id_blocked','refile_dlt_template','escalated',42000.00,'Growth Ops','2026-08-10',null,'Operator block on KYC sender — DLT template refiled, TRAI escalation open'),
    ('NTF-SMS-PAY-06','dnd_scrub_gap','enforce_dnd_scrub','closed',9600.00,'Growth Ops','2026-07-20','2026-07-16','Pre-send DND scrub enforced on promo sender — blocks dropped 60 pct'),
    ('NTF-WA-QUOTE-07','meta_template_paused','appeal_template_review','verification_pending',27400.00,'Support Ops','2026-08-12',null,'Template appeal approved — monitoring quality rating for 2 weeks'),
    ('NTF-EML-AMC-07','stale_recipient_list','clean_recipient_list','open',12800.00,'CRM Ops','2026-08-18',null,'Bounce-list hygiene run scheduled with procurement re-verification'),
    ('NTF-EML-PROMO-07','content_spam_flagged','rewrite_notification_copy','in_progress',5400.00,'Marketing','2026-08-16',null,'Digest copy rewrite plus frequency cap to cut opt-outs'),
    ('NTF-SMS-PAY-07','provider_route_degraded','switch_provider_route','verification_pending',7300.00,'Platform Eng','2026-08-11',null,'Cut over to Gupshup transactional route — verifying delivery fill'),
    ('NTF-PUSH-PROMO-06','pending_investigation','add_fallback_channel','overdue',6100.00,'Growth Ops','2026-07-30',null,'Promo push underdelivery on dormant devices — WhatsApp fallback pending')
  ) as q(nc, rc, ca, cst, cost, own, tcd, acd, nt)
  join public.notif_delivery_r3700 e
    on e.organization_id = v_org_id and e.notif_code = q.nc;
end;
$seed$;
