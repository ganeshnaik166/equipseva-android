-- Round 3119: Engineer-Founder Co-Investor Capital-Call Risk + Reserve Tracker
-- Tracks LP capital-call timing, reserves earmarked, follow-on commitments,
-- delayed-funding risk, secondary appetite, sidecar opportunities.

create table if not exists engineer_co_investor_commitments_r3119 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references organizations(id) on delete set null,
  lp_name text not null,
  lp_type text not null check (lp_type in ('engineer_partner','founder_syndicate','angel','family_office','strategic_corp','sidecar_vehicle','secondary_buyer')),
  vintage_quarter text not null check (vintage_quarter ~ '^[0-9]{4}-Q[1-4]$'),
  total_commitment_rupees bigint not null check (total_commitment_rupees > 0),
  called_to_date_rupees bigint not null default 0 check (called_to_date_rupees >= 0),
  reserves_earmarked_rupees bigint not null default 0 check (reserves_earmarked_rupees >= 0),
  follow_on_commitment_rupees bigint not null default 0 check (follow_on_commitment_rupees >= 0),
  next_call_due_at timestamptz,
  next_call_amount_rupees bigint check (next_call_amount_rupees is null or next_call_amount_rupees >= 0),
  funding_risk_band text not null check (funding_risk_band in ('green','amber','red','default_imminent')),
  secondary_appetite text not null check (secondary_appetite in ('none','exploratory','active_buy','active_sell','tender_open')),
  sidecar_eligible boolean not null default false,
  side_letter_terms text,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists engineer_co_investor_capital_calls_r3119 (
  id uuid primary key default gen_random_uuid(),
  commitment_id uuid not null references engineer_co_investor_commitments_r3119(id) on delete cascade,
  call_sequence integer not null check (call_sequence > 0),
  call_purpose text not null check (call_purpose in ('initial_close','follow_on_round','bridge','sidecar_deploy','reserve_call','secondary_purchase','warehouse_fund','expansion_capex')),
  requested_rupees bigint not null check (requested_rupees > 0),
  received_rupees bigint not null default 0 check (received_rupees >= 0),
  notice_sent_at timestamptz not null,
  due_at timestamptz not null,
  settled_at timestamptz,
  delay_days integer not null default 0,
  status text not null check (status in ('notice_sent','partial','funded','delayed','defaulted','waived','rolled_forward')),
  risk_flag text not null check (risk_flag in ('on_track','watch','breach','remedy_active','escalated_to_gp')),
  reserve_release_pct numeric(5,2) check (reserve_release_pct is null or (reserve_release_pct >= 0 and reserve_release_pct <= 100)),
  remediation_plan text,
  created_at timestamptz not null default now()
);

create index if not exists idx_co_inv_commit_risk_r3119 on engineer_co_investor_commitments_r3119(funding_risk_band, next_call_due_at);
create index if not exists idx_co_inv_call_status_r3119 on engineer_co_investor_capital_calls_r3119(status, due_at);

alter table engineer_co_investor_commitments_r3119 enable row level security;
alter table engineer_co_investor_capital_calls_r3119 enable row level security;

-- Seeds (org from first row)
with org as (select id from organizations order by created_at asc limit 1)
insert into engineer_co_investor_commitments_r3119
  (organization_id, lp_name, lp_type, vintage_quarter, total_commitment_rupees, called_to_date_rupees, reserves_earmarked_rupees, follow_on_commitment_rupees, next_call_due_at, next_call_amount_rupees, funding_risk_band, secondary_appetite, sidecar_eligible, side_letter_terms, notes)
