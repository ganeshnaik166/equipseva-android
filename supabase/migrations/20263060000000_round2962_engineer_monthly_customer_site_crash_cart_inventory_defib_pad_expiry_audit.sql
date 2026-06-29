-- Round 2962: Engineer Monthly Customer Site Crash-Cart Inventory & Defib Pad Expiry Audit

create table if not exists crash_cart_audits_r2962 (
  id uuid primary key default gen_random_uuid(),
  hospital_name text not null,
  site_code text not null,
  city text not null,
  engineer_name text not null,
  audit_date date not null,
  cart_location text not null,
  total_items_expected int not null,
  total_items_present int not null,
  missing_items int not null,
  expired_items int not null,
  defib_pad_lot text not null,
  defib_pad_expiry date not null,
  defib_pad_status text not null check (defib_pad_status in ('valid','expiring_soon','expired','replaced')),
  ecg_paper_rolls int not null,
  ambu_bag_present boolean not null,
  o2_cylinder_pressure_psi int not null,
  cart_seal_intact boolean not null,
  overall_grade text not null check (overall_grade in ('A','B','C','D','F')),
  remediation_required boolean not null,
  next_audit_due date not null,
  created_at timestamptz default now()
);

create table if not exists crash_cart_remediation_r2962 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid references crash_cart_audits_r2962(id) on delete cascade,
  item_name text not null,
  issue_type text not null check (issue_type in ('missing','expired','damaged','wrong_lot','seal_broken')),
  severity text not null check (severity in ('p0','p1','p2','p3')),
  replacement_cost_rupees int not null,
  resolved boolean not null,
  resolved_at date,
  resolution_notes text not null,
  created_at timestamptz default now()
);

alter table crash_cart_audits_r2962 enable row level security;
alter table crash_cart_remediation_r2962 enable row level security;

drop policy if exists cca_r2962_sel on crash_cart_audits_r2962;
create policy cca_r2962_sel on crash_cart_audits_r2962 for select using (is_founder());

drop policy if exists ccr_r2962_sel on crash_cart_remediation_r2962;
create policy ccr_r2962_sel on crash_cart_remediation_r2962 for select using (is_founder());

