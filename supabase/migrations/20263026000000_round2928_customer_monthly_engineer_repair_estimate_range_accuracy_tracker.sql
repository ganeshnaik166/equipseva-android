-- Round 2928 — Customer Monthly Engineer Repair Estimate-Range Accuracy Tracker
-- 1500 +50-MAJORS MILESTONE · HEAVY ★★★★

create table if not exists customer_monthly_engineer_estimate_range_r2928 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  cycle_month date not null,
  customer_org_label text not null,
  engineer_label text not null,
  engineer_tier text not null check (engineer_tier in ('bronze','silver','gold','platinum')),
  estimate_low_rupees int not null,
  estimate_high_rupees int not null,
  actual_billed_rupees int not null,
  job_kind text not null check (job_kind in ('repair','maintenance')),
  within_range boolean not null,
  delta_pct numeric(6,2) not null,
  notes text
);

create table if not exists customer_monthly_estimate_accuracy_alerts_r2928 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  cycle_month date not null,
  engineer_label text not null,
  alert_kind text not null check (alert_kind in ('chronic_underestimate','chronic_overestimate','single_blowout','recovered')),
  severity text not null check (severity in ('p0','p1','p2','p3')),
  estimates_count int not null,
  breach_count int not null,
  median_delta_pct numeric(6,2) not null,
  action_taken text,
  resolved boolean not null default false
);

alter table customer_monthly_engineer_estimate_range_r2928 enable row level security;
alter table customer_monthly_estimate_accuracy_alerts_r2928 enable row level security;

drop policy if exists r2928_estimate_founder_read on customer_monthly_engineer_estimate_range_r2928;
create policy r2928_estimate_founder_read on customer_monthly_engineer_estimate_range_r2928
  for select to authenticated using (is_founder());

drop policy if exists r2928_alerts_founder_read on customer_monthly_estimate_accuracy_alerts_r2928;
create policy r2928_alerts_founder_read on customer_monthly_estimate_accuracy_alerts_r2928
  for select to authenticated using (is_founder());

insert into customer_monthly_engineer_estimate_range_r2928
  (cycle_month, customer_org_label, engineer_label, engineer_tier, estimate_low_rupees, estimate_high_rupees, actual_billed_rupees, job_kind, within_range, delta_pct, notes)
