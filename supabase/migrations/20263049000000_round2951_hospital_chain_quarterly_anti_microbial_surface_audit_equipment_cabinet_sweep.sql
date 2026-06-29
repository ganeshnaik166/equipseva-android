-- Round 2951: Hospital Chain Quarterly Anti-Microbial Surface-Audit Equipment Cabinet Sweep
-- HEAVY ★★★★ — 2 tables + 7 RPCs

create table if not exists hospital_chain_amr_cabinet_sweeps_r2951 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  hospital_branch text not null,
  cabinet_code text not null,
  sweep_quarter text not null check (sweep_quarter in ('q1','q2','q3','q4')),
  swab_zone text not null check (swab_zone in ('door_handle','drawer_pull','top_surface','inner_shelf','keypad','probe_holder')),
  cfu_per_cm2 numeric(8,2) not null,
  pathogen_flag text not null check (pathogen_flag in ('clean','staph_aureus','mrsa','pseudomonas','c_diff','klebsiella')),
  sweep_status text not null check (sweep_status in ('scheduled','swabbed','lab_pending','passed','failed','remediated')),
  remediation_cost_rupees integer not null default 0,
  swept_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists hospital_chain_amr_remediation_actions_r2951 (
  id uuid primary key default gen_random_uuid(),
  sweep_id uuid references hospital_chain_amr_cabinet_sweeps_r2951(id) on delete cascade,
  action_kind text not null check (action_kind in ('deep_clean','uv_cycle','part_swap','vendor_callback','quarantine','escalate_infection_control')),
  action_owner text not null,
  rupees_spent integer not null default 0,
  outcome text not null check (outcome in ('open','in_progress','resolved','escalated')),
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

alter table hospital_chain_amr_cabinet_sweeps_r2951 enable row level security;
alter table hospital_chain_amr_remediation_actions_r2951 enable row level security;

drop policy if exists r2951_sweeps_founder_all on hospital_chain_amr_cabinet_sweeps_r2951;
create policy r2951_sweeps_founder_all on hospital_chain_amr_cabinet_sweeps_r2951 for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists r2951_actions_founder_all on hospital_chain_amr_remediation_actions_r2951;
create policy r2951_actions_founder_all on hospital_chain_amr_remediation_actions_r2951 for all to authenticated using (is_founder()) with check (is_founder());

insert into hospital_chain_amr_cabinet_sweeps_r2951 (chain_name, hospital_branch, cabinet_code, sweep_quarter, swab_zone, cfu_per_cm2, pathogen_flag, sweep_status, remediation_cost_rupees, swept_at) values
('Apollo','Jubilee Hills','CAB-AP-JH-01','q2','door_handle',12.40,'clean','passed',0,'2026-06-01'::timestamptz),
('Apollo','Jubilee Hills','CAB-AP-JH-02','q2','drawer_pull',88.10,'staph_aureus','failed',14500,'2026-06-02'::timestamptz),
('Apollo','Banjara Hills','CAB-AP-BH-01','q2','top_surface',201.50,'mrsa','remediated',38900,'2026-06-03'::timestamptz),
('Apollo','Secunderabad','CAB-AP-SC-01','q2','keypad',45.20,'pseudomonas','lab_pending',0,'2026-06-04'::timestamptz),
('Manipal','Vijayawada','CAB-MN-VJ-01','q2','inner_shelf',9.80,'clean','passed',0,'2026-06-05'::timestamptz),
('Manipal','Vijayawada','CAB-MN-VJ-02','q2','probe_holder',312.60,'c_diff','failed',62000,'2026-06-06'::timestamptz),
('Manipal','Vizag','CAB-MN-VZ-01','q2','door_handle',22.10,'clean','passed',0,'2026-06-07'::timestamptz),
('Manipal','Vizag','CAB-MN-VZ-02','q2','drawer_pull',155.30,'klebsiella','remediated',27500,'2026-06-08'::timestamptz),
('Yashoda','Somajiguda','CAB-YS-SG-01','q2','top_surface',5.40,'clean','passed',0,'2026-06-09'::timestamptz),
('Yashoda','Somajiguda','CAB-YS-SG-02','q2','keypad',77.30,'staph_aureus','remediated',11200,'2026-06-10'::timestamptz),
('Yashoda','Malakpet','CAB-YS-MK-01','q2','inner_shelf',98.90,'pseudomonas','failed',19800,'2026-06-11'::timestamptz),
('KIMS','Kondapur','CAB-KM-KD-01','q2','probe_holder',14.20,'clean','passed',0,'2026-06-12'::timestamptz),
('KIMS','Kondapur','CAB-KM-KD-02','q2','door_handle',267.80,'mrsa','failed',71000,'2026-06-13'::timestamptz),
('KIMS','Begumpet','CAB-KM-BG-01','q2','drawer_pull',31.10,'clean','passed',0,'2026-06-14'::timestamptz),
('Continental','Gachibowli','CAB-CT-GB-01','q2','top_surface',182.40,'klebsiella','remediated',33400,'2026-06-15'::timestamptz),
('Continental','Gachibowli','CAB-CT-GB-02','q2','keypad',6.20,'clean','passed',0,'2026-06-16'::timestamptz),
('Citizens','Nampally','CAB-CZ-NM-01','q2','inner_shelf',122.70,'staph_aureus','failed',24100,'2026-06-17'::timestamptz),
('Citizens','Nampally','CAB-CZ-NM-02','q2','probe_holder',58.40,'pseudomonas','remediated',16700,'2026-06-18'::timestamptz),
('Rainbow','Banjara Hills','CAB-RB-BH-01','q2','door_handle',8.10,'clean','passed',0,'2026-06-19'::timestamptz),
('Rainbow','Hi-Tech City','CAB-RB-HT-01','q2','drawer_pull',244.50,'c_diff','failed',58300,'2026-06-20'::timestamptz);

insert into hospital_chain_amr_remediation_actions_r2951 (sweep_id, action_kind, action_owner, rupees_spent, outcome, resolved_at)
select id, 'deep_clean','infection_control_lead', 12000,'resolved', swept_at + interval '2 days' from hospital_chain_amr_cabinet_sweeps_r2951 where pathogen_flag='staph_aureus' limit 3;

insert into hospital_chain_amr_remediation_actions_r2951 (sweep_id, action_kind, action_owner, rupees_spent, outcome, resolved_at)
select id, 'uv_cycle','biomed_engineer', 8500,'resolved', swept_at + interval '1 day' from hospital_chain_amr_cabinet_sweeps_r2951 where pathogen_flag='pseudomonas' limit 3;

insert into hospital_chain_amr_remediation_actions_r2951 (sweep_id, action_kind, action_owner, rupees_spent, outcome, resolved_at)
select id, 'part_swap','vendor_field_eng', 45000,'in_progress', null from hospital_chain_amr_cabinet_sweeps_r2951 where pathogen_flag='mrsa' limit 2;

insert into hospital_chain_amr_remediation_actions_r2951 (sweep_id, action_kind, action_owner, rupees_spent, outcome, resolved_at)
select id, 'vendor_callback','account_manager', 0,'open', null from hospital_chain_amr_cabinet_sweeps_r2951 where pathogen_flag='klebsiella' limit 2;

insert into hospital_chain_amr_remediation_actions_r2951 (sweep_id, action_kind, action_owner, rupees_spent, outcome, resolved_at)
select id, 'quarantine','ward_supervisor', 5000,'resolved', swept_at + interval '3 days' from hospital_chain_amr_cabinet_sweeps_r2951 where pathogen_flag='c_diff' limit 2;

insert into hospital_chain_amr_remediation_actions_r2951 (sweep_id, action_kind, action_owner, rupees_spent, outcome, resolved_at)
select id, 'escalate_infection_control','chief_medical_officer', 0,'escalated', null from hospital_chain_amr_cabinet_sweeps_r2951 where cfu_per_cm2 > 200 limit 3;

-- RPC 1: chain-level pass/fail summary
create or replace function rpc_r2951_chain_summary()
returns table(chain_name text, total_sweeps int, failed_sweeps int, remediated_sweeps int, pass_rate_pct numeric, total_remediation_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.chain_name,
         count(*)::int,
         (count(*) filter (where s.sweep_status='failed'))::int,
         (count(*) filter (where s.sweep_status='remediated'))::int,
         round(100.0 * (count(*) filter (where s.sweep_status in ('passed','remediated')))::numeric / nullif(count(*),0), 1),
         coalesce(sum(s.remediation_cost_rupees),0)::bigint
  from hospital_chain_amr_cabinet_sweeps_r2951 s
  group by s.chain_name
  order by s.chain_name;
end;$$;

-- RPC 2: pathogen breakdown
create or replace function rpc_r2951_pathogen_breakdown()
returns table(pathogen_flag text, sweep_count int, mean_cfu numeric, max_cfu numeric, branches_affected int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.pathogen_flag,
         count(*)::int,
         round(avg(s.cfu_per_cm2),1),
         max(s.cfu_per_cm2),
         count(distinct s.hospital_branch)::int
  from hospital_chain_amr_cabinet_sweeps_r2951 s
  group by s.pathogen_flag
  order by max(s.cfu_per_cm2) desc;
end;$$;

-- RPC 3: hottest cabinets
create or replace function rpc_r2951_hottest_cabinets()
returns table(chain_name text, hospital_branch text, cabinet_code text, swab_zone text, cfu_per_cm2 numeric, pathogen_flag text, sweep_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.chain_name, s.hospital_branch, s.cabinet_code, s.swab_zone, s.cfu_per_cm2, s.pathogen_flag, s.sweep_status
  from hospital_chain_amr_cabinet_sweeps_r2951 s
  order by s.cfu_per_cm2 desc
  limit 10;
end;$$;

-- RPC 4: zone risk
create or replace function rpc_r2951_zone_risk()
returns table(swab_zone text, sweeps int, failures int, mean_cfu numeric, risk_score numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.swab_zone,
         count(*)::int,
         (count(*) filter (where s.sweep_status='failed'))::int,
         round(avg(s.cfu_per_cm2),1),
         round(avg(s.cfu_per_cm2) * (1 + (count(*) filter (where s.sweep_status='failed'))::numeric / nullif(count(*),0)), 1)
  from hospital_chain_amr_cabinet_sweeps_r2951 s
  group by s.swab_zone
  order by 5 desc;
end;$$;

-- RPC 5: remediation pipeline
create or replace function rpc_r2951_remediation_pipeline()
returns table(action_kind text, open_count int, in_progress_count int, resolved_count int, escalated_count int, total_spent bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.action_kind,
         (count(*) filter (where a.outcome='open'))::int,
         (count(*) filter (where a.outcome='in_progress'))::int,
         (count(*) filter (where a.outcome='resolved'))::int,
         (count(*) filter (where a.outcome='escalated'))::int,
         coalesce(sum(a.rupees_spent),0)::bigint
  from hospital_chain_amr_remediation_actions_r2951 a
  group by a.action_kind
  order by a.action_kind;
end;$$;

-- RPC 6: branch failure heatmap
create or replace function rpc_r2951_branch_heatmap()
returns table(chain_name text, hospital_branch text, sweeps int, fails int, remediated int, worst_pathogen text, total_cost bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.chain_name, s.hospital_branch,
         count(*)::int,
         (count(*) filter (where s.sweep_status='failed'))::int,
         (count(*) filter (where s.sweep_status='remediated'))::int,
         (array_agg(s.pathogen_flag order by s.cfu_per_cm2 desc))[1],
         coalesce(sum(s.remediation_cost_rupees),0)::bigint
  from hospital_chain_amr_cabinet_sweeps_r2951 s
  group by s.chain_name, s.hospital_branch
  order by 4 desc, 7 desc;
end;$$;

-- RPC 7: open escalations
create or replace function rpc_r2951_open_escalations()
returns table(chain_name text, hospital_branch text, cabinet_code text, pathogen_flag text, cfu_per_cm2 numeric, action_kind text, action_owner text, outcome text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.chain_name, s.hospital_branch, s.cabinet_code, s.pathogen_flag, s.cfu_per_cm2, a.action_kind, a.action_owner, a.outcome
  from hospital_chain_amr_remediation_actions_r2951 a
  join hospital_chain_amr_cabinet_sweeps_r2951 s on s.id = a.sweep_id
  where a.outcome in ('open','in_progress','escalated')
  order by s.cfu_per_cm2 desc;
end;$$;

revoke all on function rpc_r2951_chain_summary() from public, anon;
revoke all on function rpc_r2951_pathogen_breakdown() from public, anon;
revoke all on function rpc_r2951_hottest_cabinets() from public, anon;
revoke all on function rpc_r2951_zone_risk() from public, anon;
revoke all on function rpc_r2951_remediation_pipeline() from public, anon;
revoke all on function rpc_r2951_branch_heatmap() from public, anon;
revoke all on function rpc_r2951_open_escalations() from public, anon;

grant execute on function rpc_r2951_chain_summary() to authenticated;
grant execute on function rpc_r2951_pathogen_breakdown() to authenticated;
grant execute on function rpc_r2951_hottest_cabinets() to authenticated;
grant execute on function rpc_r2951_zone_risk() to authenticated;
grant execute on function rpc_r2951_remediation_pipeline() to authenticated;
grant execute on function rpc_r2951_branch_heatmap() to authenticated;
grant execute on function rpc_r2951_open_escalations() to authenticated;
