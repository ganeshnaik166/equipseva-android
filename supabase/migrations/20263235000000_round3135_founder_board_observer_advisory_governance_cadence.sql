-- Round 3135 HEAVY: Founder Quarterly Strategic Board Observer + Advisory Board Governance Cadence Tracker
-- Scope: Board observer + advisory board — member x cadence x attendance x NDA x pre-read x decision follow-up x conflict declaration x comp
begin;

create table if not exists board_advisory_members_r3135 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  member_full_name text not null,
  member_role text not null check (member_role in ('board_observer','independent_advisor','clinical_advisor','regulatory_advisor','investor_observer','founder_mentor','operating_partner','domain_expert')),
  affiliation_org text not null,
  seat_class text not null check (seat_class in ('paid_observer','equity_advisor','honorary','pro_bono','investor_pro_rata','domain_paid')),
  nda_status text not null check (nda_status in ('signed','pending','expired','not_required','under_review')),
  nda_signed_on date,
  conflict_declared text not null check (conflict_declared in ('none','disclosed_mitigated','pending_review','recuse_required','material_conflict')),
  compensation_type text not null check (compensation_type in ('cash_retainer','equity_grant','cash_plus_equity','equity_only','honorary_zero','expense_only')),
  quarterly_retainer_rupees integer not null default 0 check (quarterly_retainer_rupees >= 0),
  equity_bps integer not null default 0 check (equity_bps >= 0 and equity_bps <= 500),
  onboarded_at timestamptz not null default now(),
  offboarded_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists board_cadence_sessions_r3135 (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references board_advisory_members_r3135(id) on delete cascade,
  session_quarter text not null check (session_quarter in ('Q1_FY26','Q2_FY26','Q3_FY26','Q4_FY26','Q1_FY27','Q2_FY27')),
  session_type text not null check (session_type in ('formal_board_observer','advisory_1on1','quarterly_strategy_review','ad_hoc_diligence','annual_offsite','crisis_convene')),
  scheduled_on timestamptz not null,
  attendance_status text not null check (attendance_status in ('attended_full','attended_partial','sent_written_notes','no_show_notified','no_show_unnotified','rescheduled')),
  pre_read_delivery text not null check (pre_read_delivery in ('delivered_on_time','delivered_late','skipped','not_required','delivered_partial')),
  pre_read_lead_hours integer check (pre_read_lead_hours >= 0),
  decision_follow_up_status text not null check (decision_follow_up_status in ('closed','in_progress','blocked','waived','not_actioned','deferred_next_quarter')),
  decision_summary text not null,
  action_items_count integer not null default 0 check (action_items_count >= 0),
  compensation_paid_rupees integer not null default 0 check (compensation_paid_rupees >= 0),
  created_at timestamptz not null default now()
);

