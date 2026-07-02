-- Round 3115: Founder Quarterly Strategic Channel Partner / Distributor Engagement Margin Tracker
-- HEAVY ★★★★ — equipment distributor + parts reseller channel rollup
-- Scope: partner × ARR × parts orders × OEM rebate × payment terms × dispute count × tier rank

set search_path = public, pg_temp;

------------------------------------------------------------
-- Table 1: channel partner master roster
------------------------------------------------------------
create table if not exists channel_partners_r3115 (
  id uuid primary key default gen_random_uuid(),
  partner_org_id uuid not null references organizations(id) on delete cascade,
  partner_code text not null unique,
  partner_name text not null,
  partner_type text not null check (partner_type in (
    'equipment_distributor','parts_reseller','dual_channel','oem_authorized','grey_market_recovery','refurb_specialist'
  )),
  region text not null check (region in (
    'south_india','north_india','east_india','west_india','northeast','central','metro_only','tier2_tier3','pan_india'
  )),
  tier_rank text not null check (tier_rank in (
    'platinum','gold','silver','bronze','probation','watchlist','strategic'
  )),
  onboarded_on date not null,
  arr_inr_lakhs numeric(12,2) not null check (arr_inr_lakhs >= 0),
  parts_orders_q numeric(8,0) not null check (parts_orders_q >= 0),
  oem_rebate_pct numeric(6,3) not null check (oem_rebate_pct between 0 and 35),
  margin_pct numeric(6,3) not null check (margin_pct between -20 and 60),
  payment_terms_days int not null check (payment_terms_days between 0 and 180),
  dispute_count_q int not null default 0 check (dispute_count_q >= 0),
  exclusivity_clause boolean not null default false,
  primary_oem_brand text not null check (primary_oem_brand in (
    'philips','ge_healthcare','siemens','mindray','drager','nihon_kohden','bpl','schiller','allengers','multi_brand'
  )),
  strategic_notes text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists channel_partners_r3115_tier_idx on channel_partners_r3115(tier_rank);
create index if not exists channel_partners_r3115_region_idx on channel_partners_r3115(region);

------------------------------------------------------------
-- Table 2: quarterly engagement events / margin movements
------------------------------------------------------------
create table if not exists channel_engagement_events_r3115 (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references channel_partners_r3115(id) on delete cascade,
  event_type text not null check (event_type in (
    'qbr_completed','rebate_negotiation','dispute_filed','dispute_resolved','margin_review','terms_renegotiation',
    'tier_upgrade','tier_downgrade','exclusivity_signed','escalation','strategic_kickoff','churn_warning'
  )),
  event_outcome text not null check (event_outcome in (
    'favorable','neutral','adverse','blocked','pending_legal','escalated_to_founder','closed','renewal_secured'
  )),
  margin_delta_pct numeric(6,3) not null default 0 check (margin_delta_pct between -20 and 20),
  arr_impact_inr_lakhs numeric(12,2) not null default 0,
  occurred_on date not null,
  followup_due date,
  founder_attention boolean not null default false,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists channel_engagement_events_r3115_partner_idx on channel_engagement_events_r3115(partner_id);
create index if not exists channel_engagement_events_r3115_outcome_idx on channel_engagement_events_r3115(event_outcome);

------------------------------------------------------------
-- RLS lockdown — RPC-only access
------------------------------------------------------------
alter table channel_partners_r3115 enable row level security;
alter table channel_engagement_events_r3115 enable row level security;

------------------------------------------------------------
-- Seed (12+ rows across both tables)
------------------------------------------------------------
do $seed$
declare
  v_org_id uuid;
  v_p1 uuid; v_p2 uuid; v_p3 uuid; v_p4 uuid; v_p5 uuid; v_p6 uuid; v_p7 uuid;
begin
  select id into v_org_id from organizations order by created_at asc limit 1;
  if v_org_id is null then
    raise notice 'no organizations row, skip seed r3115';
    return;
  end if;

  insert into channel_partners_r3115 (
    partner_org_id, partner_code, partner_name, partner_type, region, tier_rank,
    onboarded_on, arr_inr_lakhs, parts_orders_q, oem_rebate_pct, margin_pct,
    payment_terms_days, dispute_count_q, exclusivity_clause, primary_oem_brand, strategic_notes, reviewed_at
  ) values
    (v_org_id, 'CP-HYD-001', 'Deccan MedTech Distributors', 'equipment_distributor', 'south_india', 'platinum',
     '2024-03-12', 187.50, 412, 14.250, 22.500, 45, 1, true, 'philips',
     'Anchor partner Telangana + AP; QBR clean; renewal negotiated', now() - interval '5 days'),
    (v_org_id, 'CP-MUM-002', 'Western Coast Parts Hub', 'parts_reseller', 'west_india', 'gold',
     '2024-06-01', 92.40, 1240, 9.500, 16.250, 30, 3, false, 'multi_brand',
     'High volume parts reseller; 3 disputes Q on counterfeit fuse claims', now() - interval '12 days'),
    (v_org_id, 'CP-DEL-003', 'NCR Bio-Medical Channel Co', 'dual_channel', 'north_india', 'gold',
     '2023-11-20', 154.80, 678, 11.750, 19.000, 60, 0, false, 'ge_healthcare',
     'GE authorized for NCR + UP-West; clean books', now() - interval '8 days'),
    (v_org_id, 'CP-BLR-004', 'Karnataka OEM Authorized Pvt', 'oem_authorized', 'south_india', 'platinum',
     '2023-08-15', 244.75, 520, 16.000, 24.250, 45, 0, true, 'siemens',
     'Siemens exclusivity Karnataka; strategic priority', now() - interval '3 days'),
    (v_org_id, 'CP-KOL-005', 'Eastern Refurb & Recovery', 'refurb_specialist', 'east_india', 'silver',
     '2024-09-04', 38.20, 188, 6.500, 12.750, 75, 2, false, 'multi_brand',
     'Refurb monitors WB + Jharkhand; margin pressure', null),
    (v_org_id, 'CP-PUN-006', 'Pune Med-Equip Wholesale', 'parts_reseller', 'west_india', 'silver',
     '2024-01-22', 64.10, 940, 8.750, 14.500, 45, 5, false, 'bpl',
     'BPL parts wholesale; 5 disputes flagged — investigate', now() - interval '20 days'),
    (v_org_id, 'CP-CHN-007', 'Tamil Nadu Diagnostic Channel', 'equipment_distributor', 'south_india', 'gold',
     '2023-04-09', 132.60, 356, 13.250, 18.750, 60, 1, false, 'mindray',
     'Mindray distributor TN + Pondicherry', now() - interval '15 days'),
    (v_org_id, 'CP-AHM-008', 'Gujarat Critical Care Distributors', 'oem_authorized', 'west_india', 'platinum',
     '2023-06-18', 198.40, 467, 15.500, 23.000, 45, 0, true, 'drager',
     'Drager exclusivity Gujarat; ventilator pipeline strong', now() - interval '7 days'),
    (v_org_id, 'CP-GHY-009', 'Northeast MedSupply Network', 'dual_channel', 'northeast', 'bronze',
     '2024-11-30', 22.80, 142, 7.000, 11.250, 90, 4, false, 'multi_brand',
     'Northeast logistics challenge; 4 disputes Q; consider probation', null),
    (v_org_id, 'CP-IND-010', 'Indore Central India Channel', 'equipment_distributor', 'central', 'silver',
     '2024-02-14', 71.50, 298, 10.250, 15.500, 60, 2, false, 'schiller',
     'Schiller ECG channel MP + Chhattisgarh', now() - interval '18 days'),
    (v_org_id, 'CP-LKO-011', 'UP-East Grey Market Recovery', 'grey_market_recovery', 'north_india', 'probation',
     '2025-01-08', 18.90, 87, 5.250, 9.750, 90, 7, false, 'multi_brand',
     'Grey market recovery UP-East; 7 disputes — watchlist candidate', now() - interval '2 days'),
    (v_org_id, 'CP-COK-012', 'Kerala Coastal Channel Network', 'parts_reseller', 'south_india', 'gold',
     '2023-12-11', 88.30, 612, 9.750, 17.000, 45, 1, false, 'nihon_kohden',
     'Nihon Kohden parts Kerala + Lakshadweep; stable', now() - interval '10 days'),
    (v_org_id, 'CP-JAI-013', 'Rajasthan Tier2 Strategic Channel', 'dual_channel', 'tier2_tier3', 'strategic',
     '2024-07-25', 56.40, 234, 12.000, 17.500, 60, 0, false, 'allengers',
     'Allengers Rajasthan strategic; tier2 expansion bet', now() - interval '4 days'),
    (v_org_id, 'CP-PAN-014', 'Pan-India Watchlist Reseller', 'parts_reseller', 'pan_india', 'watchlist',
     '2024-08-19', 14.20, 56, 4.500, 7.250, 120, 9, false, 'multi_brand',
     'Watchlist — 9 disputes Q + 120-day terms; founder review pending', null);

  select id into v_p1 from channel_partners_r3115 where partner_code = 'CP-HYD-001' limit 1;
  select id into v_p2 from channel_partners_r3115 where partner_code = 'CP-MUM-002' limit 1;
  select id into v_p3 from channel_partners_r3115 where partner_code = 'CP-DEL-003' limit 1;
  select id into v_p4 from channel_partners_r3115 where partner_code = 'CP-BLR-004' limit 1;
  select id into v_p5 from channel_partners_r3115 where partner_code = 'CP-LKO-011' limit 1;
  select id into v_p6 from channel_partners_r3115 where partner_code = 'CP-PAN-014' limit 1;
  select id into v_p7 from channel_partners_r3115 where partner_code = 'CP-GHY-009' limit 1;

  insert into channel_engagement_events_r3115 (
    partner_id, event_type, event_outcome, margin_delta_pct, arr_impact_inr_lakhs,
    occurred_on, followup_due, founder_attention, notes
  ) values
    (v_p1, 'qbr_completed', 'favorable', 1.250, 12.50, current_date - 8, current_date + 80, false,
     'Q-review clean; rebate negotiated +1.25%'),
    (v_p1, 'exclusivity_signed', 'renewal_secured', 0.750, 24.00, current_date - 22, null, true,
     'Philips exclusivity Telangana 24-month renewal'),
    (v_p2, 'dispute_filed', 'pending_legal', -0.500, -3.20, current_date - 15, current_date + 14, true,
     'Counterfeit fuse dispute #2 of quarter; legal review'),
    (v_p2, 'rebate_negotiation', 'neutral', 0.000, 0.00, current_date - 30, current_date + 60, false,
     'Held rebate flat at 9.5% pending dispute closure'),
    (v_p3, 'qbr_completed', 'favorable', 0.500, 8.40, current_date - 12, current_date + 78, false,
     'NCR QBR clean'),
    (v_p4, 'tier_upgrade', 'favorable', 2.000, 18.75, current_date - 18, null, false,
     'Siemens exclusivity Karnataka — already platinum, retained'),
    (v_p4, 'strategic_kickoff', 'favorable', 0.000, 0.00, current_date - 60, current_date + 30, true,
     'Joint pipeline planning Q3; founder attended'),
    (v_p5, 'churn_warning', 'adverse', -1.500, -4.20, current_date - 5, current_date + 7, true,
     'Probation partner — 7 disputes; founder must decide'),
    (v_p5, 'margin_review', 'adverse', -0.750, -1.40, current_date - 25, null, false,
     'Margin slipped to 9.75%'),
    (v_p6, 'escalation', 'escalated_to_founder', -2.000, -8.50, current_date - 2, current_date + 5, true,
     'Watchlist partner 9 disputes + 120-day terms; recommend terminate'),
    (v_p6, 'dispute_filed', 'blocked', 0.000, 0.00, current_date - 10, current_date + 20, true,
     'Counterfeit cable dispute; legal hold'),
    (v_p7, 'terms_renegotiation', 'adverse', -1.000, -2.80, current_date - 9, current_date + 21, false,
     'Northeast partner pushed for 90-day terms; conceded'),
    (v_p7, 'dispute_resolved', 'closed', 0.250, 0.40, current_date - 40, null, false,
     'Resolved 1 of 4 disputes via credit note'),
    (v_p3, 'rebate_negotiation', 'favorable', 1.500, 9.20, current_date - 35, null, false,
     'GE rebate stepped up to 11.75%');
end
$seed$;

------------------------------------------------------------
-- RPC 1: roster snapshot
------------------------------------------------------------
create or replace function fn_r3115_partner_roster_snapshot()
returns table (
  partner_code text,
  partner_name text,
  partner_type text,
  region text,
  tier_rank text,
  arr_inr_lakhs numeric,
  parts_orders_q numeric,
  oem_rebate_pct numeric,
  margin_pct numeric,
  payment_terms_days int,
  dispute_count_q int,
  exclusivity_clause boolean,
  primary_oem_brand text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select cp.partner_code, cp.partner_name, cp.partner_type, cp.region, cp.tier_rank,
           cp.arr_inr_lakhs, cp.parts_orders_q, cp.oem_rebate_pct, cp.margin_pct,
           cp.payment_terms_days, cp.dispute_count_q, cp.exclusivity_clause, cp.primary_oem_brand
      from channel_partners_r3115 cp
     order by cp.arr_inr_lakhs desc;
end
$$;

revoke execute on function fn_r3115_partner_roster_snapshot() from public, anon;
grant execute on function fn_r3115_partner_roster_snapshot() to authenticated;

------------------------------------------------------------
-- RPC 2: tier distribution
------------------------------------------------------------
create or replace function fn_r3115_tier_distribution()
returns table (
  tier_rank text,
  partner_count bigint,
  total_arr_lakhs numeric,
  avg_margin_pct numeric,
  total_disputes bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select cp.tier_rank,
           count(*)::bigint,
           round(sum(cp.arr_inr_lakhs)::numeric, 2),
           round(avg(cp.margin_pct)::numeric, 3),
           sum(cp.dispute_count_q)::bigint
      from channel_partners_r3115 cp
     group by cp.tier_rank
     order by sum(cp.arr_inr_lakhs) desc;
end
$$;

revoke execute on function fn_r3115_tier_distribution() from public, anon;
grant execute on function fn_r3115_tier_distribution() to authenticated;

------------------------------------------------------------
-- RPC 3: regional rollup
------------------------------------------------------------
create or replace function fn_r3115_regional_rollup()
returns table (
  region text,
  partner_count bigint,
  total_arr_lakhs numeric,
  total_parts_orders numeric,
  avg_rebate_pct numeric,
  avg_terms_days numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select cp.region,
           count(*)::bigint,
           round(sum(cp.arr_inr_lakhs)::numeric, 2),
           sum(cp.parts_orders_q)::numeric,
           round(avg(cp.oem_rebate_pct)::numeric, 3),
           round(avg(cp.payment_terms_days)::numeric, 1)
      from channel_partners_r3115 cp
     group by cp.region
     order by sum(cp.arr_inr_lakhs) desc;
end
$$;

revoke execute on function fn_r3115_regional_rollup() from public, anon;
grant execute on function fn_r3115_regional_rollup() to authenticated;

------------------------------------------------------------
-- RPC 4: oem brand concentration
------------------------------------------------------------
create or replace function fn_r3115_oem_brand_concentration()
returns table (
  primary_oem_brand text,
  partner_count bigint,
  total_arr_lakhs numeric,
  avg_rebate_pct numeric,
  exclusivity_count bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select cp.primary_oem_brand,
           count(*)::bigint,
           round(sum(cp.arr_inr_lakhs)::numeric, 2),
           round(avg(cp.oem_rebate_pct)::numeric, 3),
           sum(case when cp.exclusivity_clause then 1 else 0 end)::bigint
      from channel_partners_r3115 cp
     group by cp.primary_oem_brand
     order by sum(cp.arr_inr_lakhs) desc;
end
$$;

revoke execute on function fn_r3115_oem_brand_concentration() from public, anon;
grant execute on function fn_r3115_oem_brand_concentration() to authenticated;

------------------------------------------------------------
-- RPC 5: dispute heatmap
------------------------------------------------------------
create or replace function fn_r3115_dispute_heatmap()
returns table (
  partner_code text,
  partner_name text,
  tier_rank text,
  dispute_count_q int,
  margin_pct numeric,
  payment_terms_days int,
  founder_action text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select cp.partner_code, cp.partner_name, cp.tier_rank, cp.dispute_count_q,
           cp.margin_pct, cp.payment_terms_days,
           case
             when cp.dispute_count_q >= 7 then 'TERMINATE_REVIEW'
             when cp.dispute_count_q >= 4 then 'PROBATION'
             when cp.dispute_count_q >= 2 then 'QBR_FOLLOWUP'
             else 'OK'
           end as founder_action
      from channel_partners_r3115 cp
     where cp.dispute_count_q > 0
     order by cp.dispute_count_q desc, cp.arr_inr_lakhs desc;
end
$$;

revoke execute on function fn_r3115_dispute_heatmap() from public, anon;
grant execute on function fn_r3115_dispute_heatmap() to authenticated;

------------------------------------------------------------
-- RPC 6: engagement event log
------------------------------------------------------------
create or replace function fn_r3115_engagement_event_log()
returns table (
  partner_code text,
  partner_name text,
  event_type text,
  event_outcome text,
  margin_delta_pct numeric,
  arr_impact_inr_lakhs numeric,
  occurred_on date,
  founder_attention boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select cp.partner_code, cp.partner_name,
           ev.event_type, ev.event_outcome,
           ev.margin_delta_pct, ev.arr_impact_inr_lakhs,
           ev.occurred_on, ev.founder_attention, ev.notes
      from channel_engagement_events_r3115 ev
      join channel_partners_r3115 cp on cp.id = ev.partner_id
     order by ev.occurred_on desc
     limit 100;
end
$$;

revoke execute on function fn_r3115_engagement_event_log() from public, anon;
grant execute on function fn_r3115_engagement_event_log() to authenticated;

------------------------------------------------------------
-- RPC 7: outcome rollup
------------------------------------------------------------
create or replace function fn_r3115_event_outcome_rollup()
returns table (
  event_outcome text,
  event_count bigint,
  total_margin_delta numeric,
  total_arr_impact numeric,
  founder_attention_count bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select ev.event_outcome,
           count(*)::bigint,
           round(sum(ev.margin_delta_pct)::numeric, 3),
           round(sum(ev.arr_impact_inr_lakhs)::numeric, 2),
           sum(case when ev.founder_attention then 1 else 0 end)::bigint
      from channel_engagement_events_r3115 ev
     group by ev.event_outcome
     order by sum(ev.arr_impact_inr_lakhs) desc;
end
$$;

revoke execute on function fn_r3115_event_outcome_rollup() from public, anon;
grant execute on function fn_r3115_event_outcome_rollup() to authenticated;

------------------------------------------------------------
-- RPC 8: founder-attention queue
------------------------------------------------------------
create or replace function fn_r3115_founder_attention_queue()
returns table (
  partner_code text,
  partner_name text,
  tier_rank text,
  event_type text,
  event_outcome text,
  occurred_on date,
  followup_due date,
  arr_impact_inr_lakhs numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select cp.partner_code, cp.partner_name, cp.tier_rank,
           ev.event_type, ev.event_outcome, ev.occurred_on, ev.followup_due,
           ev.arr_impact_inr_lakhs, ev.notes
      from channel_engagement_events_r3115 ev
      join channel_partners_r3115 cp on cp.id = ev.partner_id
     where ev.founder_attention = true
     order by ev.occurred_on desc;
end
$$;

revoke execute on function fn_r3115_founder_attention_queue() from public, anon;
grant execute on function fn_r3115_founder_attention_queue() to authenticated;

------------------------------------------------------------
-- RPC 9: strategic margin scoreboard
------------------------------------------------------------
create or replace function fn_r3115_margin_scoreboard()
returns table (
  partner_code text,
  partner_name text,
  tier_rank text,
  margin_pct numeric,
  arr_inr_lakhs numeric,
  oem_rebate_pct numeric,
  composite_score numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select cp.partner_code, cp.partner_name, cp.tier_rank,
           cp.margin_pct, cp.arr_inr_lakhs, cp.oem_rebate_pct,
           round(
             (cp.margin_pct * 0.45 + cp.oem_rebate_pct * 0.30
              + (cp.arr_inr_lakhs / nullif(250,0)) * 100 * 0.20
              - cp.dispute_count_q * 1.5)::numeric, 3
           ) as composite_score
      from channel_partners_r3115 cp
     order by 7 desc;
end
$$;

revoke execute on function fn_r3115_margin_scoreboard() from public, anon;
grant execute on function fn_r3115_margin_scoreboard() to authenticated;
