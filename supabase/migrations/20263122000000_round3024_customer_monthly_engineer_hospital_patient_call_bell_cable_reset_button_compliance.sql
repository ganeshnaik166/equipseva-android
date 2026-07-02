-- Round 3024: Customer Monthly Engineer Hospital Patient-Call-Bell Cable & Reset-Button Compliance
-- HEAVY ★★★★ · Batch 430 milestone

create table if not exists public.call_bell_cable_checks_r3024 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid,
  ward_code text not null,
  bed_number text not null,
  cable_serial text not null,
  cable_length_cm int not null check (cable_length_cm between 50 and 600),
  insulation_status text not null check (insulation_status in ('intact','minor_wear','cracked','exposed_wire')),
  connector_status text not null check (connector_status in ('ok','loose','corroded','broken')),
  reset_button_status text not null check (reset_button_status in ('responsive','sticky','jammed','missing')),
  reset_response_ms int check (reset_response_ms between 0 and 5000),
  engineer_user_id uuid,
  checked_at timestamptz not null,
  pass boolean not null,
  patient_safety_risk text not null check (patient_safety_risk in ('none','low','medium','high','critical')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.call_bell_monthly_summary_r3024 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid,
  hospital_name text not null,
  month_start date not null,
  beds_audited int not null check (beds_audited >= 0),
  beds_passed int not null check (beds_passed >= 0),
  cables_replaced int not null check (cables_replaced >= 0),
  reset_buttons_replaced int not null check (reset_buttons_replaced >= 0),
  critical_findings int not null check (critical_findings >= 0),
  compliance_pct numeric(5,2) not null check (compliance_pct between 0 and 100),
  nabh_grade text not null check (nabh_grade in ('A','B','C','D','F')),
  engineer_user_id uuid,
  signed_off_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.call_bell_cable_checks_r3024 enable row level security;
alter table public.call_bell_monthly_summary_r3024 enable row level security;

drop policy if exists cbc_r3024_founder_all on public.call_bell_cable_checks_r3024;
create policy cbc_r3024_founder_all on public.call_bell_cable_checks_r3024 for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists cbms_r3024_founder_all on public.call_bell_monthly_summary_r3024;
create policy cbms_r3024_founder_all on public.call_bell_monthly_summary_r3024 for all to authenticated using (is_founder()) with check (is_founder());

-- Seeds: call_bell_cable_checks_r3024 (20 rows)
insert into public.call_bell_cable_checks_r3024 (ward_code, bed_number, cable_serial, cable_length_cm, insulation_status, connector_status, reset_button_status, reset_response_ms, checked_at, pass, patient_safety_risk, notes) values
('ICU-A','B-101','CBL-A1001',180,'intact','ok','responsive',120,(now() - interval '28 days')::timestamptz,true,'none','clean'),
('ICU-A','B-102','CBL-A1002',180,'minor_wear','ok','responsive',150,(now() - interval '27 days')::timestamptz,true,'low','wear noted'),
('ICU-A','B-103','CBL-A1003',180,'cracked','loose','sticky',900,(now() - interval '26 days')::timestamptz,false,'high','schedule replace'),
('ICU-B','B-201','CBL-B2001',220,'intact','ok','responsive',110,(now() - interval '25 days')::timestamptz,true,'none','ok'),
('ICU-B','B-202','CBL-B2002',220,'exposed_wire','corroded','jammed',null,(now() - interval '24 days')::timestamptz,false,'critical','immediate replace'),
('ICU-B','B-203','CBL-B2003',220,'intact','ok','responsive',95,(now() - interval '23 days')::timestamptz,true,'none','ok'),
('WARD-3','B-301','CBL-W3001',150,'minor_wear','ok','responsive',180,(now() - interval '22 days')::timestamptz,true,'low','ok'),
('WARD-3','B-302','CBL-W3002',150,'intact','ok','sticky',420,(now() - interval '21 days')::timestamptz,false,'medium','button replace'),
('WARD-3','B-303','CBL-W3003',150,'intact','ok','responsive',130,(now() - interval '20 days')::timestamptz,true,'none','ok'),
('WARD-4','B-401','CBL-W4001',200,'cracked','ok','responsive',160,(now() - interval '19 days')::timestamptz,false,'high','cable replace'),
('WARD-4','B-402','CBL-W4002',200,'intact','ok','responsive',140,(now() - interval '18 days')::timestamptz,true,'none','ok'),
('WARD-4','B-403','CBL-W4003',200,'intact','loose','responsive',170,(now() - interval '17 days')::timestamptz,false,'medium','reseat connector'),
('PEDIA-1','B-501','CBL-P5001',160,'intact','ok','responsive',105,(now() - interval '16 days')::timestamptz,true,'none','ok'),
('PEDIA-1','B-502','CBL-P5002',160,'minor_wear','ok','responsive',155,(now() - interval '15 days')::timestamptz,true,'low','ok'),
('PEDIA-1','B-503','CBL-P5003',160,'exposed_wire','broken','missing',null,(now() - interval '14 days')::timestamptz,false,'critical','urgent'),
('ER-1','B-601','CBL-E6001',250,'intact','ok','responsive',88,(now() - interval '13 days')::timestamptz,true,'none','ok'),
('ER-1','B-602','CBL-E6002',250,'intact','ok','responsive',115,(now() - interval '12 days')::timestamptz,true,'none','ok'),
('ER-1','B-603','CBL-E6003',250,'cracked','corroded','jammed',null,(now() - interval '11 days')::timestamptz,false,'critical','urgent replace'),
('ONC-2','B-701','CBL-O7001',190,'intact','ok','responsive',135,(now() - interval '10 days')::timestamptz,true,'none','ok'),
('ONC-2','B-702','CBL-O7002',190,'minor_wear','loose','sticky',380,(now() - interval '9 days')::timestamptz,false,'medium','tune up');

-- Seeds: call_bell_monthly_summary_r3024 (15 rows)
insert into public.call_bell_monthly_summary_r3024 (hospital_name, month_start, beds_audited, beds_passed, cables_replaced, reset_buttons_replaced, critical_findings, compliance_pct, nabh_grade, signed_off_at) values
('Apollo Jubilee Hills',(date_trunc('month', now()) - interval '1 month')::date, 220, 198, 14, 9, 2, 90.00, 'A',(now() - interval '20 days')::timestamptz),
('KIMS Secunderabad',(date_trunc('month', now()) - interval '1 month')::date, 180, 156, 18, 11, 3, 86.67, 'B',(now() - interval '19 days')::timestamptz),
('Yashoda Somajiguda',(date_trunc('month', now()) - interval '1 month')::date, 160, 149, 8, 6, 1, 93.13, 'A',(now() - interval '18 days')::timestamptz),
('Continental Gachibowli',(date_trunc('month', now()) - interval '1 month')::date, 140, 110, 22, 15, 5, 78.57, 'C',(now() - interval '17 days')::timestamptz),
('AIG Hospitals',(date_trunc('month', now()) - interval '1 month')::date, 200, 188, 9, 7, 1, 94.00, 'A',(now() - interval '16 days')::timestamptz),
('Care Banjara',(date_trunc('month', now()) - interval '1 month')::date, 130, 112, 12, 9, 2, 86.15, 'B',(now() - interval '15 days')::timestamptz),
('Sunshine Begumpet',(date_trunc('month', now()) - interval '1 month')::date, 110, 88, 16, 13, 4, 80.00, 'C',(now() - interval '14 days')::timestamptz),
('Rainbow Hyderguda',(date_trunc('month', now()) - interval '1 month')::date, 95, 92, 4, 3, 0, 96.84, 'A',(now() - interval '13 days')::timestamptz),
('Star Banjara',(date_trunc('month', now()) - interval '1 month')::date, 120, 95, 18, 14, 3, 79.17, 'C',(now() - interval '12 days')::timestamptz),
('Citizens Nallagandla',(date_trunc('month', now()) - interval '1 month')::date, 105, 98, 6, 5, 1, 93.33, 'A',(now() - interval '11 days')::timestamptz),
('Olive Madhapur',(date_trunc('month', now()) - interval '1 month')::date, 80, 60, 14, 10, 4, 75.00, 'D',(now() - interval '10 days')::timestamptz),
('MaxCure Madhapur',(date_trunc('month', now()) - interval '1 month')::date, 115, 100, 11, 8, 2, 86.96, 'B',(now() - interval '9 days')::timestamptz),
('Virinchi Hospitals',(date_trunc('month', now()) - interval '1 month')::date, 90, 78, 9, 7, 2, 86.67, 'B',(now() - interval '8 days')::timestamptz),
('Image Hospitals',(date_trunc('month', now()) - interval '1 month')::date, 70, 50, 13, 11, 5, 71.43, 'F',(now() - interval '7 days')::timestamptz),
('Renova Soni Soga',(date_trunc('month', now()) - interval '1 month')::date, 85, 80, 5, 4, 1, 94.12, 'A',(now() - interval '6 days')::timestamptz);

revoke all on public.call_bell_cable_checks_r3024 from public, anon;
revoke all on public.call_bell_monthly_summary_r3024 from public, anon;
grant select, insert, update, delete on public.call_bell_cable_checks_r3024 to authenticated;
grant select, insert, update, delete on public.call_bell_monthly_summary_r3024 to authenticated;

-- RPC 1: overview KPIs
create or replace function public.cbc_r3024_overview()
returns table(total_checks int, total_pass int, pass_rate_pct numeric, critical_count int, hospitals_audited int, beds_audited int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
    select
      (select count(*)::int from public.call_bell_cable_checks_r3024),
      (select (count(*) filter (where pass))::int from public.call_bell_cable_checks_r3024),
      (select round((count(*) filter (where pass))::numeric * 100 / nullif(count(*),0), 2) from public.call_bell_cable_checks_r3024),
      (select (count(*) filter (where patient_safety_risk = 'critical'))::int from public.call_bell_cable_checks_r3024),
      (select count(distinct hospital_name)::int from public.call_bell_monthly_summary_r3024),
      (select coalesce(sum(beds_audited),0)::int from public.call_bell_monthly_summary_r3024);
end;$$;

-- RPC 2: failures by ward
create or replace function public.cbc_r3024_failures_by_ward()
returns table(ward_code text, checks int, failures int, critical int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
    select c.ward_code,
      count(*)::int,
      (count(*) filter (where not c.pass))::int,
      (count(*) filter (where c.patient_safety_risk = 'critical'))::int
    from public.call_bell_cable_checks_r3024 c
    group by c.ward_code
    order by (count(*) filter (where not c.pass))::int desc;
end;$$;

-- RPC 3: reset button issues
create or replace function public.cbc_r3024_reset_button_issues()
returns table(reset_button_status text, occurrences int, avg_response_ms numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
    select c.reset_button_status,
      count(*)::int,
      round(avg(c.reset_response_ms)::numeric, 1)
    from public.call_bell_cable_checks_r3024 c
    group by c.reset_button_status
    order by count(*) desc;
end;$$;

-- RPC 4: cable insulation breakdown
create or replace function public.cbc_r3024_insulation_breakdown()
returns table(insulation_status text, occurrences int, fail_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
    select c.insulation_status,
      count(*)::int,
      (count(*) filter (where not c.pass))::int
    from public.call_bell_cable_checks_r3024 c
    group by c.insulation_status
    order by count(*) desc;
end;$$;

-- RPC 5: monthly hospital ranking
create or replace function public.cbc_r3024_monthly_ranking()
returns table(hospital_name text, beds_audited int, compliance_pct numeric, nabh_grade text, critical_findings int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
    select m.hospital_name, m.beds_audited, m.compliance_pct, m.nabh_grade, m.critical_findings
    from public.call_bell_monthly_summary_r3024 m
    order by m.compliance_pct desc;
end;$$;

-- RPC 6: critical findings detail
create or replace function public.cbc_r3024_critical_findings()
returns table(ward_code text, bed_number text, cable_serial text, insulation_status text, connector_status text, reset_button_status text, checked_at timestamptz, notes text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
    select c.ward_code, c.bed_number, c.cable_serial, c.insulation_status, c.connector_status, c.reset_button_status, c.checked_at, c.notes
    from public.call_bell_cable_checks_r3024 c
    where c.patient_safety_risk in ('high','critical')
    order by c.checked_at desc;
end;$$;

-- RPC 7: replacements totals across hospitals
create or replace function public.cbc_r3024_replacements_totals()
returns table(total_cables_replaced int, total_buttons_replaced int, hospitals int, avg_compliance_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
    select coalesce(sum(m.cables_replaced),0)::int,
           coalesce(sum(m.reset_buttons_replaced),0)::int,
           count(*)::int,
           round(avg(m.compliance_pct)::numeric, 2)
    from public.call_bell_monthly_summary_r3024 m;
end;$$;

revoke all on function public.cbc_r3024_overview() from public, anon;
revoke all on function public.cbc_r3024_failures_by_ward() from public, anon;
revoke all on function public.cbc_r3024_reset_button_issues() from public, anon;
revoke all on function public.cbc_r3024_insulation_breakdown() from public, anon;
revoke all on function public.cbc_r3024_monthly_ranking() from public, anon;
revoke all on function public.cbc_r3024_critical_findings() from public, anon;
revoke all on function public.cbc_r3024_replacements_totals() from public, anon;
grant execute on function public.cbc_r3024_overview() to authenticated;
grant execute on function public.cbc_r3024_failures_by_ward() to authenticated;
grant execute on function public.cbc_r3024_reset_button_issues() to authenticated;
grant execute on function public.cbc_r3024_insulation_breakdown() to authenticated;
grant execute on function public.cbc_r3024_monthly_ranking() to authenticated;
grant execute on function public.cbc_r3024_critical_findings() to authenticated;
grant execute on function public.cbc_r3024_replacements_totals() to authenticated;
