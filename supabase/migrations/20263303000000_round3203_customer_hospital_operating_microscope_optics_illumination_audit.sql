-- Round 3203: Customer Hospital Operating-Microscope & Loupe Optics-Illumination Audit
-- Microscope QA — specialty scope × magnification steps × illumination lux × lamp hours × balance-arm drift × focus/zoom motor × drape fit × fungus check × CAPA

-- =============================================================================
-- TABLE 1: op_microscope_r3203 — individual operating-microscope audit runs
-- =============================================================================
create table if not exists public.op_microscope_r3203 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ot_room_code text not null,
  scope_asset_tag text not null,
  microscope_model text not null,
  scope_specialty text not null check (scope_specialty in (
    'ent','ophthalmic','neuro','dental','plastic_reconstructive','spine'
  )),
  audit_date date not null,
  magnification_steps_ok boolean not null default true,
  magnification_range text,
  illumination_lux int not null,
  illumination_verdict text check (illumination_verdict in (
    'adequate','dim','flicker','uneven_field','failed'
  )),
  lamp_type text not null check (lamp_type in (
    'xenon','led','halogen','dual_led_backup'
  )),
  lamp_hours_used int not null,
  lamp_hours_rated int,
  balance_arm_drift text check (balance_arm_drift in (
    'none','minor_drift','moderate_drift','severe_drift','locked_stiff'
  )),
  focus_zoom_motor text check (focus_zoom_motor in (
    'smooth','sluggish','intermittent','noisy','failed'
  )),
  sterile_drape_fit text check (sterile_drape_fit in (
    'good_fit','loose_fit','tears_observed','wrong_size','not_assessed'
  )),
  fungus_check text check (fungus_check in (
    'clear','early_spots','fungus_confirmed','cleaned_recheck','not_checked'
  )),
  auditor_profile_id uuid references public.profiles(id) on delete set null,
  audit_verdict text not null check (audit_verdict in (
    'fit_for_use','restricted_use','needs_service','condemned','pending_parts','recheck_scheduled'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.op_microscope_r3203 enable row level security;

create index if not exists idx_op_microscope_r3203_org on public.op_microscope_r3203(organization_id);
create index if not exists idx_op_microscope_r3203_date on public.op_microscope_r3203(audit_date);
create index if not exists idx_op_microscope_r3203_verdict on public.op_microscope_r3203(audit_verdict);

-- =============================================================================
-- TABLE 2: op_microscope_capa_actions_r3203 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.op_microscope_capa_actions_r3203 (
  id uuid primary key default gen_random_uuid(),
  microscope_audit_id uuid not null references public.op_microscope_r3203(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'fungus_growth','lamp_end_of_life','illumination_low','balance_arm_fault',
    'motor_fault','drape_mismatch','optics_scratch','magnification_fault',
    'preventive_maintenance_due','operator_handling'
  )),
  root_cause text not null check (root_cause in (
    'humidity_ingress','seal_degraded','lamp_hours_exceeded','power_board_fault',
    'arm_tension_worn','gear_train_worn','wrong_consumable_stocked','handling_damage',
    'coating_delamination','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'anti_fungal_treatment','replace_lamp_module','replace_power_board','retension_balance_arm',
    'replace_zoom_gear','stock_correct_drapes','polish_recoat_optics','recalibrate_magnification',
    'schedule_amc_visit','retrain_staff','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.op_microscope_capa_actions_r3203 enable row level security;

create index if not exists idx_op_microscope_capa_r3203_audit on public.op_microscope_capa_actions_r3203(microscope_audit_id);
create index if not exists idx_op_microscope_capa_r3203_status on public.op_microscope_capa_actions_r3203(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 13 microscope audit rows
  insert into public.op_microscope_r3203 (
    organization_id, hospital_name, ot_room_code, scope_asset_tag, microscope_model,
    scope_specialty, audit_date, magnification_steps_ok, magnification_range,
    illumination_lux, illumination_verdict, lamp_type, lamp_hours_used, lamp_hours_rated,
    balance_arm_drift, focus_zoom_motor, sterile_drape_fit, fungus_check,
    audit_verdict, notes
  )
  select v_org_id, q.hosp, q.ot, q.tag, q.model,
    q.spec, q.ad::date, q.mago, q.magr,
    q.lux, q.ilv, q.lamp, q.lhu, q.lhr,
    q.bad, q.fzm, q.sdf, q.fng,
    q.vd, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','OT-7','OM-APL-101','Zeiss OPMI Lumera 700','ophthalmic','2026-07-02',true,'6x to 40x',
     82000,'adequate','xenon',412,500,'none','smooth','good_fit','clear','fit_for_use','Cataract suite scope — xenon at 82% life, plan lamp swap'),
    ('Apollo Hyderabad Jubilee Hills','OT-2','OM-APL-102','Zeiss OPMI Vario S88','neuro','2026-07-02',true,'2.4x to 16x',
     61000,'dim','xenon',498,500,'minor_drift','smooth','good_fit','clear','needs_service','Xenon at rated life — lux below neuro threshold'),
    ('Fortis Bannerghatta Bengaluru','OT-4','OM-FRT-201','Leica M530 OHX','neuro','2026-07-01',true,'2.5x to 15x',
     95000,'adequate','led',1650,60000,'none','smooth','good_fit','clear','fit_for_use','LED illumination excellent — annual PM done'),
    ('Fortis Bannerghatta Bengaluru','ENT-1','OM-FRT-202','Zeiss OPMI Sensera','ent','2026-07-01',false,'6x step jump fault',
     54000,'uneven_field','halogen',890,1000,'moderate_drift','sluggish','loose_fit','early_spots','restricted_use','Magnification changer sticking at 10x step — mastoid list only'),
    ('Manipal Whitefield Bengaluru','OT-3','OM-MNP-301','Leica M320 F12','dental','2026-06-30',true,'6.4x to 40x',
     38000,'dim','led',5200,60000,'none','smooth','wrong_size','clear','restricted_use','LED driver derated — implant cases moved to OT-5 scope'),
    ('Manipal Whitefield Bengaluru','OT-5','OM-MNP-302','Zeiss OPMI Pico','dental','2026-06-30',true,'4x to 25x',
     47000,'adequate','led',2100,50000,'none','smooth','good_fit','clear','fit_for_use','Routine quarterly audit clean'),
    ('AIIMS New Delhi Ansari Nagar','OT-9','OM-AIM-401','Zeiss KINEVO 900','neuro','2026-06-29',true,'2x to 20x',
     102000,'adequate','xenon',122,500,'none','smooth','good_fit','clear','fit_for_use','Robotic scope — all QA points passed'),
    ('AIIMS New Delhi Ansari Nagar','ENT-2','OM-AIM-402','Karl Kaps SOM 62','ent','2026-06-29',true,'5x to 30x',
     29000,'failed','halogen',1040,1000,'severe_drift','intermittent','tears_observed','fungus_confirmed','condemned','Fungus on beam splitter + halogen past life — board approval to condemn'),
    ('KIMS Secunderabad','OT-1','OM-KIM-501','Zeiss OPMI Lumera T','ophthalmic','2026-06-28',true,'5x to 33x',
     76000,'flicker','xenon',465,500,'minor_drift','smooth','good_fit','early_spots','needs_service','Flicker at max illumination — igniter suspected; fungal spots on eyepiece'),
    ('Care Hospitals Banjara Hills','OT-6','OM-CAR-601','Leica M844 F40','ophthalmic','2026-06-28',true,'3.5x to 21x',
     88000,'adequate','xenon',233,400,'none','smooth','good_fit','clear','fit_for_use','Retina suite scope healthy'),
    ('Yashoda Somajiguda Hyderabad','OT-2','OM-YSH-701','Zeiss OPMI Vario 700','plastic_reconstructive','2026-06-27',true,'4.7x to 28x',
     69000,'adequate','xenon',388,500,'moderate_drift','noisy','good_fit','clear','recheck_scheduled','Balance arm sags mid-case; zoom motor whine — recheck after retension'),
    ('St John''s Bengaluru','OT-8','OM-STJ-801','Leica M525 F50','spine','2026-06-27',true,'2.5x to 15x',
     91000,'adequate','led',980,60000,'none','smooth','good_fit','clear','fit_for_use','Spine scope post-PM verification passed'),
    ('Rainbow Children''s Hyderabad','OT-3','OM-RBW-901','Zeiss OPMI Pentero 800','neuro','2026-06-26',false,'zoom stuck at 8x',
     72000,'adequate','xenon',301,500,'minor_drift','failed','not_assessed','not_checked','pending_parts','Zoom motor failed mid-audit — gear kit on order from Zeiss')
  ) as q(hosp, ot, tag, model, spec, ad, mago, magr, lux, ilv, lamp, lhu, lhr, bad, fzm, sdf, fng, vd, nt);

  -- CAPA seed — attach to specific audited scopes by asset tag
  insert into public.op_microscope_capa_actions_r3203 (
    microscope_audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('OM-AIM-402','fungus_growth','humidity_ingress','anti_fungal_treatment','2026-07-08',null,'escalated','patient_safety_alert',185000.00,'Beam splitter fungus beyond cleaning — condemnation board notified'),
    ('OM-APL-102','lamp_end_of_life','lamp_hours_exceeded','replace_lamp_module','2026-07-06',null,'in_progress','internal_only',68000.00,'Xenon module quoted by Zeiss — PO raised'),
    ('OM-FRT-202','magnification_fault','gear_train_worn','recalibrate_magnification','2026-07-09',null,'open','nabh_finding',24000.00,'Changer detent worn — service visit booked'),
    ('OM-KIM-501','illumination_low','power_board_fault','replace_power_board','2026-07-04','2026-07-03','closed','iso_13485_deviation',41000.50,'Igniter board swapped — flicker resolved on retest'),
    ('OM-YSH-701','balance_arm_fault','arm_tension_worn','retension_balance_arm','2026-07-05',null,'verification_pending','internal_only',9500.00,'Arm retensioned — recheck audit scheduled'),
    ('OM-RBW-901','motor_fault','gear_train_worn','replace_zoom_gear','2026-06-30',null,'overdue','cdsco_notifiable',57500.00,'Gear kit shipment delayed — paediatric neuro list impacted'),
    ('OM-MNP-301','drape_mismatch','wrong_consumable_stocked','stock_correct_drapes','2026-07-03','2026-07-02','closed','none',3200.00,'Correct Leica drape SKU restocked')
  ) as q(tag, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.op_microscope_r3203 e
    on e.organization_id = v_org_id and e.scope_asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3203_audit_verdict_rollup()
returns table(audit_verdict text, scopes bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.op_microscope_r3203)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.op_microscope_r3203 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3203_audit_verdict_rollup() from public, anon;
grant execute on function public.founder_r3203_audit_verdict_rollup() to authenticated;

-- 2) Hospital-level optics scorecard
create or replace function public.founder_r3203_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  fit_for_use bigint,
  restricted bigint,
  condemned bigint,
  fungus_hits bigint,
  lamp_over_80pct bigint,
  avg_illumination_lux numeric,
  fit_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'fit_for_use')::bigint,
    count(*) filter (where l.audit_verdict = 'restricted_use')::bigint,
    count(*) filter (where l.audit_verdict = 'condemned')::bigint,
    count(*) filter (where l.fungus_check in ('early_spots','fungus_confirmed'))::bigint,
    count(*) filter (where l.lamp_hours_rated is not null
      and l.lamp_hours_used::numeric >= 0.8 * l.lamp_hours_rated::numeric)::bigint,
    round(avg(l.illumination_lux)::numeric, 0),
    round(100.0 * count(*) filter (where l.audit_verdict = 'fit_for_use')::numeric / nullif(count(*),0), 1)
  from public.op_microscope_r3203 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3203_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3203_hospital_scorecard() to authenticated;

-- 3) Specialty × lamp-type matrix
create or replace function public.founder_r3203_specialty_lamp_matrix()
returns table(scope_specialty text, lamp_type text, audits bigint, fit_for_use bigint, avg_lux numeric, avg_lamp_life_used_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.scope_specialty, l.lamp_type, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'fit_for_use')::bigint,
    round(avg(l.illumination_lux)::numeric, 0),
    round(avg(100.0 * l.lamp_hours_used::numeric / nullif(l.lamp_hours_rated,0)), 1)
  from public.op_microscope_r3203 l
  group by l.scope_specialty, l.lamp_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3203_specialty_lamp_matrix() from public, anon;
grant execute on function public.founder_r3203_specialty_lamp_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3203_daily_audit_trend()
returns table(audit_date date, audits bigint, fit_for_use bigint, needs_service bigint, fungus_flagged bigint, avg_lux numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'fit_for_use')::bigint,
    count(*) filter (where l.audit_verdict = 'needs_service')::bigint,
    count(*) filter (where l.fungus_check in ('early_spots','fungus_confirmed'))::bigint,
    round(avg(l.illumination_lux)::numeric, 0)
  from public.op_microscope_r3203 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3203_daily_audit_trend() from public, anon;
grant execute on function public.founder_r3203_daily_audit_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3203_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_or_escalated bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.op_microscope_capa_actions_r3203 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3203_capa_status_board() from public, anon;
grant execute on function public.founder_r3203_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3203_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.op_microscope_capa_actions_r3203)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.op_microscope_capa_actions_r3203 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3203_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3203_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3203_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.op_microscope_capa_actions_r3203 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3203_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3203_regulatory_impact_digest() to authenticated;

-- 8) High-risk scopes queue (top individual concerns)
create or replace function public.founder_r3203_high_risk_scopes()
returns table(
  hospital_name text,
  ot_room_code text,
  scope_asset_tag text,
  audit_date date,
  audit_verdict text,
  fungus_check text,
  focus_zoom_motor text,
  illumination_verdict text,
  lamp_life_used_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ot_room_code, l.scope_asset_tag, l.audit_date,
    l.audit_verdict, l.fungus_check, l.focus_zoom_motor, l.illumination_verdict,
    round(100.0 * l.lamp_hours_used::numeric / nullif(l.lamp_hours_rated,0), 1),
    l.notes
  from public.op_microscope_r3203 l
  where l.audit_verdict in ('restricted_use','needs_service','condemned','pending_parts','recheck_scheduled')
     or l.fungus_check in ('early_spots','fungus_confirmed')
     or l.focus_zoom_motor in ('intermittent','failed')
     or l.illumination_verdict in ('flicker','failed')
     or not l.magnification_steps_ok
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3203_high_risk_scopes() from public, anon;
grant execute on function public.founder_r3203_high_risk_scopes() to authenticated;
