-- Round 3692: Founder Key-Management / Master-Key Register Board
-- Physical key management — master-key register, issuance, returns, lost keys, rekeys and audits per own site

-- =============================================================================
-- TABLE 1: key_mgmt_r3692 — per-site per-month key-register entries
-- =============================================================================
create table if not exists public.key_mgmt_r3692 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  key_set_code text not null,
  site_name text not null,
  period_month date not null,
  keys_total int not null,
  keys_issued int not null,
  keys_returned int not null,
  keys_lost int not null,
  locks_rekeyed int not null,
  custodian_assigned boolean not null,
  register_audit_current boolean not null,
  last_audit_date date,
  discrepancies int not null,
  key_class text not null check (key_class in (
    'master_key','sub_master','server_room_key','warehouse_dock','vehicle_key'
  )),
  register_status text not null check (register_status in (
    'reconciled','issuance_gap','lost_key_open','audit_due','uncontrolled'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.key_mgmt_r3692 enable row level security;

create index if not exists idx_key_mgmt_r3692_org on public.key_mgmt_r3692(organization_id);
create index if not exists idx_key_mgmt_r3692_month on public.key_mgmt_r3692(period_month);
create index if not exists idx_key_mgmt_r3692_status on public.key_mgmt_r3692(register_status);

-- =============================================================================
-- TABLE 2: key_mgmt_capa_actions_r3692 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.key_mgmt_capa_actions_r3692 (
  id uuid primary key default gen_random_uuid(),
  register_id uuid not null references public.key_mgmt_r3692(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'custodian_change_unlogged','key_duplicated_unauthorised','contractor_key_not_returned',
    'register_not_updated','key_cabinet_unsecured','key_lost_in_field',
    'audit_backlog','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'rekey_locks','recover_key_from_holder','update_register_and_reconcile',
    'assign_new_custodian','install_key_cabinet','retrain_site_staff',
    'full_site_key_audit','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  rekey_cost_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.key_mgmt_capa_actions_r3692 enable row level security;

create index if not exists idx_key_mgmt_capa_r3692_reg on public.key_mgmt_capa_actions_r3692(register_id);
create index if not exists idx_key_mgmt_capa_r3692_status on public.key_mgmt_capa_actions_r3692(capa_status);

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

  -- 16 key-register rows
  insert into public.key_mgmt_r3692 (
    organization_id, key_set_code, site_name, period_month,
    keys_total, keys_issued, keys_returned, keys_lost, locks_rekeyed,
    custodian_assigned, register_audit_current, last_audit_date, discrepancies,
    key_class, register_status, trend_dir, notes
  )
  select v_org_id, q.kcode, q.site, q.pm::date,
    q.ktot, q.kiss, q.kret, q.klost, q.rkey,
    q.cust, q.audcur, q.lad::date, q.disc,
    q.kcls, q.rstat, q.tdir, q.nt
  from (values
    ('KMS-MUM-MK-01','Mumbai HQ','2026-07-01',12,4,4,0,0,
     true,true,'2026-07-05',0,'master_key','reconciled','stable','HQ grand-master set fully reconciled; monthly audit clean'),
    ('KMS-MUM-SR-02','Mumbai HQ','2026-07-01',8,6,5,0,0,
     true,true,'2026-07-05',1,'server_room_key','issuance_gap','improving','One server-room key issued to Netmagic vendor engineer not yet signed back'),
    ('KMS-MUM-SM-03','Mumbai HQ','2026-06-01',20,11,11,0,0,
     true,true,'2026-06-06',0,'sub_master','reconciled','stable','Floor sub-master keys reconciled against Godrej cabinet log'),
    ('KMS-MUM-VH-04','Mumbai HQ','2026-07-01',10,7,6,1,1,
     true,false,'2026-05-30',2,'vehicle_key','lost_key_open','worsening','Service-van key lost by field engineer; ignition rekeyed and FIR filed'),
    ('KMS-CHE-MK-11','Chennai Branch','2026-07-01',6,2,2,0,0,
     true,true,'2026-07-04',0,'master_key','reconciled','improving','Branch master set verified by admin custodian'),
    ('KMS-CHE-SM-12','Chennai Branch','2026-06-01',14,9,8,0,0,
     true,false,'2026-04-18',1,'sub_master','audit_due','stable','Quarterly register audit overdue; one open issuance to housekeeping'),
    ('KMS-CHE-SR-13','Chennai Branch','2026-07-01',4,3,3,0,0,
     true,true,'2026-07-04',0,'server_room_key','reconciled','stable','Server-room keys under dual custody with IT lead'),
    ('KMS-CHE-VH-14','Chennai Branch','2026-05-01',6,5,4,1,0,
     false,false,'2026-03-22',3,'vehicle_key','uncontrolled','worsening','No custodian after admin exit; van key missing and rekey quote awaited'),
    ('KMS-DEL-MK-21','Delhi Warehouse','2026-07-01',8,3,3,0,0,
     true,true,'2026-07-06',0,'master_key','reconciled','stable','Warehouse master set audited with CCTV cross-check'),
    ('KMS-DEL-WD-22','Delhi Warehouse','2026-07-01',16,12,10,0,0,
     true,true,'2026-07-06',2,'warehouse_dock','issuance_gap','stable','Two dock shutter keys with night-shift contractor pending return'),
    ('KMS-DEL-WD-23','Delhi Warehouse','2026-06-01',16,10,9,1,1,
     true,true,'2026-06-07',1,'warehouse_dock','lost_key_open','improving','Dock key lost by Safexpress loader; shutter lock rekeyed'),
    ('KMS-DEL-SM-24','Delhi Warehouse','2026-05-01',18,8,8,0,0,
     true,false,'2026-02-14',0,'sub_master','audit_due','stable','Half-yearly physical audit slipped; register otherwise clean'),
    ('KMS-BLR-MK-31','Bengaluru Refurb Center','2026-07-01',6,2,2,0,0,
     true,true,'2026-07-03',0,'master_key','reconciled','stable','Refurb center master set reconciled; Godrej key cabinet serviced'),
    ('KMS-BLR-SR-32','Bengaluru Refurb Center','2026-06-01',5,4,4,0,1,
     true,true,'2026-06-05',0,'server_room_key','reconciled','improving','Test-lab server-room lock rekeyed on vendor audit advice'),
    ('KMS-BLR-SM-33','Bengaluru Refurb Center','2026-07-01',12,9,7,0,0,
     false,true,'2026-07-03',2,'sub_master','uncontrolled','worsening','Custodian on long leave without handover; two sub-masters untracked'),
    ('KMS-BLR-VH-34','Bengaluru Refurb Center','2026-07-01',8,6,6,0,0,
     true,true,'2026-07-03',0,'vehicle_key','reconciled','stable','Pickup-truck keys reconciled; duplicate set sealed in cabinet')
  ) as q(kcode, site, pm, ktot, kiss, kret, klost, rkey, cust, audcur, lad, disc, kcls, rstat, tdir, nt);

  -- CAPA seed — attach to specific register entries via key_set_code
  insert into public.key_mgmt_capa_actions_r3692 (
    register_id, root_cause, corrective_action, capa_status,
    rekey_cost_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.cost, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('KMS-MUM-VH-04','key_lost_in_field','rekey_locks','in_progress',9500.00,'Admin Manager - Mumbai','2026-07-20',null,'Van ignition and fuel-cap locks rekeyed; FIR copy filed with insurer'),
    ('KMS-MUM-SR-02','contractor_key_not_returned','recover_key_from_holder','open',0.00,'IT Facilities Lead','2026-07-15',null,'Vendor engineer to surrender server-room key at next scheduled visit'),
    ('KMS-CHE-VH-14','custodian_change_unlogged','assign_new_custodian','escalated',18500.00,'Branch Manager - Chennai','2026-07-10',null,'No handover after admin exit; van rekey quote from Godrej pending'),
    ('KMS-CHE-SM-12','audit_backlog','full_site_key_audit','open',3000.00,'Regional Admin Head','2026-07-25',null,'Quarterly physical key audit to be completed with HR witness'),
    ('KMS-DEL-WD-23','key_lost_in_field','rekey_locks','closed',6200.00,'Warehouse Supervisor - Delhi','2026-06-20','2026-06-14','Dock shutter lock rekeyed; loader agency billed for cylinder'),
    ('KMS-DEL-WD-22','contractor_key_not_returned','recover_key_from_holder','verification_pending',0.00,'Warehouse Supervisor - Delhi','2026-07-12',null,'Night-shift contractor to return both dock keys; verify against gate log'),
    ('KMS-DEL-SM-24','audit_backlog','full_site_key_audit','overdue',2500.00,'Regional Admin Head','2026-06-30',null,'Half-yearly audit past target date; scheduling clash with stock count'),
    ('KMS-BLR-SM-33','custodian_change_unlogged','assign_new_custodian','in_progress',4000.00,'Center Head - Bengaluru','2026-07-18',null,'Interim custodian named; two sub-masters being traced via issue slips')
  ) as q(kcode, rc, ca, cst, cost, own, tcd, acd, nt)
  join public.key_mgmt_r3692 e
    on e.organization_id = v_org_id and e.key_set_code = q.kcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Register status distribution
create or replace function public.founder_r3692_register_status_rollup()
returns table(register_status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.key_mgmt_r3692)
  select l.register_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.key_mgmt_r3692 l
  group by l.register_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3692_register_status_rollup() from public, anon;
grant execute on function public.founder_r3692_register_status_rollup() to authenticated;

-- 2) Site-level key-register scorecard
create or replace function public.founder_r3692_site_scorecard()
returns table(
  site_name text,
  entries bigint,
  keys_total_sum bigint,
  keys_issued_sum bigint,
  keys_returned_sum bigint,
  keys_lost_sum bigint,
  discrepancies_sum bigint,
  reconciled bigint,
  reconciled_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name,
    count(*)::bigint,
    coalesce(sum(l.keys_total),0)::bigint,
    coalesce(sum(l.keys_issued),0)::bigint,
    coalesce(sum(l.keys_returned),0)::bigint,
    coalesce(sum(l.keys_lost),0)::bigint,
    coalesce(sum(l.discrepancies),0)::bigint,
    count(*) filter (where l.register_status = 'reconciled')::bigint,
    round(100.0 * count(*) filter (where l.register_status = 'reconciled')::numeric / nullif(count(*),0), 1)
  from public.key_mgmt_r3692 l
  group by l.site_name
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3692_site_scorecard() from public, anon;
grant execute on function public.founder_r3692_site_scorecard() to authenticated;

-- 3) Key class × register status matrix
create or replace function public.founder_r3692_key_class_status_matrix()
returns table(key_class text, register_status text, entries bigint, keys_lost_sum bigint, discrepancies_sum bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.key_class, l.register_status, count(*)::bigint,
    coalesce(sum(l.keys_lost),0)::bigint,
    coalesce(sum(l.discrepancies),0)::bigint
  from public.key_mgmt_r3692 l
  group by l.key_class, l.register_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3692_key_class_status_matrix() from public, anon;
grant execute on function public.founder_r3692_key_class_status_matrix() to authenticated;

-- 4) Monthly issuance trend
create or replace function public.founder_r3692_monthly_issuance_trend()
returns table(period_month date, entries bigint, keys_issued_sum bigint, keys_returned_sum bigint, keys_lost_sum bigint, locks_rekeyed_sum bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.keys_issued),0)::bigint,
    coalesce(sum(l.keys_returned),0)::bigint,
    coalesce(sum(l.keys_lost),0)::bigint,
    coalesce(sum(l.locks_rekeyed),0)::bigint
  from public.key_mgmt_r3692 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3692_monthly_issuance_trend() from public, anon;
grant execute on function public.founder_r3692_monthly_issuance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3692_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.rekey_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.key_mgmt_capa_actions_r3692 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3692_capa_status_board() from public, anon;
grant execute on function public.founder_r3692_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3692_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.key_mgmt_capa_actions_r3692)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.rekey_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.key_mgmt_capa_actions_r3692 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3692_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3692_root_cause_pareto() to authenticated;

-- 7) Lost-key digest by key class
create or replace function public.founder_r3692_lost_key_digest()
returns table(key_class text, entries bigint, keys_lost_sum bigint, locks_rekeyed_sum bigint, lost_key_open bigint, uncontrolled bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.key_class, count(*)::bigint,
    coalesce(sum(l.keys_lost),0)::bigint,
    coalesce(sum(l.locks_rekeyed),0)::bigint,
    count(*) filter (where l.register_status = 'lost_key_open')::bigint,
    count(*) filter (where l.register_status = 'uncontrolled')::bigint
  from public.key_mgmt_r3692 l
  group by l.key_class
  order by coalesce(sum(l.keys_lost),0) desc, count(*) desc;
end;
$$;

revoke all on function public.founder_r3692_lost_key_digest() from public, anon;
grant execute on function public.founder_r3692_lost_key_digest() to authenticated;

-- 8) High-risk register queue (uncontrolled / lost-key-open / gaps)
create or replace function public.founder_r3692_high_risk_queue()
returns table(
  site_name text,
  key_set_code text,
  key_class text,
  period_month date,
  register_status text,
  keys_lost int,
  discrepancies int,
  custodian_assigned boolean,
  register_audit_current boolean,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name, l.key_set_code, l.key_class, l.period_month,
    l.register_status, l.keys_lost, l.discrepancies,
    l.custodian_assigned, l.register_audit_current, l.trend_dir, l.notes
  from public.key_mgmt_r3692 l
  where l.register_status in ('uncontrolled','lost_key_open','issuance_gap','audit_due')
     or l.keys_lost > 0
     or l.discrepancies > 0
     or l.custodian_assigned = false
     or l.register_audit_current = false
  order by l.period_month desc, l.site_name;
end;
$$;

revoke all on function public.founder_r3692_high_risk_queue() from public, anon;
grant execute on function public.founder_r3692_high_risk_queue() to authenticated;
