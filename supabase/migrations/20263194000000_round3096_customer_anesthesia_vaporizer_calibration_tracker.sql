-- Round 3096 — Customer Anesthesia Workstation Vaporizer Output Concentration Calibration Tracker
-- Quarterly engineer-led vaporizer calibration log for anesthesia workstations.

begin;

create table if not exists public.vaporizer_calibration_logs_r3096 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid references public.organizations(id) on delete set null,
  workstation_serial text not null,
  workstation_model text not null check (workstation_model in ('Draeger Fabius Plus','Draeger Primus','GE Aisys CS2','Mindray A7','Penlon Prima SP2','BPL Cerus 100')),
  vaporizer_agent text not null check (vaporizer_agent in ('sevoflurane','isoflurane','desflurane')),
  vaporizer_serial text not null,
  set_concentration_pct numeric(5,2) not null check (set_concentration_pct between 0.50 and 18.00),
  delivered_concentration_pct numeric(5,2) not null check (delivered_concentration_pct between 0.00 and 20.00),
  deviation_pct numeric(6,2) not null check (deviation_pct between -100.00 and 100.00),
  status text not null check (status in ('within_tolerance','out_of_tolerance','critical_deviation','recalibrated','quarantined')),
  calibration_certificate_id text,
  engineer_id uuid references public.engineers(id) on delete set null,
  calibrated_at timestamptz not null default now(),
  next_due_at timestamptz not null,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_vcl_r3096_hospital on public.vaporizer_calibration_logs_r3096(hospital_org_id);
create index if not exists idx_vcl_r3096_status on public.vaporizer_calibration_logs_r3096(status);
create index if not exists idx_vcl_r3096_agent on public.vaporizer_calibration_logs_r3096(vaporizer_agent);
create index if not exists idx_vcl_r3096_calibrated on public.vaporizer_calibration_logs_r3096(calibrated_at);

create table if not exists public.vaporizer_capa_queue_r3096 (
  id uuid primary key default gen_random_uuid(),
  calibration_log_id uuid not null references public.vaporizer_calibration_logs_r3096(id) on delete cascade,
  capa_severity text not null check (capa_severity in ('low','medium','high','critical')),
  capa_state text not null check (capa_state in ('open','in_progress','awaiting_parts','closed','escalated')),
  root_cause text check (root_cause in ('wick_saturation','thermo_compensator_drift','filling_seal_leak','sensor_calibration_offset','user_handling','unknown')),
  corrective_action text,
  preventive_action text,
  assigned_engineer_id uuid references public.engineers(id) on delete set null,
  opened_at timestamptz not null default now(),
  target_close_at timestamptz,
  closed_at timestamptz,
  cost_rupees numeric(12,2) not null default 0 check (cost_rupees >= 0),
  created_at timestamptz not null default now()
);

create index if not exists idx_vcq_r3096_log on public.vaporizer_capa_queue_r3096(calibration_log_id);
create index if not exists idx_vcq_r3096_state on public.vaporizer_capa_queue_r3096(capa_state);
create index if not exists idx_vcq_r3096_severity on public.vaporizer_capa_queue_r3096(capa_severity);

-- Seed data (8 calibration logs + 5 CAPA rows = 13 total)
insert into public.vaporizer_calibration_logs_r3096
  (id, workstation_serial, workstation_model, vaporizer_agent, vaporizer_serial, set_concentration_pct, delivered_concentration_pct, deviation_pct, status, calibration_certificate_id, calibrated_at, next_due_at, notes)
