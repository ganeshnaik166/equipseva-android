-- Round 3099: Founder Quarterly Strategic Engineer-Founder Government Tender Bid Loss Post-Mortem Tracker
-- Lost government tender bids analysis — tender × eligibility gap × price gap × winning bidder × disqualification reason × lessons-learned × replay playbook

-- =====================================================================
-- TABLE 1: govt_tender_bid_loss_postmortems_r3099
-- =====================================================================
create table if not exists public.govt_tender_bid_loss_postmortems_r3099 (
  id uuid primary key default gen_random_uuid(),
  tender_reference_no text not null,
  tender_title text not null,
  issuing_authority text not null,
  authority_state text not null,
  tender_category text not null check (tender_category in (
    'central_govt_hospital','state_govt_hospital','aiims_network','esic_network',
    'railway_hospital','defence_medical','municipal_hospital','district_hospital',
    'medical_college','primary_health_centre'
  )),
  equipment_scope text not null check (equipment_scope in (
    'imaging_radiology','dialysis_units','ventilators_icu','anaesthesia_workstations',
    'patient_monitors','surgical_lights','autoclaves_csssd','laboratory_analysers',
    'pathology_microscopes','dental_chair_units','ophthalmology_chairs','mixed_amc_basket'
  )),
  bid_submitted_on date not null,
  bid_opened_on date not null,
  award_announced_on date not null,
  bid_value_rupees bigint not null check (bid_value_rupees > 0),
  l1_winning_value_rupees bigint not null check (l1_winning_value_rupees > 0),
  price_gap_percent numeric(6,2) not null,
  disqualification_reason text not null check (disqualification_reason in (
    'technical_non_responsive','financial_non_competitive','emd_shortfall',
    'turnover_eligibility_fail','prior_experience_fail','oem_authorisation_missing',
    'bis_certificate_missing','nabh_clause_missing','startup_exemption_not_claimed',
    'gem_registration_lapsed','dgs_d_rate_contract_absent','class_2_dsc_expired'
  )),
  eligibility_gap_summary text not null,
  winning_bidder_name text not null,
  winning_bidder_tier text not null check (winning_bidder_tier in (
    'tier1_oem_direct','tier2_authorised_distributor','tier3_msme_local',
    'tier4_psu','tier5_startup_dpiit','tier6_pse_jv'
  )),
  loss_severity text not null check (loss_severity in (
    'catastrophic_flagship','major_revenue','moderate_pipeline','minor_pilot','strategic_signal'
  )),
  founder_lessons_learned text not null,
  replay_decision text not null check (replay_decision in (
    'replay_with_oem_partner','replay_with_consortium','replay_as_msme_subcontractor',
    'skip_future_cycles','escalate_to_court_review','file_pre_bid_clarification',
    'pursue_gem_market_directly','defer_two_quarters'
  )),
  founder_owner_id uuid references public.profiles(id),
  postmortem_status text not null default 'open' check (postmortem_status in (
    'open','draft_review','founder_signed','replay_executing','closed_archived','escalated_legal'
  )),
  recorded_at timestamptz not null default now()
);

create index if not exists idx_postmortem_r3099_status on public.govt_tender_bid_loss_postmortems_r3099(postmortem_status);
create index if not exists idx_postmortem_r3099_category on public.govt_tender_bid_loss_postmortems_r3099(tender_category);
create index if not exists idx_postmortem_r3099_disq on public.govt_tender_bid_loss_postmortems_r3099(disqualification_reason);

