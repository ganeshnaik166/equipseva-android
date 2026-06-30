-- Round 3121 — Founder Personal Cybersecurity + Device Hygiene Audit
-- Tracks founder personal cyber posture: devices, OS patch level, 2FA coverage,
-- VPN posture, phishing simulation results, backups, leaked credential checks,
-- and account recovery readiness. Founder-gated only.

set search_path = public, pg_temp;

-- ============================================================
-- TABLE 1 — founder devices + per-device cyber posture
-- ============================================================
create table if not exists founder_cyber_devices_r3121 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  device_label text not null,
  device_kind text not null check (device_kind in ('laptop','desktop','phone','tablet','router','nas','usb_key','smartwatch')),
  os_family text not null check (os_family in ('macos','ios','windows','android','linux','router_os','watchos')),
  os_version text not null,
  patch_status text not null check (patch_status in ('current','one_behind','two_behind','eol','unknown')),
  full_disk_encryption boolean not null default false,
  screen_lock_seconds int check (screen_lock_seconds is null or screen_lock_seconds between 0 and 3600),
  mdm_enrolled boolean not null default false,
  remote_wipe_enabled boolean not null default false,
  password_manager_installed boolean not null default false,
  antivirus_installed boolean not null default false,
  firewall_enabled boolean not null default false,
  vpn_configured boolean not null default false,
  last_seen_at timestamptz,
  last_backup_at timestamptz,
  risk_score int not null check (risk_score between 0 and 100),
  risk_tier text not null check (risk_tier in ('low','medium','high','critical')),
  audit_status text not null check (audit_status in ('pass','warn','fail','remediation_open','retired')),
  remediation_owner text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_fcd_r3121_org on founder_cyber_devices_r3121(organization_id);
create index if not exists idx_fcd_r3121_tier on founder_cyber_devices_r3121(risk_tier);
create index if not exists idx_fcd_r3121_status on founder_cyber_devices_r3121(audit_status);

alter table founder_cyber_devices_r3121 enable row level security;

drop policy if exists fcd_r3121_founder_all on founder_cyber_devices_r3121;
create policy fcd_r3121_founder_all on founder_cyber_devices_r3121
  for all to authenticated
  using (is_founder())
  with check (is_founder());

-- ============================================================
-- TABLE 2 — account / identity / 2FA / phishing / leak posture
-- ============================================================
create table if not exists founder_cyber_account_checks_r3121 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  device_id uuid references founder_cyber_devices_r3121(id) on delete set null,
  account_label text not null,
  account_kind text not null check (account_kind in (
    'email','banking','upi','cloud_admin','supabase_admin','github','google_workspace',
    'apple_id','razorpay','cashfree','aadhaar_link','domain_registrar','dns_provider','payroll','vendor_portal'
  )),
  check_kind text not null check (check_kind in (
    '2fa_enrollment','phishing_simulation','leaked_credential_scan','recovery_setup',
    'session_token_audit','oauth_grants_review','sso_review','password_strength','vpn_posture'
  )),
  twofa_method text check (twofa_method is null or twofa_method in (
    'hardware_key','totp_app','sms_otp','email_otp','push_app','passkey','none'
  )),
  twofa_enrolled boolean not null default false,
  recovery_codes_offline boolean not null default false,
  backup_email_set boolean not null default false,
  backup_phone_set boolean not null default false,
  phishing_test_result text check (phishing_test_result is null or phishing_test_result in (
    'passed','failed_click','failed_credential_entry','reported','not_tested'
  )),
  leaked_in_breach boolean not null default false,
  breach_source text,
  last_password_rotation_at date,
  vpn_required boolean not null default false,
  finding_severity text not null check (finding_severity in ('p0','p1','p2','p3','info')),
  remediation_status text not null check (remediation_status in (
    'open','in_progress','blocked','done','accepted_risk','not_applicable'
  )),
  remediation_due_at date,
  remediation_owner text,
  evidence_url text,
  audit_quarter text not null check (audit_quarter ~ '^[0-9]{4}-Q[1-4]$'),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_fcac_r3121_org on founder_cyber_account_checks_r3121(organization_id);
