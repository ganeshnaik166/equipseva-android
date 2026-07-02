-- Round 2897 — Founder Weekly Cash Conversion Cycle Drilldown
-- HEAVY ★★★★ founder ops · CEO-grade weekly cash cycle readout

create table if not exists weekly_ccc_snapshots_r2897 (
  id uuid primary key default gen_random_uuid(),
  week_start date not null,
  week_label text not null,
  dso_days numeric(6,2) not null,
  dpo_days numeric(6,2) not null,
  dio_days numeric(6,2) not null,
  ccc_days numeric(6,2) not null,
  revenue_rupees bigint not null,
  cash_inflow_rupees bigint not null,
  cash_outflow_rupees bigint not null,
  net_cash_rupees bigint not null,
  collection_efficiency_pct numeric(5,2) not null,
  notes text,
  created_at timestamptz not null default now()
);
alter table weekly_ccc_snapshots_r2897 enable row level security;

create table if not exists ccc_leak_events_r2897 (
  id uuid primary key default gen_random_uuid(),
  week_start date not null,
  leak_category text not null,
  customer_segment text not null,
  invoice_ref text,
  delay_days int not null,
  amount_at_risk_rupees bigint not null,
  root_cause text not null,
  remediation_owner text not null,
  status text not null check (status in ('open','escalated','recovered','written_off')),
  recovered_rupees bigint not null default 0,
  created_at timestamptz not null default now()
);
alter table ccc_leak_events_r2897 enable row level security;

insert into weekly_ccc_snapshots_r2897 (week_start, week_label, dso_days, dpo_days, dio_days, ccc_days, revenue_rupees, cash_inflow_rupees, cash_outflow_rupees, net_cash_rupees, collection_efficiency_pct, notes) values
('2026-04-06','W15 Apr 6',58.40,22.10,14.50,50.80,1840000,1210000,980000,230000,71.20,'Pre-quarter-end push baseline'),
('2026-04-13','W16 Apr 13',56.80,21.50,14.20,49.50,1920000,1340000,1010000,330000,73.40,'Hospital chain Q1 settle wave'),
('2026-04-20','W17 Apr 20',54.30,23.80,13.90,44.40,2050000,1520000,1080000,440000,76.10,'AMC renewal cohort lands'),
('2026-04-27','W18 Apr 27',52.70,24.50,13.40,41.60,2180000,1680000,1140000,540000,78.80,'NEFT batch improvements'),
('2026-05-04','W19 May 4',55.20,23.10,13.80,45.90,2090000,1560000,1170000,390000,75.30,'Two enterprise contracts slipped'),
('2026-05-11','W20 May 11',53.10,24.20,13.20,42.10,2240000,1740000,1190000,550000,77.90,'Founder escalation wave 1'),
('2026-05-18','W21 May 18',51.40,25.30,12.80,38.90,2380000,1880000,1240000,640000,80.50,'UPI Intent v2 rollout'),
('2026-05-25','W22 May 25',49.80,25.80,12.50,36.50,2460000,1970000,1290000,680000,82.10,'Quarter close cash sweep'),
('2026-06-01','W23 Jun 1',48.20,26.10,12.10,34.20,2570000,2080000,1340000,740000,84.30,'New AMC tier pricing live'),
('2026-06-08','W24 Jun 8',46.50,26.40,11.80,31.90,2680000,2210000,1390000,820000,86.40,'Auto-dispatch GST impact'),
('2026-06-15','W25 Jun 15',44.80,26.70,11.50,29.60,2820000,2380000,1450000,930000,88.20,'Best week YTD on collection'),
('2026-06-22','W26 Jun 22',43.20,27.00,11.20,27.40,2940000,2510000,1510000,1000000,89.80,'Current — CCC at all-time low'),
('2026-06-29','W27 Jun 29',42.50,27.20,10.90,26.20,3050000,2620000,1560000,1060000,90.50,'Forecast — assumes no slippage'),
('2026-07-06','W28 Jul 6',41.80,27.50,10.70,25.00,3180000,2740000,1610000,1130000,91.20,'Forecast — Tier-1 onboarding'),
('2026-07-13','W29 Jul 13',41.20,27.80,10.50,23.90,3290000,2860000,1660000,1200000,91.80,'Forecast — chain auto-debit live'),
('2026-07-20','W30 Jul 20',40.50,28.00,10.30,22.80,3410000,2980000,1710000,1270000,92.40,'Forecast — Series A trigger zone');

