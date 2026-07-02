-- Round 3077: Quarterly Strategic Engineer-Founder Open-Book Financials Internal Town-Hall Audit

create table if not exists quarterly_townhall_sessions_r3077 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  fiscal_quarter text not null check (fiscal_quarter in ('FY26-Q1','FY26-Q2','FY26-Q3','FY26-Q4','FY27-Q1','FY27-Q2')),
  session_title text not null,
  held_on timestamptz,
  format text not null check (format in ('in_person','hybrid','remote_only','recorded_only')),
  facilitator_user_id uuid references profiles(id) on delete set null,
  engineers_invited int not null default 0,
  engineers_attended int not null default 0,
  attendance_rate_pct numeric(5,2),
  duration_minutes int,
  open_book_depth text not null check (open_book_depth in ('headline_only','pnl_summary','full_pnl','full_pnl_plus_cashflow','full_pnl_plus_cashflow_plus_runway')),
  revenue_disclosed_rupees bigint,
  gross_margin_pct numeric(5,2),
  burn_rate_rupees bigint,
  runway_months numeric(5,1),
  trust_lift_score numeric(4,2),
  candor_index numeric(4,2),
  audit_grade text not null check (audit_grade in ('A','B','C','D','F','pending_review')),
  audit_notes text,
  audit_status text not null check (audit_status in ('scheduled','in_progress','complete','flagged','remediation_due','closed'))
);

create table if not exists quarterly_townhall_audit_findings_r3077 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  session_id uuid references quarterly_townhall_sessions_r3077(id) on delete cascade,
  finding_code text not null,
  finding_category text not null check (finding_category in ('open_book_completeness','engineer_q_and_a','financial_accuracy','psychological_safety','compensation_transparency','strategic_alignment','equity_disclosure','runway_disclosure')),
  severity text not null check (severity in ('blocker','high','medium','low','info')),
  finding_summary text not null,
  remediation_owner_user_id uuid references profiles(id) on delete set null,
  remediation_due_on date,
  remediation_status text not null check (remediation_status in ('open','in_progress','blocked','complete','waived','overdue')),
  evidence_url text,
  trust_impact_delta numeric(4,2),
  flagged_by_engineer_count int not null default 0,
  closed_on timestamptz
);

alter table quarterly_townhall_sessions_r3077 enable row level security;
alter table quarterly_townhall_audit_findings_r3077 enable row level security;

drop policy if exists qts_r3077_founder_all on quarterly_townhall_sessions_r3077;
create policy qts_r3077_founder_all on quarterly_townhall_sessions_r3077 for all using (is_founder()) with check (is_founder());

drop policy if exists qta_r3077_founder_all on quarterly_townhall_audit_findings_r3077;
create policy qta_r3077_founder_all on quarterly_townhall_audit_findings_r3077 for all using (is_founder()) with check (is_founder());