with org_pick as (
  select id as org_id from organizations order by created_at asc limit 1
),
member_seed as (
  insert into board_advisory_members_r3135 (
    organization_id, member_full_name, member_role, affiliation_org, seat_class,
    nda_status, nda_signed_on, conflict_declared, compensation_type,
    quarterly_retainer_rupees, equity_bps, onboarded_at, offboarded_at
  )
  select o.org_id, q.member_full_name, q.member_role, q.affiliation_org, q.seat_class,
         q.nda_status, q.nda_signed_on::date, q.conflict_declared, q.compensation_type,
         q.quarterly_retainer_rupees, q.equity_bps, q.onboarded_at::timestamptz, q.offboarded_at::timestamptz
  from org_pick o
  cross join (values
    ('Dr Ramesh Krishnan','board_observer','Peak XV Partners India','investor_pro_rata','signed','2026-01-15','none','honorary_zero',0,0,'2026-01-20 10:00:00+05:30',null),
    ('Meera Subramanian','independent_advisor','Ex-Philips Healthcare India','equity_advisor','signed','2026-02-01','disclosed_mitigated','equity_only',0,25,'2026-02-05 11:00:00+05:30',null),
    ('Dr Anjali Deshmukh','clinical_advisor','Apollo Hospitals Chennai','equity_advisor','signed','2026-01-28','none','cash_plus_equity',75000,15,'2026-02-01 09:30:00+05:30',null),
    ('Vikram Rajgopal','regulatory_advisor','Ex-CDSCO Joint Commissioner','domain_paid','signed','2026-02-10','disclosed_mitigated','cash_retainer',150000,0,'2026-02-15 14:00:00+05:30',null),
    ('Sanjay Bhatnagar','investor_observer','Blume Ventures','investor_pro_rata','signed','2026-03-01','none','honorary_zero',0,0,'2026-03-05 10:00:00+05:30',null),
    ('Priya Ganesan','operating_partner','Ex-BigBasket COO','equity_advisor','signed','2026-01-10','none','equity_only',0,50,'2026-01-15 11:00:00+05:30',null),
    ('Dr Suresh Menon','clinical_advisor','St John''s Medical College Bangalore','equity_advisor','pending','2026-06-15','pending_review','cash_plus_equity',60000,10,'2026-06-20 15:00:00+05:30',null),
    ('Rakesh Iyer','founder_mentor','Ex-Portea Medical Founder','honorary','signed','2026-01-05','none','honorary_zero',0,0,'2026-01-10 09:00:00+05:30',null),
    ('Dr Kavitha Reddy','domain_expert','KIMS Hyderabad Biomedical Head','domain_paid','signed','2026-02-20','disclosed_mitigated','cash_retainer',100000,0,'2026-02-25 10:00:00+05:30',null),
    ('Arjun Kapoor','independent_advisor','Ex-Practo Growth VP','equity_advisor','expired','2025-12-01','material_conflict','equity_only',0,20,'2025-12-05 11:00:00+05:30','2026-04-30 18:00:00+05:30'),
    ('Neha Malhotra','regulatory_advisor','Ex-NABH Assessor','paid_observer','signed','2026-03-10','none','cash_retainer',80000,0,'2026-03-15 12:00:00+05:30',null),
    ('Dr Prakash Iyengar','operating_partner','Ex-Siemens Healthineers India MD','equity_advisor','under_review','2026-06-25','pending_review','cash_plus_equity',125000,30,'2026-06-28 10:00:00+05:30',null),
    ('Lakshmi Narayanan','investor_observer','Elevation Capital','investor_pro_rata','signed','2026-04-01','none','honorary_zero',0,0,'2026-04-05 11:00:00+05:30',null),
    ('Dr Bhaskar Rao','clinical_advisor','AIIMS Delhi Cardiology','domain_paid','not_required','2026-05-10','recuse_required','expense_only',0,0,'2026-05-15 09:00:00+05:30',null)
  ) as q(member_full_name, member_role, affiliation_org, seat_class, nda_status, nda_signed_on, conflict_declared, compensation_type, quarterly_retainer_rupees, equity_bps, onboarded_at, offboarded_at)
  returning id, member_full_name
)
select count(*) from member_seed;

insert into board_cadence_sessions_r3135 (
  member_id, session_quarter, session_type, scheduled_on, attendance_status,
  pre_read_delivery, pre_read_lead_hours, decision_follow_up_status, decision_summary,
  action_items_count, compensation_paid_rupees
)
select m.id, q.session_quarter, q.session_type, q.scheduled_on::timestamptz, q.attendance_status,
       q.pre_read_delivery, q.pre_read_lead_hours, q.decision_follow_up_status, q.decision_summary,
       q.action_items_count, q.compensation_paid_rupees
