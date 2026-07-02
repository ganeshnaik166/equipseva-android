-- Round 3001 — Founder Quarterly Strategic Engineer-Driven Hardware-IP & Soft-IP Portfolio Audit
-- 2 tables (_r3001) + 7 RPCs (is_founder gated)

set search_path = public, pg_temp;

-- ============================================================
-- TABLE 1: hardware-IP assets surfaced by engineers
-- ============================================================
create table if not exists engineer_hardware_ip_assets_r3001 (
  id uuid primary key default gen_random_uuid(),
  asset_code text not null unique,
  engineer_name text not null,
  asset_title text not null,
  ip_category text not null check (ip_category in ('jig','fixture','probe','tooling','adapter','bench_rig','calibration_device','field_kit')),
  hardware_modality text not null check (hardware_modality in ('mri','ct','ultrasound','xray','cath_lab','endoscopy','ventilator','dialysis','monitor','autoclave')),
  patent_status text not null check (patent_status in ('idea','disclosure_filed','provisional','full_filing','granted','trade_secret','open_source')),
  protection_strength_score int not null check (protection_strength_score between 0 and 100),
  estimated_value_rupees bigint not null check (estimated_value_rupees >= 0),
  deployed_field_units int not null default 0 check (deployed_field_units >= 0),
  reuse_count_quarter int not null default 0 check (reuse_count_quarter >= 0),
  defensibility_grade text not null check (defensibility_grade in ('A','B','C','D','F')),
  strategic_pillar text not null check (strategic_pillar in ('moat','margin','speed','safety','compliance')),
  last_audited_on date not null,
  created_at timestamptz not null default now()
);

alter table engineer_hardware_ip_assets_r3001 enable row level security;

drop policy if exists hw_ip_founder_select_r3001 on engineer_hardware_ip_assets_r3001;
create policy hw_ip_founder_select_r3001 on engineer_hardware_ip_assets_r3001
  for select to authenticated using (is_founder());

insert into engineer_hardware_ip_assets_r3001
  (asset_code, engineer_name, asset_title, ip_category, hardware_modality, patent_status, protection_strength_score, estimated_value_rupees, deployed_field_units, reuse_count_quarter, defensibility_grade, strategic_pillar, last_audited_on)
values
  ('HWIP-3001','Ravi Teja','MRI gradient coil alignment jig','jig','mri','granted',92,4800000,18,42,'A','moat','2026-06-10'::date),
  ('HWIP-3002','Anita Sharma','CT detector swap fixture','fixture','ct','full_filing',81,3200000,14,33,'A','margin','2026-06-11'::date),
  ('HWIP-3003','Mohammed Irfan','Ultrasound probe re-tin rig','bench_rig','ultrasound','provisional',68,1800000,9,27,'B','speed','2026-06-09'::date),
  ('HWIP-3004','Sunita Patel','Cath lab table calibration device','calibration_device','cath_lab','granted',95,5600000,7,18,'A','safety','2026-06-12'::date),
  ('HWIP-3005','Karthik Iyer','Endoscope lens centering tool','tooling','endoscopy','disclosure_filed',55,1100000,11,24,'B','speed','2026-06-08'::date),
  ('HWIP-3006','Deepa Nair','Ventilator flow-sensor adapter','adapter','ventilator','full_filing',77,2400000,22,55,'A','safety','2026-06-13'::date),
  ('HWIP-3007','Vikram Bose','Dialysis pump test bench','bench_rig','dialysis','trade_secret',62,1900000,5,12,'B','margin','2026-06-07'::date),
  ('HWIP-3008','Priya Menon','Patient monitor field kit','field_kit','monitor','open_source',38,650000,31,71,'C','speed','2026-06-14'::date),
  ('HWIP-3009','Arjun Reddy','X-ray collimator probe','probe','xray','provisional',71,2100000,8,19,'B','compliance','2026-06-10'::date),
  ('HWIP-3010','Lakshmi Rao','Autoclave seal-pressure jig','jig','autoclave','idea',22,420000,3,6,'D','compliance','2026-06-05'::date),
  ('HWIP-3011','Sandeep Joshi','MRI cryo level verifier','calibration_device','mri','full_filing',84,3800000,12,21,'A','moat','2026-06-11'::date),
  ('HWIP-3012','Neha Kapoor','CT tube swap adapter v2','adapter','ct','granted',88,4200000,16,38,'A','margin','2026-06-12'::date),
  ('HWIP-3013','Rahul Verma','Ultrasound cable test fixture','fixture','ultrasound','disclosure_filed',47,890000,10,22,'C','margin','2026-06-09'::date),
  ('HWIP-3014','Geeta Subramanian','Cath lab contrast injector probe','probe','cath_lab','provisional',73,2700000,6,14,'B','safety','2026-06-13'::date),
  ('HWIP-3015','Tarun Khanna','Endoscopy washer calibration kit','field_kit','endoscopy','trade_secret',58,1450000,9,17,'B','compliance','2026-06-08'::date),
  ('HWIP-3016','Meera Pillai','Ventilator inspiratory jig','jig','ventilator','full_filing',79,3000000,13,29,'A','safety','2026-06-14'::date),
  ('HWIP-3017','Suresh Goyal','Dialysis dialyser holder','tooling','dialysis','open_source',31,520000,18,40,'C','speed','2026-06-06'::date),
  ('HWIP-3018','Asha Bhandari','Monitor ECG lead test rig','bench_rig','monitor','provisional',64,1650000,11,25,'B','safety','2026-06-12'::date);

