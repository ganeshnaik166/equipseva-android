-- Round 3103: Founder Quarterly Strategic Acquirer Target List + Diligence Readiness Tracker
-- Tracks potential acquirers (strategic fit, banker intro, NDA, valuation ask, deal probability)
-- and diligence readiness across functional workstreams.

set search_path = public, pg_temp;

-- =========================================================
-- TABLE 1: strategic acquirer targets
-- =========================================================
create table if not exists public.founder_strategic_acquirer_targets_r3103 (
  id uuid primary key default gen_random_uuid(),
  acquirer_name text not null,
  acquirer_country text not null check (acquirer_country in (
    'india','usa','germany','japan','singapore','uae','uk','netherlands','china','south_korea'
  )),
  acquirer_archetype text not null check (acquirer_archetype in (
    'global_oem','indian_oem','pe_buyout','strategic_distributor','hospital_chain','health_conglomerate','sovereign_fund','family_office'
  )),
  strategic_fit_score int not null check (strategic_fit_score between 0 and 100),
  strategic_rationale text not null,
  banker_intro_status text not null check (banker_intro_status in (
    'not_started','banker_identified','intro_requested','intro_made','meeting_scheduled','meeting_held','passed','active'
  )),
  banker_firm text,
  banker_partner_name text,
  first_meeting_date date,
  last_touch_date date,
  nda_status text not null check (nda_status in (
    'not_required','draft','sent_for_review','under_negotiation','executed','expired','superseded'
  )),
  nda_executed_at timestamptz,
  nda_expires_at timestamptz,
  valuation_ask_inr_crore numeric(12,2) not null check (valuation_ask_inr_crore > 0),
  valuation_floor_inr_crore numeric(12,2) check (valuation_floor_inr_crore is null or valuation_floor_inr_crore > 0),
  indicative_offer_inr_crore numeric(12,2),
  deal_probability_pct int not null check (deal_probability_pct between 0 and 100),
  deal_stage text not null check (deal_stage in (
    'cold_outreach','warm_intro','first_meeting','exploratory','nda_signed','data_room_open','ioi_received','loi_received','exclusive_diligence','term_sheet','closed_won','closed_lost'
  )),
  expected_close_quarter text not null check (expected_close_quarter in (
    'Q1_FY27','Q2_FY27','Q3_FY27','Q4_FY27','Q1_FY28','Q2_FY28','Q3_FY28','Q4_FY28','beyond_FY28'
  )),
  deal_structure_pref text not null check (deal_structure_pref in (
    'all_cash','cash_plus_stock','earnout','asset_purchase','share_swap','minority_stake','majority_buyout','strategic_partnership_first'
  )),
  reference_org_id uuid references public.organizations(id) on delete set null,
  founder_priority text not null check (founder_priority in ('tier1_hot','tier2_warm','tier3_long_shot','tier4_optional')),
  killer_concern text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_fsat_r3103_stage on public.founder_strategic_acquirer_targets_r3103(deal_stage);
create index if not exists idx_fsat_r3103_priority on public.founder_strategic_acquirer_targets_r3103(founder_priority);
create index if not exists idx_fsat_r3103_prob on public.founder_strategic_acquirer_targets_r3103(deal_probability_pct desc);

-- =========================================================
-- TABLE 2: diligence readiness workstreams (per acquirer-target OR global)
-- =========================================================
create table if not exists public.founder_diligence_readiness_workstreams_r3103 (
  id uuid primary key default gen_random_uuid(),
  acquirer_target_id uuid references public.founder_strategic_acquirer_targets_r3103(id) on delete cascade,
  workstream text not null check (workstream in (
    'financial','legal','tax_gst','hr_payroll','technology','dpdp_privacy','commercial_contracts','clinical_regulatory','intellectual_property','esg_dei','cyber_security','customer_references','operations_qms','data_room_index','q_of_e_audit'
  )),
  readiness_pct int not null check (readiness_pct between 0 and 100),
  readiness_status text not null check (readiness_status in (
    'not_started','in_progress','docs_drafted','docs_under_review','complete','blocked','external_audit_pending','signed_off'
  )),
  owner_role text not null check (owner_role in (
    'founder','cfo','vp_engineering','head_legal','head_hr','head_clinical','external_counsel','external_auditor','head_security','head_ops','head_commercial','head_dpdp','banker'
  )),
  external_advisor_firm text,
  estimated_completion_date date,
  blocker_summary text,
  documents_uploaded int not null default 0 check (documents_uploaded >= 0),
  documents_required int not null check (documents_required > 0),
  red_flag_count int not null default 0 check (red_flag_count >= 0),
  remediation_cost_inr_lakh numeric(10,2) not null default 0 check (remediation_cost_inr_lakh >= 0),
  last_updated_at timestamptz not null default now(),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_fdrw_r3103_ws on public.founder_diligence_readiness_workstreams_r3103(workstream);
create index if not exists idx_fdrw_r3103_status on public.founder_diligence_readiness_workstreams_r3103(readiness_status);
create index if not exists idx_fdrw_r3103_target on public.founder_diligence_readiness_workstreams_r3103(acquirer_target_id);

-- =========================================================
-- SEED DATA — strategic acquirer targets (8 rows)
-- =========================================================
insert into public.founder_strategic_acquirer_targets_r3103 (
  acquirer_name, acquirer_country, acquirer_archetype, strategic_fit_score, strategic_rationale,
  banker_intro_status, banker_firm, banker_partner_name, first_meeting_date, last_touch_date,
  nda_status, nda_executed_at, nda_expires_at,
  valuation_ask_inr_crore, valuation_floor_inr_crore, indicative_offer_inr_crore,
  deal_probability_pct, deal_stage, expected_close_quarter, deal_structure_pref,
  reference_org_id, founder_priority, killer_concern
)
select * from (values
  ('GE HealthCare India','india','global_oem',92,'Owns largest India installed base of CT/MRI; we run their service tail in 14 cities','meeting_held','Avendus Capital','Ritesh Chandra','2026-03-12'::date,'2026-06-22'::date,'executed','2026-03-20 10:00+05:30'::timestamptz,'2027-03-20 10:00+05:30'::timestamptz,420.00::numeric,320.00::numeric,275.00::numeric,55,'ioi_received','Q3_FY27','cash_plus_stock',(select id from public.organizations order by created_at limit 1),'tier1_hot','Wants 3-year founder lock-in; we want 18 months'),
  ('Siemens Healthineers AG','germany','global_oem',88,'Strategic India play; X-ray + ultrasound service gap; complements EU service ops','meeting_held','JP Morgan India','Aisha Kanchwala','2026-04-08'::date,'2026-06-18'::date,'executed','2026-04-15 14:00+05:30'::timestamptz,'2027-04-15 14:00+05:30'::timestamptz,500.00::numeric,380.00::numeric,null::numeric,38,'data_room_open','Q1_FY28','cash_plus_stock',(select id from public.organizations order by created_at limit 1),'tier1_hot','DPDP + cross-border data residency concerns'),
  ('Apollo Hospitals Enterprise','india','hospital_chain',78,'Captive service arm for 73-hospital network; AMC tariff card synergy','meeting_scheduled','Kotak Investment Banking','Ramesh Srinivasan','2026-05-22'::date,'2026-06-25'::date,'under_negotiation',null::timestamptz,null::timestamptz,300.00::numeric,240.00::numeric,null::numeric,42,'exploratory','Q4_FY27','majority_buyout',(select id from public.organizations order by created_at limit 1),'tier1_hot','Channel conflict with non-Apollo hospital customers (62% of revenue)'),
  ('Mitsubishi Electric Medical','japan','global_oem',71,'Wants India service footprint for dental + endoscopy ladder','intro_made','Nomura India','Yuki Tanaka','2026-06-10'::date,'2026-06-26'::date,'sent_for_review',null::timestamptz,null::timestamptz,360.00::numeric,300.00::numeric,null::numeric,22,'first_meeting','Q2_FY28','strategic_partnership_first',(select id from public.organizations order by created_at limit 1),'tier2_warm','Cultural fit; slow decision cycle (18+ months typical)'),
  ('TPG Growth Asia','singapore','pe_buyout',85,'Looking for India healthtech rollup; would bond us with Sahyadri + a diagnostics chain','meeting_held','Avendus Capital','Ritesh Chandra','2026-02-28'::date,'2026-06-20'::date,'executed','2026-03-05 11:30+05:30'::timestamptz,'2027-03-05 11:30+05:30'::timestamptz,450.00::numeric,360.00::numeric,310.00::numeric,48,'loi_received','Q3_FY27','majority_buyout',(select id from public.organizations order by created_at limit 1),'tier1_hot','PE financial buyer — founder ESOP dilution + rollup integration risk'),
  ('Mubadala Health','uae','sovereign_fund',64,'India healthcare exposure for GCC sovereign portfolio; long-hold strategic','intro_requested','Citi India','Vivek Mehrotra',null::date,'2026-06-15'::date,'draft',null::timestamptz,null::timestamptz,400.00::numeric,320.00::numeric,null::numeric,15,'warm_intro','Q4_FY28','minority_stake',(select id from public.organizations order by created_at limit 1),'tier3_long_shot','Geopolitical India-UAE healthcare data sensitivities'),
  ('Trivitron Healthcare','india','indian_oem',58,'Domestic OEM consolidator; complementary in-vitro diagnostics service','banker_identified','MAPE Advisory','Sundar Krishnan',null::date,'2026-05-30'::date,'not_required',null::timestamptz,null::timestamptz,220.00::numeric,180.00::numeric,null::numeric,18,'cold_outreach','Q1_FY28','share_swap',(select id from public.organizations order by created_at limit 1),'tier3_long_shot','Valuation gap (their public mcap implies 4x revenue, we want 8x)'),
  ('Philips Healthcare Indian Subcontinent','netherlands','global_oem',81,'Service-arm partnership lapsed 2024; renewing under M&A umbrella','meeting_scheduled','Morgan Stanley','Pradeep Iyer','2026-06-05'::date,'2026-06-28'::date,'under_negotiation',null::timestamptz,null::timestamptz,475.00::numeric,360.00::numeric,null::numeric,28,'exploratory','Q2_FY28','cash_plus_stock',(select id from public.organizations order by created_at limit 1),'tier2_warm','Their CFO wants tax-efficient earnout structure; we want all-cash')
) as v(acquirer_name, acquirer_country, acquirer_archetype, strategic_fit_score, strategic_rationale, banker_intro_status, banker_firm, banker_partner_name, first_meeting_date, last_touch_date, nda_status, nda_executed_at, nda_expires_at, valuation_ask_inr_crore, valuation_floor_inr_crore, indicative_offer_inr_crore, deal_probability_pct, deal_stage, expected_close_quarter, deal_structure_pref, reference_org_id, founder_priority, killer_concern);

-- =========================================================
-- SEED DATA — diligence readiness workstreams (10 rows)
-- =========================================================
with target_ge as (select id from public.founder_strategic_acquirer_targets_r3103 where acquirer_name='GE HealthCare India' limit 1),
     target_tpg as (select id from public.founder_strategic_acquirer_targets_r3103 where acquirer_name='TPG Growth Asia' limit 1),
     target_siemens as (select id from public.founder_strategic_acquirer_targets_r3103 where acquirer_name='Siemens Healthineers AG' limit 1),
     target_apollo as (select id from public.founder_strategic_acquirer_targets_r3103 where acquirer_name='Apollo Hospitals Enterprise' limit 1)
insert into public.founder_diligence_readiness_workstreams_r3103 (
  acquirer_target_id, workstream, readiness_pct, readiness_status, owner_role, external_advisor_firm,
  estimated_completion_date, blocker_summary, documents_uploaded, documents_required, red_flag_count,
  remediation_cost_inr_lakh, notes
) values
  ((select id from target_ge), 'financial', 78, 'docs_under_review', 'cfo', 'BSR & Co (KPMG India)', '2026-07-15', null, 42, 54, 2, 8.50, 'Q-of-E audit in flight; 2 channel-stuffing flags in FY24 to remediate'),
  ((select id from target_ge), 'legal', 65, 'in_progress', 'external_counsel', 'Cyril Amarchand Mangaldas', '2026-08-01', 'Pending hospital MSA assignment-on-control clauses (62 contracts)', 138, 210, 4, 22.00, 'Change-of-control covenants in 4 anchor hospital contracts — need waivers'),
  ((select id from target_ge), 'dpdp_privacy', 52, 'in_progress', 'head_dpdp', 'AZB & Partners', '2026-08-30', 'DPDP grievance officer cert pending; engineer photo retention policy review', 18, 38, 3, 12.50, 'Patient PHI in service tickets must be redacted before data room upload'),
  ((select id from target_tpg), 'financial', 88, 'signed_off', 'cfo', 'BSR & Co (KPMG India)', '2026-06-15', null, 54, 54, 0, 0.00, 'Q-of-E signed off; TPG team uses Avendus model as base case'),
  ((select id from target_tpg), 'tax_gst', 70, 'docs_under_review', 'external_auditor', 'PwC India', '2026-07-10', 'GST input credit reversal on 2 spare-part SKUs under DGGSTI scrutiny', 26, 38, 1, 4.20, 'Disclosed in IM; provisioned 1.2 cr; not a deal-breaker per TPG counsel'),
  ((select id from target_tpg), 'commercial_contracts', 72, 'docs_under_review', 'head_commercial', null, '2026-07-20', 'Top-20 customer NPS + churn waterfall pending', 28, 40, 1, 0.00, 'Apollo + Manipal + Yashoda references pre-cleared'),
  ((select id from target_siemens), 'cyber_security', 45, 'in_progress', 'head_security', 'Lucideus', '2026-09-15', 'ISO 27001 audit pending; SOC2 not started; pentest finding 7 mediums open', 22, 60, 7, 35.00, 'Siemens Germany security team requires SOC2 Type II — 6-month gap'),
  ((select id from target_siemens), 'clinical_regulatory', 80, 'docs_under_review', 'head_clinical', 'IndegeneCDX', '2026-07-25', null, 34, 42, 0, 0.00, 'CDSCO service-provider registrations clean across 14 cities'),
  ((select id from target_apollo), 'operations_qms', 60, 'in_progress', 'head_ops', null, '2026-08-10', 'NABH-Service-Provider certification in 6 of 14 cities (target = 14)', 36, 60, 2, 18.00, 'Apollo procurement requires NABH-SP in all cities — 4-month gap'),
  ((select id from target_apollo), 'q_of_e_audit', 55, 'external_audit_pending', 'external_auditor', 'EY India', '2026-08-25', 'Apollo wants independent Q-of-E (not TPG/GE shared file)', 24, 50, 1, 6.50, 'Estimated cr 18-22 EBITDA adjustment under Apollo accounting policy');

-- =========================================================
-- RPCs (8 founder-gated)
-- =========================================================

-- 1. Pipeline summary by deal stage
create or replace function public.fn_acquirer_pipeline_by_stage_r3103()
returns table(deal_stage text, target_count bigint, total_ask_cr numeric, weighted_value_cr numeric, avg_fit_score numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.deal_stage::text,
         count(*)::bigint as target_count,
         coalesce(sum(t.valuation_ask_inr_crore),0)::numeric as total_ask_cr,
         coalesce(sum(t.valuation_ask_inr_crore * t.deal_probability_pct / 100.0),0)::numeric as weighted_value_cr,
         round(avg(t.strategic_fit_score)::numeric, 1) as avg_fit_score
  from public.founder_strategic_acquirer_targets_r3103 t
  group by t.deal_stage
  order by total_ask_cr desc;
end $$;
revoke execute on function public.fn_acquirer_pipeline_by_stage_r3103() from public, anon;
grant execute on function public.fn_acquirer_pipeline_by_stage_r3103() to authenticated;

-- 2. Top targets by weighted expected value
create or replace function public.fn_acquirer_top_weighted_targets_r3103()
returns table(acquirer_name text, archetype text, fit int, probability_pct int, valuation_ask_cr numeric, weighted_value_cr numeric, stage text, priority text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.acquirer_name,
         t.acquirer_archetype,
         t.strategic_fit_score,
         t.deal_probability_pct,
         t.valuation_ask_inr_crore,
         (t.valuation_ask_inr_crore * t.deal_probability_pct / 100.0)::numeric as weighted_value_cr,
         t.deal_stage,
         t.founder_priority
  from public.founder_strategic_acquirer_targets_r3103 t
  order by (t.valuation_ask_inr_crore * t.deal_probability_pct) desc
  limit 12;
end $$;
revoke execute on function public.fn_acquirer_top_weighted_targets_r3103() from public, anon;
grant execute on function public.fn_acquirer_top_weighted_targets_r3103() to authenticated;

-- 3. NDA + banker funnel
create or replace function public.fn_acquirer_nda_banker_funnel_r3103()
returns table(banker_status text, count bigint, executed_ndas bigint, avg_days_since_last_touch numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.banker_intro_status,
         count(*)::bigint,
         count(*) filter (where t.nda_status = 'executed')::bigint as executed_ndas,
         round(avg(extract(epoch from (now() - t.last_touch_date::timestamptz)) / 86400.0)::numeric, 1) as avg_days_since_last_touch
  from public.founder_strategic_acquirer_targets_r3103 t
  group by t.banker_intro_status
  order by count(*) desc;
end $$;
revoke execute on function public.fn_acquirer_nda_banker_funnel_r3103() from public, anon;
grant execute on function public.fn_acquirer_nda_banker_funnel_r3103() to authenticated;

-- 4. Diligence readiness rollup by workstream
create or replace function public.fn_diligence_readiness_by_workstream_r3103()
returns table(workstream text, avg_readiness_pct numeric, total_docs_uploaded bigint, total_docs_required bigint, total_red_flags bigint, total_remediation_lakh numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select w.workstream,
         round(avg(w.readiness_pct)::numeric, 1) as avg_readiness_pct,
         sum(w.documents_uploaded)::bigint,
         sum(w.documents_required)::bigint,
         sum(w.red_flag_count)::bigint,
         sum(w.remediation_cost_inr_lakh)::numeric
  from public.founder_diligence_readiness_workstreams_r3103 w
  group by w.workstream
  order by avg_readiness_pct asc;
end $$;
revoke execute on function public.fn_diligence_readiness_by_workstream_r3103() from public, anon;
grant execute on function public.fn_diligence_readiness_by_workstream_r3103() to authenticated;

-- 5. Per-acquirer readiness rollup
create or replace function public.fn_diligence_per_acquirer_rollup_r3103()
returns table(acquirer_name text, stage text, workstream_count bigint, avg_readiness_pct numeric, red_flag_total bigint, remediation_lakh numeric, blocked_count bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.acquirer_name,
         t.deal_stage,
         count(w.id)::bigint,
         round(coalesce(avg(w.readiness_pct), 0)::numeric, 1),
         coalesce(sum(w.red_flag_count), 0)::bigint,
         coalesce(sum(w.remediation_cost_inr_lakh), 0)::numeric,
         count(*) filter (where w.readiness_status = 'blocked')::bigint
  from public.founder_strategic_acquirer_targets_r3103 t
  left join public.founder_diligence_readiness_workstreams_r3103 w on w.acquirer_target_id = t.id
  group by t.id, t.acquirer_name, t.deal_stage
  order by avg_readiness_pct asc;
end $$;
revoke execute on function public.fn_diligence_per_acquirer_rollup_r3103() from public, anon;
grant execute on function public.fn_diligence_per_acquirer_rollup_r3103() to authenticated;

-- 6. Expected close calendar
create or replace function public.fn_acquirer_close_calendar_r3103()
returns table(expected_close_quarter text, target_count bigint, total_ask_cr numeric, weighted_close_cr numeric, top_acquirer text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.expected_close_quarter,
         count(*)::bigint,
         sum(t.valuation_ask_inr_crore)::numeric,
         sum(t.valuation_ask_inr_crore * t.deal_probability_pct / 100.0)::numeric,
         (array_agg(t.acquirer_name order by t.deal_probability_pct desc))[1]
  from public.founder_strategic_acquirer_targets_r3103 t
  group by t.expected_close_quarter
  order by t.expected_close_quarter;
end $$;
revoke execute on function public.fn_acquirer_close_calendar_r3103() from public, anon;
grant execute on function public.fn_acquirer_close_calendar_r3103() to authenticated;

-- 7. Diligence red-flag hot list
create or replace function public.fn_diligence_red_flag_hotlist_r3103()
returns table(acquirer_name text, workstream text, red_flag_count int, readiness_pct int, status text, owner_role text, remediation_lakh numeric, blocker_summary text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select coalesce(t.acquirer_name, 'GLOBAL'),
         w.workstream,
         w.red_flag_count,
         w.readiness_pct,
         w.readiness_status,
         w.owner_role,
         w.remediation_cost_inr_lakh,
         w.blocker_summary
  from public.founder_diligence_readiness_workstreams_r3103 w
  left join public.founder_strategic_acquirer_targets_r3103 t on t.id = w.acquirer_target_id
  where w.red_flag_count > 0 or w.readiness_status in ('blocked','external_audit_pending')
  order by w.red_flag_count desc, w.remediation_cost_inr_lakh desc
  limit 20;
end $$;
revoke execute on function public.fn_diligence_red_flag_hotlist_r3103() from public, anon;
grant execute on function public.fn_diligence_red_flag_hotlist_r3103() to authenticated;

-- 8. Archetype distribution (strategic mix)
create or replace function public.fn_acquirer_archetype_mix_r3103()
returns table(archetype text, count bigint, avg_ask_cr numeric, avg_probability numeric, total_weighted_cr numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.acquirer_archetype,
         count(*)::bigint,
         round(avg(t.valuation_ask_inr_crore)::numeric, 1),
         round(avg(t.deal_probability_pct)::numeric, 1),
         sum(t.valuation_ask_inr_crore * t.deal_probability_pct / 100.0)::numeric
  from public.founder_strategic_acquirer_targets_r3103 t
  group by t.acquirer_archetype
  order by total_weighted_cr desc;
end $$;
revoke execute on function public.fn_acquirer_archetype_mix_r3103() from public, anon;
grant execute on function public.fn_acquirer_archetype_mix_r3103() to authenticated;

-- 9. Founder priority tier rollup
create or replace function public.fn_acquirer_priority_tier_rollup_r3103()
returns table(founder_priority text, count bigint, executed_nda_count bigint, avg_fit numeric, avg_probability numeric, total_weighted_cr numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.founder_priority,
         count(*)::bigint,
         count(*) filter (where t.nda_status='executed')::bigint,
         round(avg(t.strategic_fit_score)::numeric, 1),
         round(avg(t.deal_probability_pct)::numeric, 1),
         sum(t.valuation_ask_inr_crore * t.deal_probability_pct / 100.0)::numeric
  from public.founder_strategic_acquirer_targets_r3103 t
  group by t.founder_priority
  order by t.founder_priority;
end $$;
revoke execute on function public.fn_acquirer_priority_tier_rollup_r3103() from public, anon;
grant execute on function public.fn_acquirer_priority_tier_rollup_r3103() to authenticated;