from (values
  ('Dr Ramesh Krishnan','Q1_FY26','formal_board_observer','2026-04-15 15:00:00+05:30','attended_full','delivered_on_time',72,'closed','Approved v0.5 phase roadmap; endorsed Cashfree KYC push',4,0),
  ('Meera Subramanian','Q1_FY26','quarterly_strategy_review','2026-04-18 11:00:00+05:30','attended_full','delivered_on_time',48,'in_progress','Recommended tier-2 city expansion sequencing Nashik-Coimbatore-Kochi',3,0),
  ('Dr Anjali Deshmukh','Q1_FY26','advisory_1on1','2026-04-20 16:00:00+05:30','attended_partial','delivered_late',12,'closed','Clinical review of dental sterilizer SLA framework — approved',2,75000),
  ('Vikram Rajgopal','Q1_FY26','ad_hoc_diligence','2026-04-22 14:00:00+05:30','attended_full','delivered_on_time',96,'closed','CDSCO representative letter reviewed; bonded parts provenance blessed',5,150000),
  ('Dr Anjali Deshmukh','Q2_FY26','advisory_1on1','2026-06-10 15:30:00+05:30','attended_full','delivered_on_time',48,'in_progress','NABH ZIP export methodology validated for hospital chains',3,75000),
  ('Vikram Rajgopal','Q2_FY26','quarterly_strategy_review','2026-06-15 10:00:00+05:30','sent_written_notes','delivered_on_time',72,'closed','DPDP grievance auto-routing SOP approved with 2 amendments',4,150000),
  ('Sanjay Bhatnagar','Q2_FY26','formal_board_observer','2026-06-18 14:00:00+05:30','attended_full','delivered_on_time',72,'closed','Reviewed unit economics; endorsed AMC tier restructure',3,0),
  ('Priya Ganesan','Q2_FY26','annual_offsite','2026-06-22 09:00:00+05:30','attended_full','delivered_on_time',168,'in_progress','Operating cadence — weekly board pack format finalized',6,0),
  ('Dr Suresh Menon','Q2_FY26','advisory_1on1','2026-06-25 16:00:00+05:30','no_show_notified','not_required',null,'deferred_next_quarter','Clinical review deferred — NDA pending',0,0),
  ('Dr Kavitha Reddy','Q1_FY26','ad_hoc_diligence','2026-04-25 11:00:00+05:30','attended_full','delivered_partial',24,'closed','KIMS pilot deployment risks catalogued — 3 mitigations approved',3,100000),
  ('Rakesh Iyer','Q1_FY26','advisory_1on1','2026-04-28 17:00:00+05:30','attended_full','delivered_on_time',48,'closed','Founder mental-health check + hiring plan sanity — no red flags',1,0),
  ('Arjun Kapoor','Q1_FY26','quarterly_strategy_review','2026-04-30 15:00:00+05:30','no_show_unnotified','skipped',null,'waived','Session waived — conflict of interest surfaced with competing portfolio',0,0),
  ('Neha Malhotra','Q2_FY26','ad_hoc_diligence','2026-06-05 12:00:00+05:30','attended_full','delivered_on_time',48,'closed','NABH audit-24 review — 5/5 findings confirmed and mitigated',5,80000),
  ('Dr Prakash Iyengar','Q2_FY26','crisis_convene','2026-06-28 18:00:00+05:30','attended_partial','delivered_late',6,'blocked','Emergency review of Cashfree activation delay — mitigation blocked externally',2,0),
  ('Lakshmi Narayanan','Q2_FY26','formal_board_observer','2026-06-20 14:30:00+05:30','attended_full','delivered_on_time',72,'closed','Series A prep — data room checklist reviewed',4,0),
  ('Dr Bhaskar Rao','Q2_FY26','advisory_1on1','2026-06-12 15:00:00+05:30','sent_written_notes','delivered_on_time',24,'not_actioned','Cardiology equipment SLA framework — recused from vendor selection',0,0),
  ('Meera Subramanian','Q2_FY26','quarterly_strategy_review','2026-06-25 11:30:00+05:30','attended_full','delivered_on_time',48,'in_progress','v0.6 roadmap review — 10 phase plan endorsed with 2 kills',5,0),
  ('Dr Ramesh Krishnan','Q2_FY26','formal_board_observer','2026-06-30 15:00:00+05:30','rescheduled','delivered_on_time',72,'deferred_next_quarter','Rescheduled to Q3 due to founder travel conflict',0,0)
) as q(member_full_name, session_quarter, session_type, scheduled_on, attendance_status, pre_read_delivery, pre_read_lead_hours, decision_follow_up_status, decision_summary, action_items_count, compensation_paid_rupees)
join board_advisory_members_r3135 m on m.member_full_name = q.member_full_name;

