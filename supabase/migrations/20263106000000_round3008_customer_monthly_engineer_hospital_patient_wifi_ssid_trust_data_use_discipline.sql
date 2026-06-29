-- Round r3008: Customer Monthly Engineer Hospital Patient-WiFi-SSID Trust & Data-Use Discipline
-- HEAVY ★★★★

create extension if not exists pgcrypto;

-- ============================================================
-- TABLE 1: WiFi SSID trust registry per hospital
-- ============================================================
create table if not exists patient_wifi_ssid_trust_r3008 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid,
  hospital_name text not null,
  ssid text not null,
  bssid_prefix text,
  trust_tier text not null check (trust_tier in ('verified','provisional','suspicious','blocked')),
  ssid_class text not null check (ssid_class in ('clinical','staff','guest','iot_devices','rogue')),
  encryption_mode text not null check (encryption_mode in ('wpa3_enterprise','wpa2_enterprise','wpa2_psk','open','captive_portal')),
  pii_data_use_policy text not null check (pii_data_use_policy in ('strict_none','aggregate_only','consented_full','blocked')),
  last_audited_on date not null,
  next_audit_due date not null,
  monthly_engineer_visits int not null default 0,
  patient_devices_seen int not null default 0,
  suspicious_event_count int not null default 0,
  discipline_score numeric(5,2) not null check (discipline_score between 0 and 100),
  status_note text,
  created_at timestamptz default now()
);

alter table patient_wifi_ssid_trust_r3008 enable row level security;
drop policy if exists wifi_ssid_trust_r3008_founder_all on patient_wifi_ssid_trust_r3008;
create policy wifi_ssid_trust_r3008_founder_all on patient_wifi_ssid_trust_r3008
  for all using (is_founder()) with check (is_founder());

-- ============================================================
-- TABLE 2: Monthly data-use discipline events from engineer visits
-- ============================================================
create table if not exists engineer_wifi_data_use_events_r3008 (
  id uuid primary key default gen_random_uuid(),
  trust_id uuid references patient_wifi_ssid_trust_r3008(id) on delete cascade,
  hospital_name text not null,
  ssid text not null,
  engineer_name text not null,
  event_month date not null,
  event_kind text not null check (event_kind in ('clean_visit','captive_login','unauthorized_ssid','pii_packet_capture','consent_breach','offline_only','vpn_required','escalated')),
  data_use_class text not null check (data_use_class in ('none','metadata','aggregate','identified','sensitive')),
  patient_pii_flag boolean not null default false,
  bytes_transferred_mb numeric(10,2) not null default 0,
  discipline_impact numeric(5,2) not null check (discipline_impact between -50 and 50),
  resolution_status text not null check (resolution_status in ('resolved','open','pending_review','waived','escalated_to_dpo')),
  occurred_at timestamptz not null default now(),
  notes text,
  created_at timestamptz default now()
);

alter table engineer_wifi_data_use_events_r3008 enable row level security;
drop policy if exists wifi_data_use_events_r3008_founder_all on engineer_wifi_data_use_events_r3008;
create policy wifi_data_use_events_r3008_founder_all on engineer_wifi_data_use_events_r3008
  for all using (is_founder()) with check (is_founder());

-- ============================================================
-- SEEDS: TABLE 1 (16 rows)
-- ============================================================
insert into patient_wifi_ssid_trust_r3008
  (hospital_name, ssid, bssid_prefix, trust_tier, ssid_class, encryption_mode, pii_data_use_policy, last_audited_on, next_audit_due, monthly_engineer_visits, patient_devices_seen, suspicious_event_count, discipline_score, status_note)