insert into ccc_leak_events_r2897 (week_start, leak_category, customer_segment, invoice_ref, delay_days, amount_at_risk_rupees, root_cause, remediation_owner, status, recovered_rupees) values
('2026-06-22','disputed_invoice','enterprise_hospital','INV-2026-04812',42,184000,'Service SLA dispute — engineer no-show','founder','escalated',0),
('2026-06-22','late_payment','tier2_chain','INV-2026-04901',28,92000,'Accounts payable cycle mismatch','collections','open',0),
('2026-06-22','pending_po','enterprise_hospital','INV-2026-04955',21,256000,'PO never issued, work proceeded on email','sales_ops','escalated',0),
('2026-06-15','late_payment','single_hospital','INV-2026-04723',35,48000,'Hospital admin on leave','collections','recovered',48000),
('2026-06-15','disputed_invoice','enterprise_hospital','INV-2026-04688',49,312000,'GST mismatch on invoice','finance','recovered',312000),
('2026-06-15','partial_payment','tier2_chain','INV-2026-04802',18,67000,'Disputed parts line item','founder','open',0),
('2026-06-08','late_payment','single_hospital','INV-2026-04611',22,38000,'NEFT bounce — wrong IFSC','collections','recovered',38000),
('2026-06-08','disputed_invoice','enterprise_hospital','INV-2026-04522',55,428000,'Engineer tier downgrade dispute','founder','recovered',385000),
('2026-06-01','pending_po','tier2_chain','INV-2026-04401',31,142000,'Procurement system migration','sales_ops','recovered',142000),
('2026-06-01','late_payment','single_hospital','INV-2026-04388',16,29000,'Founder approval queue stuck','founder','recovered',29000),
('2026-05-25','partial_payment','enterprise_hospital','INV-2026-04201',38,198000,'Bonded parts provenance challenge','founder','recovered',198000),
('2026-05-25','disputed_invoice','single_hospital','INV-2026-04156',12,52000,'Wrong contact email — no notification','collections','recovered',52000),
('2026-05-18','late_payment','tier2_chain','INV-2026-04077',24,88000,'Festival holiday cycle','collections','recovered',88000),
('2026-05-18','write_off','single_hospital','INV-2026-04001',92,18000,'Hospital shut down','finance','written_off',0),
('2026-05-11','disputed_invoice','enterprise_hospital','INV-2026-03922',61,234000,'Code Red SLA penalty claim','founder','recovered',187000),
('2026-05-11','late_payment','tier2_chain','INV-2026-03877',19,76000,'AP team turnover','collections','recovered',76000),
('2026-05-04','partial_payment','single_hospital','INV-2026-03801',26,42000,'Cash discount expected unilaterally','founder','recovered',38000),
('2026-04-27','disputed_invoice','enterprise_hospital','INV-2026-03722',74,512000,'AMC tier dispute — wrong band billed','founder','recovered',498000);

