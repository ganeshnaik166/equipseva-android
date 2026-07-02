-- Round 3071: Hospital Chain Quarterly ENT Endoscope Channel Brush Wear & Cross-Contamination Audit
-- Tracks channel brush wear cycles and cross-contamination risk signals across hospital chain ENT endoscopes.

create table if not exists ent_endoscope_brush_wear_r3071 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  chain_code text not null,
  hospital_site text not null,
  endoscope_model text not null,
  endoscope_serial text not null,
  channel_type text not null check (channel_type in ('suction','biopsy','air_water','elevator_wire')),
  brush_lot_id text,
  brushes_used_quarter int not null check (brushes_used_quarter between 0 and 5000),
  bristle_loss_pct numeric(5,2) not null check (bristle_loss_pct >= 0 and bristle_loss_pct <= 100),
  shaft_deformation_grade text not null check (shaft_deformation_grade in ('none','mild','moderate','severe')),
  wear_threshold_breach boolean not null default false,
  last_brush_change_at timestamptz,
  replacement_due_in_cycles int check (replacement_due_in_cycles between -200 and 2000),
  audit_quarter text not null check (audit_quarter in ('Q1','Q2','Q3','Q4')),
  audit_year int not null check (audit_year between 2024 and 2030),
  notes text
);

create table if not exists ent_endoscope_cross_contam_r3071 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  chain_code text not null,
  hospital_site text not null,
  endoscope_serial text not null,
  channel_type text not null check (channel_type in ('suction','biopsy','air_water','elevator_wire')),
  swab_sample_id text not null,
  swab_taken_at timestamptz not null,
  organism_detected text not null check (organism_detected in ('none','pseudomonas','klebsiella','mycobacterium','staph_aureus','candida','e_coli','enterococcus')),
  cfu_count int not null check (cfu_count between 0 and 1000000),
  risk_tier text not null check (risk_tier in ('green','amber','red','critical')),
  patient_exposure_count int check (patient_exposure_count between 0 and 500),
  quarantine_initiated boolean not null default false,
  resolved_at timestamptz,
  root_cause text check (root_cause in ('worn_brush','skipped_step','dryer_fault','rinse_water','staff_error','unknown')),
  audit_quarter text not null check (audit_quarter in ('Q1','Q2','Q3','Q4')),
  audit_year int not null check (audit_year between 2024 and 2030)
);

alter table ent_endoscope_brush_wear_r3071 enable row level security;
alter table ent_endoscope_cross_contam_r3071 enable row level security;

drop policy if exists brush_wear_founder_r3071 on ent_endoscope_brush_wear_r3071;
create policy brush_wear_founder_r3071 on ent_endoscope_brush_wear_r3071 for select using (is_founder());

drop policy if exists cross_contam_founder_r3071 on ent_endoscope_cross_contam_r3071;
create policy cross_contam_founder_r3071 on ent_endoscope_cross_contam_r3071 for select using (is_founder());