-- =====================================================================
-- TABLE 2: govt_tender_replay_playbook_actions_r3099
-- =====================================================================
create table if not exists public.govt_tender_replay_playbook_actions_r3099 (
  id uuid primary key default gen_random_uuid(),
  postmortem_id uuid not null references public.govt_tender_bid_loss_postmortems_r3099(id) on delete cascade,
  action_sequence_no int not null check (action_sequence_no between 1 and 50),
  action_title text not null,
  action_category text not null check (action_category in (
    'compliance_doc_refresh','oem_partnership_secured','consortium_formed',
    'msme_certificate_renewal','dsc_class3_procured','gem_seller_upgrade',
    'pre_bid_query_filed','price_benchmark_rebuilt','technical_response_redrafted',
    'capacity_proof_assembled','site_visit_completed','escrow_emd_pre_funded'
  )),
  responsible_owner text not null check (responsible_owner in (
    'founder_ceo','head_tenders','head_compliance','head_finance',
    'oem_partner_manager','msme_consultant','legal_counsel','founder_advisor_panel'
  )),
  target_completion_date date not null,
  action_status text not null check (action_status in (
    'not_started','in_progress','blocked_oem','blocked_legal',
    'awaiting_authority_clarification','completed','superseded','abandoned'
  )),
  estimated_cost_rupees bigint not null check (estimated_cost_rupees >= 0),
  expected_unlock_value_rupees bigint not null check (expected_unlock_value_rupees >= 0),
  blocker_notes text,
  reviewed_by_founder boolean not null default false,
  created_at timestamptz not null default now(),
  unique (postmortem_id, action_sequence_no)
);

create index if not exists idx_replay_action_r3099_status on public.govt_tender_replay_playbook_actions_r3099(action_status);
create index if not exists idx_replay_action_r3099_category on public.govt_tender_replay_playbook_actions_r3099(action_category);

-- =====================================================================
-- SEED DATA — postmortems (8 rows)
-- =====================================================================
insert into public.govt_tender_bid_loss_postmortems_r3099
(tender_reference_no, tender_title, issuing_authority, authority_state, tender_category, equipment_scope,
 bid_submitted_on, bid_opened_on, award_announced_on, bid_value_rupees, l1_winning_value_rupees, price_gap_percent,
 disqualification_reason, eligibility_gap_summary, winning_bidder_name, winning_bidder_tier, loss_severity,
 founder_lessons_learned, replay_decision, postmortem_status)
values
('AIIMS/DEL/IMG/2026/118','AIIMS Delhi CT-scan AMC 5yr basket','AIIMS New Delhi','Delhi','aiims_network','imaging_radiology',
 '2026-04-12','2026-04-25','2026-05-08', 18750000, 16420000, 14.20,
 'oem_authorisation_missing','Siemens OEM letter not on AIIMS-format letterhead; rejected at technical stage',
 'Wipro GE Healthcare Pvt Ltd','tier1_oem_direct','catastrophic_flagship',
 'Lock OEM MoU 6 weeks before bid; demand authority-format authorisation letter','replay_with_oem_partner','founder_signed'),
('ESIC/MUM/DIAL/2026/044','ESIC Mumbai dialysis machine AMC + consumables','ESIC Mumbai','Maharashtra','esic_network','dialysis_units',
 '2026-03-18','2026-03-30','2026-04-11', 9420000, 8100000, 16.30,
 'turnover_eligibility_fail','3yr avg turnover ₹4.2cr — ESIC clause requires ₹6cr',
 'Fresenius Medical Care India','tier1_oem_direct','major_revenue',
 'Apply startup_dpiit exemption clause — saves turnover bar','replay_as_msme_subcontractor','replay_executing'),
('GMC/HYD/VENT/2026/077','Gandhi Medical College Hyderabad ICU ventilator AMC','Gandhi Medical College','Telangana','medical_college','ventilators_icu',
 '2026-02-22','2026-03-06','2026-03-18', 5640000, 4980000, 13.25,
 'bis_certificate_missing','BIS IS 17304 cert for ventilator AMC tooling expired 2026-01',
 'Skanray Technologies','tier3_msme_local','moderate_pipeline',
 'Renew BIS 90d before expiry; calendar tied to compliance head','replay_with_oem_partner','founder_signed'),
('RLY/SCR/MON/2026/091','South Central Railway hospital patient-monitor AMC','South Central Railway','Andhra Pradesh','railway_hospital','patient_monitors',
 '2026-03-04','2026-03-15','2026-03-28', 3240000, 2890000, 12.11,
 'class_2_dsc_expired','Class-2 DSC of authorised signatory expired; needed Class-3 anyway',
 'Mindray India Pvt Ltd','tier2_authorised_distributor','minor_pilot',
 'Migrate all signatories to Class-3 DSC org-wide','replay_with_oem_partner','closed_archived'),