create or replace function founder_ccc_weekly_trend_r2897()
returns table(week_label text, ccc_days numeric, dso_days numeric, dpo_days numeric, dio_days numeric, net_cash_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query select s.week_label, s.ccc_days, s.dso_days, s.dpo_days, s.dio_days, s.net_cash_rupees
    from weekly_ccc_snapshots_r2897 s order by s.week_start;
end$$;
revoke execute on function founder_ccc_weekly_trend_r2897() from public, anon;
grant execute on function founder_ccc_weekly_trend_r2897() to authenticated;

create or replace function founder_ccc_current_week_kpis_r2897()
returns table(metric text, value text, delta_4w text, trend text)
language plpgsql security definer set search_path = public, pg_temp as $$
declare cur record; prev record;
begin
  if not is_founder() then raise exception 'founder only'; end if;
  select * into cur from weekly_ccc_snapshots_r2897 where week_start='2026-06-22';
  select avg(ccc_days) as ccc, avg(dso_days) as dso, avg(collection_efficiency_pct) as ce, avg(net_cash_rupees) as nc
    into prev from weekly_ccc_snapshots_r2897 where week_start between '2026-05-25' and '2026-06-15';
  return query values
    ('CCC days', cur.ccc_days::text, round(cur.ccc_days-prev.ccc,1)::text, case when cur.ccc_days<prev.ccc then 'down_good' else 'up_bad' end),
    ('DSO days', cur.dso_days::text, round(cur.dso_days-prev.dso,1)::text, case when cur.dso_days<prev.dso then 'down_good' else 'up_bad' end),
    ('Collection Eff %', cur.collection_efficiency_pct::text, round(cur.collection_efficiency_pct-prev.ce,1)::text, 'up_good'),
    ('Net Cash ₹', cur.net_cash_rupees::text, (cur.net_cash_rupees-prev.nc::bigint)::text, 'up_good');
end$$;
revoke execute on function founder_ccc_current_week_kpis_r2897() from public, anon;
grant execute on function founder_ccc_current_week_kpis_r2897() to authenticated;

create or replace function founder_ccc_open_leaks_r2897()
returns table(invoice_ref text, segment text, delay_days int, amount_rupees bigint, root_cause text, owner text, status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query select e.invoice_ref, e.customer_segment, e.delay_days, e.amount_at_risk_rupees, e.root_cause, e.remediation_owner, e.status
    from ccc_leak_events_r2897 e where e.status in ('open','escalated') order by e.amount_at_risk_rupees desc;
end$$;
revoke execute on function founder_ccc_open_leaks_r2897() from public, anon;
grant execute on function founder_ccc_open_leaks_r2897() to authenticated;

create or replace function founder_ccc_recovery_scorecard_r2897()
returns table(week_label text, at_risk_rupees bigint, recovered_rupees bigint, recovery_rate_pct numeric, write_off_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
    select to_char(e.week_start,'Mon DD') as week_label,
           sum(e.amount_at_risk_rupees)::bigint,
           sum(e.recovered_rupees)::bigint,
           round(100.0*sum(e.recovered_rupees)/nullif(sum(e.amount_at_risk_rupees),0),1),
           sum(case when e.status='written_off' then e.amount_at_risk_rupees else 0 end)::bigint
    from ccc_leak_events_r2897 e group by e.week_start order by e.week_start desc;
end$$;
revoke execute on function founder_ccc_recovery_scorecard_r2897() from public, anon;
grant execute on function founder_ccc_recovery_scorecard_r2897() to authenticated;

create or replace function founder_ccc_leak_by_segment_r2897()
returns table(segment text, leak_count bigint, total_at_risk bigint, avg_delay numeric, recovery_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
    select e.customer_segment, count(*)::bigint, sum(e.amount_at_risk_rupees)::bigint,
           round(avg(e.delay_days),1), round(100.0*sum(e.recovered_rupees)/nullif(sum(e.amount_at_risk_rupees),0),1)
    from ccc_leak_events_r2897 e group by e.customer_segment order by sum(e.amount_at_risk_rupees) desc;
end$$;
revoke execute on function founder_ccc_leak_by_segment_r2897() from public, anon;
grant execute on function founder_ccc_leak_by_segment_r2897() to authenticated;

create or replace function founder_ccc_root_cause_breakdown_r2897()
returns table(root_cause text, occurrences bigint, total_amount bigint, avg_delay_days numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query select e.root_cause, count(*)::bigint, sum(e.amount_at_risk_rupees)::bigint, round(avg(e.delay_days),1)
    from ccc_leak_events_r2897 e group by e.root_cause order by sum(e.amount_at_risk_rupees) desc;
end$$;
revoke execute on function founder_ccc_root_cause_breakdown_r2897() from public, anon;
grant execute on function founder_ccc_root_cause_breakdown_r2897() to authenticated;

create or replace function founder_ccc_forecast_runway_r2897()
returns table(week_label text, projected_ccc numeric, projected_net_cash bigint, cumulative_cash bigint, milestone text)
language plpgsql security definer set search_path = public, pg_temp as $$
declare cum bigint := 0; r record;
begin
  if not is_founder() then raise exception 'founder only'; end if;
  for r in select * from weekly_ccc_snapshots_r2897 where week_start >= '2026-06-29' order by week_start loop
    cum := cum + r.net_cash_rupees;
    week_label := r.week_label; projected_ccc := r.ccc_days; projected_net_cash := r.net_cash_rupees; cumulative_cash := cum;
    milestone := case when cum > 5000000 then 'Series A trigger zone' when cum > 3000000 then 'Bridge break-even' else 'Build-up phase' end;
    return next;
  end loop;
end$$;
revoke execute on function founder_ccc_forecast_runway_r2897() from public, anon;
grant execute on function founder_ccc_forecast_runway_r2897() to authenticated;

create or replace function founder_ccc_owner_load_r2897()
returns table(owner text, open_count bigint, open_amount bigint, escalated_count bigint, oldest_delay int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
    select e.remediation_owner,
           count(*) filter (where e.status in ('open','escalated'))::bigint,
           coalesce(sum(e.amount_at_risk_rupees) filter (where e.status in ('open','escalated')),0)::bigint,
           count(*) filter (where e.status='escalated')::bigint,
           coalesce(max(e.delay_days) filter (where e.status in ('open','escalated')),0)
    from ccc_leak_events_r2897 e group by e.remediation_owner order by 3 desc;
end$$;
revoke execute on function founder_ccc_owner_load_r2897() from public, anon;
grant execute on function founder_ccc_owner_load_r2897() to authenticated;