-- Seed brush wear (18 rows)
insert into ent_endoscope_brush_wear_r3071 (chain_code, hospital_site, endoscope_model, endoscope_serial, channel_type, brush_lot_id, brushes_used_quarter, bristle_loss_pct, shaft_deformation_grade, wear_threshold_breach, last_brush_change_at, replacement_due_in_cycles, audit_quarter, audit_year, notes) values
('APOLLO','Apollo Jubilee','Olympus ENF-VH','OLY-001','suction','BL-2026-Q1-001',420,12.5,'none',false,'2026-03-12'::timestamptz,180,'Q1',2026,'baseline ok'),
('APOLLO','Apollo Hyderguda','Pentax EPK-i7000','PEN-014','biopsy','BL-2026-Q1-002',610,45.2,'mild',true,'2026-02-28'::timestamptz,40,'Q1',2026,'breach — schedule swap'),
('APOLLO','Apollo Secunderabad','Olympus ENF-VT3','OLY-022','suction','BL-2026-Q1-003',380,8.1,'none',false,'2026-03-20'::timestamptz,220,'Q1',2026,null),
('FORTIS','Fortis Banjara','Karl Storz 11101','KST-008','elevator_wire','BL-2026-Q1-004',290,62.5,'moderate',true,'2026-01-15'::timestamptz,-10,'Q1',2026,'overdue 10 cycles'),
('FORTIS','Fortis Mulund','Pentax EE-1580K','PEN-031','air_water',null,510,28.0,'mild',false,null,95,'Q1',2026,'lot tag missing on brush'),
('MANIPAL','Manipal Whitefield','Olympus ENF-V2','OLY-045','suction','BL-2026-Q1-006',440,18.4,'none',false,'2026-03-05'::timestamptz,160,'Q1',2026,null),
('MANIPAL','Manipal Yeshwanthpur','Pentax EPK-i5000','PEN-052','biopsy','BL-2026-Q1-007',720,51.0,'moderate',true,'2026-02-10'::timestamptz,15,'Q1',2026,'biopsy bristles flayed'),
('NARAYANA','Narayana Bommasandra','Olympus ENF-VT2','OLY-061','suction','BL-2026-Q1-008',330,9.3,'none',false,'2026-03-18'::timestamptz,210,'Q1',2026,null),
('NARAYANA','Narayana Mazumdar','Karl Storz 11102','KST-073','elevator_wire','BL-2026-Q1-009',280,72.8,'severe',true,'2026-01-04'::timestamptz,-45,'Q1',2026,'critical — quarantined'),
('AIIMS','AIIMS New Delhi','Pentax FNL-15RP3','PEN-088','biopsy','BL-2026-Q1-010',640,33.6,'mild',true,'2026-02-22'::timestamptz,30,'Q1',2026,null),
('AIIMS','AIIMS Rishikesh','Olympus ENF-VH','OLY-091','air_water','BL-2026-Q1-011',410,14.7,'none',false,'2026-03-09'::timestamptz,175,'Q1',2026,null),
('KIMS','KIMS Secunderabad','Pentax EE-1580K','PEN-103','suction','BL-2026-Q1-012',490,22.0,'mild',false,'2026-02-26'::timestamptz,110,'Q1',2026,null),
('KIMS','KIMS Kondapur','Olympus ENF-VT3','OLY-112','biopsy','BL-2026-Q1-013',560,41.8,'moderate',true,'2026-02-05'::timestamptz,25,'Q1',2026,'order brush BL-Q2 ASAP'),
('CARE','CARE Banjara','Karl Storz 11101','KST-128','elevator_wire','BL-2026-Q1-014',310,55.4,'moderate',true,'2026-01-22'::timestamptz,-5,'Q1',2026,null),
('CARE','CARE Nampally','Pentax EPK-i7000','PEN-135','suction','BL-2026-Q1-015',360,11.2,'none',false,'2026-03-15'::timestamptz,200,'Q1',2026,null),
('YASHODA','Yashoda Somajiguda','Olympus ENF-V2','OLY-144','biopsy','BL-2026-Q1-016',680,47.5,'moderate',true,null,20,'Q1',2026,'replacement log lost'),
('YASHODA','Yashoda Malakpet','Pentax FNL-15RP3','PEN-152','air_water','BL-2026-Q1-017',420,16.9,'none',false,'2026-03-11'::timestamptz,170,'Q1',2026,null),
('CONTINENTAL','Continental Gachibowli','Karl Storz 11102','KST-167','elevator_wire','BL-2026-Q1-018',270,68.0,'severe',true,'2026-01-08'::timestamptz,-30,'Q1',2026,'severe deformation');