('AFMS/PUN/SURG/2026/033','Armed Forces Medical Services Pune surgical lights AMC','Armed Forces Medical Services','Maharashtra','defence_medical','surgical_lights',
 '2026-01-29','2026-02-10','2026-02-22', 4720000, 4120000, 14.56,
 'prior_experience_fail','Defence prior-experience clause: 3 similar contracts in last 5yr — equipseva had 1',
 'Trumpf Medical Systems','tier1_oem_direct','major_revenue',
 'Build consortium with PSE that has defence experience','replay_with_consortium','founder_signed'),
('DHFW/CHE/LAB/2026/056','TN Dept Health & FW lab analyser AMC chennai cluster','TN Dept Health and Family Welfare','Tamil Nadu','state_govt_hospital','laboratory_analysers',
 '2026-04-02','2026-04-14','2026-04-28', 7820000, 6900000, 13.33,
 'startup_exemption_not_claimed','DPIIT startup exemption clause not invoked in cover letter; turnover bar applied',
 'Transasia Bio-Medicals','tier1_oem_direct','major_revenue',
 'Add DPIIT clause invocation to every cover letter template','replay_with_oem_partner','replay_executing'),
('MCGM/MUM/AUTO/2026/102','MCGM Mumbai CSSSD autoclave AMC 30 hospitals','Municipal Corporation Greater Mumbai','Maharashtra','municipal_hospital','autoclaves_csssd',
 '2026-03-25','2026-04-08','2026-04-22', 11240000, 9870000, 13.88,
 'emd_shortfall','EMD pre-funded ₹1.8L; tender required ₹2.25L — bank guarantee delayed',
 'Steelco India','tier2_authorised_distributor','catastrophic_flagship',
 'Pre-fund EMD escrow at 110% of estimate by tender T-21d','replay_with_consortium','escalated_legal'),
('GEM/CEN/DENT/2026/118','GeM bid central govt dental chair AMC pan-India','GeM Government Marketplace','Delhi','central_govt_hospital','dental_chair_units',
 '2026-02-15','2026-02-28','2026-03-14', 6120000, 5420000, 12.92,
 'gem_registration_lapsed','GeM seller registration lapsed 11 days before bid open; auto-rejected',
 'Confident Dental Equipments','tier3_msme_local','strategic_signal',
 'Auto-renew GeM 60d before expiry; calendar reminders to founder','pursue_gem_market_directly','founder_signed');

-- =====================================================================
-- SEED DATA — replay actions (10 rows across 5 postmortems)
-- =====================================================================
insert into public.govt_tender_replay_playbook_actions_r3099
(postmortem_id, action_sequence_no, action_title, action_category, responsible_owner,
 target_completion_date, action_status, estimated_cost_rupees, expected_unlock_value_rupees, blocker_notes, reviewed_by_founder)
select id, 1, 'Secure Siemens India OEM authorisation in AIIMS letterhead format',
 'oem_partnership_secured','founder_ceo','2026-07-15','in_progress', 150000, 18750000,
 'Siemens regional head out-of-country till 2026-07-08', true
from public.govt_tender_bid_loss_postmortems_r3099 where tender_reference_no='AIIMS/DEL/IMG/2026/118';

insert into public.govt_tender_replay_playbook_actions_r3099
(postmortem_id, action_sequence_no, action_title, action_category, responsible_owner,
 target_completion_date, action_status, estimated_cost_rupees, expected_unlock_value_rupees, blocker_notes, reviewed_by_founder)
select id, 2, 'Build technical response template for AIIMS imaging AMC class',
 'technical_response_redrafted','head_tenders','2026-07-25','not_started', 50000, 18750000, null, false
from public.govt_tender_bid_loss_postmortems_r3099 where tender_reference_no='AIIMS/DEL/IMG/2026/118';