insert into crash_cart_audits_r2962 (hospital_name, site_code, city, engineer_name, audit_date, cart_location, total_items_expected, total_items_present, missing_items, expired_items, defib_pad_lot, defib_pad_expiry, defib_pad_status, ecg_paper_rolls, ambu_bag_present, o2_cylinder_pressure_psi, cart_seal_intact, overall_grade, remediation_required, next_audit_due)
values
('Apollo Hyderabad','APL-HYD-01','Hyderabad','Ravi Kumar','2026-06-01'::date,'ICU-Bay-3',42,42,0,0,'PAD-LOT-A2261','2027-03-15'::date,'valid',8,true,2100,true,'A',false,'2026-07-01'::date),
('Apollo Hyderabad','APL-HYD-01','Hyderabad','Ravi Kumar','2026-05-01'::date,'ICU-Bay-3',42,40,2,1,'PAD-LOT-A2199','2026-06-30'::date,'expiring_soon',6,true,1950,true,'B',true,'2026-06-01'::date),
('KIMS Secunderabad','KIMS-SEC-02','Secunderabad','Priya Menon','2026-06-03'::date,'OT-Recovery',42,38,4,2,'PAD-LOT-B1844','2026-05-01'::date,'expired',5,true,1800,false,'D',true,'2026-06-17'::date),
('Yashoda Somajiguda','YSH-SMG-04','Hyderabad','Arjun Reddy','2026-06-05'::date,'ER-Triage',42,41,1,0,'PAD-LOT-C3012','2027-08-20'::date,'valid',9,true,2200,true,'A',false,'2026-07-05'::date),
('Care Banjara','CARE-BNJ-07','Hyderabad','Sneha Iyer','2026-06-07'::date,'Casualty-Ward',42,36,6,3,'PAD-LOT-D1788','2026-04-10'::date,'expired',4,false,1700,false,'F',true,'2026-06-14'::date),
('Continental Gachibowli','CNT-GCB-09','Hyderabad','Vikram Singh','2026-06-08'::date,'ICU-Floor-2',42,42,0,0,'PAD-LOT-E2904','2027-05-05'::date,'valid',10,true,2150,true,'A',false,'2026-07-08'::date),
('Citizens Nallagandla','CTZ-NLG-11','Hyderabad','Meera Nair','2026-06-10'::date,'CCU',42,39,3,1,'PAD-LOT-F1622','2026-07-15'::date,'expiring_soon',7,true,2000,true,'C',true,'2026-06-24'::date),
('AIG Gachibowli','AIG-GCB-13','Hyderabad','Rohan Das','2026-06-12'::date,'GI-OT-Recovery',42,42,0,0,'PAD-LOT-G3401','2027-11-30'::date,'valid',8,true,2250,true,'A',false,'2026-07-12'::date),
('Sunshine Paradise','SUN-PRD-15','Secunderabad','Anjali Sharma','2026-06-13'::date,'Multi-Specialty-Ward',42,40,2,1,'PAD-LOT-H2018','2026-06-25'::date,'expiring_soon',6,true,1880,true,'B',true,'2026-06-27'::date),
('Medicover Hitec City','MED-HTC-17','Hyderabad','Karthik Rao','2026-06-14'::date,'Step-Down-ICU',42,38,4,2,'PAD-LOT-I1599','2026-05-20'::date,'expired',5,true,1750,false,'D',true,'2026-06-21'::date),
('Star Banjara','STR-BNJ-19','Hyderabad','Divya Pillai','2026-06-15'::date,'Cardio-Lab',42,41,1,0,'PAD-LOT-J2877','2027-06-10'::date,'valid',9,true,2180,true,'A',false,'2026-07-15'::date),
('Olive Trimulgherry','OLV-TRG-21','Secunderabad','Rajesh Verma','2026-06-16'::date,'Pediatric-ICU',42,37,5,2,'PAD-LOT-K1455','2026-05-15'::date,'expired',4,true,1700,false,'F',true,'2026-06-23'::date),
('Renova Sapphire','REN-SPH-23','Hyderabad','Lakshmi Krishnan','2026-06-17'::date,'Tower-A-ICU',42,42,0,0,'PAD-LOT-L3188','2027-09-25'::date,'valid',10,true,2230,true,'A',false,'2026-07-17'::date),
('Virinchi LB Nagar','VRC-LBN-25','Hyderabad','Suresh Babu','2026-06-18'::date,'Neuro-ICU',42,39,3,1,'PAD-LOT-M1977','2026-07-08'::date,'expiring_soon',7,true,1950,true,'C',true,'2026-07-02'::date),
('Aware Gachibowli','AWR-GCB-27','Hyderabad','Pooja Bhatt','2026-06-19'::date,'General-Ward-2',42,40,2,0,'PAD-LOT-N2566','2027-02-14'::date,'valid',8,true,2050,true,'B',false,'2026-07-19'::date),
('Maxcure Madhapur','MXC-MDP-29','Hyderabad','Aditya Hegde','2026-06-20'::date,'ICU-Wing-B',42,36,6,3,'PAD-LOT-O1311','2026-04-25'::date,'expired',3,false,1650,false,'F',true,'2026-06-27'::date),
('SLG Bachupally','SLG-BCP-31','Hyderabad','Neha Joshi','2026-06-21'::date,'Emergency-Bay',42,41,1,0,'PAD-LOT-P2944','2027-07-30'::date,'valid',9,true,2170,true,'A',false,'2026-07-21'::date),
('Sunshine Secunderabad','SUN-SEC-33','Secunderabad','Manish Tiwari','2026-06-22'::date,'Cardiac-OT',42,38,4,2,'PAD-LOT-Q1722','2026-06-15'::date,'expired',5,true,1820,true,'D',true,'2026-06-29'::date),
('Asian Institute','ASN-INS-35','Hyderabad','Kavya Reddy','2026-06-23'::date,'Liver-Transplant-ICU',42,42,0,0,'PAD-LOT-R3055','2027-10-08'::date,'valid',10,true,2240,true,'A',false,'2026-07-23'::date),
('Prime Hospitals','PRM-HSP-37','Hyderabad','Tarun Saxena','2026-06-24'::date,'General-ICU',42,40,2,1,'PAD-LOT-S2188','2026-07-20'::date,'expiring_soon',6,true,1900,true,'B',true,'2026-07-08'::date);

