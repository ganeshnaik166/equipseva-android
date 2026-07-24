-- Round 3392: Engineer IFU / Instructions-for-Use & Training-Material Version-Currency Tracker
-- Field IFU currency — equipment × IFU language × site vs latest OEM version × training-material currency × recall-related × safety-critical × CAPA

-- =============================================================================
-- TABLE 1: ifu_version_currency_r3392 — per site/equipment IFU currency checks
-- =============================================================================
create table if not exists public.ifu_version_currency_r3392 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  region text not null check (region in ('north','south','east','west','central')),
  equipment_type text not null check (equipment_type in (
    'patient_monitor','ventilator','infusion_pump','imaging','dialysis','lab_analyzer','defibrillator','anesthesia'
  )),
  ifu_document_ref text not null,
  ifu_language text not null check (ifu_language in (
    'english','hindi','regional','multilingual'
  )),
  current_version_at_site text not null,
  latest_oem_version text not null,
  version_current boolean not null,
  ifu_available_at_site boolean not null,
  training_material_current boolean not null,
  staff_trained_on_current boolean not null,
  recall_related_update boolean not null,
  days_since_oem_update int not null,
  safety_critical_update boolean not null,
  currency_verdict text not null check (currency_verdict in (
    'current','update_pending','outdated_at_risk','recall_critical','not_available'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ifu_version_currency_r3392 enable row level security;

create index if not exists idx_ifu_version_currency_r3392_org on public.ifu_version_currency_r3392(organization_id);
create index if not exists idx_ifu_version_currency_r3392_verdict on public.ifu_version_currency_r3392(currency_verdict);

-- =============================================================================
-- TABLE 2: ifu_version_currency_capa_actions_r3392 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ifu_version_currency_capa_actions_r3392 (
  id uuid primary key default gen_random_uuid(),
  ifu_log_id uuid not null references public.ifu_version_currency_r3392(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'outdated_ifu','missing_ifu','training_material_outdated','staff_not_trained',
    'recall_update_pending','language_gap','safety_critical_update_pending','version_mismatch'
  )),
  root_cause text not null check (root_cause in (
    'oem_update_not_distributed','site_copy_not_replaced','training_backlog','translation_pending',
    'recall_notice_not_actioned','operator_change','pending_investigation','distribution_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'distribute_latest_ifu','replace_site_copy','deliver_refresher_training','commission_translation',
    'action_recall_update','notify_users','schedule_reissue','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ifu_version_currency_capa_actions_r3392 enable row level security;

create index if not exists idx_ifu_version_capa_r3392_log on public.ifu_version_currency_capa_actions_r3392(ifu_log_id);
create index if not exists idx_ifu_version_capa_r3392_status on public.ifu_version_currency_capa_actions_r3392(capa_status);

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

  insert into public.ifu_version_currency_r3392 (
    organization_id, engineer_name, hospital_name, region, equipment_type, ifu_document_ref, ifu_language,
    current_version_at_site, latest_oem_version, version_current, ifu_available_at_site,
    training_material_current, staff_trained_on_current, recall_related_update,
    days_since_oem_update, safety_critical_update, currency_verdict, notes
  )
  select v_org_id, q.eng, q.hosp, q.region, q.etype, q.ref, q.lang,
    q.curv, q.latv, q.vcur, q.avail,
    q.tmcur, q.trained, q.recall,
    q.days::int, q.safety, q.cv, q.nt
  from (values
    ('Ravi Kumar','Apollo Chennai','south','patient_monitor','IFU-PM-2201','english','v3.2','v3.2',true,true,true,true,false,20,false,'current','IFU and training current, staff trained on v3.2'),
    ('Ravi Kumar','Apollo Chennai','south','ventilator','IFU-VNT-1180','multilingual','v5.1','v5.1',true,true,true,true,false,35,false,'current','Ventilator IFU current across languages'),
    ('Anita Desai','Fortis Gurgaon','north','infusion_pump','IFU-INF-3320','english','v2.0','v2.3',false,true,true,false,false,60,false,'update_pending','Site on v2.0, OEM v2.3 available — reissue and retrain pending'),
    ('Anita Desai','Fortis Gurgaon','north','imaging','IFU-IMG-4410','english','v6.0','v6.4',false,true,false,false,true,95,true,'outdated_at_risk','Imaging IFU 95d behind with safety-critical update; training outdated'),
    ('Suresh Nair','Manipal Bengaluru','south','dialysis','IFU-DIA-2270','regional','v4.1','v4.1',true,false,true,true,false,15,false,'not_available','Latest IFU version but physical copy not available at site'),
    ('Suresh Nair','Manipal Bengaluru','south','defibrillator','IFU-DEF-1120','english','v3.0','v3.0',true,true,true,true,false,10,false,'current','Defibrillator IFU current, staff trained'),
    ('Priya Menon','AIIMS Delhi','central','lab_analyzer','IFU-LAB-5510','english','v7.2','v7.5',false,true,true,true,true,40,false,'recall_critical','Recall-related IFU update pending action — high priority'),
    ('Priya Menon','AIIMS Delhi','central','anesthesia','IFU-ANE-3390','multilingual','v4.4','v4.4',true,true,true,true,false,25,false,'current','Anesthesia workstation IFU current'),
    ('Vikram Rao','CMC Vellore','south','patient_monitor','IFU-PM-2202','english','v3.2','v3.2',true,true,true,true,false,18,false,'current','Patient monitor IFU current at CMC'),
    ('Vikram Rao','CMC Vellore','south','ventilator','IFU-VNT-1181','regional','v5.0','v5.1',false,true,false,false,false,55,false,'update_pending','Regional-language ventilator IFU update + training pending'),
    ('Deepa Iyer','KIMS Hyderabad','south','imaging','IFU-IMG-4411','english','v6.4','v6.4',true,true,true,true,false,22,false,'current','Imaging IFU current post-update'),
    ('Deepa Iyer','KIMS Hyderabad','south','infusion_pump','IFU-INF-3321','english','v2.3','v2.3',true,true,false,false,false,48,false,'update_pending','Infusion pump IFU current but training material outdated — refresh due'),
    ('Arjun Shah','Yashoda Hyderabad','south','dialysis','IFU-DIA-2271','english','v4.1','v4.1',true,true,true,true,false,12,false,'current','Dialysis IFU current'),
    ('Arjun Shah','Kokilaben Mumbai','west','defibrillator','IFU-DEF-1121','english','v2.5','v3.0',false,false,false,false,true,120,true,'recall_critical','Defibrillator recall IFU not at site, safety-critical, 120d behind — escalate')
  ) as q(eng, hosp, region, etype, ref, lang, curv, latv, vcur, avail, tmcur, trained, recall, days, safety, cv, nt);

  insert into public.ifu_version_currency_capa_actions_r3392 (
    ifu_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('IFU-IMG-4410','safety_critical_update_pending','oem_update_not_distributed','distribute_latest_ifu','in_progress','patient_safety_alert','2026-07-06',null,3000.00,'Safety-critical imaging IFU distribution and retraining underway'),
    ('IFU-LAB-5510','recall_update_pending','recall_notice_not_actioned','action_recall_update','escalated','cdsco_notifiable','2026-07-04',null,5000.00,'Recall IFU update escalated — action on all affected units'),
    ('IFU-DEF-1121','recall_update_pending','recall_notice_not_actioned','action_recall_update','open','patient_safety_alert','2026-07-05',null,4500.00,'Defibrillator recall IFU missing at site — reissue + notify users'),
    ('IFU-INF-3320','outdated_ifu','site_copy_not_replaced','replace_site_copy','verification_pending','internal_only','2026-07-05',null,1500.00,'Infusion pump IFU v2.3 reissued — verify retraining'),
    ('IFU-VNT-1181','training_material_outdated','translation_pending','commission_translation','overdue','internal_only','2026-06-30',null,8000.00,'Regional-language ventilator training material past target'),
    ('IFU-DIA-2270','missing_ifu','distribution_gap','distribute_latest_ifu','open','nabh_finding','2026-07-07',null,1200.00,'Dialysis IFU physical copy to be placed at site'),
    ('IFU-INF-3321','training_material_outdated','training_backlog','deliver_refresher_training','open','none','2026-07-08',null,2500.00,'Infusion pump refresher training scheduled')
  ) as q(ref, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ifu_version_currency_r3392 e
    on e.organization_id = v_org_id and e.ifu_document_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

create or replace function public.founder_r3392_currency_verdict_rollup()
returns table(currency_verdict text, records bigint, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ifu_version_currency_r3392)
  select l.currency_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ifu_version_currency_r3392 l group by l.currency_verdict order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3392_currency_verdict_rollup() from public, anon;
grant execute on function public.founder_r3392_currency_verdict_rollup() to authenticated;

create or replace function public.founder_r3392_region_scorecard()
returns table(
  region text, total_records bigint, current_count bigint, update_pending bigint, at_risk bigint,
  recall_critical bigint, not_available bigint, safety_critical bigint, current_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region, count(*)::bigint,
    count(*) filter (where l.currency_verdict = 'current')::bigint,
    count(*) filter (where l.currency_verdict = 'update_pending')::bigint,
    count(*) filter (where l.currency_verdict = 'outdated_at_risk')::bigint,
    count(*) filter (where l.currency_verdict = 'recall_critical')::bigint,
    count(*) filter (where l.currency_verdict = 'not_available')::bigint,
    count(*) filter (where l.safety_critical_update = true)::bigint,
    round(100.0 * count(*) filter (where l.currency_verdict = 'current')::numeric / nullif(count(*),0), 1)
  from public.ifu_version_currency_r3392 l group by l.region order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3392_region_scorecard() from public, anon;
grant execute on function public.founder_r3392_region_scorecard() to authenticated;

create or replace function public.founder_r3392_equipment_language_matrix()
returns table(equipment_type text, ifu_language text, records bigint, current_count bigint, outdated_count bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.ifu_language, count(*)::bigint,
    count(*) filter (where l.version_current = true)::bigint,
    count(*) filter (where l.version_current = false)::bigint
  from public.ifu_version_currency_r3392 l group by l.equipment_type, l.ifu_language order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3392_equipment_language_matrix() from public, anon;
grant execute on function public.founder_r3392_equipment_language_matrix() to authenticated;

create or replace function public.founder_r3392_staleness_trend()
returns table(days_bucket text, records bigint, at_risk bigint, safety_critical bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    case
      when l.days_since_oem_update <= 30 then '0_30'
      when l.days_since_oem_update <= 60 then '31_60'
      when l.days_since_oem_update <= 90 then '61_90'
      else 'over_90'
    end as days_bucket,
    count(*)::bigint,
    count(*) filter (where l.currency_verdict in ('outdated_at_risk','recall_critical'))::bigint,
    count(*) filter (where l.safety_critical_update = true)::bigint
  from public.ifu_version_currency_r3392 l
  group by 1 order by 1;
end;
$$;
revoke execute on function public.founder_r3392_staleness_trend() from public, anon;
grant execute on function public.founder_r3392_staleness_trend() to authenticated;

create or replace function public.founder_r3392_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.ifu_version_currency_capa_actions_r3392 c group by c.capa_status order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3392_capa_status_board() from public, anon;
grant execute on function public.founder_r3392_capa_status_board() to authenticated;

create or replace function public.founder_r3392_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ifu_version_currency_capa_actions_r3392)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ifu_version_currency_capa_actions_r3392 c group by c.root_cause order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3392_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3392_root_cause_pareto() to authenticated;

create or replace function public.founder_r3392_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.ifu_version_currency_capa_actions_r3392 c group by c.regulatory_impact order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3392_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3392_regulatory_impact_digest() to authenticated;

create or replace function public.founder_r3392_high_risk_queue()
returns table(
  hospital_name text, engineer_name text, equipment_type text, ifu_document_ref text, region text,
  current_version_at_site text, latest_oem_version text, currency_verdict text, days_since_oem_update int, notes text
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.equipment_type, l.ifu_document_ref, l.region,
    l.current_version_at_site, l.latest_oem_version, l.currency_verdict, l.days_since_oem_update, l.notes
  from public.ifu_version_currency_r3392 l
  where l.currency_verdict in ('update_pending','outdated_at_risk','recall_critical','not_available')
     or l.version_current = false
     or l.ifu_available_at_site = false
     or l.training_material_current = false
     or l.staff_trained_on_current = false
     or l.safety_critical_update = true
  order by
    case l.currency_verdict when 'recall_critical' then 0 when 'outdated_at_risk' then 1 when 'not_available' then 2 else 3 end,
    l.days_since_oem_update desc;
end;
$$;
revoke execute on function public.founder_r3392_high_risk_queue() from public, anon;
grant execute on function public.founder_r3392_high_risk_queue() to authenticated;