values
  ('Apollo Hyderabad','APL-CLIN-A','5C:E0:C5','verified','clinical','wpa3_enterprise','strict_none','2026-06-01'::date,'2026-07-15'::date,18,420,0,98.50,'Gold standard'),
  ('Apollo Hyderabad','APL-GUEST','5C:E0:C5','verified','guest','captive_portal','aggregate_only','2026-06-02'::date,'2026-07-16'::date,4,1240,1,92.10,'Captive portal solid'),
  ('Yashoda Secunderabad','YS-MED-1','A4:2B:8C','verified','clinical','wpa2_enterprise','strict_none','2026-05-28'::date,'2026-07-10'::date,22,380,2,89.40,'Strong'),
  ('Yashoda Secunderabad','YS-IOT','A4:2B:8C','provisional','iot_devices','wpa2_psk','blocked','2026-05-30'::date,'2026-07-05'::date,9,67,3,71.20,'PSK shared key risk'),
  ('KIMS Kondapur','KIMS-STAFF','B8:3A:08','verified','staff','wpa2_enterprise','aggregate_only','2026-06-05'::date,'2026-07-20'::date,15,210,0,94.80,'Solid'),
  ('Care Banjara','CARE-WIFI','D0:17:C2','provisional','clinical','wpa2_enterprise','consented_full','2026-06-08'::date,'2026-07-08'::date,11,295,4,77.50,'Consent flow under review'),
  ('Continental Gachibowli','CONT-MED','7C:8A:E1','verified','clinical','wpa3_enterprise','strict_none','2026-06-10'::date,'2026-07-22'::date,14,340,1,95.30,'Excellent'),
  ('Continental Gachibowli','CONT-GUEST','7C:8A:E1','provisional','guest','captive_portal','aggregate_only','2026-06-10'::date,'2026-07-22'::date,3,890,2,85.10,'Mostly clean'),
  ('Sunshine Paradise','SUNSHINE-OPEN','94:65:9C','suspicious','guest','open','blocked','2026-06-12'::date,'2026-06-30'::date,7,540,8,42.10,'Open SSID — flagged'),
  ('Sunshine Paradise','SUNSHINE-CLIN','94:65:9C','provisional','clinical','wpa2_psk','aggregate_only','2026-06-12'::date,'2026-07-12'::date,12,180,3,68.40,'Migrate to enterprise'),
  ('Star Hospitals','STAR-RADIO','E0:91:F5','verified','clinical','wpa3_enterprise','strict_none','2026-06-15'::date,'2026-07-25'::date,8,150,0,97.20,'Imaging dept clean'),
  ('Medicover','MED-FREE','40:B8:9A','suspicious','rogue','open','blocked','2026-06-14'::date,'2026-06-28'::date,2,72,11,28.50,'Rogue AP suspected'),
  ('Medicover','MED-MAIN','40:B8:9A','verified','clinical','wpa2_enterprise','strict_none','2026-06-14'::date,'2026-07-18'::date,16,310,1,91.60,'Solid baseline'),
  ('AIG Gachibowli','AIG-CLIN','C8:21:58','verified','clinical','wpa3_enterprise','strict_none','2026-06-18'::date,'2026-07-28'::date,13,275,0,96.90,'Gastro dept'),
  ('Rainbow Banjara','RNBW-PED','3A:B5:7E','provisional','clinical','wpa2_enterprise','consented_full','2026-06-19'::date,'2026-07-19'::date,10,225,2,82.40,'Pediatric — consent layered'),
  ('Omega Specialty','OMEGA-OPEN','5E:33:71','blocked','rogue','open','blocked','2026-06-20'::date,'2026-06-25'::date,0,18,15,12.00,'Hard-blocked rogue');

-- ============================================================
-- SEEDS: TABLE 2 (20 rows)
-- ============================================================
insert into engineer_wifi_data_use_events_r3008
  (hospital_name, ssid, engineer_name, event_month, event_kind, data_use_class, patient_pii_flag, bytes_transferred_mb, discipline_impact, resolution_status, occurred_at, notes)