insert into quarterly_townhall_sessions_r3077 (fiscal_quarter, session_title, held_on, format, engineers_invited, engineers_attended, attendance_rate_pct, duration_minutes, open_book_depth, revenue_disclosed_rupees, gross_margin_pct, burn_rate_rupees, runway_months, trust_lift_score, candor_index, audit_grade, audit_notes, audit_status) values
('FY26-Q1','Founding Quarter Open-Book Reveal','2026-04-05 15:00:00+05:30'::timestamptz,'in_person',8,8,100.00,95,'full_pnl_plus_cashflow_plus_runway',1240000,38.20,1850000,9.5,8.70,9.10,'A','First open-book; engineers asked 23 questions','closed'),
('FY26-Q1','Mid-Quarter Pulse Check','2026-05-10 16:30:00+05:30'::timestamptz,'hybrid',10,9,90.00,60,'pnl_summary',1480000,39.10,1820000,9.7,8.40,8.60,'B','Compressed format; less Q&A time','closed'),
('FY26-Q2','Q2 Strategy + Numbers','2026-07-12 15:00:00+05:30'::timestamptz,'in_person',12,11,91.67,105,'full_pnl_plus_cashflow_plus_runway',2100000,41.50,1920000,10.2,8.90,9.30,'A','Equity refresh disclosed','closed'),
('FY26-Q2','Compensation Transparency Special','2026-08-18 17:00:00+05:30'::timestamptz,'in_person',12,12,100.00,120,'full_pnl_plus_cashflow_plus_runway',2240000,42.00,1890000,10.5,9.20,9.40,'A','All salary bands disclosed','closed'),
('FY26-Q3','Q3 Open-Book + Runway','2026-10-04 15:30:00+05:30'::timestamptz,'hybrid',14,13,92.86,90,'full_pnl_plus_cashflow',2890000,43.80,2050000,11.0,8.80,9.00,'A','Runway extended via revenue','closed'),
('FY26-Q3','Mid-Q3 Strategic Pivot','2026-11-15 16:00:00+05:30'::timestamptz,'remote_only',14,10,71.43,75,'pnl_summary',3120000,44.20,2110000,11.2,7.80,8.20,'B','Remote format hurt candor','closed'),
('FY26-Q4','Annual Wrap + Q4 Numbers','2027-01-20 15:00:00+05:30'::timestamptz,'in_person',16,16,100.00,150,'full_pnl_plus_cashflow_plus_runway',3680000,45.50,2200000,12.0,9.40,9.50,'A','Best session yet','closed'),
('FY26-Q4','Year-End All-Hands Audit','2027-03-08 14:00:00+05:30'::timestamptz,'in_person',16,15,93.75,120,'full_pnl_plus_cashflow_plus_runway',3950000,46.20,2240000,12.5,9.30,9.40,'A','External auditor present','closed'),
('FY27-Q1','FY27 Kickoff Open-Book','2027-04-15 15:00:00+05:30'::timestamptz,'in_person',18,17,94.44,135,'full_pnl_plus_cashflow_plus_runway',4220000,47.10,2380000,13.0,9.10,9.20,'A','New fiscal year disclosures','complete'),
('FY27-Q1','Q1 Compensation Refresh','2027-05-22 16:00:00+05:30'::timestamptz,'hybrid',18,16,88.89,90,'full_pnl_plus_cashflow',4480000,47.80,2410000,13.2,8.70,8.90,'B','Hybrid mode reduced trust signal','complete'),
('FY27-Q2','Mid-Year Strategic Review','2027-07-08 15:00:00+05:30'::timestamptz,'in_person',20,19,95.00,120,'full_pnl_plus_cashflow_plus_runway',4920000,48.40,2520000,13.8,9.00,9.10,'A','Strategy + numbers integrated','in_progress'),
('FY27-Q2','Q2 Quick Pulse','2027-08-25 17:00:00+05:30'::timestamptz,'remote_only',20,14,70.00,45,'headline_only',5120000,48.90,2540000,13.9,7.20,7.50,'C','Too brief; format flagged','flagged'),
('FY26-Q1','Founder-Only Engineer Roundtable',null,'recorded_only',8,7,87.50,60,'pnl_summary',1240000,38.20,1850000,9.5,8.10,8.30,'B','Recording-only; less interactive','complete'),
('FY27-Q2','Crisis Open-Book Special','2027-09-02 19:00:00+05:30'::timestamptz,'in_person',20,20,100.00,180,'full_pnl_plus_cashflow_plus_runway',5050000,47.20,2680000,12.1,9.50,9.60,'A','Convened over funding gap','remediation_due'),
('FY26-Q4','Pre-Audit Dry Run','2027-02-12 14:00:00+05:30'::timestamptz,'hybrid',16,12,75.00,75,'pnl_summary',3820000,45.80,2210000,12.2,8.00,8.30,'B','Dry-run; not all leads present','scheduled');