-- RPC 1: member roster with NDA + conflict
create or replace function founder_r3135_member_roster()
returns table (
  member_full_name text,
  member_role text,
  affiliation_org text,
  seat_class text,
  nda_status text,
  conflict_declared text,
  compensation_type text,
  quarterly_retainer_rupees integer,
  equity_bps integer,
  is_active boolean
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select m.member_full_name, m.member_role, m.affiliation_org, m.seat_class,
           m.nda_status, m.conflict_declared, m.compensation_type,
           m.quarterly_retainer_rupees, m.equity_bps,
           (m.offboarded_at is null) as is_active
    from board_advisory_members_r3135 m
    order by m.onboarded_at asc;
end
$$;

revoke execute on function founder_r3135_member_roster() from public, anon;
grant execute on function founder_r3135_member_roster() to authenticated;

-- RPC 2: attendance rollup by member
create or replace function founder_r3135_attendance_by_member()
returns table (
  member_full_name text,
  total_sessions integer,
  attended_full_count integer,
  attended_partial_count integer,
  written_notes_count integer,
  no_show_count integer,
  rescheduled_count integer,
  attendance_score_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select m.member_full_name,
           count(s.*)::integer as total_sessions,
           count(*) filter (where s.attendance_status = 'attended_full')::integer,
           count(*) filter (where s.attendance_status = 'attended_partial')::integer,
           count(*) filter (where s.attendance_status = 'sent_written_notes')::integer,
           (count(*) filter (where s.attendance_status in ('no_show_notified','no_show_unnotified')))::integer,
           count(*) filter (where s.attendance_status = 'rescheduled')::integer,
           case when count(s.*) = 0 then 0
                else round(100.0 * count(*) filter (where s.attendance_status in ('attended_full','attended_partial','sent_written_notes')) / count(s.*), 1)
           end as attendance_score_pct
    from board_advisory_members_r3135 m
    left join board_cadence_sessions_r3135 s on s.member_id = m.id
    group by m.member_full_name
    order by attendance_score_pct desc nulls last;
end
$$;

revoke execute on function founder_r3135_attendance_by_member() from public, anon;
grant execute on function founder_r3135_attendance_by_member() to authenticated;

-- RPC 3: NDA status rollup
create or replace function founder_r3135_nda_status_rollup()
returns table (
  nda_status text,
  member_count integer,
  active_count integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select m.nda_status,
           count(*)::integer,
           count(*) filter (where m.offboarded_at is null)::integer
    from board_advisory_members_r3135 m
    group by m.nda_status
    order by member_count desc;
end
$$;

revoke execute on function founder_r3135_nda_status_rollup() from public, anon;
grant execute on function founder_r3135_nda_status_rollup() to authenticated;

-- RPC 4: pre-read delivery discipline
create or replace function founder_r3135_pre_read_discipline()
returns table (
  session_quarter text,
  total_sessions integer,
  delivered_on_time integer,
  delivered_late integer,
  delivered_partial integer,
  skipped integer,
  avg_lead_hours numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.session_quarter,
           count(*)::integer,
           count(*) filter (where s.pre_read_delivery = 'delivered_on_time')::integer,
           count(*) filter (where s.pre_read_delivery = 'delivered_late')::integer,
           count(*) filter (where s.pre_read_delivery = 'delivered_partial')::integer,
           count(*) filter (where s.pre_read_delivery = 'skipped')::integer,
           coalesce(round(avg(s.pre_read_lead_hours)::numeric, 1), 0) as avg_lead_hours
    from board_cadence_sessions_r3135 s
    group by s.session_quarter
    order by s.session_quarter;
end
$$;

revoke execute on function founder_r3135_pre_read_discipline() from public, anon;
grant execute on function founder_r3135_pre_read_discipline() to authenticated;

-- RPC 5: decision follow-up status by member
create or replace function founder_r3135_decision_follow_up()
returns table (
  member_full_name text,
  session_type text,
  session_quarter text,
  scheduled_on timestamptz,
  decision_follow_up_status text,
  decision_summary text,
  action_items_count integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select m.member_full_name, s.session_type, s.session_quarter, s.scheduled_on,
           s.decision_follow_up_status, s.decision_summary, s.action_items_count
    from board_cadence_sessions_r3135 s
    join board_advisory_members_r3135 m on m.id = s.member_id
    where s.decision_follow_up_status in ('in_progress','blocked','deferred_next_quarter','not_actioned')
    order by s.scheduled_on desc;
end
$$;

revoke execute on function founder_r3135_decision_follow_up() from public, anon;
grant execute on function founder_r3135_decision_follow_up() to authenticated;

-- RPC 6: conflict declaration audit
create or replace function founder_r3135_conflict_audit()
returns table (
  conflict_declared text,
  member_count integer,
  active_members integer,
  members_list text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select m.conflict_declared,
           count(*)::integer,
           count(*) filter (where m.offboarded_at is null)::integer,
           string_agg(m.member_full_name, ', ' order by m.member_full_name) as members_list
    from board_advisory_members_r3135 m
    group by m.conflict_declared
    order by member_count desc;
end
$$;

revoke execute on function founder_r3135_conflict_audit() from public, anon;
grant execute on function founder_r3135_conflict_audit() to authenticated;

-- RPC 7: compensation ledger
create or replace function founder_r3135_compensation_ledger()
returns table (
  member_full_name text,
  compensation_type text,
  quarterly_retainer_rupees integer,
  equity_bps integer,
  total_paid_rupees integer,
  sessions_compensated integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select m.member_full_name, m.compensation_type,
           m.quarterly_retainer_rupees, m.equity_bps,
           coalesce(sum(s.compensation_paid_rupees), 0)::integer as total_paid_rupees,
           count(*) filter (where s.compensation_paid_rupees > 0)::integer as sessions_compensated
    from board_advisory_members_r3135 m
    left join board_cadence_sessions_r3135 s on s.member_id = m.id
    group by m.member_full_name, m.compensation_type, m.quarterly_retainer_rupees, m.equity_bps
    order by total_paid_rupees desc;
end
$$;

revoke execute on function founder_r3135_compensation_ledger() from public, anon;
grant execute on function founder_r3135_compensation_ledger() to authenticated;

-- RPC 8: session-type rollup by quarter
create or replace function founder_r3135_session_type_rollup()
returns table (
  session_quarter text,
  session_type text,
  session_count integer,
  total_action_items integer,
  closed_count integer,
  in_progress_count integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.session_quarter, s.session_type,
           count(*)::integer,
           coalesce(sum(s.action_items_count), 0)::integer,
           count(*) filter (where s.decision_follow_up_status = 'closed')::integer,
           count(*) filter (where s.decision_follow_up_status = 'in_progress')::integer
    from board_cadence_sessions_r3135 s
    group by s.session_quarter, s.session_type
    order by s.session_quarter, s.session_type;
end
$$;

revoke execute on function founder_r3135_session_type_rollup() from public, anon;
grant execute on function founder_r3135_session_type_rollup() to authenticated;

-- RPC 9: governance risk flags
create or replace function founder_r3135_governance_risk_flags()
returns table (
  member_full_name text,
  affiliation_org text,
  nda_status text,
  conflict_declared text,
  is_offboarded boolean,
  risk_severity text,
  risk_note text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select m.member_full_name, m.affiliation_org, m.nda_status, m.conflict_declared,
           (m.offboarded_at is not null) as is_offboarded,
           case
             when m.nda_status = 'expired' then 'HIGH'
             when m.conflict_declared in ('material_conflict','recuse_required') then 'HIGH'
             when m.nda_status in ('pending','under_review') then 'MEDIUM'
             when m.conflict_declared = 'pending_review' then 'MEDIUM'
             else 'LOW'
           end as risk_severity,
           case
             when m.nda_status = 'expired' then 'NDA expired — pause all pre-reads until re-signed'
             when m.conflict_declared = 'material_conflict' then 'Material conflict — offboard or recuse fully'
             when m.conflict_declared = 'recuse_required' then 'Recusal required on vendor decisions'
             when m.nda_status = 'pending' then 'NDA pending signature'
             when m.nda_status = 'under_review' then 'NDA in legal review'
             when m.conflict_declared = 'pending_review' then 'Conflict disclosure under review'
             else 'No action required'
           end as risk_note
    from board_advisory_members_r3135 m
    order by
      case
        when m.nda_status = 'expired' then 1
        when m.conflict_declared in ('material_conflict','recuse_required') then 2
        when m.nda_status in ('pending','under_review') then 3
        else 4
      end,
      m.member_full_name;
end
$$;

revoke execute on function founder_r3135_governance_risk_flags() from public, anon;
grant execute on function founder_r3135_governance_risk_flags() to authenticated;

commit;
