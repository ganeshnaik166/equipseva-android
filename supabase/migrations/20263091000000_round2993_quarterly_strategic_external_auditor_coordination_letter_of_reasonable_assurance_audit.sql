-- Round 2993: Quarterly Strategic External-Auditor Coordination & Letter-Of-Reasonable-Assurance Audit
-- HEAVY ★★★★ — 2 tables + 7 RPCs

create table if not exists external_auditor_engagements_r2993 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  quarter_label text not null,
  audit_firm text not null,
  lead_partner_name text not null,
  engagement_status text not null check (engagement_status in ('planning','fieldwork','review','reporting','signed_off','deferred')),
  scope_summary text not null,
  fee_rupees int not null check (fee_rupees between 50000 and 5000000),
  kickoff_date date not null,
  target_signoff_date date not null,
  open_pbc_items int not null check (open_pbc_items between 0 and 500),
  closed_pbc_items int not null check (closed_pbc_items between 0 and 500),
  material_findings int not null check (material_findings between 0 and 50),
  assurance_letter_status text not null check (assurance_letter_status in ('not_started','drafted','partner_review','issued','qualified','adverse')),
  founder_priority text not null check (founder_priority in ('low','medium','high','critical'))
);

create table if not exists assurance_letter_clauses_r2993 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  engagement_id uuid references external_auditor_engagements_r2993(id) on delete cascade,
  clause_ref text not null,
  clause_topic text not null,
  reasonable_assurance_level text not null check (reasonable_assurance_level in ('reasonable','limited','disclaimer','qualified','adverse')),
  evidence_completeness_pct int not null check (evidence_completeness_pct between 0 and 100),
  risk_rating text not null check (risk_rating in ('low','medium','high','severe')),
  remediation_owner text not null,
  remediation_due_date date not null,
  clause_status text not null check (clause_status in ('open','in_progress','resolved','accepted_risk','escalated')),
  founder_sign_required boolean not null default false
);

alter table external_auditor_engagements_r2993 enable row level security;
alter table assurance_letter_clauses_r2993 enable row level security;

drop policy if exists eae_r2993_select on external_auditor_engagements_r2993;
create policy eae_r2993_select on external_auditor_engagements_r2993 for select using (is_founder());

drop policy if exists alc_r2993_select on assurance_letter_clauses_r2993;
create policy alc_r2993_select on assurance_letter_clauses_r2993 for select using (is_founder());

insert into external_auditor_engagements_r2993 (quarter_label, audit_firm, lead_partner_name, engagement_status, scope_summary, fee_rupees, kickoff_date, target_signoff_date, open_pbc_items, closed_pbc_items, material_findings, assurance_letter_status, founder_priority) values
('Q1-FY26','Deloitte Haskins & Sells','Anand Subramanian','fieldwork','Revenue recognition + AMC deferred revenue + repair job WIP',1850000,'2026-04-05'::date,'2026-07-15'::date,42,118,3,'drafted','high'),
('Q2-FY26','BSR & Co (KPMG)','Priya Venkatesh','planning','SOC2 Type II + DPDP compliance + payout reconciliation',2200000,'2026-07-01'::date,'2026-10-20'::date,87,12,0,'not_started','critical'),
('Q3-FY26','PwC India','Rajesh Iyer','review','Inventory provenance + GST input credit + 80IAC startup deduction',1650000,'2026-10-01'::date,'2027-01-15'::date,15,156,1,'partner_review','high'),
('Q4-FY26','Walker Chandiok (GT)','Meera Nair','reporting','Year-end statutory + ICFR + investor deck attestation',2850000,'2027-01-15'::date,'2027-04-30'::date,8,201,5,'partner_review','critical'),
('Q1-FY26-Internal','EY Internal Audit','Vikram Shah','signed_off','Q1 internal controls + cash handling + engineer-payout fraud risk',950000,'2026-04-10'::date,'2026-06-15'::date,0,89,2,'issued','medium'),
('SOC2-2026','Schellman','Karen Liu','fieldwork','SOC2 Type II controls observation period readiness',3200000,'2026-03-01'::date,'2026-09-30'::date,28,142,1,'drafted','critical'),
('ISO27001-Recert','BSI India','Suresh Pillai','review','ISO 27001 surveillance audit',680000,'2026-05-20'::date,'2026-07-30'::date,4,67,0,'partner_review','medium'),
('PCI-DSS-SAQ','Trustwave','Anita Khan','signed_off','PCI DSS SAQ-D for hosted payment data flows',420000,'2026-02-10'::date,'2026-05-10'::date,0,45,0,'issued','high'),
('Tax-Audit-44AB','MZSK & Associates','Mukesh Singhi','planning','Section 44AB tax audit FY26',520000,'2026-08-01'::date,'2026-09-30'::date,38,4,0,'not_started','high'),
('Transfer-Pricing','BDO India','Lakshmi Rao','deferred','TP study + Form 3CEB for inter-co royalties',780000,'2026-06-15'::date,'2026-11-30'::date,22,3,0,'not_started','medium'),
('DPDP-Readiness','Nishith Desai','Adv. Tanya Aggarwal','fieldwork','DPDP Act 2023 controller obligations audit',650000,'2026-05-01'::date,'2026-08-15'::date,17,38,2,'drafted','critical'),
('AMC-Actuarial','MCA Actuaries','Ramesh Bhatia','review','Actuarial valuation of AMC deferred service liability',380000,'2026-06-01'::date,'2026-08-30'::date,6,29,1,'drafted','high'),
('Pre-Series-B-VDR','Deloitte','Anand Subramanian','planning','Pre-Series-B financial+commercial VDR attestation',1750000,'2026-09-01'::date,'2026-12-15'::date,95,0,0,'not_started','critical'),
('GST-Health-Check','Lakshmikumaran','CA Ashwin Patel','signed_off','GST input credit reconciliation + GSTR-9 readiness',290000,'2026-03-15'::date,'2026-05-30'::date,0,67,0,'issued','medium'),
('Cyber-Insurance','HDFC Ergo Sec','Vivek Menon','signed_off','Cyber insurance underwriting assessment',180000,'2026-04-01'::date,'2026-05-15'::date,0,34,0,'issued','low');