create index if not exists idx_fcac_r3121_kind on founder_cyber_account_checks_r3121(check_kind);
create index if not exists idx_fcac_r3121_sev on founder_cyber_account_checks_r3121(finding_severity);
create index if not exists idx_fcac_r3121_quarter on founder_cyber_account_checks_r3121(audit_quarter);

alter table founder_cyber_account_checks_r3121 enable row level security;

drop policy if exists fcac_r3121_founder_all on founder_cyber_account_checks_r3121;
create policy fcac_r3121_founder_all on founder_cyber_account_checks_r3121
  for all to authenticated
  using (is_founder())
  with check (is_founder());

-- ============================================================
-- SEEDS
-- ============================================================
with first_org as (
  select id as org_id from organizations order by created_at asc limit 1
)
insert into founder_cyber_devices_r3121 (
  organization_id, device_label, device_kind, os_family, os_version,
  patch_status, full_disk_encryption, screen_lock_seconds, mdm_enrolled,
  remote_wipe_enabled, password_manager_installed, antivirus_installed,
  firewall_enabled, vpn_configured, last_seen_at, last_backup_at,
  risk_score, risk_tier, audit_status, remediation_owner, notes
)
select fo.org_id, d.device_label, d.device_kind, d.os_family, d.os_version,
       d.patch_status, d.full_disk_encryption, d.screen_lock_seconds, d.mdm_enrolled,
       d.remote_wipe_enabled, d.password_manager_installed, d.antivirus_installed,
       d.firewall_enabled, d.vpn_configured, d.last_seen_at::timestamptz, d.last_backup_at::timestamptz,
       d.risk_score, d.risk_tier, d.audit_status, d.remediation_owner, d.notes
from first_org fo
cross join (values
  ('Founder MacBook Pro M3 (primary)','laptop','macos','14.6.1','current',true,60,true,true,true,true,true,true,
   now() - interval '2 hours', now() - interval '6 hours', 12, 'low','pass','founder','daily driver — Sequoia, FileVault on, Little Snitch active'),
  ('Founder iPhone 15 Pro','phone','ios','17.5.1','current',true,30,true,true,true,false,true,true,
   now() - interval '15 minutes', now() - interval '1 day', 8, 'low','pass','founder','primary UPI device, FaceID + recovery key offline'),
  ('Founder iPad Pro 11 (review)','tablet','ios','17.5.1','current',true,60,true,true,true,false,true,false,
   now() - interval '3 days', now() - interval '4 days', 28, 'low','warn','founder','VPN not configured — board-pack review device'),
  ('Backup Windows laptop (Dell)','laptop','windows','11.23H2','one_behind',true,120,false,false,true,true,true,true,
   now() - interval '11 days', now() - interval '12 days', 58, 'medium','remediation_open','founder','no MDM, patch one_behind — used for vendor portals'),
  ('Co-founder Pixel 8 Pro','phone','android','14','current',true,60,true,true,true,false,true,true,
   now() - interval '4 hours', now() - interval '1 day', 18, 'low','pass','cofounder','Titan M2 chip, work profile separated'),
  ('Old MacBook Air 2019 (parents)','laptop','macos','12.7.4','two_behind',false,300,false,false,false,false,false,false,
   now() - interval '22 days', null::timestamptz, 82, 'high','fail','founder','SHARES iCloud — must wipe + retire by next quarter'),
  ('Apple Watch Series 9','smartwatch','watchos','10.5','current',true,null,false,false,false,false,false,false,
   now() - interval '20 minutes', null::timestamptz, 22, 'low','warn','founder','passcode unlock from iPhone, no independent risk'),
  ('Home office router (ASUS RT-AX88U)','router','router_os','3.0.0.4.388','one_behind',false,null,false,false,false,false,true,false,
   now() - interval '1 hour', null::timestamptz, 64, 'medium','remediation_open','founder','firmware one_behind, WPA3 on, guest network isolated'),
  ('Synology NAS DS923+','nas','linux','DSM 7.2.2','current',true,null,false,true,false,false,true,true,
   now() - interval '30 minutes', now() - interval '6 hours', 24, 'low','pass','founder','snapshots hourly, off-site C2 backup nightly'),
  ('YubiKey 5C NFC (primary)','usb_key','linux','5.4.3','current',false,null,false,false,false,false,false,false,
   now() - interval '2 hours', null::timestamptz, 4, 'low','pass','founder','primary hardware 2FA across GitHub + Google + 1Password'),
  ('YubiKey 5 NFC (backup, safe deposit)','usb_key','linux','5.2.7','two_behind',false,null,false,false,false,false,false,false,
   now() - interval '90 days', null::timestamptz, 16, 'low','pass','founder','locked in bank safe deposit, quarterly rotation check'),
  ('Old iPhone 12 (resale pending)','phone','ios','16.7.8','eol',true,60,false,true,false,false,false,false,
   now() - interval '40 days', now() - interval '60 days', 88, 'critical','remediation_open','founder','still signed into Apple ID — wipe + sign-out before resale')
) as d(device_label, device_kind, os_family, os_version, patch_status, full_disk_encryption,
       screen_lock_seconds, mdm_enrolled, remote_wipe_enabled, password_manager_installed,
       antivirus_installed, firewall_enabled, vpn_configured, last_seen_at, last_backup_at,
       risk_score, risk_tier, audit_status, remediation_owner, notes);