values
  ('Apollo Hyderabad','APL-CLIN-A','Ravi Teja','2026-06-01'::date,'clean_visit','metadata',false,12.40,4.50,'resolved','2026-06-03 09:30:00+05:30'::timestamptz,'Routine BMC check'),
  ('Apollo Hyderabad','APL-GUEST','Suresh M','2026-06-01'::date,'captive_login','none',false,2.10,2.00,'resolved','2026-06-05 11:15:00+05:30'::timestamptz,'Guest captive used'),
  ('Yashoda Secunderabad','YS-MED-1','Anita K','2026-06-01'::date,'clean_visit','metadata',false,8.30,4.00,'resolved','2026-06-04 14:00:00+05:30'::timestamptz,'BP monitor calib'),
  ('Yashoda Secunderabad','YS-IOT','Anita K','2026-06-01'::date,'unauthorized_ssid','aggregate',false,5.60,-12.00,'open','2026-06-06 16:45:00+05:30'::timestamptz,'Engineer joined IoT VLAN'),
  ('KIMS Kondapur','KIMS-STAFF','Vikram R','2026-06-01'::date,'clean_visit','metadata',false,4.20,5.00,'resolved','2026-06-07 10:20:00+05:30'::timestamptz,'No PII'),
  ('Care Banjara','CARE-WIFI','Priya N','2026-06-01'::date,'consent_breach','identified',true,18.70,-25.00,'escalated_to_dpo','2026-06-08 12:30:00+05:30'::timestamptz,'PII observed in pcap'),
  ('Continental Gachibowli','CONT-MED','Karthik S','2026-06-01'::date,'clean_visit','metadata',false,6.10,4.50,'resolved','2026-06-10 08:50:00+05:30'::timestamptz,'Vent service'),
  ('Continental Gachibowli','CONT-GUEST','Karthik S','2026-06-01'::date,'offline_only','none',false,0.00,3.00,'resolved','2026-06-10 13:00:00+05:30'::timestamptz,'Engineer offline'),
  ('Sunshine Paradise','SUNSHINE-OPEN','Bharath G','2026-06-01'::date,'pii_packet_capture','sensitive',true,42.10,-45.00,'escalated_to_dpo','2026-06-12 15:00:00+05:30'::timestamptz,'Open SSID — sensitive data leak risk'),
  ('Sunshine Paradise','SUNSHINE-CLIN','Bharath G','2026-06-01'::date,'vpn_required','metadata',false,3.40,1.50,'resolved','2026-06-12 16:00:00+05:30'::timestamptz,'VPN tunnel used'),
  ('Star Hospitals','STAR-RADIO','Naveen P','2026-06-01'::date,'clean_visit','none',false,1.80,5.00,'resolved','2026-06-15 11:00:00+05:30'::timestamptz,'CT room — air-gapped'),
  ('Medicover','MED-FREE','Rohit V','2026-06-01'::date,'unauthorized_ssid','none',false,0.50,-20.00,'pending_review','2026-06-14 17:30:00+05:30'::timestamptz,'Rogue AP — engineer flagged'),
  ('Medicover','MED-MAIN','Rohit V','2026-06-01'::date,'clean_visit','metadata',false,7.20,4.00,'resolved','2026-06-14 18:00:00+05:30'::timestamptz,'Back on sanctioned AP'),
  ('AIG Gachibowli','AIG-CLIN','Deepa L','2026-06-01'::date,'clean_visit','metadata',false,5.50,5.00,'resolved','2026-06-18 09:15:00+05:30'::timestamptz,'Endoscope'),
  ('Rainbow Banjara','RNBW-PED','Sanjay T','2026-06-01'::date,'captive_login','aggregate',false,9.80,2.00,'resolved','2026-06-19 14:45:00+05:30'::timestamptz,'Consent captured'),
  ('Apollo Hyderabad','APL-CLIN-A','Ravi Teja','2026-05-01'::date,'clean_visit','metadata',false,11.20,4.50,'resolved','2026-05-15 10:00:00+05:30'::timestamptz,'Prior month'),
  ('Omega Specialty','OMEGA-OPEN','Bharath G','2026-06-01'::date,'escalated','sensitive',true,55.30,-50.00,'escalated_to_dpo','2026-06-20 19:00:00+05:30'::timestamptz,'Hard escalation — DPO notified'),
  ('Continental Gachibowli','CONT-MED','Karthik S','2026-05-01'::date,'clean_visit','metadata',false,5.80,4.00,'resolved','2026-05-20 11:30:00+05:30'::timestamptz,'Last month clean'),
  ('Care Banjara','CARE-WIFI','Priya N','2026-05-01'::date,'consent_breach','identified',true,14.20,-18.00,'waived','2026-05-22 13:00:00+05:30'::timestamptz,'Waived — consent later signed'),
  ('Sunshine Paradise','SUNSHINE-CLIN','Bharath G','2026-05-01'::date,'vpn_required','metadata',false,2.90,1.00,'resolved','2026-05-25 15:30:00+05:30'::timestamptz,'VPN enforced');