select org.id, v.lp_name, v.lp_type, v.vintage_quarter, v.total_commitment_rupees, v.called_to_date_rupees, v.reserves_earmarked_rupees, v.follow_on_commitment_rupees, v.next_call_due_at::timestamptz, v.next_call_amount_rupees, v.funding_risk_band, v.secondary_appetite, v.sidecar_eligible, v.side_letter_terms, v.notes
from org, (values
  ('Apollo Biomed Engineers Syndicate','engineer_partner','2026-Q1', 25000000::bigint, 18000000::bigint, 5000000::bigint, 7000000::bigint, (now() + interval '12 days')::timestamptz, 4000000::bigint, 'green','exploratory', true, 'MFN clause; 8% pref; pro-rata on next 2 rounds','Lead engineer-LP; mentors Tier-3 cohort'),
  ('Manipal Founders Pool','founder_syndicate','2026-Q1', 40000000::bigint, 32000000::bigint, 6000000::bigint, 10000000::bigint, (now() + interval '5 days')::timestamptz, 6000000::bigint, 'amber','active_buy', true, 'Co-investment rights on AMC vertical','3 founders pooled cheques; want sidecar in dental'),
  ('Madurai Angel Collective','angel','2025-Q4', 8000000::bigint, 8000000::bigint, 1500000::bigint, 0::bigint, null::timestamptz, null::bigint, 'green','none', false, null, 'Single-tranche; fully called'),
  ('Khanna Family Office','family_office','2026-Q2', 60000000::bigint, 24000000::bigint, 12000000::bigint, 18000000::bigint, (now() + interval '20 days')::timestamptz, 9000000::bigint, 'green','tender_open', true, 'GP clawback; reporting in INR; ESG screen','Largest LP; opening secondary tender Q4'),
  ('Velluri Strategic Corp (PSU)','strategic_corp','2026-Q2', 50000000::bigint, 10000000::bigint, 8000000::bigint, 25000000::bigint, (now() + interval '45 days')::timestamptz, 12000000::bigint, 'amber','exploratory', false, 'Board observer; quarterly NDA refresh','Slow PSU disbursement cycle; treasury-routed'),
  ('Tamil Sidecar I — Dental Vertical','sidecar_vehicle','2026-Q2', 15000000::bigint, 3000000::bigint, 4000000::bigint, 8000000::bigint, (now() + interval '8 days')::timestamptz, 5000000::bigint, 'amber','none', true, 'Sleeve-fund; dental-only deployment','SPV warehoused for dental chain rollup'),
  ('Bengaluru Bridge Angels','angel','2026-Q1', 12000000::bigint, 6000000::bigint, 2000000::bigint, 4000000::bigint, (now() + interval '15 days')::timestamptz, 3000000::bigint, 'red','exploratory', false, 'No info rights beyond quarterly','Two angels delayed Q1 call by 22 days'),
  ('Kerala Hospital Consortium','strategic_corp','2026-Q3', 35000000::bigint, 5000000::bigint, 6000000::bigint, 15000000::bigint, (now() + interval '60 days')::timestamptz, 8000000::bigint, 'amber','active_sell', false, 'Right of first offer on equipment supply','Want to exit 30% via tender'),
  ('Sundaram Engineer-LP Fund','engineer_partner','2026-Q1', 18000000::bigint, 14000000::bigint, 3500000::bigint, 5000000::bigint, (now() + interval '10 days')::timestamptz, 3500000::bigint, 'green','exploratory', true, 'Sweat-equity convertible at 0.8x','Field engineer LP; high reliability'),
  ('Hyderabad Secondary Buyer A','secondary_buyer','2026-Q2', 22000000::bigint, 0::bigint, 0::bigint, 0::bigint, (now() + interval '30 days')::timestamptz, 7000000::bigint, 'green','active_buy', false, 'Buying angel-tranche secondary at 1.4x','Stapled tender; awaiting GP approval'),
  ('Gujarat Family Trust','family_office','2025-Q3', 30000000::bigint, 30000000::bigint, 4500000::bigint, 6000000::bigint, null::timestamptz, null::bigint, 'green','none', false, 'Founder-friendly; no veto','Fully deployed; passive'),
  ('Defaulting Angel — Pune','angel','2026-Q1', 5000000::bigint, 1000000::bigint, 0::bigint, 0::bigint, (now() - interval '18 days')::timestamptz, 2000000::bigint, 'default_imminent','active_sell', false, null, 'Missed two calls; 18d delinquent; GP remedy initiated')
) as v(lp_name, lp_type, vintage_quarter, total_commitment_rupees, called_to_date_rupees, reserves_earmarked_rupees, follow_on_commitment_rupees, next_call_due_at, next_call_amount_rupees, funding_risk_band, secondary_appetite, sidecar_eligible, side_letter_terms, notes);

-- Capital calls seeds: pick first commitment, then a few representative
with c as (
  select id, lp_name from engineer_co_investor_commitments_r3119 order by created_at asc
)
insert into engineer_co_investor_capital_calls_r3119
  (commitment_id, call_sequence, call_purpose, requested_rupees, received_rupees, notice_sent_at, due_at, settled_at, delay_days, status, risk_flag, reserve_release_pct, remediation_plan)
