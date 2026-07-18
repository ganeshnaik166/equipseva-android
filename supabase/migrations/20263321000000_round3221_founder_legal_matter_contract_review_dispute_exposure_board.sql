-- Round 3221: Founder Legal Matter, Contract Review & Dispute Exposure Board
-- Legal board — matter type × counterparty × exposure × external counsel × hearing/deadline × resolution verdict × CAPA

-- =============================================================================
-- TABLE 1: legal_matter_r3221 — legal matters, contract reviews & disputes
-- =============================================================================
create table if not exists public.legal_matter_r3221 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  matter_ref text not null,
  matter_type text not null check (matter_type in (
    'contract_review','employment','customer_dispute','ip',
    'regulatory','vendor_dispute','insurance_claim','arbitration'
  )),
  counterparty_role text not null check (counterparty_role in (
    'customer_hospital','employee','vendor_oem','competitor',
    'regulator_cdsco','insurer','service_partner','landlord'
  )),
  matter_title text not null,
  exposure_amount_rupees numeric(12,2) not null,
  external_counsel_engaged boolean not null default false,
  external_counsel_firm text,
  opened_date date not null,
  next_deadline_date date,
  risk_rating text not null check (risk_rating in ('low','medium','high','critical')),
  matter_status text not null check (matter_status in (
    'open','under_review','negotiation','escalated_to_counsel',
    'hearing_scheduled','settled','closed','withdrawn'
  )),
  resolution_verdict text check (resolution_verdict in (
    'pending','settled_amicably','won','lost','contract_signed',
    'contract_terminated','consent_order','withdrawn_by_counterparty'
  )),
  resolved_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.legal_matter_r3221 enable row level security;

create index if not exists idx_legal_matter_r3221_org on public.legal_matter_r3221(organization_id);
create index if not exists idx_legal_matter_r3221_status on public.legal_matter_r3221(matter_status);
create index if not exists idx_legal_matter_r3221_deadline on public.legal_matter_r3221(next_deadline_date);