values
  ('a1111111-1111-1111-1111-111111111101','AWS-HYD-001','Draeger Primus','sevoflurane','VAP-SEV-7701',2.00,2.04,2.00,'within_tolerance','CERT-2026-Q2-001', now() - interval '12 days', now() + interval '78 days','Routine quarterly cal'),
  ('a1111111-1111-1111-1111-111111111102','AWS-BLR-014','GE Aisys CS2','isoflurane','VAP-ISO-3322',1.50,1.71,14.00,'out_of_tolerance','CERT-2026-Q2-002', now() - interval '20 days', now() + interval '70 days','Wick saturation suspected'),
  ('a1111111-1111-1111-1111-111111111103','AWS-MUM-022','Mindray A7','desflurane','VAP-DES-9911',6.00,7.32,22.00,'critical_deviation','CERT-2026-Q2-003', now() - interval '8 days', now() + interval '82 days','Pulled from service'),
  ('a1111111-1111-1111-1111-111111111104','AWS-DEL-007','Draeger Fabius Plus','sevoflurane','VAP-SEV-4421',3.00,2.97,-1.00,'within_tolerance','CERT-2026-Q2-004', now() - interval '35 days', now() + interval '55 days','Good drift profile'),
  ('a1111111-1111-1111-1111-111111111105','AWS-CHN-019','Penlon Prima SP2','isoflurane','VAP-ISO-5523',1.00,1.08,8.00,'recalibrated','CERT-2026-Q2-005', now() - interval '45 days', now() + interval '45 days','Recalibrated on-site'),
  ('a1111111-1111-1111-1111-111111111106','AWS-KOL-031','BPL Cerus 100','sevoflurane','VAP-SEV-1102',2.50,2.61,4.40,'within_tolerance','CERT-2026-Q1-088', now() - interval '70 days', now() + interval '20 days','Stable across quarter'),
  ('a1111111-1111-1111-1111-111111111107','AWS-PUN-044','Draeger Primus','desflurane','VAP-DES-7788',8.00,9.84,23.00,'quarantined','CERT-2026-Q2-006', now() - interval '5 days', now() + interval '85 days','Tagged out — CAPA opened'),
  ('a1111111-1111-1111-1111-111111111108','AWS-AHM-052','GE Aisys CS2','sevoflurane','VAP-SEV-6655',2.00,2.12,6.00,'out_of_tolerance','CERT-2026-Q2-007', now() - interval '18 days', now() + interval '72 days','Sensor offset suspected');

insert into public.vaporizer_capa_queue_r3096
  (calibration_log_id, capa_severity, capa_state, root_cause, corrective_action, preventive_action, opened_at, target_close_at, cost_rupees)
values
  ('a1111111-1111-1111-1111-111111111102','high','in_progress','wick_saturation','Replace wick assembly','Add monthly visual inspection', now() - interval '18 days', now() + interval '12 days', 18500.00),
  ('a1111111-1111-1111-1111-111111111103','critical','escalated','thermo_compensator_drift','Vaporizer swap from spares','OEM RMA + 6-month watch', now() - interval '7 days', now() + interval '23 days', 145000.00),
  ('a1111111-1111-1111-1111-111111111105','medium','closed','sensor_calibration_offset','Field recalibration', 'Quarterly cert verification', now() - interval '45 days', now() - interval '40 days', 6500.00),
  ('a1111111-1111-1111-1111-111111111107','critical','awaiting_parts','filling_seal_leak','Seal kit + leak test','Spare seal kit inventory at hub', now() - interval '5 days', now() + interval '25 days', 38000.00),
  ('a1111111-1111-1111-1111-111111111108','medium','open','sensor_calibration_offset','On-site recalibration scheduled','Auto-flag if deviation > 5%', now() - interval '16 days', now() + interval '14 days', 8200.00);

-- ============ RPCs ============