values
  ('2026-06-01'::date, 'Apollo Jubilee', 'ENG-1041 Ravi', 'gold', 3500, 5500, 4800, 'repair', true, 0.00, 'O2 concentrator valve replace'),
  ('2026-06-01'::date, 'KIMS Secunderabad', 'ENG-1052 Anita', 'platinum', 8000, 12000, 11200, 'repair', true, 0.00, 'ventilator board swap'),
  ('2026-06-01'::date, 'Yashoda Hitec City', 'ENG-1063 Kiran', 'silver', 1500, 2500, 3600, 'repair', false, 44.00, 'autoclave heater + sensor (over)'),
  ('2026-06-01'::date, 'Continental Gachibowli', 'ENG-1074 Meera', 'gold', 6000, 9000, 7800, 'maintenance', true, 0.00, 'CT cooling loop'),
  ('2026-06-01'::date, 'Care Banjara', 'ENG-1085 Vikram', 'bronze', 2000, 3500, 5400, 'repair', false, 54.29, 'ECG cable rework (under-est)'),
  ('2026-06-01'::date, 'Sunshine Paradise', 'ENG-1096 Deepa', 'silver', 4000, 6000, 4900, 'repair', true, 0.00, 'ultrasound probe'),
  ('2026-06-01'::date, 'Olive Madhapur', 'ENG-1107 Sandeep', 'gold', 9000, 13000, 14800, 'repair', false, 13.85, 'dialysis pump (over)'),
  ('2026-06-01'::date, 'Rainbow Hyderguda', 'ENG-1118 Pooja', 'platinum', 5500, 8000, 7100, 'maintenance', true, 0.00, 'MRI chiller quarterly'),
  ('2026-06-01'::date, 'Asian Inst Gastro', 'ENG-1129 Naveen', 'gold', 7000, 10000, 9400, 'repair', true, 0.00, 'endoscope light source'),
  ('2026-06-01'::date, 'Star Banjara', 'ENG-1041 Ravi', 'gold', 3000, 5000, 4400, 'repair', true, 0.00, 'pulse-ox board'),
  ('2026-06-01'::date, 'Apollo Jubilee', 'ENG-1052 Anita', 'platinum', 10000, 14000, 13700, 'repair', true, 0.00, 'anesthesia workstation'),
  ('2026-06-01'::date, 'KIMS Secunderabad', 'ENG-1063 Kiran', 'silver', 2500, 4000, 6200, 'repair', false, 55.00, 'syringe pump x3 (under)'),
  ('2026-06-01'::date, 'Yashoda Hitec City', 'ENG-1074 Meera', 'gold', 5000, 7500, 6900, 'maintenance', true, 0.00, 'cath-lab calibration'),
  ('2026-06-01'::date, 'Continental Gachibowli', 'ENG-1085 Vikram', 'bronze', 1200, 2200, 2000, 'repair', true, 0.00, 'BP monitor cuff'),
  ('2026-06-01'::date, 'Care Banjara', 'ENG-1096 Deepa', 'silver', 3500, 5500, 8900, 'repair', false, 61.82, 'infant warmer (under est)'),
  ('2026-06-01'::date, 'Sunshine Paradise', 'ENG-1107 Sandeep', 'gold', 6500, 9500, 8400, 'repair', true, 0.00, 'X-ray generator capacitor'),
  ('2026-06-01'::date, 'Olive Madhapur', 'ENG-1118 Pooja', 'platinum', 11000, 15000, 14600, 'repair', true, 0.00, 'PET-CT detector reseat'),
  ('2026-06-01'::date, 'Rainbow Hyderguda', 'ENG-1129 Naveen', 'gold', 4500, 6500, 7400, 'repair', false, 13.85, 'phototherapy LED bank'),
  ('2026-06-01'::date, 'Asian Inst Gastro', 'ENG-1041 Ravi', 'gold', 3800, 5800, 5200, 'repair', true, 0.00, 'biopsy forceps line'),
  ('2026-06-01'::date, 'Star Banjara', 'ENG-1052 Anita', 'platinum', 9500, 13500, 13100, 'repair', true, 0.00, 'CR plate reader board'),
  ('2026-06-01'::date, 'Apollo Jubilee', 'ENG-1063 Kiran', 'silver', 2000, 3500, 5800, 'repair', false, 65.71, 'suction unit (chronic under)'),
  ('2026-06-01'::date, 'KIMS Secunderabad', 'ENG-1074 Meera', 'gold', 7500, 10500, 9800, 'maintenance', true, 0.00, 'MRI helium top-up'),
  ('2026-06-01'::date, 'Yashoda Hitec City', 'ENG-1085 Vikram', 'bronze', 1800, 3000, 2700, 'repair', true, 0.00, 'nebulizer compressor'),
  ('2026-06-01'::date, 'Continental Gachibowli', 'ENG-1096 Deepa', 'silver', 4200, 6200, 5400, 'repair', true, 0.00, 'patient monitor port');

insert into customer_monthly_estimate_accuracy_alerts_r2928
  (cycle_month, engineer_label, alert_kind, severity, estimates_count, breach_count, median_delta_pct, action_taken, resolved)
values
  ('2026-06-01'::date, 'ENG-1063 Kiran', 'chronic_underestimate', 'p1', 12, 7, 58.50, 'tier review queued', false),
  ('2026-06-01'::date, 'ENG-1085 Vikram', 'chronic_underestimate', 'p2', 9, 4, 41.20, 'pair-shadow with ENG-1052', false),
  ('2026-06-01'::date, 'ENG-1107 Sandeep', 'single_blowout', 'p3', 11, 1, 13.85, 'reviewed; one-off', true),
  ('2026-06-01'::date, 'ENG-1096 Deepa', 'chronic_underestimate', 'p1', 10, 5, 52.40, 'estimate template retrain', false),
  ('2026-06-01'::date, 'ENG-1129 Naveen', 'single_blowout', 'p3', 10, 1, 13.85, null, false),
  ('2026-06-01'::date, 'ENG-1041 Ravi', 'recovered', 'p3', 14, 0, 0.00, 'no breaches', true),
  ('2026-06-01'::date, 'ENG-1052 Anita', 'recovered', 'p3', 13, 0, 0.00, 'platinum baseline holds', true),
  ('2026-06-01'::date, 'ENG-1074 Meera', 'recovered', 'p3', 12, 0, 0.00, null, true),
  ('2026-06-01'::date, 'ENG-1118 Pooja', 'recovered', 'p3', 11, 0, 0.00, null, true),
  ('2026-06-01'::date, 'ENG-1063 Kiran', 'chronic_overestimate', 'p2', 12, 3, -22.10, 'review pricing sheet', false),
  ('2026-06-01'::date, 'ENG-1085 Vikram', 'single_blowout', 'p2', 9, 2, 48.00, 'mentor assigned', false),
  ('2026-06-01'::date, 'ENG-1096 Deepa', 'single_blowout', 'p1', 10, 1, 61.82, 'apology + credit issued', false);