-- =============================================================================
-- TABLE 2: legal_matter_capa_actions_r3221 — follow-up / CAPA actions
-- =============================================================================
create table if not exists public.legal_matter_capa_actions_r3221 (
  id uuid primary key default gen_random_uuid(),
  matter_id uuid not null references public.legal_matter_r3221(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'missing_indemnity_cap','unfavorable_sla_penalty','ip_ownership_gap',
    'payment_term_breach','data_privacy_gap','regulatory_notice',
    'employee_grievance','contract_ambiguity','licence_lapse','warranty_scope_gap'
  )),
  root_cause text not null check (root_cause in (
    'no_legal_review_gate','template_outdated','ambiguous_scope_language',
    'delayed_escalation','hr_policy_gap','compliance_calendar_missing',
    'sales_negotiation_pressure','pending_investigation','process_not_followed','documentation_missing'
  )),
  corrective_action text not null check (corrective_action in (
    'update_contract_template','mandate_legal_review_gate','renegotiate_clause',
    'send_legal_notice','settle_out_of_court','update_hr_policy',
    'build_compliance_calendar','train_sales_team','file_counter_response','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cdsco_notifiable','labour_dept_notifiable','data_protection_board',
    'court_reportable','none','internal_only'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.legal_matter_capa_actions_r3221 enable row level security;

create index if not exists idx_legal_capa_r3221_matter on public.legal_matter_capa_actions_r3221(matter_id);
create index if not exists idx_legal_capa_r3221_status on public.legal_matter_capa_actions_r3221(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only
-- =============================================================================
do $$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 14 legal matter rows
  insert into public.legal_matter_r3221 (
    organization_id, hospital_name, matter_ref, matter_type, counterparty_role,
    matter_title, exposure_amount_rupees, external_counsel_engaged, external_counsel_firm,
    opened_date, next_deadline_date, risk_rating, matter_status,
    resolution_verdict, resolved_at, notes
  )
  select v_org_id, q.hosp, q.ref, q.mt, q.cp,
    q.title, q.exp, q.ec, q.firm,
    q.od::date, q.nd::date, q.rr, q.st,
    q.rv, q.ra::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','LM-3221-001','contract_review','customer_hospital',
     'AMC master agreement renewal — indemnity cap missing',2500000.00,true,'Khaitan & Co','2026-06-20','2026-07-25','high','escalated_to_counsel',null,null,'OEM pushing unlimited liability clause — counsel drafting capped-indemnity rider'),
    ('Apollo Hyderabad Jubilee Hills','LM-3221-002','customer_dispute','customer_hospital',
     'Disputed invoice on C-arm repair spares',480000.00,false,null,'2026-06-25','2026-07-20','medium','negotiation',null,null,'Hospital claims spares were covered under extended warranty'),
    ('Fortis Bannerghatta Bengaluru','LM-3221-003','customer_dispute','customer_hospital',
     'SLA penalty claim for ventilator fleet downtime',1200000.00,true,'Cyril Amarchand Mangaldas','2026-06-15','2026-08-04','critical','hearing_scheduled',null,null,'Arbitration hearing listed — downtime logs contested'),
    ('Fortis Bannerghatta Bengaluru','LM-3221-004','contract_review','customer_hospital',
     'Multi-site AMC consolidation draft review',3600000.00,false,null,'2026-07-01','2026-07-30','medium','under_review',null,null,'Revised uptime table and LD slab under legal check'),
    ('Manipal Whitefield Bengaluru','LM-3221-005','employment','employee',
     'Field engineer wrongful termination claim',850000.00,true,'Trilegal','2026-05-28','2026-07-22','high','escalated_to_counsel',null,null,'Labour court conciliation stage — notice pay disputed'),
    ('Manipal Whitefield Bengaluru','LM-3221-006','contract_review','vendor_oem',
     'Spare-parts distribution agreement with OEM',5400000.00,false,null,'2026-06-10',null,'low','closed','contract_signed','2026-07-05 11:00:00+05:30','Signed after two redline rounds — exclusivity dropped'),
    ('AIIMS New Delhi Ansari Nagar','LM-3221-007','regulatory','regulator_cdsco',
     'CDSCO show-cause on refurbished import labelling',2000000.00,true,'Khaitan & Co','2026-06-05','2026-07-21','critical','escalated_to_counsel',null,null,'Response drafted — awaiting counsel sign-off before filing'),
    ('AIIMS New Delhi Ansari Nagar','LM-3221-008','contract_review','customer_hospital',
     'Rate-contract tender terms review',7500000.00,false,null,'2026-06-28','2026-08-10','medium','under_review',null,null,'LD clause at 0.5 pct per week flagged as onerous'),
    ('KIMS Secunderabad','LM-3221-009','customer_dispute','customer_hospital',
     'Escrow release dispute on dialysis machine repair',320000.00,false,null,'2026-06-22','2026-07-19','medium','negotiation',null,null,'Hospital withheld release citing recurring fault after repair'),
    ('Care Hospitals Banjara Hills','LM-3221-010','ip','competitor',
     'Trademark opposition against lookalike service brand',1500000.00,true,'Anand and Anand','2026-05-15','2026-09-02','high','hearing_scheduled',null,null,'Opposition filed at Chennai registry — evidence stage'),
    ('Yashoda Somajiguda Hyderabad','LM-3221-011','employment','employee',
     'On-site engineer overtime wage claim',180000.00,false,null,'2026-06-18',null,'low','settled','settled_amicably','2026-07-10 15:30:00+05:30','Arrears paid with revised roster policy'),
    ('St John''s Bengaluru','LM-3221-012','contract_review','customer_hospital',
     'Data-processing addendum for ABDM integration',900000.00,false,null,'2026-07-02','2026-07-28','medium','under_review',null,null,'DPDP consent and breach-notice clauses under legal check'),
    ('Rainbow Children''s Hyderabad','LM-3221-013','customer_dispute','customer_hospital',
     'Warranty scope dispute on infant warmer probe',260000.00,false,null,'2026-06-30','2026-07-26','medium','open',null,null,'Hospital claims skin probe covered under warranty'),
    ('KIMS Secunderabad','LM-3221-014','regulatory','regulator_cdsco',
     'Biomedical waste authorisation renewal lapse',400000.00,false,null,'2026-06-12',null,'high','closed','consent_order','2026-07-08 12:00:00+05:30','Penalty paid — authorisation renewed with consent order')
  ) as q(hosp, ref, mt, cp, title, exp, ec, firm, od, nd, rr, st, rv, ra, nt);

  -- CAPA seed — attach to specific matters
  insert into public.legal_matter_capa_actions_r3221 (
    matter_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('LM-3221-001','missing_indemnity_cap','template_outdated','update_contract_template','2026-07-28',null,'in_progress','internal_only',150000.00,'Capped-indemnity master template rolled out to all new AMC deals'),
    ('LM-3221-003','unfavorable_sla_penalty','ambiguous_scope_language','renegotiate_clause','2026-08-05',null,'escalated','court_reportable',600000.00,'Downtime definition to exclude hospital-caused access delays'),
    ('LM-3221-005','employee_grievance','hr_policy_gap','update_hr_policy','2026-07-30',null,'in_progress','labour_dept_notifiable',85000.00,'Termination checklist and notice-pay matrix issued to HR'),
    ('LM-3221-007','regulatory_notice','compliance_calendar_missing','build_compliance_calendar','2026-07-25',null,'verification_pending','cdsco_notifiable',200000.00,'Import-labelling SOP drafted — CDSCO response filed'),
    ('LM-3221-011','employee_grievance','process_not_followed','settle_out_of_court','2026-07-12','2026-07-10','closed','none',180000.00,'Wage arrears settled — roster policy revised'),
    ('LM-3221-012','data_privacy_gap','no_legal_review_gate','mandate_legal_review_gate','2026-08-08',null,'open','data_protection_board',120000.00,'DPDP addendum checklist added to deal desk')
  ) as q(ref, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.legal_matter_r3221 e
    on e.organization_id = v_org_id and e.matter_ref = q.ref;
end;
$$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Matter status rollup (+ exposure & share)
create or replace function public.founder_r3221_matter_status_rollup()
returns table(matter_status text, matters bigint, total_exposure_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.legal_matter_r3221)
  select l.matter_status, count(*)::bigint,
         coalesce(sum(l.exposure_amount_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.legal_matter_r3221 l
  group by l.matter_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3221_matter_status_rollup() from public, anon;
grant execute on function public.founder_r3221_matter_status_rollup() to authenticated;

-- 2) Hospital / entity exposure scorecard
create or replace function public.founder_r3221_hospital_scorecard()
returns table(
  hospital_name text,
  total_matters bigint,
  open_matters bigint,
  disputes bigint,
  external_counsel_matters bigint,
  critical_matters bigint,
  total_exposure_rupees numeric,
  resolved_pct numeric
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
    count(*) filter (where l.matter_status in ('open','under_review','negotiation','escalated_to_counsel','hearing_scheduled'))::bigint,
    count(*) filter (where l.matter_type = 'customer_dispute')::bigint,
    count(*) filter (where l.external_counsel_engaged)::bigint,
    count(*) filter (where l.risk_rating = 'critical')::bigint,
    coalesce(sum(l.exposure_amount_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.matter_status in ('settled','closed','withdrawn'))::numeric / nullif(count(*),0), 1)
  from public.legal_matter_r3221 l
  group by l.hospital_name
  order by coalesce(sum(l.exposure_amount_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3221_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3221_hospital_scorecard() to authenticated;

-- 3) Matter type × risk-rating matrix
create or replace function public.founder_r3221_type_risk_matrix()
returns table(matter_type text, risk_rating text, matters bigint, total_exposure_rupees numeric, avg_exposure_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.matter_type, l.risk_rating, count(*)::bigint,
    coalesce(sum(l.exposure_amount_rupees),0)::numeric,
    round(avg(l.exposure_amount_rupees), 0)
  from public.legal_matter_r3221 l
  group by l.matter_type, l.risk_rating
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3221_type_risk_matrix() from public, anon;
grant execute on function public.founder_r3221_type_risk_matrix() to authenticated;

-- 4) Matters opened daily trend
create or replace function public.founder_r3221_opened_daily_trend()
returns table(opened_date date, matters_opened bigint, disputes bigint, contract_reviews bigint, exposure_opened_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.opened_date, count(*)::bigint,
    count(*) filter (where l.matter_type = 'customer_dispute')::bigint,
    count(*) filter (where l.matter_type = 'contract_review')::bigint,
    coalesce(sum(l.exposure_amount_rupees),0)::numeric
  from public.legal_matter_r3221 l
  group by l.opened_date
  order by l.opened_date desc;
end;
$$;

revoke execute on function public.founder_r3221_opened_daily_trend() from public, anon;
grant execute on function public.founder_r3221_opened_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3221_capa_status_board()
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
  from public.legal_matter_capa_actions_r3221 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3221_capa_status_board() from public, anon;
grant execute on function public.founder_r3221_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3221_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.legal_matter_capa_actions_r3221)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.legal_matter_capa_actions_r3221 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3221_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3221_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3221_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','escalated','overdue'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.legal_matter_capa_actions_r3221 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3221_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3221_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority matter queue
create or replace function public.founder_r3221_high_risk_queue()
returns table(
  hospital_name text,
  matter_ref text,
  matter_type text,
  matter_status text,
  risk_rating text,
  exposure_amount_rupees numeric,
  external_counsel_engaged boolean,
  next_deadline_date date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.matter_ref, l.matter_type, l.matter_status, l.risk_rating,
    l.exposure_amount_rupees, l.external_counsel_engaged, l.next_deadline_date, l.notes
  from public.legal_matter_r3221 l
  where l.matter_status not in ('settled','closed','withdrawn')
    and (l.risk_rating in ('high','critical')
      or l.matter_status in ('escalated_to_counsel','hearing_scheduled')
      or l.exposure_amount_rupees >= 1000000)
  order by l.next_deadline_date asc nulls last, l.exposure_amount_rupees desc;
end;
$$;

revoke execute on function public.founder_r3221_high_risk_queue() from public, anon;
grant execute on function public.founder_r3221_high_risk_queue() to authenticated;