with first_org as (
  select id as org_id from organizations order by created_at asc limit 1
),
primary_device as (
  select id as dev_id from founder_cyber_devices_r3121
  where device_label = 'Founder MacBook Pro M3 (primary)' limit 1
)
insert into founder_cyber_account_checks_r3121 (
  organization_id, device_id, account_label, account_kind, check_kind,
  twofa_method, twofa_enrolled, recovery_codes_offline, backup_email_set, backup_phone_set,
  phishing_test_result, leaked_in_breach, breach_source, last_password_rotation_at,
  vpn_required, finding_severity, remediation_status, remediation_due_at,
  remediation_owner, evidence_url, audit_quarter, notes
)
select fo.org_id, pd.dev_id, a.account_label, a.account_kind, a.check_kind,
       a.twofa_method, a.twofa_enrolled, a.recovery_codes_offline, a.backup_email_set, a.backup_phone_set,
       a.phishing_test_result, a.leaked_in_breach, a.breach_source, a.last_password_rotation_at::date,
       a.vpn_required, a.finding_severity, a.remediation_status, a.remediation_due_at::date,
       a.remediation_owner, a.evidence_url, a.audit_quarter, a.notes
from first_org fo
cross join primary_device pd
cross join (values
  ('ops@getphyllo.com (founder primary email)','email','2fa_enrollment','hardware_key',true,true,true,true,
   'passed',false,null,'2026-05-15',false,'info','done','2026-09-15','founder',
   'https://drive.example.com/audit/email-2fa.png','2026-Q2','YubiKey 5C primary + 5 NFC backup; passkey on iCloud Keychain'),
  ('Supabase admin (project ref)','supabase_admin','2fa_enrollment','totp_app',true,true,true,false,
   'not_tested',false,null,'2026-05-20',true,'p2','open','2026-07-30','founder',
   null,'2026-Q2','need to upgrade from TOTP to hardware key — Supabase added passkey support'),
  ('GitHub @equipseva-ops','github','phishing_simulation','hardware_key',true,true,true,true,
   'reported',false,null,'2026-04-01',false,'info','done','2026-09-30','founder',
   'https://gophish.example.com/r/abc','2026-Q2','reported phish to security@github via X-PHISH header within 4 min'),
  ('HDFC Bank corporate netbanking','banking','leaked_credential_scan','sms_otp',true,false,true,true,
   'passed',true,'collection-1 (2019)','2026-06-01',false,'p1','in_progress','2026-07-15','founder',
   'https://haveibeenpwned.com/account/founder','2026-Q2','old password in Collection #1 — rotated, still SMS OTP only'),
  ('UPI @okhdfcbank (primary)','upi','recovery_setup','push_app',true,false,false,true,
   'not_tested',false,null,'2026-03-10',false,'p2','open','2026-08-01','founder',
   null,'2026-Q2','no offline recovery codes; UPI PIN known only to founder — risk if device lost'),
  ('Cashfree merchant dashboard','cashfree','session_token_audit','totp_app',true,true,true,true,
   'not_tested',false,null,'2026-05-22',true,'p2','done','2026-07-01','founder',
   null,'2026-Q2','revoked 4 stale sessions (2 mobile, 2 desktop) older than 30 days'),
  ('Razorpay merchant dashboard','razorpay','oauth_grants_review','totp_app',true,true,true,true,
   'not_tested',false,null,'2026-05-22',true,'p3','done','2026-07-01','founder',
   null,'2026-Q2','removed 1 stale OAuth grant (test app from 2024)'),
  ('Google Workspace admin','google_workspace','sso_review','hardware_key',true,true,true,true,
   'passed',false,null,'2026-04-15',false,'info','done','2026-09-15','founder',
   'https://admin.google.com/audit/login','2026-Q2','advanced protection on; only 1 super-admin (founder); recovery via cofounder'),
  ('Apple ID (founder personal)','apple_id','recovery_setup','passkey',true,true,true,true,
   'not_tested',false,null,'2026-02-01',false,'p3','done','2026-08-15','founder',
   null,'2026-Q2','Account Recovery Contact set to cofounder + Recovery Key printed + safe'),
  ('GoDaddy domain registrar (equipseva.com)','domain_registrar','2fa_enrollment','sms_otp',true,false,true,true,
   'not_tested',false,null,'2025-11-10',false,'p1','blocked','2026-07-20','founder',
   null,'2026-Q2','registrar lock + 60-day transfer hold on; SMS OTP only — migrating to Cloudflare Registrar'),
  ('Cloudflare DNS','dns_provider','2fa_enrollment','hardware_key',true,true,true,true,
   'passed',false,null,'2026-05-30',false,'info','done','2026-09-30','founder',
   null,'2026-Q2','API tokens scoped to single zone; hardware key + recovery codes offline'),
  ('Old Yahoo email (used 2010-2018)','email','leaked_credential_scan','none',false,false,false,false,
   'not_tested',true,'Yahoo 2013 (3B accounts)','2018-06-01',false,'p3','accepted_risk','2026-07-30','founder',
   'https://haveibeenpwned.com/account/old','2026-Q2','dormant, no 2FA possible, no recovery — accepted risk, never reused password'),
  ('Phishing sim Q2 — fake DocuSign','email','phishing_simulation','hardware_key',true,true,true,true,
   'passed',false,null,'2026-05-15',false,'info','done','2026-09-30','founder',
   'https://gophish.example.com/r/q2','2026-Q2','founder identified spoofed sender within 12 seconds, reported to IT'),
  ('Founder Mac VPN posture (Tailscale)','cloud_admin','vpn_posture','hardware_key',true,true,true,true,
   'not_tested',false,null,'2026-06-01',true,'info','done','2026-09-30','founder',
   null,'2026-Q2','Tailscale ACLs reviewed, MagicDNS on, exit node only for banking + admin')
) as a(account_label, account_kind, check_kind, twofa_method, twofa_enrolled,
       recovery_codes_offline, backup_email_set, backup_phone_set,
       phishing_test_result, leaked_in_breach, breach_source, last_password_rotation_at,
       vpn_required, finding_severity, remediation_status, remediation_due_at,
       remediation_owner, evidence_url, audit_quarter, notes);

