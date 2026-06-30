-- Round 3117 — Founder Personal Tax + Filing + Indemnity Clock Tracker
-- Tracks founder personal statutory clock: advance tax, ITR filing, DSC renewal,
-- indemnity insurance, CA assignments, clearance certificates, penalty risk.

begin;

-- ============================================================
-- Table 1: founder personal statutory clock items
-- ============================================================
create table if not exists founder_statutory_clock_items_r3117 (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  clock_kind text not null check (clock_kind in (
    'advance_tax_q1','advance_tax_q2','advance_tax_q3','advance_tax_q4',
    'itr_filing','dsc_renewal','indemnity_renewal','gst_personal',
    'pesh_filing','tds_return','professional_tax','board_filing'
  )),
  fiscal_year text not null check (fiscal_year in ('FY25-26','FY26-27','FY27-28')),
  assessment_year text not null,
  statutory_due_at timestamptz not null,
  internal_target_at timestamptz not null,
  completed_at timestamptz,
  status text not null check (status in (
    'upcoming','in_progress','submitted','filed','paid','renewed',
    'overdue','penalty_risk','escalated','closed'
  )),
  amount_due_rupees integer not null default 0 check (amount_due_rupees >= 0),
  amount_paid_rupees integer not null default 0 check (amount_paid_rupees >= 0),
  penalty_accrued_rupees integer not null default 0 check (penalty_accrued_rupees >= 0),
  interest_accrued_rupees integer not null default 0 check (interest_accrued_rupees >= 0),
  ca_assigned text,
  ca_firm text,
  filing_reference text,
  clearance_cert_no text,
  risk_band text not null check (risk_band in ('green','amber','red','critical')),
  days_to_due integer not null default 0,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_fsci_r3117_status on founder_statutory_clock_items_r3117(status);
create index if not exists idx_fsci_r3117_kind on founder_statutory_clock_items_r3117(clock_kind);
create index if not exists idx_fsci_r3117_risk on founder_statutory_clock_items_r3117(risk_band);
create index if not exists idx_fsci_r3117_due on founder_statutory_clock_items_r3117(statutory_due_at);

-- ============================================================
-- Table 2: founder indemnity + clearance certificates
-- ============================================================
create table if not exists founder_indemnity_clearance_r3117 (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  clock_item_id uuid references founder_statutory_clock_items_r3117(id) on delete set null,
  doc_kind text not null check (doc_kind in (
    'd_and_o_insurance','professional_indemnity','cyber_liability',
    'product_liability','itr_clearance','gst_clearance','pf_clearance',
    'esi_clearance','tds_certificate','no_objection_cert','udyam_cert','dsc_cert'
  )),
  issuer text not null,
  policy_or_ref_no text not null,
  cover_amount_rupees integer check (cover_amount_rupees >= 0),
  premium_paid_rupees integer not null default 0 check (premium_paid_rupees >= 0),
  issued_on date not null,
  expires_on date not null,
  renewal_window_days integer not null default 30 check (renewal_window_days > 0),
  status text not null check (status in (
    'active','expiring_soon','expired','lapsed','renewed','cancelled','pending_issue'
  )),
  ca_assigned text,
  custody_location text not null check (custody_location in (
    'founder_locker','ca_office','digilocker','company_vault','bank_locker'
  )),
  verification_status text not null check (verification_status in (
    'verified','pending','disputed','re_issue_requested'
  )),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_fic_r3117_doc on founder_indemnity_clearance_r3117(doc_kind);
create index if not exists idx_fic_r3117_status on founder_indemnity_clearance_r3117(status);
create index if not exists idx_fic_r3117_expires on founder_indemnity_clearance_r3117(expires_on);

-- ============================================================
-- Seeds: statutory clock items (8 rows)
-- ============================================================
insert into founder_statutory_clock_items_r3117 (
  org_id, clock_kind, fiscal_year, assessment_year, statutory_due_at,
  internal_target_at, completed_at, status, amount_due_rupees,
  amount_paid_rupees, penalty_accrued_rupees, interest_accrued_rupees,
  ca_assigned, ca_firm, filing_reference, clearance_cert_no, risk_band,
  days_to_due, notes
)
select q.org_id, q.clock_kind, q.fiscal_year, q.assessment_year,
       q.statutory_due_at::timestamptz, q.internal_target_at::timestamptz,
       q.completed_at::timestamptz, q.status, q.amount_due_rupees,
       q.amount_paid_rupees, q.penalty_accrued_rupees, q.interest_accrued_rupees,
       q.ca_assigned, q.ca_firm, q.filing_reference, q.clearance_cert_no,
       q.risk_band, q.days_to_due, q.notes
from (
  select (select id from organizations order by created_at asc limit 1) as org_id, *
  from (values
    ('advance_tax_q1','FY26-27','AY27-28','2026-06-15 23:59:00+05:30'::timestamptz,'2026-06-10 18:00:00+05:30'::timestamptz,'2026-06-12 14:22:00+05:30'::timestamptz,'paid',180000,180000,0,0,'Suresh Iyer','Iyer & Associates','CHL202606-A1',null::text,'green',0,'Q1 advance tax paid on time'),
    ('advance_tax_q2','FY26-27','AY27-28','2026-09-15 23:59:00+05:30'::timestamptz,'2026-09-10 18:00:00+05:30'::timestamptz,null::timestamptz,'upcoming',220000,0,0,0,'Suresh Iyer','Iyer & Associates',null::text,null::text,'amber',77,'45% cumulative due by Q2'),
    ('advance_tax_q3','FY26-27','AY27-28','2026-12-15 23:59:00+05:30'::timestamptz,'2026-12-08 18:00:00+05:30'::timestamptz,null::timestamptz,'upcoming',260000,0,0,0,'Suresh Iyer','Iyer & Associates',null::text,null::text,'green',168,'75% cumulative milestone'),
    ('itr_filing','FY25-26','AY26-27','2026-07-31 23:59:00+05:30'::timestamptz,'2026-07-15 18:00:00+05:30'::timestamptz,null::timestamptz,'in_progress',0,0,0,0,'Suresh Iyer','Iyer & Associates',null::text,null::text,'amber',31,'ITR-3 draft under CA review'),
    ('dsc_renewal','FY26-27','AY27-28','2026-08-12 23:59:00+05:30'::timestamptz,'2026-07-28 18:00:00+05:30'::timestamptz,null::timestamptz,'upcoming',2500,0,0,0,'NA','eMudhra Class-3',null::text,null::text,'green',43,'2-year token expires Aug 12'),
    ('indemnity_renewal','FY26-27','AY27-28','2026-07-05 23:59:00+05:30'::timestamptz,'2026-06-25 18:00:00+05:30'::timestamptz,null::timestamptz,'penalty_risk',45000,0,0,0,'NA','HDFC Ergo',null::text,null::text,'red',5,'D&O policy expires in 5 days'),
    ('pesh_filing','FY25-26','AY26-27','2026-05-31 23:59:00+05:30'::timestamptz,'2026-05-25 18:00:00+05:30'::timestamptz,null::timestamptz,'overdue',18000,0,5400,1080,'Lakshmi Rao','Rao Tax Chambers','PESH-PEND','none','critical',-30,'Professional tax overdue 30 days, penalty accruing'),
    ('tds_return','FY25-26','Q4','2026-05-31 23:59:00+05:30'::timestamptz,'2026-05-20 18:00:00+05:30'::timestamptz,'2026-05-28 11:00:00+05:30'::timestamptz,'filed',0,0,0,0,'Suresh Iyer','Iyer & Associates','24Q-Q4-2526','TDS-CL-Q4','green',-30,'Q4 24Q filed; clearance certificate received')
  ) as v(clock_kind,fiscal_year,assessment_year,statutory_due_at,internal_target_at,completed_at,status,amount_due_rupees,amount_paid_rupees,penalty_accrued_rupees,interest_accrued_rupees,ca_assigned,ca_firm,filing_reference,clearance_cert_no,risk_band,days_to_due,notes)
) q;

-- ============================================================
-- Seeds: indemnity + clearance docs (8 rows)
-- ============================================================
insert into founder_indemnity_clearance_r3117 (
  org_id, doc_kind, issuer, policy_or_ref_no, cover_amount_rupees,
  premium_paid_rupees, issued_on, expires_on, renewal_window_days,
  status, ca_assigned, custody_location, verification_status, notes
)
select q.org_id, q.doc_kind, q.issuer, q.policy_or_ref_no,
       q.cover_amount_rupees, q.premium_paid_rupees, q.issued_on,
       q.expires_on, q.renewal_window_days, q.status, q.ca_assigned,
       q.custody_location, q.verification_status, q.notes
from (
  select (select id from organizations order by created_at asc limit 1) as org_id, *
  from (values
    ('d_and_o_insurance','HDFC Ergo','DO-HDFC-2526-88421',10000000,45000,'2025-07-05'::date,'2026-07-05'::date,30,'expiring_soon','NA','founder_locker','verified','D&O 1Cr cover expires in 5 days'),
    ('professional_indemnity','ICICI Lombard','PI-ICICI-2526-77310',5000000,28000,'2025-09-15'::date,'2026-09-15'::date,30,'active','NA','founder_locker','verified','5L cover, healthcare class'),
    ('cyber_liability','Bajaj Allianz','CYB-BAJAJ-2526-44012',2500000,18500,'2025-11-20'::date,'2026-11-20'::date,30,'active','NA','company_vault','verified','Includes ransomware + breach'),
    ('itr_clearance','Income Tax Dept','ITR-CLR-AY2526-X88',null::integer,0,'2026-04-12'::date,'2099-12-31'::date,30,'active','Suresh Iyer','digilocker','verified','AY25-26 clearance issued'),
    ('gst_clearance','GSTN','GST-CLR-FY2526-T44',null::integer,0,'2026-04-30'::date,'2099-12-31'::date,30,'active','Suresh Iyer','digilocker','verified','FY25-26 GST clearance'),
    ('udyam_cert','MSME Ministry','UDYAM-TS-07-0099805',null::integer,0,'2026-06-10'::date,'2099-12-31'::date,30,'active','NA','digilocker','verified','MSME small enterprise classification'),
    ('dsc_cert','eMudhra','EMUDHRA-CL3-FH-998812',null::integer,2500,'2024-08-12'::date,'2026-08-12'::date,30,'expiring_soon','NA','founder_locker','verified','Class-3 USB token, renew by Jul 28'),
    ('pf_clearance','EPFO','PF-CLR-PEND-TS-7741',null::integer,0,'2026-03-15'::date,'2026-09-15'::date,30,'pending_issue','Lakshmi Rao','ca_office','pending','EPFO clearance pending, ETA 2 weeks')
  ) as v(doc_kind,issuer,policy_or_ref_no,cover_amount_rupees,premium_paid_rupees,issued_on,expires_on,renewal_window_days,status,ca_assigned,custody_location,verification_status,notes)
) q;

-- ============================================================
-- RPC 1: clock summary
-- ============================================================
create or replace function founder_statutory_clock_summary_r3117()
returns table(
  total_items bigint,
  upcoming_count bigint,
  in_progress_count bigint,
  overdue_count bigint,
  penalty_risk_count bigint,
  total_amount_due_rupees bigint,
  total_penalty_rupees bigint,
  total_interest_rupees bigint,
  critical_items bigint
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select count(*),
           count(*) filter (where status = 'upcoming'),
           count(*) filter (where status = 'in_progress'),
           count(*) filter (where status = 'overdue'),
           count(*) filter (where status = 'penalty_risk'),
           coalesce(sum(amount_due_rupees - amount_paid_rupees), 0)::bigint,
           coalesce(sum(penalty_accrued_rupees), 0)::bigint,
           coalesce(sum(interest_accrued_rupees), 0)::bigint,
           count(*) filter (where risk_band = 'critical')
    from founder_statutory_clock_items_r3117;
end $$;

revoke execute on function founder_statutory_clock_summary_r3117() from public, anon;
grant execute on function founder_statutory_clock_summary_r3117() to authenticated;

-- ============================================================
-- RPC 2: upcoming clock items (next 90 days)
-- ============================================================
create or replace function founder_upcoming_clock_items_r3117()
returns table(
  id uuid,
  clock_kind text,
  fiscal_year text,
  statutory_due_at timestamptz,
  status text,
  amount_due_rupees integer,
  ca_assigned text,
  risk_band text,
  days_to_due integer
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.id, c.clock_kind, c.fiscal_year, c.statutory_due_at,
           c.status, c.amount_due_rupees, c.ca_assigned, c.risk_band,
           c.days_to_due
    from founder_statutory_clock_items_r3117 c
    where c.status in ('upcoming','in_progress','penalty_risk')
    order by c.statutory_due_at asc;
end $$;

revoke execute on function founder_upcoming_clock_items_r3117() from public, anon;
grant execute on function founder_upcoming_clock_items_r3117() to authenticated;

-- ============================================================
-- RPC 3: overdue + penalty items
-- ============================================================
create or replace function founder_overdue_clock_items_r3117()
returns table(
  id uuid,
  clock_kind text,
  fiscal_year text,
  statutory_due_at timestamptz,
  status text,
  penalty_accrued_rupees integer,
  interest_accrued_rupees integer,
  ca_assigned text,
  days_to_due integer,
  notes text
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.id, c.clock_kind, c.fiscal_year, c.statutory_due_at,
           c.status, c.penalty_accrued_rupees, c.interest_accrued_rupees,
           c.ca_assigned, c.days_to_due, c.notes
    from founder_statutory_clock_items_r3117 c
    where c.status in ('overdue','penalty_risk','escalated')
       or c.penalty_accrued_rupees > 0
    order by c.penalty_accrued_rupees desc, c.statutory_due_at asc;
end $$;

revoke execute on function founder_overdue_clock_items_r3117() from public, anon;
grant execute on function founder_overdue_clock_items_r3117() to authenticated;

-- ============================================================
-- RPC 4: advance tax ladder
-- ============================================================
create or replace function founder_advance_tax_ladder_r3117()
returns table(
  id uuid,
  clock_kind text,
  fiscal_year text,
  statutory_due_at timestamptz,
  amount_due_rupees integer,
  amount_paid_rupees integer,
  status text,
  filing_reference text,
  days_to_due integer
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.id, c.clock_kind, c.fiscal_year, c.statutory_due_at,
           c.amount_due_rupees, c.amount_paid_rupees, c.status,
           c.filing_reference, c.days_to_due
    from founder_statutory_clock_items_r3117 c
    where c.clock_kind in ('advance_tax_q1','advance_tax_q2','advance_tax_q3','advance_tax_q4')
    order by c.statutory_due_at asc;
end $$;

revoke execute on function founder_advance_tax_ladder_r3117() from public, anon;
grant execute on function founder_advance_tax_ladder_r3117() to authenticated;

-- ============================================================
-- RPC 5: indemnity policy roster
-- ============================================================
create or replace function founder_indemnity_roster_r3117()
returns table(
  id uuid,
  doc_kind text,
  issuer text,
  policy_or_ref_no text,
  cover_amount_rupees integer,
  expires_on date,
  status text,
  custody_location text,
  days_to_expiry integer
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select d.id, d.doc_kind, d.issuer, d.policy_or_ref_no,
           d.cover_amount_rupees, d.expires_on, d.status,
           d.custody_location,
           (d.expires_on - current_date)::integer as days_to_expiry
    from founder_indemnity_clearance_r3117 d
    where d.doc_kind in ('d_and_o_insurance','professional_indemnity','cyber_liability','product_liability')
    order by d.expires_on asc;
end $$;

revoke execute on function founder_indemnity_roster_r3117() from public, anon;
grant execute on function founder_indemnity_roster_r3117() to authenticated;

-- ============================================================
-- RPC 6: clearance certificate vault
-- ============================================================
create or replace function founder_clearance_vault_r3117()
returns table(
  id uuid,
  doc_kind text,
  issuer text,
  policy_or_ref_no text,
  issued_on date,
  expires_on date,
  status text,
  custody_location text,
  verification_status text
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select d.id, d.doc_kind, d.issuer, d.policy_or_ref_no,
           d.issued_on, d.expires_on, d.status,
           d.custody_location, d.verification_status
    from founder_indemnity_clearance_r3117 d
    where d.doc_kind in ('itr_clearance','gst_clearance','pf_clearance','esi_clearance','tds_certificate','no_objection_cert','udyam_cert','dsc_cert')
    order by d.issued_on desc;
end $$;

revoke execute on function founder_clearance_vault_r3117() from public, anon;
grant execute on function founder_clearance_vault_r3117() to authenticated;

-- ============================================================
-- RPC 7: CA assignment roster
-- ============================================================
create or replace function founder_ca_assignment_roster_r3117()
returns table(
  ca_assigned text,
  ca_firm text,
  items_assigned bigint,
  pending_items bigint,
  total_amount_rupees bigint,
  total_penalty_rupees bigint
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.ca_assigned, c.ca_firm,
           count(*)::bigint,
           count(*) filter (where c.status in ('upcoming','in_progress','overdue','penalty_risk'))::bigint,
           coalesce(sum(c.amount_due_rupees), 0)::bigint,
           coalesce(sum(c.penalty_accrued_rupees), 0)::bigint
    from founder_statutory_clock_items_r3117 c
    where c.ca_assigned is not null
    group by c.ca_assigned, c.ca_firm
    order by count(*) desc;
end $$;

revoke execute on function founder_ca_assignment_roster_r3117() from public, anon;
grant execute on function founder_ca_assignment_roster_r3117() to authenticated;

-- ============================================================
-- RPC 8: risk-band heatmap
-- ============================================================
create or replace function founder_risk_band_heatmap_r3117()
returns table(
  risk_band text,
  items_count bigint,
  amount_at_risk_rupees bigint,
  penalty_rupees bigint,
  earliest_due timestamptz
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.risk_band,
           count(*)::bigint,
           coalesce(sum(c.amount_due_rupees), 0)::bigint,
           coalesce(sum(c.penalty_accrued_rupees), 0)::bigint,
           min(c.statutory_due_at)
    from founder_statutory_clock_items_r3117 c
    group by c.risk_band
    order by case c.risk_band
      when 'critical' then 1 when 'red' then 2 when 'amber' then 3 when 'green' then 4
    end;
end $$;

revoke execute on function founder_risk_band_heatmap_r3117() from public, anon;
grant execute on function founder_risk_band_heatmap_r3117() to authenticated;

-- ============================================================
-- RPC 9: expiring docs alert (next 60 days)
-- ============================================================
create or replace function founder_expiring_docs_r3117()
returns table(
  id uuid,
  doc_kind text,
  issuer text,
  policy_or_ref_no text,
  expires_on date,
  status text,
  days_to_expiry integer,
  renewal_window_days integer
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select d.id, d.doc_kind, d.issuer, d.policy_or_ref_no,
           d.expires_on, d.status,
           (d.expires_on - current_date)::integer,
           d.renewal_window_days
    from founder_indemnity_clearance_r3117 d
    where d.expires_on <= current_date + interval '60 days'
      and d.expires_on >= current_date - interval '30 days'
    order by d.expires_on asc;
end $$;

revoke execute on function founder_expiring_docs_r3117() from public, anon;
grant execute on function founder_expiring_docs_r3117() to authenticated;

commit;