insert into public.govt_tender_replay_playbook_actions_r3099
(postmortem_id, action_sequence_no, action_title, action_category, responsible_owner,
 target_completion_date, action_status, estimated_cost_rupees, expected_unlock_value_rupees, blocker_notes, reviewed_by_founder)
select id, 1, 'File DPIIT startup exemption claim for ESIC turnover relief',
 'msme_certificate_renewal','head_compliance','2026-07-05','completed', 25000, 9420000, null, true
from public.govt_tender_bid_loss_postmortems_r3099 where tender_reference_no='ESIC/MUM/DIAL/2026/044';

insert into public.govt_tender_replay_playbook_actions_r3099
(postmortem_id, action_sequence_no, action_title, action_category, responsible_owner,
 target_completion_date, action_status, estimated_cost_rupees, expected_unlock_value_rupees, blocker_notes, reviewed_by_founder)
select id, 2, 'Secure Fresenius dealership for Mumbai ESIC dialysis pool',
 'oem_partnership_secured','oem_partner_manager','2026-08-12','blocked_oem', 200000, 9420000,
 'Fresenius needs proof of 3 prior ESIC engagements', false
from public.govt_tender_bid_loss_postmortems_r3099 where tender_reference_no='ESIC/MUM/DIAL/2026/044';

insert into public.govt_tender_replay_playbook_actions_r3099
(postmortem_id, action_sequence_no, action_title, action_category, responsible_owner,
 target_completion_date, action_status, estimated_cost_rupees, expected_unlock_value_rupees, blocker_notes, reviewed_by_founder)
select id, 1, 'Renew BIS IS 17304 ventilator AMC tooling certification',
 'compliance_doc_refresh','head_compliance','2026-07-20','in_progress', 85000, 5640000, null, true
from public.govt_tender_bid_loss_postmortems_r3099 where tender_reference_no='GMC/HYD/VENT/2026/077';

insert into public.govt_tender_replay_playbook_actions_r3099
(postmortem_id, action_sequence_no, action_title, action_category, responsible_owner,
 target_completion_date, action_status, estimated_cost_rupees, expected_unlock_value_rupees, blocker_notes, reviewed_by_founder)
select id, 1, 'Procure Class-3 DSC for all 4 authorised tender signatories',
 'dsc_class3_procured','head_compliance','2026-07-02','completed', 18000, 3240000, null, true
from public.govt_tender_bid_loss_postmortems_r3099 where tender_reference_no='RLY/SCR/MON/2026/091';

insert into public.govt_tender_replay_playbook_actions_r3099
(postmortem_id, action_sequence_no, action_title, action_category, responsible_owner,
 target_completion_date, action_status, estimated_cost_rupees, expected_unlock_value_rupees, blocker_notes, reviewed_by_founder)
select id, 1, 'Form consortium with BEL/HAL for AFMS defence eligibility',
 'consortium_formed','founder_ceo','2026-08-30','in_progress', 350000, 4720000,
 'BEL legal vetting in progress', true
from public.govt_tender_bid_loss_postmortems_r3099 where tender_reference_no='AFMS/PUN/SURG/2026/033';

insert into public.govt_tender_replay_playbook_actions_r3099
(postmortem_id, action_sequence_no, action_title, action_category, responsible_owner,
 target_completion_date, action_status, estimated_cost_rupees, expected_unlock_value_rupees, blocker_notes, reviewed_by_founder)
select id, 1, 'Standardise DPIIT clause invocation in all bid cover-letter templates',
 'technical_response_redrafted','head_tenders','2026-07-10','completed', 15000, 7820000, null, true
from public.govt_tender_bid_loss_postmortems_r3099 where tender_reference_no='DHFW/CHE/LAB/2026/056';

insert into public.govt_tender_replay_playbook_actions_r3099
(postmortem_id, action_sequence_no, action_title, action_category, responsible_owner,
 target_completion_date, action_status, estimated_cost_rupees, expected_unlock_value_rupees, blocker_notes, reviewed_by_founder)