insert into assurance_letter_clauses_r2993 (engagement_id, clause_ref, clause_topic, reasonable_assurance_level, evidence_completeness_pct, risk_rating, remediation_owner, remediation_due_date, clause_status, founder_sign_required)
select e.id, c.clause_ref, c.clause_topic, c.reasonable_assurance_level, c.evidence_completeness_pct, c.risk_rating, c.remediation_owner, c.remediation_due_date::date, c.clause_status, c.founder_sign_required
from external_auditor_engagements_r2993 e
join (values
  ('Q1-FY26','RA-001','Revenue cutoff for AMC contracts','reasonable',92,'medium','CFO','2026-07-01','in_progress',true),
  ('Q1-FY26','RA-002','Repair job WIP valuation','limited',78,'high','Controller','2026-07-08','open',true),
  ('Q1-FY26','RA-003','Engineer payout completeness','reasonable',95,'low','Payroll Lead','2026-07-10','resolved',false),
  ('Q2-FY26','RA-101','SOC2 CC6.1 logical access','limited',65,'high','Head of Eng','2026-09-15','in_progress',true),
  ('Q2-FY26','RA-102','DPDP Section 8 grievance SLA','disclaimer',45,'severe','DPO','2026-08-20','escalated',true),
  ('Q3-FY26','RA-201','GST ITC reversal under Rule 42','reasonable',88,'medium','Tax Manager','2026-12-15','in_progress',false),
  ('Q3-FY26','RA-202','80IAC startup deduction eligibility','reasonable',97,'low','CFO','2027-01-05','resolved',true),
  ('Q4-FY26','RA-301','Going concern + 18-month runway','reasonable',91,'high','CFO','2027-03-15','in_progress',true),
  ('Q4-FY26','RA-302','Related-party transactions Sch-V','reasonable',99,'low','Co-Sec','2027-04-15','resolved',false),
  ('Q4-FY26','RA-303','Investor deck attestation FY26','limited',72,'high','Founder','2027-04-20','open',true),
  ('SOC2-2026','RA-401','CC7.2 change management evidence','limited',68,'high','SRE Lead','2026-09-01','in_progress',true),
  ('SOC2-2026','RA-402','CC9.2 vendor risk reviews','reasonable',85,'medium','Vendor Manager','2026-09-10','in_progress',false),
  ('DPDP-Readiness','RA-501','Consent records audit trail','limited',58,'severe','DPO','2026-07-30','escalated',true),
  ('AMC-Actuarial','RA-601','Deferred service liability assumptions','limited',74,'high','CFO','2026-08-15','in_progress',true),
  ('Pre-Series-B-VDR','RA-701','Q-of-E earnings adjustments','disclaimer',38,'severe','Founder','2026-11-30','open',true),
  ('Pre-Series-B-VDR','RA-702','Customer concentration disclosure','limited',62,'high','Head of Sales','2026-12-01','in_progress',true),
  ('ISO27001-Recert','RA-801','A.8.16 monitoring activities','reasonable',89,'medium','SOC Lead','2026-07-20','resolved',false),
  ('Tax-Audit-44AB','RA-901','Form 3CD clause 21 disallowances','reasonable',82,'medium','Tax Manager','2026-09-20','in_progress',false)
) as c(qlabel, clause_ref, clause_topic, reasonable_assurance_level, evidence_completeness_pct, risk_rating, remediation_owner, remediation_due_date, clause_status, founder_sign_required)
on c.qlabel = e.quarter_label;