insert into crash_cart_remediation_r2962 (audit_id, item_name, issue_type, severity, replacement_cost_rupees, resolved, resolved_at, resolution_notes)
select id, 'Defib Pads Adult', 'expired', 'p0', 4500, true, '2026-05-10'::date, 'Replaced with lot A2261; old lot returned to supplier' from crash_cart_audits_r2962 where site_code='APL-HYD-01' and audit_date='2026-05-01'::date
union all select id, 'Atropine Vial 1mg', 'missing', 'p1', 250, true, '2026-05-12'::date, 'Restocked from pharmacy' from crash_cart_audits_r2962 where site_code='APL-HYD-01' and audit_date='2026-05-01'::date
union all select id, 'Defib Pads Pediatric', 'expired', 'p0', 5200, false, null, 'Vendor backorder; manual paddles in use temporarily' from crash_cart_audits_r2962 where site_code='KIMS-SEC-02'
union all select id, 'Adrenaline Ampoule', 'missing', 'p0', 180, true, '2026-06-04'::date, 'Restocked next day' from crash_cart_audits_r2962 where site_code='KIMS-SEC-02'
union all select id, 'Crash Cart Seal', 'seal_broken', 'p1', 50, true, '2026-06-04'::date, 'New tamper-evident seal applied' from crash_cart_audits_r2962 where site_code='KIMS-SEC-02'
union all select id, 'Defib Pads Adult', 'expired', 'p0', 4500, false, null, 'Vendor escalation in progress' from crash_cart_audits_r2962 where site_code='CARE-BNJ-07'
union all select id, 'Ambu Bag Adult', 'missing', 'p0', 1800, false, null, 'Purchase order raised; ETA 3 days' from crash_cart_audits_r2962 where site_code='CARE-BNJ-07'
union all select id, 'Suction Catheters', 'missing', 'p2', 400, true, '2026-06-09'::date, 'Restocked from central store' from crash_cart_audits_r2962 where site_code='CARE-BNJ-07'
union all select id, 'Defib Pads Adult', 'expired', 'p2', 4500, false, null, 'Reorder placed; current pads valid 14 more days' from crash_cart_audits_r2962 where site_code='CTZ-NLG-11'
union all select id, 'Lignocaine Vial', 'expired', 'p1', 320, true, '2026-06-11'::date, 'Replaced from pharmacy' from crash_cart_audits_r2962 where site_code='CTZ-NLG-11'
union all select id, 'Defib Pads Adult', 'expired', 'p0', 4500, true, '2026-06-15'::date, 'Replaced; staff retraining scheduled' from crash_cart_audits_r2962 where site_code='MED-HTC-17'
union all select id, 'Endotracheal Tubes', 'missing', 'p1', 600, true, '2026-06-15'::date, 'Set of 3 restocked' from crash_cart_audits_r2962 where site_code='MED-HTC-17'
union all select id, 'Defib Pads Pediatric', 'expired', 'p0', 5200, false, null, 'Vendor backorder; awaiting fresh stock' from crash_cart_audits_r2962 where site_code='OLV-TRG-21'
union all select id, 'Amiodarone Vial', 'expired', 'p1', 850, true, '2026-06-17'::date, 'Replaced from central pharmacy' from crash_cart_audits_r2962 where site_code='OLV-TRG-21'
union all select id, 'Defib Pads Adult', 'expired', 'p2', 4500, true, '2026-06-19'::date, 'Pre-emptive replacement done' from crash_cart_audits_r2962 where site_code='VRC-LBN-25'
union all select id, 'Defib Pads Adult', 'expired', 'p0', 4500, false, null, 'Critical escalation; vendor onsite tomorrow' from crash_cart_audits_r2962 where site_code='MXC-MDP-29'
union all select id, 'Ambu Bag Pediatric', 'missing', 'p0', 2100, false, null, 'PO raised; ETA 2 days' from crash_cart_audits_r2962 where site_code='MXC-MDP-29'
union all select id, 'Laryngoscope Blades', 'damaged', 'p1', 1500, false, null, 'Set sent for sterilization replacement' from crash_cart_audits_r2962 where site_code='MXC-MDP-29'
union all select id, 'Defib Pads Adult', 'expired', 'p0', 4500, true, '2026-06-23'::date, 'Replaced same day; root-cause: missed cycle' from crash_cart_audits_r2962 where site_code='SUN-SEC-33'
union all select id, 'Defib Pads Adult', 'expired', 'p2', 4500, false, null, 'Reorder placed' from crash_cart_audits_r2962 where site_code='PRM-HSP-37';