-- ============================================================
-- TABLE 2: soft-IP assets (algorithms, playbooks, datasets, SOPs)
-- ============================================================
create table if not exists engineer_soft_ip_assets_r3001 (
  id uuid primary key default gen_random_uuid(),
  asset_code text not null unique,
  engineer_name text not null,
  asset_title text not null,
  soft_ip_kind text not null check (soft_ip_kind in ('algorithm','playbook','dataset','sop','training_module','diagnostic_tree','firmware_patch','config_template')),
  modality_scope text not null check (modality_scope in ('mri','ct','ultrasound','xray','cath_lab','endoscopy','ventilator','dialysis','monitor','cross_modality')),
  copyright_status text not null check (copyright_status in ('unregistered','registered','trade_secret','open_license','licensed_out','licensed_in')),
  adoption_score int not null check (adoption_score between 0 and 100),
  estimated_value_rupees bigint not null check (estimated_value_rupees >= 0),
  active_user_engineers int not null default 0 check (active_user_engineers >= 0),
  invocation_count_quarter int not null default 0 check (invocation_count_quarter >= 0),
  defensibility_grade text not null check (defensibility_grade in ('A','B','C','D','F')),
  strategic_pillar text not null check (strategic_pillar in ('moat','margin','speed','safety','compliance')),
  documentation_completeness int not null check (documentation_completeness between 0 and 100),
  last_audited_on date not null,
  created_at timestamptz not null default now()
);

alter table engineer_soft_ip_assets_r3001 enable row level security;

drop policy if exists soft_ip_founder_select_r3001 on engineer_soft_ip_assets_r3001;
create policy soft_ip_founder_select_r3001 on engineer_soft_ip_assets_r3001
  for select to authenticated using (is_founder());

insert into engineer_soft_ip_assets_r3001
  (asset_code, engineer_name, asset_title, soft_ip_kind, modality_scope, copyright_status, adoption_score, estimated_value_rupees, active_user_engineers, invocation_count_quarter, defensibility_grade, strategic_pillar, documentation_completeness, last_audited_on)
values
  ('SWIP-3001','Ravi Teja','MRI helium predictive decay model','algorithm','mri','trade_secret',88,5200000,24,312,'A','moat',92,'2026-06-12'::date),
  ('SWIP-3002','Anita Sharma','CT tube failure decision tree','diagnostic_tree','ct','registered',82,3800000,31,418,'A','speed',88,'2026-06-13'::date),
  ('SWIP-3003','Mohammed Irfan','Ultrasound transducer triage playbook','playbook','ultrasound','registered',76,2200000,28,256,'A','speed',85,'2026-06-10'::date),
  ('SWIP-3004','Sunita Patel','Cath lab uptime SOP v4','sop','cath_lab','registered',91,4400000,19,189,'A','safety',95,'2026-06-14'::date),
  ('SWIP-3005','Karthik Iyer','Endoscope wash-cycle training module','training_module','endoscopy','unregistered',54,890000,42,520,'B','compliance',62,'2026-06-09'::date),
  ('SWIP-3006','Deepa Nair','Ventilator alarm-pattern dataset','dataset','ventilator','trade_secret',79,3100000,15,142,'A','safety',81,'2026-06-13'::date),
  ('SWIP-3007','Vikram Bose','Dialysis pump firmware patch','firmware_patch','dialysis','licensed_out',86,4900000,11,98,'A','margin',90,'2026-06-11'::date),
  ('SWIP-3008','Priya Menon','Multi-vendor monitor config template','config_template','monitor','open_license',44,720000,55,640,'C','speed',58,'2026-06-08'::date),
  ('SWIP-3009','Arjun Reddy','X-ray dose calibration playbook','playbook','xray','registered',73,2600000,22,210,'B','compliance',79,'2026-06-12'::date),
  ('SWIP-3010','Lakshmi Rao','Cross-modality PM scheduler','algorithm','cross_modality','trade_secret',81,3400000,38,488,'A','margin',86,'2026-06-14'::date),
  ('SWIP-3011','Sandeep Joshi','MRI shim coil tuning SOP','sop','mri','registered',84,3000000,17,176,'A','safety',91,'2026-06-11'::date),
  ('SWIP-3012','Neha Kapoor','CT reconstruction artifact diagnostic tree','diagnostic_tree','ct','trade_secret',77,2700000,20,224,'A','safety',83,'2026-06-13'::date),
  ('SWIP-3013','Rahul Verma','Ultrasound probe-life dataset','dataset','ultrasound','registered',69,1800000,14,118,'B','margin',74,'2026-06-09'::date),
  ('SWIP-3014','Geeta Subramanian','Cath lab contrast-pump firmware patch','firmware_patch','cath_lab','licensed_in',58,1300000,8,72,'B','safety',66,'2026-06-12'::date),
  ('SWIP-3015','Tarun Khanna','Endoscopy quality audit playbook','playbook','endoscopy','registered',71,2100000,26,238,'B','compliance',78,'2026-06-10'::date),
  ('SWIP-3016','Meera Pillai','Ventilator weaning training module','training_module','ventilator','unregistered',47,820000,33,360,'C','safety',55,'2026-06-08'::date),
  ('SWIP-3017','Suresh Goyal','Dialysis water-quality dataset','dataset','dialysis','trade_secret',75,2400000,12,108,'B','compliance',82,'2026-06-13'::date),
  ('SWIP-3018','Asha Bhandari','Monitor multi-parameter algorithm','algorithm','monitor','registered',80,2900000,18,196,'A','moat',87,'2026-06-14'::date);