create or replace function r2993_list_engagements()
returns setof external_auditor_engagements_r2993
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select * from external_auditor_engagements_r2993 order by target_signoff_date asc;
end; $$;

create or replace function r2993_engagement_status_summary()
returns table(engagement_status text, n int, avg_fee_rupees int, total_open_pbc int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.engagement_status, count(*)::int, avg(e.fee_rupees)::int, sum(e.open_pbc_items)::int
  from external_auditor_engagements_r2993 e
  group by e.engagement_status
  order by count(*) desc;
end; $$;

create or replace function r2993_critical_engagements()
returns setof external_auditor_engagements_r2993
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select * from external_auditor_engagements_r2993
  where founder_priority in ('critical','high') and engagement_status not in ('signed_off','deferred')
  order by target_signoff_date asc;
end; $$;

create or replace function r2993_assurance_clauses_open()
returns setof assurance_letter_clauses_r2993
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select * from assurance_letter_clauses_r2993
  where clause_status in ('open','in_progress','escalated')
  order by case risk_rating when 'severe' then 0 when 'high' then 1 when 'medium' then 2 else 3 end, remediation_due_date asc;
end; $$;

create or replace function r2993_risk_rating_breakdown()
returns table(risk_rating text, n int, avg_evidence_pct int, founder_sign_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.risk_rating, count(*)::int, avg(c.evidence_completeness_pct)::int,
         (count(*) filter (where c.founder_sign_required))::int
  from assurance_letter_clauses_r2993 c
  group by c.risk_rating
  order by case c.risk_rating when 'severe' then 0 when 'high' then 1 when 'medium' then 2 else 3 end;
end; $$;

create or replace function r2993_pbc_completion()
returns table(quarter_label text, audit_firm text, closed_pbc_items int, open_pbc_items int, completion_pct int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.quarter_label, e.audit_firm, e.closed_pbc_items, e.open_pbc_items,
         case when (e.open_pbc_items + e.closed_pbc_items) = 0 then 100
              else (100 * e.closed_pbc_items / (e.open_pbc_items + e.closed_pbc_items))::int end
  from external_auditor_engagements_r2993 e
  order by 5 desc;
end; $$;

create or replace function r2993_founder_signoff_queue()
returns setof assurance_letter_clauses_r2993
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select * from assurance_letter_clauses_r2993
  where founder_sign_required = true and clause_status in ('open','in_progress','escalated')
  order by remediation_due_date asc;
end; $$;

create or replace function r2993_fee_spend_total()
returns table(total_engagements int, total_fee_rupees bigint, signed_off_count int, critical_open_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select count(*)::int, sum(fee_rupees)::bigint,
         (count(*) filter (where engagement_status = 'signed_off'))::int,
         (count(*) filter (where founder_priority = 'critical' and engagement_status not in ('signed_off','deferred')))::int
  from external_auditor_engagements_r2993;
end; $$;

revoke all on function r2993_list_engagements() from public, anon;
revoke all on function r2993_engagement_status_summary() from public, anon;
revoke all on function r2993_critical_engagements() from public, anon;
revoke all on function r2993_assurance_clauses_open() from public, anon;
revoke all on function r2993_risk_rating_breakdown() from public, anon;
revoke all on function r2993_pbc_completion() from public, anon;
revoke all on function r2993_founder_signoff_queue() from public, anon;
revoke all on function r2993_fee_spend_total() from public, anon;

grant execute on function r2993_list_engagements() to authenticated;
grant execute on function r2993_engagement_status_summary() to authenticated;
grant execute on function r2993_critical_engagements() to authenticated;
grant execute on function r2993_assurance_clauses_open() to authenticated;
grant execute on function r2993_risk_rating_breakdown() to authenticated;
grant execute on function r2993_pbc_completion() to authenticated;
grant execute on function r2993_founder_signoff_queue() to authenticated;
grant execute on function r2993_fee_spend_total() to authenticated;