insert into quarterly_townhall_audit_findings_r3077 (session_id, finding_code, finding_category, severity, finding_summary, remediation_due_on, remediation_status, evidence_url, trust_impact_delta, flagged_by_engineer_count, closed_on) values
((select id from quarterly_townhall_sessions_r3077 where session_title='Founding Quarter Open-Book Reveal'),'F-3077-001','open_book_completeness','low','Cash-in-bank exact figure not stated','2026-04-20'::date,'complete','https://audit.equipseva.example/f3077-001',0.20,2,'2026-04-18 11:00:00+05:30'::timestamptz),
((select id from quarterly_townhall_sessions_r3077 where session_title='Mid-Quarter Pulse Check'),'F-3077-002','engineer_q_and_a','medium','Q&A truncated due to time','2026-05-25'::date,'complete','https://audit.equipseva.example/f3077-002',0.50,5,'2026-05-23 14:00:00+05:30'::timestamptz),
((select id from quarterly_townhall_sessions_r3077 where session_title='Q2 Strategy + Numbers'),'F-3077-003','equity_disclosure','low','Vesting cliffs explained verbally only','2026-07-30'::date,'complete',null,0.10,1,'2026-07-28 09:00:00+05:30'::timestamptz),
((select id from quarterly_townhall_sessions_r3077 where session_title='Compensation Transparency Special'),'F-3077-004','compensation_transparency','info','Band methodology requested in writing','2026-09-05'::date,'complete','https://audit.equipseva.example/f3077-004',0.00,0,'2026-09-02 10:30:00+05:30'::timestamptz),
((select id from quarterly_townhall_sessions_r3077 where session_title='Q3 Open-Book + Runway'),'F-3077-005','runway_disclosure','medium','Runway sensitivity scenarios missing','2026-10-25'::date,'complete','https://audit.equipseva.example/f3077-005',0.40,3,'2026-10-22 16:00:00+05:30'::timestamptz),
((select id from quarterly_townhall_sessions_r3077 where session_title='Mid-Q3 Strategic Pivot'),'F-3077-006','psychological_safety','high','Engineers reported reluctance to ask hard Qs on remote','2026-12-10'::date,'complete','https://audit.equipseva.example/f3077-006',-1.10,7,'2026-12-08 11:15:00+05:30'::timestamptz),
((select id from quarterly_townhall_sessions_r3077 where session_title='Mid-Q3 Strategic Pivot'),'F-3077-007','engineer_q_and_a','medium','Remote-only format limited follow-ups','2026-12-10'::date,'complete',null,-0.60,4,'2026-12-09 12:00:00+05:30'::timestamptz),
((select id from quarterly_townhall_sessions_r3077 where session_title='Annual Wrap + Q4 Numbers'),'F-3077-008','financial_accuracy','low','GST line reconciliation needed','2027-02-05'::date,'complete','https://audit.equipseva.example/f3077-008',0.10,1,'2027-02-03 15:00:00+05:30'::timestamptz),
((select id from quarterly_townhall_sessions_r3077 where session_title='Year-End All-Hands Audit'),'F-3077-009','strategic_alignment','info','Roadmap vs financials linkage strong','2027-03-20'::date,'complete',null,0.30,0,'2027-03-15 10:00:00+05:30'::timestamptz),
((select id from quarterly_townhall_sessions_r3077 where session_title='FY27 Kickoff Open-Book'),'F-3077-010','open_book_completeness','low','Per-engineer cost-to-company not disclosed','2027-05-01'::date,'in_progress',null,0.20,2,null),
((select id from quarterly_townhall_sessions_r3077 where session_title='Q1 Compensation Refresh'),'F-3077-011','compensation_transparency','high','Hybrid format caused band confusion','2027-06-10'::date,'in_progress','https://audit.equipseva.example/f3077-011',-0.80,6,null),
((select id from quarterly_townhall_sessions_r3077 where session_title='Mid-Year Strategic Review'),'F-3077-012','strategic_alignment','medium','3-year plan vs cash needs alignment unclear','2027-07-30'::date,'open',null,-0.30,3,null),
((select id from quarterly_townhall_sessions_r3077 where session_title='Q2 Quick Pulse'),'F-3077-013','open_book_completeness','blocker','Headline-only depth violated open-book charter','2027-09-15'::date,'open','https://audit.equipseva.example/f3077-013',-2.40,12,null),
((select id from quarterly_townhall_sessions_r3077 where session_title='Q2 Quick Pulse'),'F-3077-014','psychological_safety','high','Remote + brief format chilled candor','2027-09-15'::date,'open',null,-1.80,9,null),
((select id from quarterly_townhall_sessions_r3077 where session_title='Crisis Open-Book Special'),'F-3077-015','runway_disclosure','high','Funding gap disclosed; remediation plan due','2027-09-20'::date,'in_progress','https://audit.equipseva.example/f3077-015',-0.90,8,null),
((select id from quarterly_townhall_sessions_r3077 where session_title='Crisis Open-Book Special'),'F-3077-016','financial_accuracy','medium','Burn forecast variance > 8%','2027-09-25'::date,'blocked',null,-0.50,5,null),
((select id from quarterly_townhall_sessions_r3077 where session_title='Founder-Only Engineer Roundtable'),'F-3077-017','engineer_q_and_a','low','Recording-only format reduced engagement','2026-05-01'::date,'waived',null,-0.20,2,'2026-04-28 09:00:00+05:30'::timestamptz),
((select id from quarterly_townhall_sessions_r3077 where session_title='Pre-Audit Dry Run'),'F-3077-018','open_book_completeness','medium','Dry-run skipped 3 financial lines','2027-02-25'::date,'overdue',null,-0.40,3,null),
((select id from quarterly_townhall_sessions_r3077 where session_title='Compensation Transparency Special'),'F-3077-019','equity_disclosure','low','Pool dilution math requested in slide form','2026-09-10'::date,'complete','https://audit.equipseva.example/f3077-019',0.10,1,'2026-09-07 13:00:00+05:30'::timestamptz),
((select id from quarterly_townhall_sessions_r3077 where session_title='Q3 Open-Book + Runway'),'F-3077-020','strategic_alignment','info','Strategy-numbers narrative cohesive','2026-10-30'::date,'complete',null,0.30,0,'2026-10-25 11:00:00+05:30'::timestamptz);