-- RPC 1
create or replace function rpc_r2928_recent_estimates()
returns setof customer_monthly_engineer_estimate_range_r2928
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query select * from customer_monthly_engineer_estimate_range_r2928 order by created_at desc limit 50;
end $$;

-- RPC 2
create or replace function rpc_r2928_breach_summary()
returns table(engineer_label text, total_jobs int, breaches int, breach_pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
    select e.engineer_label,
           count(*)::int as total_jobs,
           sum(case when not e.within_range then 1 else 0 end)::int as breaches,
           round(100.0 * sum(case when not e.within_range then 1 else 0 end)::numeric / nullif(count(*),0), 2) as breach_pct
    from customer_monthly_engineer_estimate_range_r2928 e
    group by e.engineer_label
    order by breach_pct desc nulls last;
end $$;

-- RPC 3
create or replace function rpc_r2928_tier_accuracy()
returns table(engineer_tier text, jobs int, within int, accuracy_pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
    select e.engineer_tier,
           count(*)::int,
           sum(case when e.within_range then 1 else 0 end)::int,
           round(100.0 * sum(case when e.within_range then 1 else 0 end)::numeric / nullif(count(*),0), 2)
    from customer_monthly_engineer_estimate_range_r2928 e
    group by e.engineer_tier
    order by accuracy_pct desc nulls last;
end $$;

-- RPC 4
create or replace function rpc_r2928_open_alerts()
returns setof customer_monthly_estimate_accuracy_alerts_r2928
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query select * from customer_monthly_estimate_accuracy_alerts_r2928 where not resolved order by severity, created_at desc;
end $$;

-- RPC 5
create or replace function rpc_r2928_top_underestimators()
returns table(engineer_label text, under_count int, median_delta numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
    select e.engineer_label,
           (count(*) filter (where e.actual_billed_rupees > e.estimate_high_rupees))::int,
           round(percentile_cont(0.5) within group (order by e.delta_pct) filter (where e.actual_billed_rupees > e.estimate_high_rupees), 2)
    from customer_monthly_engineer_estimate_range_r2928 e
    group by e.engineer_label
    having count(*) filter (where e.actual_billed_rupees > e.estimate_high_rupees) > 0
    order by 2 desc;
end $$;

-- RPC 6
create or replace function rpc_r2928_customer_pain()
returns table(customer_org_label text, jobs int, breaches int, breach_pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
    select e.customer_org_label,
           count(*)::int,
           sum(case when not e.within_range then 1 else 0 end)::int,
           round(100.0 * sum(case when not e.within_range then 1 else 0 end)::numeric / nullif(count(*),0), 2)
    from customer_monthly_engineer_estimate_range_r2928 e
    group by e.customer_org_label
    order by breach_pct desc nulls last;
end $$;

-- RPC 7
create or replace function rpc_r2928_kpis()
returns table(total_jobs int, within_range_pct numeric, median_delta numeric, open_alerts int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
    select (select count(*)::int from customer_monthly_engineer_estimate_range_r2928),
           (select round(100.0 * sum(case when within_range then 1 else 0 end)::numeric / nullif(count(*),0), 2) from customer_monthly_engineer_estimate_range_r2928),
           (select round(percentile_cont(0.5) within group (order by delta_pct), 2) from customer_monthly_engineer_estimate_range_r2928 where not within_range),
           (select count(*)::int from customer_monthly_estimate_accuracy_alerts_r2928 where not resolved);
end $$;

revoke execute on function rpc_r2928_recent_estimates() from public, anon;
revoke execute on function rpc_r2928_breach_summary() from public, anon;
revoke execute on function rpc_r2928_tier_accuracy() from public, anon;
revoke execute on function rpc_r2928_open_alerts() from public, anon;
revoke execute on function rpc_r2928_top_underestimators() from public, anon;
revoke execute on function rpc_r2928_customer_pain() from public, anon;
revoke execute on function rpc_r2928_kpis() from public, anon;

grant execute on function rpc_r2928_recent_estimates() to authenticated;
grant execute on function rpc_r2928_breach_summary() to authenticated;
grant execute on function rpc_r2928_tier_accuracy() to authenticated;
grant execute on function rpc_r2928_open_alerts() to authenticated;
grant execute on function rpc_r2928_top_underestimators() to authenticated;
grant execute on function rpc_r2928_customer_pain() to authenticated;
grant execute on function rpc_r2928_kpis() to authenticated;