select c.id, x.call_sequence, x.call_purpose, x.requested_rupees, x.received_rupees,
  x.notice_sent_at::timestamptz, x.due_at::timestamptz, x.settled_at::timestamptz,
  x.delay_days, x.status, x.risk_flag, x.reserve_release_pct, x.remediation_plan
from c
join (values
  ('Apollo Biomed Engineers Syndicate', 1, 'initial_close', 10000000::bigint, 10000000::bigint, (now() - interval '90 days'), (now() - interval '80 days'), (now() - interval '78 days'), 0, 'funded','on_track', 20.0::numeric, null),
  ('Apollo Biomed Engineers Syndicate', 2, 'follow_on_round', 8000000::bigint, 8000000::bigint, (now() - interval '40 days'), (now() - interval '30 days'), (now() - interval '29 days'), 0, 'funded','on_track', 15.0::numeric, null),
  ('Apollo Biomed Engineers Syndicate', 3, 'reserve_call', 4000000::bigint, 0::bigint, (now() - interval '2 days'), (now() + interval '12 days'), null, 0, 'notice_sent','on_track', null, null),
  ('Manipal Founders Pool', 1, 'initial_close', 20000000::bigint, 20000000::bigint, (now() - interval '120 days'), (now() - interval '110 days'), (now() - interval '108 days'), 0, 'funded','on_track', 25.0::numeric, null),
  ('Manipal Founders Pool', 2, 'sidecar_deploy', 12000000::bigint, 12000000::bigint, (now() - interval '50 days'), (now() - interval '40 days'), (now() - interval '36 days'), 4, 'funded','watch', 10.0::numeric,'Treasury routing delay; remediated'),
  ('Manipal Founders Pool', 3, 'follow_on_round', 6000000::bigint, 0::bigint, (now() - interval '10 days'), (now() + interval '5 days'), null, 0, 'notice_sent','watch', null,'Watch — flagged for slow PSU cycle'),
  ('Khanna Family Office', 1, 'initial_close', 15000000::bigint, 15000000::bigint, (now() - interval '150 days'), (now() - interval '140 days'), (now() - interval '139 days'), 0, 'funded','on_track', 18.0::numeric, null),
  ('Khanna Family Office', 2, 'expansion_capex', 9000000::bigint, 0::bigint, (now() - interval '5 days'), (now() + interval '20 days'), null, 0, 'notice_sent','on_track', null, null),
  ('Velluri Strategic Corp (PSU)', 1, 'initial_close', 10000000::bigint, 10000000::bigint, (now() - interval '80 days'), (now() - interval '60 days'), (now() - interval '52 days'), 8, 'funded','watch', 12.0::numeric,'PSU treasury 8-day lag; acceptable'),
  ('Velluri Strategic Corp (PSU)', 2, 'expansion_capex', 12000000::bigint, 0::bigint, (now() - interval '15 days'), (now() + interval '45 days'), null, 0, 'notice_sent','watch', null,'Pre-emptive notice — long PSU cycle'),
  ('Tamil Sidecar I — Dental Vertical', 1, 'sidecar_deploy', 5000000::bigint, 3000000::bigint, (now() - interval '20 days'), (now() + interval '8 days'), null, 0, 'partial','watch', 5.0::numeric,'2 of 5 LPs in SPV settled; chasing'),
  ('Bengaluru Bridge Angels', 1, 'bridge', 6000000::bigint, 6000000::bigint, (now() - interval '70 days'), (now() - interval '60 days'), (now() - interval '38 days'), 22, 'funded','breach', 8.0::numeric,'22-day delay; written warning issued'),
  ('Bengaluru Bridge Angels', 2, 'follow_on_round', 3000000::bigint, 0::bigint, (now() - interval '8 days'), (now() + interval '15 days'), null, 0, 'notice_sent','breach', null,'On watchlist after prior delay'),
  ('Kerala Hospital Consortium', 1, 'initial_close', 5000000::bigint, 5000000::bigint, (now() - interval '60 days'), (now() - interval '50 days'), (now() - interval '47 days'), 3, 'funded','on_track', 14.0::numeric, null),
  ('Hyderabad Secondary Buyer A', 1, 'secondary_purchase', 7000000::bigint, 0::bigint, (now() - interval '3 days'), (now() + interval '30 days'), null, 0, 'notice_sent','on_track', null,'Stapled tender; awaits GP+seller'),
  ('Defaulting Angel — Pune', 1, 'initial_close', 1500000::bigint, 1000000::bigint, (now() - interval '110 days'), (now() - interval '95 days'), (now() - interval '70 days'), 25, 'partial','escalated_to_gp', null,'GP remedy notice; 33% deficient'),
  ('Defaulting Angel — Pune', 2, 'follow_on_round', 2000000::bigint, 0::bigint, (now() - interval '40 days'), (now() - interval '18 days'), null, 18, 'defaulted','escalated_to_gp', null,'Default declared; legal review active')
) as x(lp_name, call_sequence, call_purpose, requested_rupees, received_rupees, notice_sent_at, due_at, settled_at, delay_days, status, risk_flag, reserve_release_pct, remediation_plan)
on c.lp_name = x.lp_name;