-- ============================================================
-- RPC 1: Trust roster overview
-- ============================================================
create or replace function founder_r3008_trust_roster()
returns table(
  id uuid,
  hospital_name text,
  ssid text,
  trust_tier text,
  ssid_class text,
  encryption_mode text,
  discipline_score numeric,
  monthly_engineer_visits int,
  suspicious_event_count int
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select t.id, t.hospital_name, t.ssid, t.trust_tier, t.ssid_class,
           t.encryption_mode, t.discipline_score, t.monthly_engineer_visits,
           t.suspicious_event_count
    from patient_wifi_ssid_trust_r3008 t
    order by t.discipline_score asc;
end $$;
revoke all on function founder_r3008_trust_roster() from public, anon;
grant execute on function founder_r3008_trust_roster() to authenticated;

-- ============================================================
-- RPC 2: Trust tier breakdown
-- ============================================================
create or replace function founder_r3008_tier_breakdown()
returns table(
  trust_tier text,
  ssid_count int,
  avg_discipline numeric,
  total_suspicious int,
  total_engineer_visits int
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select t.trust_tier,
           count(*)::int as ssid_count,
           round(avg(t.discipline_score),2) as avg_discipline,
           sum(t.suspicious_event_count)::int as total_suspicious,
           sum(t.monthly_engineer_visits)::int as total_engineer_visits
    from patient_wifi_ssid_trust_r3008 t
    group by t.trust_tier
    order by avg_discipline desc;
end $$;
revoke all on function founder_r3008_tier_breakdown() from public, anon;
grant execute on function founder_r3008_tier_breakdown() to authenticated;

-- ============================================================
-- RPC 3: Encryption mode discipline
-- ============================================================
create or replace function founder_r3008_encryption_discipline()
returns table(
  encryption_mode text,
  ssid_count int,
  verified_count int,
  blocked_count int,
  avg_discipline numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select t.encryption_mode,
           count(*)::int as ssid_count,
           (count(*) filter (where t.trust_tier='verified'))::int as verified_count,
           (count(*) filter (where t.trust_tier='blocked'))::int as blocked_count,
           round(avg(t.discipline_score),2) as avg_discipline
    from patient_wifi_ssid_trust_r3008 t
    group by t.encryption_mode
    order by avg_discipline desc;
end $$;
revoke all on function founder_r3008_encryption_discipline() from public, anon;
grant execute on function founder_r3008_encryption_discipline() to authenticated;

-- ============================================================
-- RPC 4: Recent data-use events
-- ============================================================
create or replace function founder_r3008_recent_events()
returns table(
  id uuid,
  hospital_name text,
  ssid text,
  engineer_name text,
  event_kind text,
  data_use_class text,
  patient_pii_flag boolean,
  bytes_transferred_mb numeric,
  discipline_impact numeric,
  resolution_status text,
  occurred_at timestamptz
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select e.id, e.hospital_name, e.ssid, e.engineer_name, e.event_kind,
           e.data_use_class, e.patient_pii_flag, e.bytes_transferred_mb,
           e.discipline_impact, e.resolution_status, e.occurred_at
    from engineer_wifi_data_use_events_r3008 e
    order by e.occurred_at desc
    limit 25;
end $$;
revoke all on function founder_r3008_recent_events() from public, anon;
grant execute on function founder_r3008_recent_events() to authenticated;

-- ============================================================
-- RPC 5: Monthly discipline trend
-- ============================================================
create or replace function founder_r3008_monthly_trend()
returns table(
  event_month date,
  event_count int,
  pii_event_count int,
  total_bytes_mb numeric,
  avg_discipline_impact numeric,
  escalated_count int
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select e.event_month,
           count(*)::int as event_count,
           (count(*) filter (where e.patient_pii_flag))::int as pii_event_count,
           round(sum(e.bytes_transferred_mb),2) as total_bytes_mb,
           round(avg(e.discipline_impact),2) as avg_discipline_impact,
           (count(*) filter (where e.resolution_status='escalated_to_dpo'))::int as escalated_count
    from engineer_wifi_data_use_events_r3008 e
    group by e.event_month
    order by e.event_month desc;
end $$;
revoke all on function founder_r3008_monthly_trend() from public, anon;
grant execute on function founder_r3008_monthly_trend() to authenticated;

-- ============================================================
-- RPC 6: PII data-use class breakdown
-- ============================================================
create or replace function founder_r3008_pii_class_breakdown()
returns table(
  data_use_class text,
  event_count int,
  pii_flagged int,
  open_count int,
  escalated_count int,
  total_bytes_mb numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select e.data_use_class,
           count(*)::int as event_count,
           (count(*) filter (where e.patient_pii_flag))::int as pii_flagged,
           (count(*) filter (where e.resolution_status='open'))::int as open_count,
           (count(*) filter (where e.resolution_status='escalated_to_dpo'))::int as escalated_count,
           round(sum(e.bytes_transferred_mb),2) as total_bytes_mb
    from engineer_wifi_data_use_events_r3008 e
    group by e.data_use_class
    order by total_bytes_mb desc;
end $$;
revoke all on function founder_r3008_pii_class_breakdown() from public, anon;
grant execute on function founder_r3008_pii_class_breakdown() to authenticated;

-- ============================================================
-- RPC 7: Engineer leaderboard
-- ============================================================
create or replace function founder_r3008_engineer_leaderboard()
returns table(
  engineer_name text,
  total_events int,
  clean_visits int,
  pii_incidents int,
  net_discipline numeric,
  escalations int
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select e.engineer_name,
           count(*)::int as total_events,
           (count(*) filter (where e.event_kind='clean_visit'))::int as clean_visits,
           (count(*) filter (where e.patient_pii_flag))::int as pii_incidents,
           round(sum(e.discipline_impact),2) as net_discipline,
           (count(*) filter (where e.resolution_status='escalated_to_dpo'))::int as escalations
    from engineer_wifi_data_use_events_r3008 e
    group by e.engineer_name
    order by net_discipline desc;
end $$;
revoke all on function founder_r3008_engineer_leaderboard() from public, anon;
grant execute on function founder_r3008_engineer_leaderboard() to authenticated;

-- ============================================================
-- RPC 8: Hospital trust score (aggregate of SSIDs per hospital)
-- ============================================================
create or replace function founder_r3008_hospital_trust_score()
returns table(
  hospital_name text,
  ssid_count int,
  avg_discipline numeric,
  blocked_or_suspicious int,
  total_visits int,
  total_devices int
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select t.hospital_name,
           count(*)::int as ssid_count,
           round(avg(t.discipline_score),2) as avg_discipline,
           (count(*) filter (where t.trust_tier in ('suspicious','blocked')))::int as blocked_or_suspicious,
           sum(t.monthly_engineer_visits)::int as total_visits,
           sum(t.patient_devices_seen)::int as total_devices
    from patient_wifi_ssid_trust_r3008 t
    group by t.hospital_name
    order by avg_discipline desc;
end $$;
revoke all on function founder_r3008_hospital_trust_score() from public, anon;
grant execute on function founder_r3008_hospital_trust_score() to authenticated;