select id, 1, 'Pre-fund EMD escrow at 110% of estimated tender value via SBI BG line',
 'escrow_emd_pre_funded','head_finance','2026-07-18','in_progress', 280000, 11240000, null, true
from public.govt_tender_bid_loss_postmortems_r3099 where tender_reference_no='MCGM/MUM/AUTO/2026/102';

insert into public.govt_tender_replay_playbook_actions_r3099
(postmortem_id, action_sequence_no, action_title, action_category, responsible_owner,
 target_completion_date, action_status, estimated_cost_rupees, expected_unlock_value_rupees, blocker_notes, reviewed_by_founder)
select id, 1, 'Auto-renew GeM seller registration 60 days before annual expiry',
 'gem_seller_upgrade','head_compliance','2026-07-08','completed', 12000, 6120000, null, true
from public.govt_tender_bid_loss_postmortems_r3099 where tender_reference_no='GEM/CEN/DENT/2026/118';

-- =====================================================================
-- RPC 1: portfolio summary rollup
-- =====================================================================
create or replace function public.fn_r3099_postmortem_portfolio_summary()
returns table(
  total_lost_bids bigint,
  total_bid_value_lost_rupees bigint,
  total_winning_value_rupees bigint,
  avg_price_gap_percent numeric,
  open_postmortems bigint,
  founder_signed_count bigint,
  catastrophic_count bigint
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select count(*)::bigint,
         coalesce(sum(bid_value_rupees),0)::bigint,
         coalesce(sum(l1_winning_value_rupees),0)::bigint,
         coalesce(round(avg(price_gap_percent)::numeric, 2), 0),
         count(*) filter (where postmortem_status = 'open')::bigint,
         count(*) filter (where postmortem_status = 'founder_signed')::bigint,
         count(*) filter (where loss_severity = 'catastrophic_flagship')::bigint
  from public.govt_tender_bid_loss_postmortems_r3099;
end;
$$;
revoke execute on function public.fn_r3099_postmortem_portfolio_summary() from public, anon;
grant execute on function public.fn_r3099_postmortem_portfolio_summary() to authenticated;

-- =====================================================================
-- RPC 2: losses by disqualification reason
-- =====================================================================
create or replace function public.fn_r3099_losses_by_disqualification()
returns table(
  disqualification_reason text,
  loss_count bigint,
  value_lost_rupees bigint,
  avg_price_gap_percent numeric
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.disqualification_reason,
         count(*)::bigint,
         coalesce(sum(p.bid_value_rupees),0)::bigint,
         round(avg(p.price_gap_percent)::numeric, 2)
  from public.govt_tender_bid_loss_postmortems_r3099 p
  group by p.disqualification_reason
  order by count(*) desc, sum(p.bid_value_rupees) desc;
end;
$$;
revoke execute on function public.fn_r3099_losses_by_disqualification() from public, anon;
grant execute on function public.fn_r3099_losses_by_disqualification() to authenticated;

-- =====================================================================
-- RPC 3: losses by tender category
-- =====================================================================
create or replace function public.fn_r3099_losses_by_category()
returns table(
  tender_category text,
  loss_count bigint,
  value_lost_rupees bigint,
  catastrophic_count bigint
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.tender_category,
         count(*)::bigint,
         coalesce(sum(p.bid_value_rupees),0)::bigint,
         count(*) filter (where p.loss_severity = 'catastrophic_flagship')::bigint
  from public.govt_tender_bid_loss_postmortems_r3099 p
  group by p.tender_category
  order by count(*) desc;
end;
$$;
revoke execute on function public.fn_r3099_losses_by_category() from public, anon;
grant execute on function public.fn_r3099_losses_by_category() to authenticated;

-- =====================================================================
-- RPC 4: winning bidder tier breakdown
-- =====================================================================
create or replace function public.fn_r3099_winning_bidder_tier_breakdown()
returns table(
  winning_bidder_tier text,
  wins_against_us bigint,
  total_winning_value_rupees bigint,
  avg_price_gap_percent numeric
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.winning_bidder_tier,
         count(*)::bigint,
         coalesce(sum(p.l1_winning_value_rupees),0)::bigint,
         round(avg(p.price_gap_percent)::numeric, 2)
  from public.govt_tender_bid_loss_postmortems_r3099 p
  group by p.winning_bidder_tier
  order by count(*) desc;
end;
$$;
revoke execute on function public.fn_r3099_winning_bidder_tier_breakdown() from public, anon;
grant execute on function public.fn_r3099_winning_bidder_tier_breakdown() to authenticated;

-- =====================================================================
-- RPC 5: replay decision distribution
-- =====================================================================
create or replace function public.fn_r3099_replay_decision_distribution()
returns table(
  replay_decision text,
  postmortem_count bigint,
  unlock_potential_rupees bigint
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.replay_decision,
         count(*)::bigint,
         coalesce(sum(p.bid_value_rupees),0)::bigint
  from public.govt_tender_bid_loss_postmortems_r3099 p
  group by p.replay_decision
  order by count(*) desc;
end;
$$;
revoke execute on function public.fn_r3099_replay_decision_distribution() from public, anon;
grant execute on function public.fn_r3099_replay_decision_distribution() to authenticated;

-- =====================================================================
-- RPC 6: replay action portfolio rollup
-- =====================================================================
create or replace function public.fn_r3099_replay_action_portfolio()
returns table(
  action_category text,
  action_count bigint,
  completed_count bigint,
  blocked_count bigint,
  total_estimated_cost_rupees bigint,
  total_unlock_value_rupees bigint
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.action_category,
         count(*)::bigint,
         count(*) filter (where a.action_status = 'completed')::bigint,
         count(*) filter (where a.action_status in ('blocked_oem','blocked_legal','awaiting_authority_clarification'))::bigint,
         coalesce(sum(a.estimated_cost_rupees),0)::bigint,
         coalesce(sum(a.expected_unlock_value_rupees),0)::bigint
  from public.govt_tender_replay_playbook_actions_r3099 a
  group by a.action_category
  order by count(*) desc;
end;
$$;
revoke execute on function public.fn_r3099_replay_action_portfolio() from public, anon;
grant execute on function public.fn_r3099_replay_action_portfolio() to authenticated;

-- =====================================================================
-- RPC 7: top losses by value
-- =====================================================================
create or replace function public.fn_r3099_top_losses_by_value()
returns table(
  tender_reference_no text,
  tender_title text,
  issuing_authority text,
  bid_value_rupees bigint,
  price_gap_percent numeric,
  disqualification_reason text,
  replay_decision text,
  postmortem_status text
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.tender_reference_no, p.tender_title, p.issuing_authority,
         p.bid_value_rupees, p.price_gap_percent, p.disqualification_reason,
         p.replay_decision, p.postmortem_status
  from public.govt_tender_bid_loss_postmortems_r3099 p
  order by p.bid_value_rupees desc
  limit 10;
end;
$$;
revoke execute on function public.fn_r3099_top_losses_by_value() from public, anon;
grant execute on function public.fn_r3099_top_losses_by_value() to authenticated;

-- =====================================================================
-- RPC 8: owner workload rollup
-- =====================================================================
create or replace function public.fn_r3099_owner_workload_rollup()
returns table(
  responsible_owner text,
  open_actions bigint,
  blocked_actions bigint,
  completed_actions bigint,
  unlock_value_pending_rupees bigint
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.responsible_owner,
         count(*) filter (where a.action_status in ('not_started','in_progress'))::bigint,
         count(*) filter (where a.action_status in ('blocked_oem','blocked_legal','awaiting_authority_clarification'))::bigint,
         count(*) filter (where a.action_status = 'completed')::bigint,
         coalesce(sum(a.expected_unlock_value_rupees) filter (where a.action_status <> 'completed'),0)::bigint
  from public.govt_tender_replay_playbook_actions_r3099 a
  group by a.responsible_owner
  order by count(*) desc;
end;
$$;
revoke execute on function public.fn_r3099_owner_workload_rollup() from public, anon;
grant execute on function public.fn_r3099_owner_workload_rollup() to authenticated;