-- Seed cross-contamination (20 rows)
insert into ent_endoscope_cross_contam_r3071 (chain_code, hospital_site, endoscope_serial, channel_type, swab_sample_id, swab_taken_at, organism_detected, cfu_count, risk_tier, patient_exposure_count, quarantine_initiated, resolved_at, root_cause, audit_quarter, audit_year) values
('APOLLO','Apollo Jubilee','OLY-001','suction','SW-3071-001','2026-03-14'::timestamptz,'none',0,'green',0,false,'2026-03-15'::timestamptz,null,'Q1',2026),
('APOLLO','Apollo Hyderguda','PEN-014','biopsy','SW-3071-002','2026-03-01'::timestamptz,'pseudomonas',8400,'red',12,true,null,'worn_brush','Q1',2026),
('APOLLO','Apollo Secunderabad','OLY-022','suction','SW-3071-003','2026-03-22'::timestamptz,'none',0,'green',0,false,'2026-03-23'::timestamptz,null,'Q1',2026),
('FORTIS','Fortis Banjara','KST-008','elevator_wire','SW-3071-004','2026-01-18'::timestamptz,'mycobacterium',2100,'critical',7,true,null,'worn_brush','Q1',2026),
('FORTIS','Fortis Mulund','PEN-031','air_water','SW-3071-005','2026-02-09'::timestamptz,'klebsiella',1200,'amber',3,true,'2026-02-25'::timestamptz,'rinse_water','Q1',2026),
('MANIPAL','Manipal Whitefield','OLY-045','suction','SW-3071-006','2026-03-07'::timestamptz,'none',0,'green',0,false,'2026-03-08'::timestamptz,null,'Q1',2026),
('MANIPAL','Manipal Yeshwanthpur','PEN-052','biopsy','SW-3071-007','2026-02-12'::timestamptz,'staph_aureus',4600,'red',9,true,null,'worn_brush','Q1',2026),
('NARAYANA','Narayana Bommasandra','OLY-061','suction','SW-3071-008','2026-03-20'::timestamptz,'none',0,'green',0,false,'2026-03-21'::timestamptz,null,'Q1',2026),
('NARAYANA','Narayana Mazumdar','KST-073','elevator_wire','SW-3071-009','2026-01-06'::timestamptz,'pseudomonas',18500,'critical',15,true,null,'worn_brush','Q1',2026),
('AIIMS','AIIMS New Delhi','PEN-088','biopsy','SW-3071-010','2026-02-25'::timestamptz,'candida',950,'amber',null,true,'2026-03-12'::timestamptz,'dryer_fault','Q1',2026),
('AIIMS','AIIMS Rishikesh','OLY-091','air_water','SW-3071-011','2026-03-10'::timestamptz,'none',0,'green',0,false,'2026-03-11'::timestamptz,null,'Q1',2026),
('KIMS','KIMS Secunderabad','PEN-103','suction','SW-3071-012','2026-02-28'::timestamptz,'e_coli',520,'amber',2,false,'2026-03-04'::timestamptz,'skipped_step','Q1',2026),
('KIMS','KIMS Kondapur','OLY-112','biopsy','SW-3071-013','2026-02-07'::timestamptz,'enterococcus',3300,'red',6,true,null,'worn_brush','Q1',2026),
('CARE','CARE Banjara','KST-128','elevator_wire','SW-3071-014','2026-01-24'::timestamptz,'mycobacterium',7800,'critical',4,true,null,'worn_brush','Q1',2026),
('CARE','CARE Nampally','PEN-135','suction','SW-3071-015','2026-03-16'::timestamptz,'none',0,'green',0,false,'2026-03-17'::timestamptz,null,'Q1',2026),
('YASHODA','Yashoda Somajiguda','OLY-144','biopsy','SW-3071-016','2026-02-15'::timestamptz,'klebsiella',2700,'red',8,true,null,'worn_brush','Q1',2026),
('YASHODA','Yashoda Malakpet','PEN-152','air_water','SW-3071-017','2026-03-12'::timestamptz,'none',0,'green',0,false,'2026-03-13'::timestamptz,null,'Q1',2026),
('CONTINENTAL','Continental Gachibowli','KST-167','elevator_wire','SW-3071-018','2026-01-10'::timestamptz,'pseudomonas',24000,'critical',18,true,null,'worn_brush','Q1',2026),
('APOLLO','Apollo Jubilee','OLY-001','biopsy','SW-3071-019','2026-03-28'::timestamptz,'candida',310,'amber',1,false,'2026-04-01'::timestamptz,'staff_error','Q1',2026),
('MANIPAL','Manipal Whitefield','OLY-045','elevator_wire','SW-3071-020','2026-03-25'::timestamptz,'none',0,'green',0,false,'2026-03-26'::timestamptz,null,'Q1',2026);