-- RPC 1: portfolio summary
create or replace function fn_r3119_commitments_summary()
returns table (
  total_lps bigint,
  total_commitment_rupees bigint,
  total_called_rupees bigint,
  total_uncalled_rupees bigint,
  total_reserves_rupees bigint,
  total_follow_on_rupees bigint,
  red_count bigint,
  amber_count bigint,
  green_count bigint,
  default_imminent_count bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    count(*)::bigint,
    coalesce(sum(total_commitment_rupees),0)::bigint,
    coalesce(sum(called_to_date_rupees),0)::bigint,
    coalesce(sum(total_commitment_rupees - called_to_date_rupees),0)::bigint,
    coalesce(sum(reserves_earmarked_rupees),0)::bigint,
    coalesce(sum(follow_on_commitment_rupees),0)::bigint,
    count(*) filter (where funding_risk_band='red')::bigint,
    count(*) filter (where funding_risk_band='amber')::bigint,
    count(*) filter (where funding_risk_band='green')::bigint,
    count(*) filter (where funding_risk_band='default_imminent')::bigint
  from engineer_co_investor_commitments_r3119;
end;
$$;
revoke execute on function fn_r3119_commitments_summary() from public, anon;
grant execute on function fn_r3119_commitments_summary() to authenticated;

-- RPC 2: risk band detail
create or replace function fn_r3119_commitments_by_risk()
returns table (
  lp_name text,
  lp_type text,
  vintage_quarter text,
  funding_risk_band text,
  total_commitment_rupees bigint,
  uncalled_rupees bigint,
  next_call_due_at timestamptz,
  next_call_amount_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.lp_name, c.lp_type, c.vintage_quarter, c.funding_risk_band,
         c.total_commitment_rupees,
         (c.total_commitment_rupees - c.called_to_date_rupees)::bigint,
         c.next_call_due_at, c.next_call_amount_rupees
  from engineer_co_investor_commitments_r3119 c
  order by case c.funding_risk_band
    when 'default_imminent' then 1 when 'red' then 2 when 'amber' then 3 else 4 end,
    c.next_call_due_at nulls last;
end;
$$;
revoke execute on function fn_r3119_commitments_by_risk() from public, anon;
grant execute on function fn_r3119_commitments_by_risk() to authenticated;

-- RPC 3: upcoming calls in next 60 days
create or replace function fn_r3119_upcoming_calls()
returns table (
  lp_name text,
  call_sequence integer,
  call_purpose text,
  requested_rupees bigint,
  due_at timestamptz,
  days_until_due integer,
  status text,
  risk_flag text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select com.lp_name, cc.call_sequence, cc.call_purpose, cc.requested_rupees,
         cc.due_at,
         extract(day from (cc.due_at - now()))::integer,
         cc.status, cc.risk_flag
  from engineer_co_investor_capital_calls_r3119 cc
  join engineer_co_investor_commitments_r3119 com on com.id = cc.commitment_id
  where cc.status in ('notice_sent','partial','rolled_forward')
    and cc.due_at <= now() + interval '60 days'
  order by cc.due_at asc;
end;
$$;
revoke execute on function fn_r3119_upcoming_calls() from public, anon;
grant execute on function fn_r3119_upcoming_calls() to authenticated;

-- RPC 4: delinquent / breached calls
create or replace function fn_r3119_delinquent_calls()
returns table (
  lp_name text,
  call_sequence integer,
  call_purpose text,
  requested_rupees bigint,
  received_rupees bigint,
  delay_days integer,
  status text,
  risk_flag text,
  remediation_plan text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select com.lp_name, cc.call_sequence, cc.call_purpose, cc.requested_rupees,
         cc.received_rupees, cc.delay_days, cc.status, cc.risk_flag, cc.remediation_plan
  from engineer_co_investor_capital_calls_r3119 cc
  join engineer_co_investor_commitments_r3119 com on com.id = cc.commitment_id
  where cc.status in ('delayed','defaulted','partial')
     or cc.risk_flag in ('breach','remedy_active','escalated_to_gp')
  order by cc.delay_days desc, cc.requested_rupees desc;
end;
$$;
revoke execute on function fn_r3119_delinquent_calls() from public, anon;
grant execute on function fn_r3119_delinquent_calls() to authenticated;

-- RPC 5: reserves utilization
create or replace function fn_r3119_reserves_utilization()
returns table (
  lp_name text,
  reserves_earmarked_rupees bigint,
  reserves_released_pct numeric,
  follow_on_commitment_rupees bigint,
  uncalled_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select com.lp_name,
         com.reserves_earmarked_rupees,
         coalesce(avg(cc.reserve_release_pct),0)::numeric,
         com.follow_on_commitment_rupees,
         (com.total_commitment_rupees - com.called_to_date_rupees)::bigint
  from engineer_co_investor_commitments_r3119 com
  left join engineer_co_investor_capital_calls_r3119 cc on cc.commitment_id = com.id
  group by com.id, com.lp_name, com.reserves_earmarked_rupees,
           com.follow_on_commitment_rupees, com.total_commitment_rupees, com.called_to_date_rupees
  order by com.reserves_earmarked_rupees desc;
end;
$$;
revoke execute on function fn_r3119_reserves_utilization() from public, anon;
grant execute on function fn_r3119_reserves_utilization() to authenticated;

-- RPC 6: secondary appetite
create or replace function fn_r3119_secondary_appetite()
returns table (
  secondary_appetite text,
  lp_count bigint,
  total_commitment_rupees bigint,
  uncalled_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.secondary_appetite,
         count(*)::bigint,
         sum(c.total_commitment_rupees)::bigint,
         sum(c.total_commitment_rupees - c.called_to_date_rupees)::bigint
  from engineer_co_investor_commitments_r3119 c
  group by c.secondary_appetite
  order by sum(c.total_commitment_rupees) desc;
end;
$$;
revoke execute on function fn_r3119_secondary_appetite() from public, anon;
grant execute on function fn_r3119_secondary_appetite() to authenticated;

-- RPC 7: sidecar eligibility
create or replace function fn_r3119_sidecar_eligibility()
returns table (
  lp_name text,
  lp_type text,
  sidecar_eligible boolean,
  follow_on_commitment_rupees bigint,
  uncalled_rupees bigint,
  side_letter_terms text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.lp_name, c.lp_type, c.sidecar_eligible,
         c.follow_on_commitment_rupees,
         (c.total_commitment_rupees - c.called_to_date_rupees)::bigint,
         c.side_letter_terms
  from engineer_co_investor_commitments_r3119 c
  where c.sidecar_eligible = true
  order by c.follow_on_commitment_rupees desc;
end;
$$;
revoke execute on function fn_r3119_sidecar_eligibility() from public, anon;
grant execute on function fn_r3119_sidecar_eligibility() to authenticated;

-- RPC 8: call performance by purpose
create or replace function fn_r3119_calls_by_purpose()
returns table (
  call_purpose text,
  call_count bigint,
  total_requested_rupees bigint,
  total_received_rupees bigint,
  avg_delay_days numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select cc.call_purpose,
         count(*)::bigint,
         sum(cc.requested_rupees)::bigint,
         sum(cc.received_rupees)::bigint,
         avg(cc.delay_days)::numeric
  from engineer_co_investor_capital_calls_r3119 cc
  group by cc.call_purpose
  order by sum(cc.requested_rupees) desc;
end;
$$;
revoke execute on function fn_r3119_calls_by_purpose() from public, anon;
grant execute on function fn_r3119_calls_by_purpose() to authenticated;