create or replace function r2962_audit_overview()
returns table(total_audits int, sites_audited int, grade_a_count int, grade_f_count int, expired_pad_sites int, remediation_open int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select
    count(*)::int,
    count(distinct site_code)::int,
    (count(*) filter (where overall_grade='A'))::int,
    (count(*) filter (where overall_grade='F'))::int,
    (count(*) filter (where defib_pad_status='expired'))::int,
    (select count(*) from crash_cart_remediation_r2962 where not resolved)::int
  from crash_cart_audits_r2962;
end; $$;

create or replace function r2962_defib_expiry_watch()
returns table(hospital_name text, site_code text, defib_pad_lot text, defib_pad_expiry date, defib_pad_status text, days_remaining int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select a.hospital_name, a.site_code, a.defib_pad_lot, a.defib_pad_expiry, a.defib_pad_status,
    (a.defib_pad_expiry - current_date)::int
  from crash_cart_audits_r2962 a
  where a.defib_pad_status in ('expired','expiring_soon')
  order by a.defib_pad_expiry asc;
end; $$;

create or replace function r2962_engineer_scorecard()
returns table(engineer_name text, audits_done int, avg_items_present numeric, expired_pads_found int, grade_a_count int, grade_f_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select a.engineer_name,
    count(*)::int,
    round(avg(a.total_items_present)::numeric, 1),
    (count(*) filter (where a.defib_pad_status='expired'))::int,
    (count(*) filter (where a.overall_grade='A'))::int,
    (count(*) filter (where a.overall_grade='F'))::int
  from crash_cart_audits_r2962 a
  group by a.engineer_name
  order by count(*) desc, a.engineer_name;
end; $$;

create or replace function r2962_site_grade_distribution()
returns table(overall_grade text, site_count int, pct_of_total numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
declare total_n int;
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  select count(*) into total_n from crash_cart_audits_r2962;
  return query select a.overall_grade, count(*)::int,
    round((count(*)::numeric / nullif(total_n,0)) * 100, 1)
  from crash_cart_audits_r2962 a
  group by a.overall_grade
  order by a.overall_grade;
end; $$;

create or replace function r2962_remediation_backlog()
returns table(hospital_name text, item_name text, issue_type text, severity text, replacement_cost_rupees int, resolution_notes text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select a.hospital_name, r.item_name, r.issue_type, r.severity, r.replacement_cost_rupees, r.resolution_notes
  from crash_cart_remediation_r2962 r
  join crash_cart_audits_r2962 a on a.id = r.audit_id
  where not r.resolved
  order by case r.severity when 'p0' then 0 when 'p1' then 1 when 'p2' then 2 else 3 end, a.hospital_name;
end; $$;

create or replace function r2962_p0_critical_sites()
returns table(hospital_name text, site_code text, city text, engineer_name text, overall_grade text, expired_items int, missing_items int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select a.hospital_name, a.site_code, a.city, a.engineer_name, a.overall_grade, a.expired_items, a.missing_items
  from crash_cart_audits_r2962 a
  where a.overall_grade in ('D','F') or a.defib_pad_status='expired' or not a.cart_seal_intact
  order by a.overall_grade desc, a.expired_items desc;
end; $$;

create or replace function r2962_remediation_cost_summary()
returns table(issue_type text, open_count int, resolved_count int, total_cost_rupees int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select r.issue_type,
    (count(*) filter (where not r.resolved))::int,
    (count(*) filter (where r.resolved))::int,
    coalesce(sum(r.replacement_cost_rupees),0)::int
  from crash_cart_remediation_r2962 r
  group by r.issue_type
  order by r.issue_type;
end; $$;

revoke all on function r2962_audit_overview() from public, anon;
revoke all on function r2962_defib_expiry_watch() from public, anon;
revoke all on function r2962_engineer_scorecard() from public, anon;
revoke all on function r2962_site_grade_distribution() from public, anon;
revoke all on function r2962_remediation_backlog() from public, anon;
revoke all on function r2962_p0_critical_sites() from public, anon;
revoke all on function r2962_remediation_cost_summary() from public, anon;

grant execute on function r2962_audit_overview() to authenticated;
grant execute on function r2962_defib_expiry_watch() to authenticated;
grant execute on function r2962_engineer_scorecard() to authenticated;
grant execute on function r2962_site_grade_distribution() to authenticated;
grant execute on function r2962_remediation_backlog() to authenticated;
grant execute on function r2962_p0_critical_sites() to authenticated;
grant execute on function r2962_remediation_cost_summary() to authenticated;