-- ============================================================
-- RPC 1 — device posture rollup by risk tier
-- ============================================================
create or replace function founder_r3121_device_tier_rollup()
returns table(
  risk_tier text,
  device_count bigint,
  avg_risk int,
  fde_pct numeric,
  mdm_pct numeric,
  vpn_pct numeric,
  pm_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select d.risk_tier,
         count(*)::bigint as device_count,
         coalesce(avg(d.risk_score)::int, 0) as avg_risk,
         round(100.0 * sum(case when d.full_disk_encryption then 1 else 0 end) / nullif(count(*), 0), 1) as fde_pct,
         round(100.0 * sum(case when d.mdm_enrolled then 1 else 0 end) / nullif(count(*), 0), 1) as mdm_pct,
         round(100.0 * sum(case when d.vpn_configured then 1 else 0 end) / nullif(count(*), 0), 1) as vpn_pct,
         round(100.0 * sum(case when d.password_manager_installed then 1 else 0 end) / nullif(count(*), 0), 1) as pm_pct
  from founder_cyber_devices_r3121 d
  group by d.risk_tier
  order by case d.risk_tier when 'critical' then 1 when 'high' then 2 when 'medium' then 3 else 4 end;
end;
$$;

revoke execute on function founder_r3121_device_tier_rollup() from public, anon;
grant execute on function founder_r3121_device_tier_rollup() to authenticated;

-- ============================================================
-- RPC 2 — patch + OS family posture
-- ============================================================
create or replace function founder_r3121_patch_posture()
returns table(
  os_family text,
  patch_status text,
  device_count bigint,
  critical_or_high bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select d.os_family, d.patch_status,
         count(*)::bigint as device_count,
         sum(case when d.risk_tier in ('high','critical') then 1 else 0 end)::bigint as critical_or_high
  from founder_cyber_devices_r3121 d
  group by d.os_family, d.patch_status
  order by d.os_family, d.patch_status;
end;
$$;

revoke execute on function founder_r3121_patch_posture() from public, anon;
grant execute on function founder_r3121_patch_posture() to authenticated;

-- ============================================================
-- RPC 3 — 2FA coverage by account kind
-- ============================================================
create or replace function founder_r3121_twofa_coverage()
returns table(
  account_kind text,
  total_accounts bigint,
  twofa_enrolled bigint,
  hardware_key_count bigint,
  sms_only_count bigint,
  coverage_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select a.account_kind,
         count(*)::bigint as total_accounts,
         sum(case when a.twofa_enrolled then 1 else 0 end)::bigint as twofa_enrolled,
         sum(case when a.twofa_method = 'hardware_key' then 1 else 0 end)::bigint as hardware_key_count,
         sum(case when a.twofa_method = 'sms_otp' then 1 else 0 end)::bigint as sms_only_count,
         round(100.0 * sum(case when a.twofa_enrolled then 1 else 0 end) / nullif(count(*), 0), 1) as coverage_pct
  from founder_cyber_account_checks_r3121 a
  group by a.account_kind
  order by coverage_pct nulls last, a.account_kind;
end;
$$;

revoke execute on function founder_r3121_twofa_coverage() from public, anon;
grant execute on function founder_r3121_twofa_coverage() to authenticated;

-- ============================================================
-- RPC 4 — phishing simulation summary
-- ============================================================
create or replace function founder_r3121_phishing_summary()
returns table(
  phishing_test_result text,
  tests bigint,
  most_recent_quarter text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select coalesce(a.phishing_test_result, 'not_tested') as phishing_test_result,
         count(*)::bigint as tests,
         max(a.audit_quarter) as most_recent_quarter
  from founder_cyber_account_checks_r3121 a
  where a.check_kind in ('phishing_simulation','2fa_enrollment','leaked_credential_scan')
  group by coalesce(a.phishing_test_result, 'not_tested')
  order by tests desc;
end;
$$;

revoke execute on function founder_r3121_phishing_summary() from public, anon;
grant execute on function founder_r3121_phishing_summary() to authenticated;

-- ============================================================
-- RPC 5 — leaked credential exposure
-- ============================================================
create or replace function founder_r3121_leaked_credentials()
returns table(
  account_label text,
  account_kind text,
  breach_source text,
  finding_severity text,
  remediation_status text,
  last_password_rotation_at date
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select a.account_label, a.account_kind, a.breach_source,
         a.finding_severity, a.remediation_status, a.last_password_rotation_at
  from founder_cyber_account_checks_r3121 a
  where a.leaked_in_breach
  order by case a.finding_severity when 'p0' then 1 when 'p1' then 2 when 'p2' then 3 when 'p3' then 4 else 5 end,
           a.last_password_rotation_at nulls last;
end;
$$;

revoke execute on function founder_r3121_leaked_credentials() from public, anon;
grant execute on function founder_r3121_leaked_credentials() to authenticated;

-- ============================================================
-- RPC 6 — open remediations + severity
-- ============================================================
create or replace function founder_r3121_open_remediations()
returns table(
  finding_severity text,
  open_count bigint,
  in_progress_count bigint,
  blocked_count bigint,
  earliest_due date
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select a.finding_severity,
         sum(case when a.remediation_status = 'open' then 1 else 0 end)::bigint as open_count,
         sum(case when a.remediation_status = 'in_progress' then 1 else 0 end)::bigint as in_progress_count,
         sum(case when a.remediation_status = 'blocked' then 1 else 0 end)::bigint as blocked_count,
         min(a.remediation_due_at) filter (where a.remediation_status in ('open','in_progress','blocked')) as earliest_due
  from founder_cyber_account_checks_r3121 a
  where a.remediation_status in ('open','in_progress','blocked')
  group by a.finding_severity
  order by case a.finding_severity when 'p0' then 1 when 'p1' then 2 when 'p2' then 3 when 'p3' then 4 else 5 end;
end;
$$;

revoke execute on function founder_r3121_open_remediations() from public, anon;
grant execute on function founder_r3121_open_remediations() to authenticated;

-- ============================================================
-- RPC 7 — backup + recovery readiness
-- ============================================================
create or replace function founder_r3121_backup_recovery_health()
returns table(
  device_label text,
  device_kind text,
  last_backup_at timestamptz,
  days_since_backup numeric,
  recovery_codes_offline_for_account bigint,
  audit_status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select d.device_label, d.device_kind, d.last_backup_at,
         case when d.last_backup_at is null then null
              else round(extract(epoch from (now() - d.last_backup_at)) / 86400.0, 1)
         end as days_since_backup,
         (select count(*) from founder_cyber_account_checks_r3121 a
            where a.device_id = d.id and a.recovery_codes_offline) as recovery_codes_offline_for_account,
         d.audit_status
  from founder_cyber_devices_r3121 d
  order by days_since_backup desc nulls last;
end;
$$;

revoke execute on function founder_r3121_backup_recovery_health() from public, anon;
grant execute on function founder_r3121_backup_recovery_health() to authenticated;

-- ============================================================
-- RPC 8 — quarter executive summary
-- ============================================================
create or replace function founder_r3121_quarter_executive_summary()
returns table(
  audit_quarter text,
  total_checks bigint,
  p0_count bigint,
  p1_count bigint,
  open_or_blocked bigint,
  hardware_key_pct numeric,
  passed_phish_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select a.audit_quarter,
         count(*)::bigint as total_checks,
         sum(case when a.finding_severity = 'p0' then 1 else 0 end)::bigint as p0_count,
         sum(case when a.finding_severity = 'p1' then 1 else 0 end)::bigint as p1_count,
         sum(case when a.remediation_status in ('open','blocked') then 1 else 0 end)::bigint as open_or_blocked,
         round(100.0 * sum(case when a.twofa_method = 'hardware_key' then 1 else 0 end) / nullif(count(*), 0), 1) as hardware_key_pct,
         round(100.0 * sum(case when a.phishing_test_result = 'passed' then 1 else 0 end)
               / nullif(sum(case when a.phishing_test_result is not null then 1 else 0 end), 0), 1) as passed_phish_pct
  from founder_cyber_account_checks_r3121 a
  group by a.audit_quarter
  order by a.audit_quarter desc;
end;
$$;

revoke execute on function founder_r3121_quarter_executive_summary() from public, anon;
grant execute on function founder_r3121_quarter_executive_summary() to authenticated;
