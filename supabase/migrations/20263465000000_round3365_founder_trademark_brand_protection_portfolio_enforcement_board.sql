-- Round 3365: Founder Trademark, Brand-Protection Portfolio & Enforcement Board
-- IP/brand governance — asset type × jurisdiction × registration status × renewal timeline × infringement matter × enforcement status × exposure × brand verdict × CAPA

-- =============================================================================
-- TABLE 1: trademark_brand_r3365 — per trademark asset / brand-protection matter
-- =============================================================================
create table if not exists public.trademark_brand_r3365 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  asset_name text not null,
  asset_type text not null check (asset_type in (
    'wordmark','logo_device','tagline','domain_name','social_handle','product_brand'
  )),
  jurisdiction text not null check (jurisdiction in (
    'india_ipindia','madrid_international','usa','uae','singapore'
  )),
  registration_status text not null check (registration_status in (
    'registered','applied_pending','opposed','objected','expired','abandoned'
  )),
  class_or_scope text not null,
  filing_date date not null,
  renewal_due_date date,
  days_to_renewal int,
  infringement_matter text not null check (infringement_matter in (
    'none','opposition_filed','domain_squat','counterfeit_seller','passing_off','cease_desist_sent'
  )),
  enforcement_status text not null check (enforcement_status in (
    'no_action','monitoring','notice_sent','takedown_filed','litigation','resolved'
  )),
  estimated_exposure_rupees numeric(14,2),
  brand_verdict text not null check (brand_verdict in (
    'protected','renewal_action','opposition_response','enforcement_needed','lapse_risk','escalate'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.trademark_brand_r3365 enable row level security;

create index if not exists idx_trademark_brand_r3365_org on public.trademark_brand_r3365(organization_id);
create index if not exists idx_trademark_brand_r3365_renewal on public.trademark_brand_r3365(renewal_due_date);
create index if not exists idx_trademark_brand_r3365_verdict on public.trademark_brand_r3365(brand_verdict);

-- =============================================================================
-- TABLE 2: trademark_brand_capa_actions_r3365 — CAPA & enforcement actions
-- =============================================================================
create table if not exists public.trademark_brand_capa_actions_r3365 (
  id uuid primary key default gen_random_uuid(),
  matter_id uuid not null references public.trademark_brand_r3365(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'renewal_lapse_risk','opposition_response_due','domain_squat_recovery','counterfeit_enforcement',
    'passing_off_matter','prosecution_delay','monitoring_gap'
  )),
  root_cause text not null check (root_cause in (
    'missed_renewal_docket','third_party_bad_faith_filing','cybersquatter_registration','grey_market_import',
    'examiner_objection','agent_docket_error','no_watch_service','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'file_renewal','file_opposition_counterstatement','file_udrp_complaint','send_cease_desist',
    'file_takedown_notice','file_infringement_suit','respond_to_examination','engage_watch_service',
    'escalate_to_board','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  legal_impact text not null check (legal_impact in (
    'registration_loss','brand_dilution','revenue_leakage','litigation_exposure','none','reputational_risk'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.trademark_brand_capa_actions_r3365 enable row level security;

create index if not exists idx_trademark_capa_r3365_matter on public.trademark_brand_capa_actions_r3365(matter_id);
create index if not exists idx_trademark_capa_r3365_status on public.trademark_brand_capa_actions_r3365(capa_status);

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

  -- 14 trademark / brand-protection asset rows
  insert into public.trademark_brand_r3365 (
    organization_id, asset_name, asset_type, jurisdiction, registration_status,
    class_or_scope, filing_date, renewal_due_date, days_to_renewal,
    infringement_matter, enforcement_status, estimated_exposure_rupees, brand_verdict, notes
  )
  select v_org_id, q.name, q.atype, q.juris, q.rstatus,
    q.scope, q.fdate::date, q.rdue::date, q.dtr::int,
    q.imatter, q.estatus, q.exposure::numeric, q.verdict, q.nt
  from (values
    ('EquipSeva','wordmark','india_ipindia','registered','class_37_repair_maintenance',
     '2019-03-12','2029-03-12',967,'none','no_action',0.00,'protected','Core wordmark under class 37; renewal well clear of window'),
    ('EquipSeva Gear Logo','logo_device','india_ipindia','registered','class_09_class_37_device',
     '2016-08-01','2026-11-05',109,'none','no_action',0.00,'renewal_action','Device mark renewal due in 109 days — file TM-R renewal docket'),
    ('EquipSeva','wordmark','madrid_international','applied_pending','class_37_intl_madrid',
     '2024-05-20','2034-05-20',2862,'opposition_filed','notice_sent',450000.00,'opposition_response','Madrid designation opposed by EU medical-services mark — counterstatement due'),
    ('equipseva.in','domain_name','india_ipindia','registered','domain_ccTLD_in',
     '2018-01-10','2027-01-10',540,'domain_squat','monitoring',85000.00,'enforcement_needed','Cybersquatter holding equip-seva.in redirecting to competitor — INDRP prep'),
    ('SevaCare AMC','product_brand','india_ipindia','registered','class_37_amc_service_brand',
     '2021-06-15','2031-06-15',1793,'counterfeit_seller','takedown_filed',220000.00,'enforcement_needed','Grey-market seller offering fake SevaCare AMC contracts online — takedown filed'),
    ('Uptime Guaranteed','tagline','india_ipindia','objected','class_37_advertising_tagline',
     '2023-09-02','2033-09-02',2601,'none','no_action',0.00,'opposition_response','Examiner objection u/s 9 on descriptiveness — reply to exam report due'),
    ('@equipseva','social_handle','india_ipindia','applied_pending','handle_common_law_use',
     '2020-02-14','2030-02-14',1305,'passing_off','notice_sent',30000.00,'enforcement_needed','Imposter Instagram handle @equip.seva soliciting deposits — platform notice sent'),
    ('EquipSeva','wordmark','usa','applied_pending','class_37_uspto_intl',
     '2025-01-08','2035-01-08',3095,'none','no_action',0.00,'protected','USPTO application in examination — no office action raised yet'),
    ('EquipSeva','wordmark','uae','registered','class_37_uae',
     '2015-11-20','2026-08-10',22,'none','monitoring',150000.00,'lapse_risk','UAE renewal in 22 days — agent docket delayed, lapse risk high'),
    ('EquipSeva','wordmark','singapore','expired','class_37_singapore',
     '2014-04-01','2024-04-01',-475,'none','no_action',120000.00,'lapse_risk','Singapore mark lapsed 2024 — restoration window closing, decide refile'),
    ('EquipSeva Gear Logo','logo_device','madrid_international','registered','class_09_class_37_madrid',
     '2022-07-11','2032-07-11',2184,'none','no_action',0.00,'protected','Madrid device registration granted across 4 designations — clean'),
    ('PartsPantry','product_brand','india_ipindia','opposed','class_35_spares_ecommerce',
     '2023-12-05','2033-12-05',2695,'opposition_filed','litigation',380000.00,'opposition_response','Third-party opposition by incumbent spares portal — hearing scheduled'),
    ('equipsevacare.com','domain_name','india_ipindia','abandoned','domain_defensive_gTLD',
     '2019-10-01','2025-10-01',-291,'cease_desist_sent','resolved',0.00,'protected','Defensive domain let lapse intentionally; squat attempt resolved via registrar'),
    ('Repairs Made Simple','tagline','india_ipindia','registered','class_37_tagline',
     '2020-12-18','2026-12-18',152,'none','no_action',0.00,'renewal_action','Tagline renewal due in 152 days — bundle with device-mark renewal')
  ) as q(name, atype, juris, rstatus, scope, fdate, rdue, dtr, imatter, estatus, exposure, verdict, nt);

  -- CAPA seed — attach to specific at-risk assets via (asset_name, jurisdiction)
  insert into public.trademark_brand_capa_actions_r3365 (
    matter_id, finding_category, root_cause, corrective_action,
    capa_status, legal_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.li, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('EquipSeva Gear Logo','india_ipindia','renewal_lapse_risk','agent_docket_error','file_renewal','in_progress','registration_loss','2026-10-20',null,45000.00,'Renewal form TM-R prepared; awaiting agent filing before 105-day window'),
    ('EquipSeva','madrid_international','opposition_response_due','third_party_bad_faith_filing','file_opposition_counterstatement','open','litigation_exposure','2026-08-30',null,450000.00,'Counterstatement drafting with WIPO counsel; deadline 2026-08-30'),
    ('equipseva.in','india_ipindia','domain_squat_recovery','cybersquatter_registration','file_udrp_complaint','escalated','brand_dilution','2026-09-15',null,85000.00,'INDRP complaint with NIXI being filed against squatter; evidence collated'),
    ('SevaCare AMC','india_ipindia','counterfeit_enforcement','grey_market_import','file_takedown_notice','in_progress','revenue_leakage','2026-08-05',null,220000.00,'Marketplace takedown filed; 3 fake listings removed, monitoring for reposts'),
    ('EquipSeva','uae','renewal_lapse_risk','missed_renewal_docket','file_renewal','overdue','registration_loss','2026-08-10',null,150000.00,'UAE renewal overdue on agent side — escalate to avoid lapse and grace-fee'),
    ('EquipSeva','singapore','prosecution_delay','no_watch_service','engage_watch_service','closed','none','2026-06-30','2026-06-25',60000.00,'Board decided to refile fresh SG application; watch service engaged, matter closed'),
    ('PartsPantry','india_ipindia','opposition_response_due','third_party_bad_faith_filing','file_infringement_suit','escalated','litigation_exposure','2026-10-01',null,380000.00,'Hearing prep; parallel infringement suit evaluated with external counsel')
  ) as q(aname, juris, fc, rc, ca, cst, li, tcd, acd, cost, nt)
  join public.trademark_brand_r3365 e
    on e.organization_id = v_org_id and e.asset_name = q.aname and e.jurisdiction = q.juris;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Brand verdict distribution
create or replace function public.founder_r3365_brand_verdict_rollup()
returns table(brand_verdict text, assets bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.trademark_brand_r3365)
  select l.brand_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.trademark_brand_r3365 l
  group by l.brand_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3365_brand_verdict_rollup() from public, anon;
grant execute on function public.founder_r3365_brand_verdict_rollup() to authenticated;

-- 2) Jurisdiction-level portfolio scorecard
create or replace function public.founder_r3365_jurisdiction_scorecard()
returns table(
  jurisdiction text,
  total_assets bigint,
  registered bigint,
  pending bigint,
  opposed bigint,
  expired_abandoned bigint,
  enforcement_open bigint,
  lapse_risk bigint,
  registered_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.jurisdiction,
    count(*)::bigint,
    count(*) filter (where l.registration_status = 'registered')::bigint,
    count(*) filter (where l.registration_status = 'applied_pending')::bigint,
    count(*) filter (where l.registration_status in ('opposed','objected'))::bigint,
    count(*) filter (where l.registration_status in ('expired','abandoned'))::bigint,
    count(*) filter (where l.enforcement_status in ('monitoring','notice_sent','takedown_filed','litigation'))::bigint,
    count(*) filter (where l.brand_verdict = 'lapse_risk')::bigint,
    round(100.0 * count(*) filter (where l.registration_status = 'registered')::numeric / nullif(count(*),0), 1)
  from public.trademark_brand_r3365 l
  group by l.jurisdiction
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3365_jurisdiction_scorecard() from public, anon;
grant execute on function public.founder_r3365_jurisdiction_scorecard() to authenticated;

-- 3) Asset-type × jurisdiction matrix
create or replace function public.founder_r3365_type_jurisdiction_matrix()
returns table(asset_type text, jurisdiction text, assets bigint, protected bigint, avg_days_to_renewal numeric, total_exposure_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_type, l.jurisdiction, count(*)::bigint,
    count(*) filter (where l.brand_verdict = 'protected')::bigint,
    round(avg(l.days_to_renewal), 0),
    coalesce(sum(l.estimated_exposure_rupees),0)::numeric
  from public.trademark_brand_r3365 l
  group by l.asset_type, l.jurisdiction
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3365_type_jurisdiction_matrix() from public, anon;
grant execute on function public.founder_r3365_type_jurisdiction_matrix() to authenticated;

-- 4) Renewal-due timeline trend
create or replace function public.founder_r3365_renewal_due_trend()
returns table(renewal_due_date date, assets bigint, renewal_action bigint, lapse_risk bigint, enforcement_needed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.renewal_due_date,
    count(*)::bigint,
    count(*) filter (where l.brand_verdict = 'renewal_action')::bigint,
    count(*) filter (where l.brand_verdict = 'lapse_risk')::bigint,
    count(*) filter (where l.brand_verdict = 'enforcement_needed')::bigint
  from public.trademark_brand_r3365 l
  group by l.renewal_due_date
  order by l.renewal_due_date asc;
end;
$$;

revoke execute on function public.founder_r3365_renewal_due_trend() from public, anon;
grant execute on function public.founder_r3365_renewal_due_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3365_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_flag bigint)
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
  from public.trademark_brand_capa_actions_r3365 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3365_capa_status_board() from public, anon;
grant execute on function public.founder_r3365_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3365_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.trademark_brand_capa_actions_r3365)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.trademark_brand_capa_actions_r3365 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3365_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3365_root_cause_pareto() to authenticated;

-- 7) Legal-impact digest
create or replace function public.founder_r3365_legal_impact_digest()
returns table(legal_impact text, actions bigint, open_actions bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.legal_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.trademark_brand_capa_actions_r3365 c
  group by c.legal_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3365_legal_impact_digest() from public, anon;
grant execute on function public.founder_r3365_legal_impact_digest() to authenticated;

-- 8) High-risk brand-protection queue
create or replace function public.founder_r3365_high_risk_queue()
returns table(
  asset_name text,
  asset_type text,
  jurisdiction text,
  registration_status text,
  renewal_due_date date,
  days_to_renewal int,
  infringement_matter text,
  enforcement_status text,
  brand_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_name, l.asset_type, l.jurisdiction, l.registration_status,
    l.renewal_due_date, l.days_to_renewal, l.infringement_matter, l.enforcement_status,
    l.brand_verdict, l.notes
  from public.trademark_brand_r3365 l
  where l.brand_verdict in ('renewal_action','opposition_response','enforcement_needed','lapse_risk','escalate')
     or l.infringement_matter <> 'none'
     or l.enforcement_status in ('notice_sent','takedown_filed','litigation')
     or l.registration_status in ('opposed','objected','expired','abandoned')
     or (l.days_to_renewal is not null and l.days_to_renewal < 120)
  order by l.days_to_renewal asc nulls last, l.asset_name;
end;
$$;

revoke execute on function public.founder_r3365_high_risk_queue() from public, anon;
grant execute on function public.founder_r3365_high_risk_queue() to authenticated;