-- ============================================================
-- RPC 1 — Portfolio overview
-- ============================================================
create or replace function rpc_r3001_portfolio_overview()
returns table (
  asset_class text,
  total_assets int,
  total_value_rupees bigint,
  grade_a_count int,
  protected_count int
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  select 'hardware_ip'::text,
    count(*)::int,
    coalesce(sum(estimated_value_rupees),0)::bigint,
    (count(*) filter (where defensibility_grade = 'A'))::int,
    (count(*) filter (where patent_status in ('granted','full_filing','provisional')))::int
  from engineer_hardware_ip_assets_r3001
  union all
  select 'soft_ip'::text,
    count(*)::int,
    coalesce(sum(estimated_value_rupees),0)::bigint,
    (count(*) filter (where defensibility_grade = 'A'))::int,
    (count(*) filter (where copyright_status in ('registered','trade_secret','licensed_out')))::int
  from engineer_soft_ip_assets_r3001;
end;
$$;

revoke all on function rpc_r3001_portfolio_overview() from public, anon;
grant execute on function rpc_r3001_portfolio_overview() to authenticated;

-- ============================================================
-- RPC 2 — Top engineers by IP contribution
-- ============================================================
create or replace function rpc_r3001_top_engineers()
returns table (
  engineer_name text,
  hardware_assets int,
  soft_assets int,
  total_value_rupees bigint,
  grade_a_total int
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  with hw as (
    select engineer_name,
      count(*)::int as hw_cnt,
      coalesce(sum(estimated_value_rupees),0)::bigint as hw_val,
      (count(*) filter (where defensibility_grade = 'A'))::int as hw_a
    from engineer_hardware_ip_assets_r3001 group by engineer_name
  ),
  sw as (
    select engineer_name,
      count(*)::int as sw_cnt,
      coalesce(sum(estimated_value_rupees),0)::bigint as sw_val,
      (count(*) filter (where defensibility_grade = 'A'))::int as sw_a
    from engineer_soft_ip_assets_r3001 group by engineer_name
  )
  select coalesce(hw.engineer_name, sw.engineer_name)::text,
    coalesce(hw.hw_cnt,0)::int,
    coalesce(sw.sw_cnt,0)::int,
    (coalesce(hw.hw_val,0) + coalesce(sw.sw_val,0))::bigint,
    (coalesce(hw.hw_a,0) + coalesce(sw.sw_a,0))::int
  from hw full outer join sw on hw.engineer_name = sw.engineer_name
  order by (coalesce(hw.hw_val,0) + coalesce(sw.sw_val,0)) desc
  limit 10;
end;
$$;

revoke all on function rpc_r3001_top_engineers() from public, anon;
grant execute on function rpc_r3001_top_engineers() to authenticated;

-- ============================================================
-- RPC 3 — Patent status breakdown (hardware)
-- ============================================================
create or replace function rpc_r3001_patent_status_breakdown()
returns table (
  patent_status text,
  asset_count int,
  total_value_rupees bigint,
  avg_strength numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  select patent_status::text,
    count(*)::int,
    coalesce(sum(estimated_value_rupees),0)::bigint,
    round(avg(protection_strength_score)::numeric, 1)
  from engineer_hardware_ip_assets_r3001
  group by patent_status
  order by sum(estimated_value_rupees) desc nulls last;
end;
$$;

revoke all on function rpc_r3001_patent_status_breakdown() from public, anon;
grant execute on function rpc_r3001_patent_status_breakdown() to authenticated;

-- ============================================================
-- RPC 4 — Strategic pillar distribution
-- ============================================================
create or replace function rpc_r3001_pillar_distribution()
returns table (
  strategic_pillar text,
  hardware_count int,
  soft_count int,
  combined_value_rupees bigint
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  with hw as (
    select strategic_pillar, count(*)::int as cnt, coalesce(sum(estimated_value_rupees),0)::bigint as val
    from engineer_hardware_ip_assets_r3001 group by strategic_pillar
  ),
  sw as (
    select strategic_pillar, count(*)::int as cnt, coalesce(sum(estimated_value_rupees),0)::bigint as val
    from engineer_soft_ip_assets_r3001 group by strategic_pillar
  )
  select coalesce(hw.strategic_pillar, sw.strategic_pillar)::text,
    coalesce(hw.cnt,0)::int,
    coalesce(sw.cnt,0)::int,
    (coalesce(hw.val,0) + coalesce(sw.val,0))::bigint
  from hw full outer join sw on hw.strategic_pillar = sw.strategic_pillar
  order by (coalesce(hw.val,0) + coalesce(sw.val,0)) desc;
end;
$$;

revoke all on function rpc_r3001_pillar_distribution() from public, anon;
grant execute on function rpc_r3001_pillar_distribution() to authenticated;

-- ============================================================
-- RPC 5 — Underprotected high-value assets (flag for legal)
-- ============================================================
create or replace function rpc_r3001_underprotected_flags()
returns table (
  asset_code text,
  engineer_name text,
  asset_title text,
  estimated_value_rupees bigint,
  patent_status text,
  protection_strength_score int,
  defensibility_grade text
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  select h.asset_code, h.engineer_name, h.asset_title, h.estimated_value_rupees,
    h.patent_status, h.protection_strength_score, h.defensibility_grade
  from engineer_hardware_ip_assets_r3001 h
  where h.estimated_value_rupees >= 1500000
    and (h.patent_status in ('idea','disclosure_filed') or h.protection_strength_score < 60)
  order by h.estimated_value_rupees desc;
end;
$$;

revoke all on function rpc_r3001_underprotected_flags() from public, anon;
grant execute on function rpc_r3001_underprotected_flags() to authenticated;

-- ============================================================
-- RPC 6 — Soft-IP adoption leaders
-- ============================================================
create or replace function rpc_r3001_soft_ip_adoption_leaders()
returns table (
  asset_code text,
  engineer_name text,
  asset_title text,
  soft_ip_kind text,
  adoption_score int,
  active_user_engineers int,
  invocation_count_quarter int,
  estimated_value_rupees bigint
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  select s.asset_code, s.engineer_name, s.asset_title, s.soft_ip_kind,
    s.adoption_score, s.active_user_engineers, s.invocation_count_quarter, s.estimated_value_rupees
  from engineer_soft_ip_assets_r3001 s
  order by s.adoption_score desc, s.invocation_count_quarter desc
  limit 12;
end;
$$;

revoke all on function rpc_r3001_soft_ip_adoption_leaders() from public, anon;
grant execute on function rpc_r3001_soft_ip_adoption_leaders() to authenticated;

-- ============================================================
-- RPC 7 — Modality coverage matrix
-- ============================================================
create or replace function rpc_r3001_modality_coverage()
returns table (
  modality text,
  hardware_assets int,
  soft_assets int,
  combined_value_rupees bigint,
  best_grade text
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  with hw as (
    select hardware_modality as m,
      count(*)::int as cnt,
      coalesce(sum(estimated_value_rupees),0)::bigint as val,
      min(defensibility_grade) as best
    from engineer_hardware_ip_assets_r3001 group by hardware_modality
  ),
  sw as (
    select modality_scope as m,
      count(*)::int as cnt,
      coalesce(sum(estimated_value_rupees),0)::bigint as val,
      min(defensibility_grade) as best
    from engineer_soft_ip_assets_r3001 group by modality_scope
  )
  select coalesce(hw.m, sw.m)::text,
    coalesce(hw.cnt,0)::int,
    coalesce(sw.cnt,0)::int,
    (coalesce(hw.val,0) + coalesce(sw.val,0))::bigint,
    least(coalesce(hw.best,'F'), coalesce(sw.best,'F'))::text
  from hw full outer join sw on hw.m = sw.m
  order by (coalesce(hw.val,0) + coalesce(sw.val,0)) desc;
end;
$$;

revoke all on function rpc_r3001_modality_coverage() from public, anon;
grant execute on function rpc_r3001_modality_coverage() to authenticated;