create or replace function public.rpc_r3096_status_summary()
returns table(status text, log_count bigint, avg_deviation numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select v.status, count(*)::bigint, round(avg(abs(v.deviation_pct))::numeric, 2)
    from public.vaporizer_calibration_logs_r3096 v
    group by v.status
    order by count(*) desc;
end$$;
revoke execute on function public.rpc_r3096_status_summary() from public, anon;
grant execute on function public.rpc_r3096_status_summary() to authenticated;

create or replace function public.rpc_r3096_agent_breakdown()
returns table(vaporizer_agent text, log_count bigint, avg_set numeric, avg_delivered numeric, avg_abs_deviation numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select v.vaporizer_agent, count(*)::bigint,
           round(avg(v.set_concentration_pct)::numeric,2),
           round(avg(v.delivered_concentration_pct)::numeric,2),
           round(avg(abs(v.deviation_pct))::numeric,2)
    from public.vaporizer_calibration_logs_r3096 v
    group by v.vaporizer_agent
    order by avg(abs(v.deviation_pct)) desc;
end$$;
revoke execute on function public.rpc_r3096_agent_breakdown() from public, anon;
grant execute on function public.rpc_r3096_agent_breakdown() to authenticated;

create or replace function public.rpc_r3096_monthly_trend()
returns table(month_label text, log_count bigint, out_of_tol_count bigint, critical_count bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select to_char(date_trunc('month', v.calibrated_at), 'YYYY-MM'),
           count(*)::bigint,
           count(*) filter (where v.status = 'out_of_tolerance')::bigint,
           count(*) filter (where v.status = 'critical_deviation')::bigint
    from public.vaporizer_calibration_logs_r3096 v
    group by date_trunc('month', v.calibrated_at)
    order by date_trunc('month', v.calibrated_at) desc;
end$$;
revoke execute on function public.rpc_r3096_monthly_trend() from public, anon;
grant execute on function public.rpc_r3096_monthly_trend() to authenticated;

create or replace function public.rpc_r3096_model_scorecard()
returns table(workstation_model text, units bigint, within_tol bigint, out_of_tol bigint, critical_units bigint, avg_abs_dev numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select v.workstation_model, count(*)::bigint,
           count(*) filter (where v.status = 'within_tolerance')::bigint,
           count(*) filter (where v.status = 'out_of_tolerance')::bigint,
           count(*) filter (where v.status in ('critical_deviation','quarantined'))::bigint,
           round(avg(abs(v.deviation_pct))::numeric,2)
    from public.vaporizer_calibration_logs_r3096 v
    group by v.workstation_model
    order by count(*) filter (where v.status in ('critical_deviation','quarantined')) desc;
end$$;
revoke execute on function public.rpc_r3096_model_scorecard() from public, anon;
grant execute on function public.rpc_r3096_model_scorecard() to authenticated;

create or replace function public.rpc_r3096_hotlist()
returns table(workstation_serial text, workstation_model text, vaporizer_agent text, deviation_pct numeric, status text, calibrated_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select v.workstation_serial, v.workstation_model, v.vaporizer_agent, v.deviation_pct, v.status, v.calibrated_at
    from public.vaporizer_calibration_logs_r3096 v
    where v.status in ('out_of_tolerance','critical_deviation','quarantined')
    order by abs(v.deviation_pct) desc
    limit 25;
end$$;
revoke execute on function public.rpc_r3096_hotlist() from public, anon;
grant execute on function public.rpc_r3096_hotlist() to authenticated;

create or replace function public.rpc_r3096_capa_summary()
returns table(capa_state text, capa_count bigint, total_cost numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.capa_state, count(*)::bigint, coalesce(sum(c.cost_rupees),0)::numeric
    from public.vaporizer_capa_queue_r3096 c
    group by c.capa_state
    order by sum(c.cost_rupees) desc nulls last;
end$$;
revoke execute on function public.rpc_r3096_capa_summary() from public, anon;
grant execute on function public.rpc_r3096_capa_summary() to authenticated;

create or replace function public.rpc_r3096_root_cause_breakdown()
returns table(root_cause text, capa_count bigint, avg_cost numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select coalesce(c.root_cause,'unknown'), count(*)::bigint, round(coalesce(avg(c.cost_rupees),0)::numeric,2)
    from public.vaporizer_capa_queue_r3096 c
    group by c.root_cause
    order by count(*) desc;
end$$;
revoke execute on function public.rpc_r3096_root_cause_breakdown() from public, anon;
grant execute on function public.rpc_r3096_root_cause_breakdown() to authenticated;

create or replace function public.rpc_r3096_due_soon()
returns table(workstation_serial text, workstation_model text, vaporizer_agent text, next_due_at timestamptz, days_to_due integer)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select v.workstation_serial, v.workstation_model, v.vaporizer_agent, v.next_due_at,
           extract(day from (v.next_due_at - now()))::integer
    from public.vaporizer_calibration_logs_r3096 v
    where v.next_due_at < now() + interval '60 days'
    order by v.next_due_at asc
    limit 25;
end$$;
revoke execute on function public.rpc_r3096_due_soon() from public, anon;
grant execute on function public.rpc_r3096_due_soon() to authenticated;

commit;
