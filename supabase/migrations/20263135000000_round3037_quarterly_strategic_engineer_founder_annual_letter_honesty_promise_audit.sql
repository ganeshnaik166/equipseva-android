-- Round r3037 — Quarterly Strategic Engineer-Founder Annual-Letter Honesty & Promise Audit
-- Two tables + 7 RPCs (is_founder gated)

create table if not exists annual_letter_promises_r3037 (
  id uuid primary key default gen_random_uuid(),
  letter_year int not null,
  promise_code text not null,
  promise_text text not null,
  promise_category text not null check (promise_category in ('growth','quality','people','financial','product','market')),
  promised_metric_name text,
  promised_target_value numeric,
  promised_target_unit text check (promised_target_unit in ('count','rupees_lakh','rupees_crore','percent','ratio','days','hours')),
  promised_by_date date,
  current_actual_value numeric,
  current_progress_percent numeric,
  status text not null check (status in ('on_track','behind','at_risk','achieved','missed','withdrawn')),
  honesty_grade text not null check (honesty_grade in ('A','B','C','D','F')),
  founder_self_assessment text,
  last_reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table annual_letter_promises_r3037 enable row level security;

drop policy if exists alp_r3037_founder_all on annual_letter_promises_r3037;
create policy alp_r3037_founder_all on annual_letter_promises_r3037 for all using (is_founder()) with check (is_founder());

insert into annual_letter_promises_r3037 (letter_year, promise_code, promise_text, promise_category, promised_metric_name, promised_target_value, promised_target_unit, promised_by_date, current_actual_value, current_progress_percent, status, honesty_grade, founder_self_assessment, last_reviewed_at)
select 2025, 'P-001', 'Cross 10,000 active hospitals by end of FY26', 'growth', 'active_hospitals', 10000, 'count', '2026-03-31'::date, 7200, 72.0, 'behind', 'B', 'Pipeline strong but conversion slower than modeled. Honest miss likely 8.5k.', '2026-06-15'::timestamptz
union all select 2025, 'P-002', 'Achieve 95% SLA compliance on repair jobs', 'quality', 'sla_compliance_pct', 95, 'percent', '2026-03-31'::date, 91.4, 96.2, 'at_risk', 'B', 'Tier-3 cities dragging average. P-003 reorg should help.', '2026-06-18'::timestamptz
union all select 2025, 'P-003', 'Hire 50 engineers in Tier-2 cities', 'people', 'tier2_engineers', 50, 'count', '2026-06-30'::date, 38, 76.0, 'on_track', 'A', 'On pace; Hyderabad and Pune ahead of plan.', '2026-06-20'::timestamptz
union all select 2025, 'P-004', 'Reach unit economics positive by Q4', 'financial', 'gross_margin_pct', 35, 'percent', '2026-03-31'::date, 31.2, 89.1, 'behind', 'C', 'Spare-parts margin eroded by USD/INR. Need to renegotiate vendor contracts.', '2026-06-12'::timestamptz
union all select 2025, 'P-005', 'Launch AMC v2 with tiered pricing', 'product', null, null, null, '2025-12-31'::date, null, 100.0, 'achieved', 'A', 'Shipped on schedule; 1,200 contracts signed in Q1.', '2026-04-01'::timestamptz
union all select 2025, 'P-006', 'Expand to 3 new states (TN, KA, KL)', 'market', 'states_active', 3, 'count', '2026-03-31'::date, 2, 66.7, 'behind', 'C', 'TN and KA live; KL blocked by regulatory KYC delays.', '2026-06-10'::timestamptz
union all select 2025, 'P-007', 'Reduce mean-time-to-repair to under 24h', 'quality', 'mttr_hours', 24, 'hours', '2026-03-31'::date, 28.5, 84.2, 'behind', 'B', 'Improved from 41h baseline; final 4h gap is spare-parts logistics.', '2026-06-19'::timestamptz
union all select 2025, 'P-008', 'Onboard 5 hospital chain partnerships', 'growth', 'chain_partnerships', 5, 'count', '2026-03-31'::date, 6, 120.0, 'achieved', 'A', 'Exceeded target — Apollo, Manipal, Fortis, Yashoda, KIMS, Care.', '2026-04-15'::timestamptz
union all select 2024, 'P-009', 'Build founder console with 100+ admin surfaces', 'product', 'admin_surfaces', 100, 'count', '2026-03-31'::date, 1700, 1700.0, 'achieved', 'A', 'Massively overshot — current operating reality demanded more.', '2026-06-21'::timestamptz
union all select 2024, 'P-010', 'Series A close at INR 80cr', 'financial', 'raise_inr_cr', 80, 'rupees_crore', '2025-12-31'::date, 0, 0.0, 'withdrawn', 'D', 'Withdrew; bootstrapped instead. Should have communicated earlier.', '2026-02-01'::timestamptz
union all select 2024, 'P-011', 'NABH-compliant audit trail by Q2', 'quality', null, null, null, '2025-09-30'::date, null, 100.0, 'achieved', 'A', 'Shipped Q1. Hospitals validate it.', '2025-10-01'::timestamptz
union all select 2024, 'P-012', 'Cashfree payout pipeline live', 'financial', null, null, null, '2025-06-30'::date, null, 100.0, 'achieved', 'B', 'Live but KYC delays mean we own the friction publicly.', '2025-07-15'::timestamptz
union all select 2024, 'P-013', 'Engineer NPS above 60', 'people', 'engineer_nps', 60, 'count', '2026-03-31'::date, 47, 78.3, 'behind', 'C', 'Top complaint = payout delays. Linked to P-012 dependency.', '2026-06-05'::timestamptz
union all select 2024, 'P-014', 'Reach 1M repair jobs cumulative', 'growth', 'jobs_cumulative', 1000000, 'count', '2026-03-31'::date, 612000, 61.2, 'missed', 'D', 'Honest miss. Overestimated frequency per hospital by 40%.', '2026-06-01'::timestamptz
union all select 2025, 'P-015', 'Founder responds to any hospital complaint in 4h', 'people', 'founder_sla_hours', 4, 'hours', '2026-03-31'::date, 2.1, 190.5, 'achieved', 'A', 'Met; tracked via founder_priority_actions.', '2026-06-20'::timestamptz
union all select 2025, 'P-016', 'Spare-parts authenticity 100%', 'quality', 'auth_part_pct', 100, 'percent', '2026-03-31'::date, 99.8, 99.8, 'on_track', 'A', '2 counterfeit incidents YTD; both refunded + supplier blacklisted.', '2026-06-17'::timestamptz
union all select 2025, 'P-017', 'AMC churn under 8% annual', 'financial', 'amc_churn_pct', 8, 'percent', '2026-03-31'::date, 11.2, 71.4, 'at_risk', 'C', 'Q1 spike from Tier-3; investigating segment-level pricing.', '2026-06-14'::timestamptz
union all select 2025, 'P-018', 'Launch engineer training academy', 'people', null, null, null, '2025-12-31'::date, null, 100.0, 'achieved', 'B', 'Shipped but graduation rate 62%; quality bar needs lifting.', '2026-01-20'::timestamptz;

create table if not exists honesty_audit_findings_r3037 (
  id uuid primary key default gen_random_uuid(),
  finding_code text not null,
  letter_year int not null,
  finding_type text not null check (finding_type in ('overstatement','omission','misleading_framing','vagueness','accurate','underclaim')),
  severity text not null check (severity in ('critical','high','medium','low','none')),
  passage_excerpt text not null,
  reality_check text not null,
  auditor_recommendation text,
  promise_code text,
  resolution_status text not null check (resolution_status in ('open','acknowledged','corrected','disputed','closed')),
  founder_response text,
  audited_at timestamptz,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

alter table honesty_audit_findings_r3037 enable row level security;

drop policy if exists haf_r3037_founder_all on honesty_audit_findings_r3037;
create policy haf_r3037_founder_all on honesty_audit_findings_r3037 for all using (is_founder()) with check (is_founder());

insert into honesty_audit_findings_r3037 (finding_code, letter_year, finding_type, severity, passage_excerpt, reality_check, auditor_recommendation, promise_code, resolution_status, founder_response, audited_at, resolved_at)
select 'F-001', 2024, 'overstatement', 'high', 'We serve thousands of hospitals across India', 'Actual count at time of letter was 4,200, not "thousands"; phrasing implies higher density', 'Replace with concrete number in next letter', 'P-001', 'corrected', 'Agreed. 2025 letter uses exact figures.', '2026-01-15'::timestamptz, '2026-02-01'::timestamptz
union all select 'F-002', 2024, 'omission', 'critical', 'We will close Series A by year-end', 'No mention that 3 lead investors had already passed; raise was withdrawn 6 months later', 'Disclose material counter-signals when forecasting', 'P-010', 'acknowledged', 'Painful but fair. Withdrawn-letter follow-up sent to readers.', '2026-01-15'::timestamptz, null
union all select 'F-003', 2025, 'vagueness', 'medium', 'Significant progress on quality metrics', 'Multiple quality KPIs missed targets; "significant" obscures direction', 'Tie qualitative claims to specific KPI tables', 'P-002', 'open', null, '2026-06-01'::timestamptz, null
union all select 'F-004', 2025, 'accurate', 'none', 'AMC v2 shipped on schedule with 1,200 contracts', 'Verified against amc_contracts_r3037 ledger; numbers match within ±2%', null, 'P-005', 'closed', 'Good calibration.', '2026-06-02'::timestamptz, '2026-06-02'::timestamptz
union all select 'F-005', 2025, 'misleading_framing', 'high', 'Hospital chains are our fastest-growing channel', 'True YoY but channel still 9% of revenue; framing implies dominance', 'Add denominator context', 'P-008', 'acknowledged', 'Will reword in Q3 update.', '2026-06-03'::timestamptz, null
union all select 'F-006', 2025, 'underclaim', 'low', 'Founder console has admin surfaces', 'Actual count is 1,700+; massive underclaim of operating leverage', 'Quantify the breadth in next investor pack', 'P-009', 'open', null, '2026-06-04'::timestamptz, null
union all select 'F-007', 2024, 'overstatement', 'high', 'Engineer NPS is industry-leading', 'No benchmark cited; current NPS 47 is solid but not industry-leading', 'Cite source or remove claim', 'P-013', 'corrected', 'Removed in 2025 letter draft.', '2026-01-20'::timestamptz, '2026-03-01'::timestamptz
union all select 'F-008', 2025, 'omission', 'medium', 'Spare-parts authenticity at 99.8%', 'Did not disclose 2 counterfeit incidents and customer impact', 'Disclose incidents alongside aggregate metric', 'P-016', 'disputed', 'Believe aggregate is sufficient; incidents disclosed in NABH report.', '2026-06-05'::timestamptz, null
union all select 'F-009', 2024, 'vagueness', 'medium', 'We will expand to additional states', 'No specific states or count named; could not be measured ex-post', 'Bind expansion commitments to named geographies', 'P-006', 'corrected', '2025 letter named TN, KA, KL specifically.', '2026-01-25'::timestamptz, '2026-02-15'::timestamptz
union all select 'F-010', 2025, 'misleading_framing', 'critical', 'Unit economics improving rapidly', 'Gross margin moved 31% to 31.2% — not "rapid"', 'Use precise deltas not adjectives', 'P-004', 'open', null, '2026-06-06'::timestamptz, null
union all select 'F-011', 2024, 'accurate', 'none', 'Cashfree pipeline live by Q2', 'Shipped on time per release notes', null, 'P-012', 'closed', null, '2025-08-01'::timestamptz, '2025-08-01'::timestamptz
union all select 'F-012', 2025, 'overstatement', 'medium', 'Engineer training academy is a major investment', 'Total spend INR 18 lakh; meaningful but not "major" relative to OpEx', 'Calibrate adjectives to absolute spend', 'P-018', 'acknowledged', 'Fair. Will use "focused investment" instead.', '2026-06-07'::timestamptz, null
union all select 'F-013', 2025, 'omission', 'high', 'AMC churn metric reported', 'Cohort-level churn shows Tier-3 at 19%; aggregate masks this', 'Disclose cohort breakdowns', 'P-017', 'open', null, '2026-06-08'::timestamptz, null
union all select 'F-014', 2025, 'underclaim', 'low', 'Founder response SLA met', 'Actually 1.9x better than promise; should highlight as moat', 'Promote as differentiator', 'P-015', 'closed', 'Will feature in Q3.', '2026-06-09'::timestamptz, '2026-06-15'::timestamptz
union all select 'F-015', 2024, 'misleading_framing', 'high', 'Profitability within 18 months', 'No specific definition (EBITDA vs net); definition shifted between letters', 'Lock definitions and disclose changes', 'P-004', 'disputed', 'Definition was always EBITDA per Q4 footnote.', '2026-01-30'::timestamptz, null;

-- RPC 1: promise scorecard
create or replace function f_r3037_promise_scorecard()
returns table(promise_code text, promise_text text, category text, status text, honesty_grade text, progress_percent numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select p.promise_code, p.promise_text, p.promise_category, p.status, p.honesty_grade, p.current_progress_percent
    from annual_letter_promises_r3037 p
    order by p.honesty_grade, p.current_progress_percent nulls last;
end;
$$;

revoke all on function f_r3037_promise_scorecard() from public, anon;
grant execute on function f_r3037_promise_scorecard() to authenticated;

-- RPC 2: status distribution
create or replace function f_r3037_status_distribution()
returns table(status text, promise_count int, avg_progress numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select p.status,
           (count(*) filter (where p.id is not null))::int as promise_count,
           round(avg(p.current_progress_percent)::numeric, 1) as avg_progress
    from annual_letter_promises_r3037 p
    group by p.status
    order by promise_count desc;
end;
$$;

revoke all on function f_r3037_status_distribution() from public, anon;
grant execute on function f_r3037_status_distribution() to authenticated;

-- RPC 3: honesty grade distribution
create or replace function f_r3037_honesty_grade_distribution()
returns table(honesty_grade text, promise_count int, category_breakdown text)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select p.honesty_grade,
           (count(*) filter (where p.id is not null))::int as promise_count,
           string_agg(distinct p.promise_category, ', ' order by p.promise_category) as category_breakdown
    from annual_letter_promises_r3037 p
    group by p.honesty_grade
    order by p.honesty_grade;
end;
$$;

revoke all on function f_r3037_honesty_grade_distribution() from public, anon;
grant execute on function f_r3037_honesty_grade_distribution() to authenticated;

-- RPC 4: audit findings by severity
create or replace function f_r3037_findings_by_severity()
returns table(severity text, finding_count int, open_count int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select h.severity,
           (count(*) filter (where h.id is not null))::int as finding_count,
           (count(*) filter (where h.resolution_status in ('open','acknowledged','disputed')))::int as open_count
    from honesty_audit_findings_r3037 h
    group by h.severity
    order by case h.severity when 'critical' then 1 when 'high' then 2 when 'medium' then 3 when 'low' then 4 else 5 end;
end;
$$;

revoke all on function f_r3037_findings_by_severity() from public, anon;
grant execute on function f_r3037_findings_by_severity() to authenticated;

-- RPC 5: open critical findings
create or replace function f_r3037_open_critical_findings()
returns table(finding_code text, letter_year int, finding_type text, passage text, reality text, recommendation text)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select h.finding_code, h.letter_year, h.finding_type, h.passage_excerpt, h.reality_check, h.auditor_recommendation
    from honesty_audit_findings_r3037 h
    where h.severity in ('critical','high')
      and h.resolution_status in ('open','acknowledged','disputed')
    order by case h.severity when 'critical' then 1 else 2 end, h.letter_year desc;
end;
$$;

revoke all on function f_r3037_open_critical_findings() from public, anon;
grant execute on function f_r3037_open_critical_findings() to authenticated;

-- RPC 6: promises by category honesty
create or replace function f_r3037_category_honesty()
returns table(category text, promise_count int, avg_progress numeric, on_track_count int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select p.promise_category,
           (count(*) filter (where p.id is not null))::int as promise_count,
           round(avg(p.current_progress_percent)::numeric, 1) as avg_progress,
           (count(*) filter (where p.status in ('on_track','achieved')))::int as on_track_count
    from annual_letter_promises_r3037 p
    group by p.promise_category
    order by avg_progress desc nulls last;
end;
$$;

revoke all on function f_r3037_category_honesty() from public, anon;
grant execute on function f_r3037_category_honesty() to authenticated;

-- RPC 7: year over year accuracy
create or replace function f_r3037_year_accuracy()
returns table(letter_year int, total_findings int, accurate_count int, overstatement_count int, accuracy_pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select h.letter_year,
           (count(*) filter (where h.id is not null))::int as total_findings,
           (count(*) filter (where h.finding_type = 'accurate'))::int as accurate_count,
           (count(*) filter (where h.finding_type = 'overstatement'))::int as overstatement_count,
           round((count(*) filter (where h.finding_type in ('accurate','underclaim')))::numeric
                 / nullif(count(*) filter (where h.id is not null),0) * 100, 1) as accuracy_pct
    from honesty_audit_findings_r3037 h
    group by h.letter_year
    order by h.letter_year desc;
end;
$$;

revoke all on function f_r3037_year_accuracy() from public, anon;
grant execute on function f_r3037_year_accuracy() to authenticated;