create or replace function founder_r3077_townhall_sessions_list()
returns table(
  session_id uuid,
  fiscal_quarter text,
  session_title text,
  held_on timestamptz,
  format text,
  attendance_rate_pct numeric,
  open_book_depth text,
  trust_lift_score numeric,
  candor_index numeric,
  audit_grade text,
  audit_status text
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
    select s.id, s.fiscal_quarter, s.session_title, s.held_on, s.format,
           s.attendance_rate_pct, s.open_book_depth, s.trust_lift_score,
           s.candor_index, s.audit_grade, s.audit_status
    from quarterly_townhall_sessions_r3077 s
    order by s.held_on desc nulls last, s.created_at desc;
end $$;

create or replace function founder_r3077_quarter_rollup()
returns table(
  fiscal_quarter text,
  sessions_held int,
  avg_attendance_pct numeric,
  avg_trust_lift numeric,
  avg_candor_index numeric,
  total_revenue_disclosed_rupees bigint,
  avg_runway_months numeric,
  a_grade_sessions int,
  flagged_sessions int
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
    select s.fiscal_quarter,
           count(*)::int as sessions_held,
           round(avg(s.attendance_rate_pct)::numeric,2) as avg_attendance_pct,
           round(avg(s.trust_lift_score)::numeric,2) as avg_trust_lift,
           round(avg(s.candor_index)::numeric,2) as avg_candor_index,
           sum(coalesce(s.revenue_disclosed_rupees,0))::bigint as total_revenue_disclosed_rupees,
           round(avg(s.runway_months)::numeric,1) as avg_runway_months,
           (count(*) filter (where s.audit_grade='A'))::int as a_grade_sessions,
           (count(*) filter (where s.audit_status='flagged'))::int as flagged_sessions
    from quarterly_townhall_sessions_r3077 s
    group by s.fiscal_quarter
    order by s.fiscal_quarter;
end $$;

create or replace function founder_r3077_findings_open()
returns table(
  finding_id uuid,
  finding_code text,
  session_title text,
  fiscal_quarter text,
  severity text,
  finding_category text,
  finding_summary text,
  remediation_status text,
  remediation_due_on date,
  flagged_by_engineer_count int,
  trust_impact_delta numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
    select f.id, f.finding_code, s.session_title, s.fiscal_quarter,
           f.severity, f.finding_category, f.finding_summary,
           f.remediation_status, f.remediation_due_on,
           f.flagged_by_engineer_count, f.trust_impact_delta
    from quarterly_townhall_audit_findings_r3077 f
    join quarterly_townhall_sessions_r3077 s on s.id = f.session_id
    where f.remediation_status in ('open','in_progress','blocked','overdue')
    order by
      case f.severity when 'blocker' then 0 when 'high' then 1 when 'medium' then 2 when 'low' then 3 else 4 end,
      f.remediation_due_on nulls last;
end $$;

create or replace function founder_r3077_severity_mix()
returns table(severity text, finding_count int, open_count int, avg_trust_impact numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
    select f.severity,
           count(*)::int as finding_count,
           (count(*) filter (where f.remediation_status in ('open','in_progress','blocked','overdue')))::int as open_count,
           round(avg(f.trust_impact_delta)::numeric,2) as avg_trust_impact
    from quarterly_townhall_audit_findings_r3077 f
    group by f.severity
    order by case f.severity when 'blocker' then 0 when 'high' then 1 when 'medium' then 2 when 'low' then 3 else 4 end;
end $$;

create or replace function founder_r3077_open_book_depth_breakdown()
returns table(open_book_depth text, sessions_count int, avg_trust_lift numeric, avg_candor numeric, avg_attendance_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
    select s.open_book_depth,
           count(*)::int as sessions_count,
           round(avg(s.trust_lift_score)::numeric,2) as avg_trust_lift,
           round(avg(s.candor_index)::numeric,2) as avg_candor,
           round(avg(s.attendance_rate_pct)::numeric,2) as avg_attendance_pct
    from quarterly_townhall_sessions_r3077 s
    group by s.open_book_depth
    order by avg(s.trust_lift_score) desc nulls last;
end $$;

create or replace function founder_r3077_format_impact()
returns table(format text, sessions_count int, avg_attendance_pct numeric, avg_trust_lift numeric, flagged_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
    select s.format,
           count(*)::int as sessions_count,
           round(avg(s.attendance_rate_pct)::numeric,2) as avg_attendance_pct,
           round(avg(s.trust_lift_score)::numeric,2) as avg_trust_lift,
           (count(*) filter (where s.audit_status='flagged'))::int as flagged_count
    from quarterly_townhall_sessions_r3077 s
    group by s.format
    order by avg(s.trust_lift_score) desc nulls last;
end $$;

create or replace function founder_r3077_category_findings()
returns table(finding_category text, total_findings int, blocker_high_count int, total_flags_by_engineers int, avg_trust_impact numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
    select f.finding_category,
           count(*)::int as total_findings,
           (count(*) filter (where f.severity in ('blocker','high')))::int as blocker_high_count,
           sum(f.flagged_by_engineer_count)::int as total_flags_by_engineers,
           round(avg(f.trust_impact_delta)::numeric,2) as avg_trust_impact
    from quarterly_townhall_audit_findings_r3077 f
    group by f.finding_category
    order by count(*) filter (where f.severity in ('blocker','high')) desc;
end $$;

create or replace function founder_r3077_program_health()
returns table(metric text, value text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
    select 'total_sessions'::text, count(*)::text from quarterly_townhall_sessions_r3077
    union all
    select 'sessions_grade_A', (count(*) filter (where audit_grade='A'))::text from quarterly_townhall_sessions_r3077
    union all
    select 'sessions_flagged', (count(*) filter (where audit_status='flagged'))::text from quarterly_townhall_sessions_r3077
    union all
    select 'avg_attendance_pct', coalesce(round(avg(attendance_rate_pct)::numeric,2)::text,'0') from quarterly_townhall_sessions_r3077
    union all
    select 'avg_trust_lift', coalesce(round(avg(trust_lift_score)::numeric,2)::text,'0') from quarterly_townhall_sessions_r3077
    union all
    select 'avg_candor', coalesce(round(avg(candor_index)::numeric,2)::text,'0') from quarterly_townhall_sessions_r3077
    union all
    select 'open_findings', (count(*) filter (where remediation_status in ('open','in_progress','blocked','overdue')))::text from quarterly_townhall_audit_findings_r3077
    union all
    select 'blocker_findings', (count(*) filter (where severity='blocker'))::text from quarterly_townhall_audit_findings_r3077
    union all
    select 'overdue_findings', (count(*) filter (where remediation_status='overdue'))::text from quarterly_townhall_audit_findings_r3077;
end $$;

revoke all on function founder_r3077_townhall_sessions_list() from public, anon;
revoke all on function founder_r3077_quarter_rollup() from public, anon;
revoke all on function founder_r3077_findings_open() from public, anon;
revoke all on function founder_r3077_severity_mix() from public, anon;
revoke all on function founder_r3077_open_book_depth_breakdown() from public, anon;
revoke all on function founder_r3077_format_impact() from public, anon;
revoke all on function founder_r3077_category_findings() from public, anon;
revoke all on function founder_r3077_program_health() from public, anon;

grant execute on function founder_r3077_townhall_sessions_list() to authenticated;
grant execute on function founder_r3077_quarter_rollup() to authenticated;
grant execute on function founder_r3077_findings_open() to authenticated;
grant execute on function founder_r3077_severity_mix() to authenticated;
grant execute on function founder_r3077_open_book_depth_breakdown() to authenticated;
grant execute on function founder_r3077_format_impact() to authenticated;
grant execute on function founder_r3077_category_findings() to authenticated;
grant execute on function founder_r3077_program_health() to authenticated;