-- RPC 1: chain-level brush breach summary
create or replace function founder_brush_wear_chain_summary_r3071()
returns table(chain_code text, scopes_audited int, breaches int, avg_bristle_loss numeric, severe_deformations int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select b.chain_code,
           count(*)::int,
           (count(*) filter (where b.wear_threshold_breach))::int,
           round(avg(b.bristle_loss_pct), 2),
           (count(*) filter (where b.shaft_deformation_grade = 'severe'))::int
    from ent_endoscope_brush_wear_r3071 b
    group by b.chain_code
    order by (count(*) filter (where b.wear_threshold_breach)) desc;
end; $$;

-- RPC 2: overdue replacements
create or replace function founder_brush_overdue_replacements_r3071()
returns table(chain_code text, hospital_site text, endoscope_serial text, cycles_overdue int, last_brush_change_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select b.chain_code, b.hospital_site, b.endoscope_serial,
           (-b.replacement_due_in_cycles)::int as cycles_overdue,
           b.last_brush_change_at
    from ent_endoscope_brush_wear_r3071 b
    where b.replacement_due_in_cycles < 0
    order by b.replacement_due_in_cycles asc;
end; $$;

-- RPC 3: contamination risk roll-up
create or replace function founder_contam_risk_rollup_r3071()
returns table(risk_tier text, swabs int, total_patient_exposure int, avg_cfu numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.risk_tier,
           count(*)::int,
           coalesce(sum(c.patient_exposure_count), 0)::int,
           round(avg(c.cfu_count), 1)
    from ent_endoscope_cross_contam_r3071 c
    group by c.risk_tier
    order by case c.risk_tier when 'critical' then 1 when 'red' then 2 when 'amber' then 3 else 4 end;
end; $$;

-- RPC 4: organism breakdown
create or replace function founder_contam_organism_breakdown_r3071()
returns table(organism_detected text, occurrences int, hospitals_hit int, max_cfu int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.organism_detected,
           count(*)::int,
           count(distinct c.hospital_site)::int,
           max(c.cfu_count)::int
    from ent_endoscope_cross_contam_r3071 c
    where c.organism_detected <> 'none'
    group by c.organism_detected
    order by max(c.cfu_count) desc;
end; $$;

-- RPC 5: correlation worn-brush -> contamination
create or replace function founder_worn_brush_contam_correlation_r3071()
returns table(chain_code text, breach_scopes int, contam_events_from_worn_brush int, patient_exposure int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select b.chain_code,
           (count(distinct b.endoscope_serial) filter (where b.wear_threshold_breach))::int,
           (count(c.id) filter (where c.root_cause = 'worn_brush'))::int,
           coalesce(sum(c.patient_exposure_count) filter (where c.root_cause = 'worn_brush'), 0)::int
    from ent_endoscope_brush_wear_r3071 b
    left join ent_endoscope_cross_contam_r3071 c on c.endoscope_serial = b.endoscope_serial and c.chain_code = b.chain_code
    group by b.chain_code
    order by (count(c.id) filter (where c.root_cause = 'worn_brush')) desc;
end; $$;

-- RPC 6: open quarantines
create or replace function founder_open_quarantines_r3071()
returns table(chain_code text, hospital_site text, endoscope_serial text, organism_detected text, cfu_count int, swab_taken_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.chain_code, c.hospital_site, c.endoscope_serial, c.organism_detected, c.cfu_count, c.swab_taken_at
    from ent_endoscope_cross_contam_r3071 c
    where c.quarantine_initiated and c.resolved_at is null
    order by c.cfu_count desc;
end; $$;

-- RPC 7: channel-type risk profile
create or replace function founder_channel_type_risk_profile_r3071()
returns table(channel_type text, scopes int, avg_bristle_loss numeric, red_or_critical_swabs int, total_exposure int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select b.channel_type,
           count(distinct b.endoscope_serial)::int,
           round(avg(b.bristle_loss_pct), 2),
           (count(c.id) filter (where c.risk_tier in ('red','critical')))::int,
           coalesce(sum(c.patient_exposure_count) filter (where c.risk_tier in ('red','critical')), 0)::int
    from ent_endoscope_brush_wear_r3071 b
    left join ent_endoscope_cross_contam_r3071 c on c.channel_type = b.channel_type and c.chain_code = b.chain_code
    group by b.channel_type
    order by (count(c.id) filter (where c.risk_tier in ('red','critical'))) desc;
end; $$;

revoke all on function founder_brush_wear_chain_summary_r3071() from public, anon;
revoke all on function founder_brush_overdue_replacements_r3071() from public, anon;
revoke all on function founder_contam_risk_rollup_r3071() from public, anon;
revoke all on function founder_contam_organism_breakdown_r3071() from public, anon;
revoke all on function founder_worn_brush_contam_correlation_r3071() from public, anon;
revoke all on function founder_open_quarantines_r3071() from public, anon;
revoke all on function founder_channel_type_risk_profile_r3071() from public, anon;

grant execute on function founder_brush_wear_chain_summary_r3071() to authenticated;
grant execute on function founder_brush_overdue_replacements_r3071() to authenticated;
grant execute on function founder_contam_risk_rollup_r3071() to authenticated;
grant execute on function founder_contam_organism_breakdown_r3071() to authenticated;
grant execute on function founder_worn_brush_contam_correlation_r3071() to authenticated;
grant execute on function founder_open_quarantines_r3071() to authenticated;
grant execute on function founder_channel_type_risk_profile_r3071() to authenticated;
