-- Round 3169: Founder Cash-Collection & Accounts-Receivable Aging Discipline Board
-- AR aging log — customer × invoice × aging bucket × collection status × dispute × DSO × collection/CAPA actions

-- =============================================================================
-- TABLE 1: ar_aging_r3169 — outstanding invoices & receivable aging
-- =============================================================================
create table if not exists public.ar_aging_r3169 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  customer_name text not null,
  customer_segment text not null check (customer_segment in (
    'corporate_hospital','government_hospital','trust_hospital',
    'standalone_clinic','diagnostic_chain','medical_college'
  )),
  invoice_number text not null,
  invoice_amount_rupees numeric(12,2) not null,
  invoice_date date not null,
  due_date date not null,
  days_overdue int not null,
  aging_bucket text not null check (aging_bucket in (
    'current_0_30','overdue_31_60','overdue_61_90','overdue_90_plus'
  )),
  payment_terms text not null check (payment_terms in (
    'net_15','net_30','net_45','net_60','net_90',
    'advance_payment','milestone_linked','cash_on_delivery'
  )),
  collection_status text not null check (collection_status in (
    'not_started','reminder_sent','follow_up_call','promise_to_pay',
    'partial_received','escalated_legal','written_off','settled_full'
  )),
  dispute_flag boolean not null default false,
  dispute_reason text not null check (dispute_reason in (
    'none','pricing_dispute','service_quality','documentation_missing',
    'duplicate_invoice','budget_freeze','po_mismatch','warranty_claim'
  )),
  dso_days int,
  amount_collected_rupees numeric(12,2),
  collection_verdict text not null check (collection_verdict in (
    'on_track','watch','at_risk','critical','doubtful_debt','recovered','write_off_recommended'
  )),
  last_contact_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ar_aging_r3169 enable row level security;

create index if not exists idx_ar_aging_r3169_org on public.ar_aging_r3169(organization_id);
create index if not exists idx_ar_aging_r3169_due on public.ar_aging_r3169(due_date);
create index if not exists idx_ar_aging_r3169_verdict on public.ar_aging_r3169(collection_verdict);

-- =============================================================================
-- TABLE 2: ar_aging_capa_actions_r3169 — collection & CAPA actions
-- =============================================================================
create table if not exists public.ar_aging_capa_actions_r3169 (
  id uuid primary key default gen_random_uuid(),
  ar_aging_id uuid not null references public.ar_aging_r3169(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'invoice_dispute','payment_delay','documentation_gap','credit_limit_breach',
    'budget_freeze_customer','repeated_defaulter','po_mismatch',
    'service_complaint_linked','collection_process_gap','write_off_candidate'
  )),
  root_cause text not null check (root_cause in (
    'customer_cash_flow','pricing_disagreement','missing_documentation',
    'service_quality_issue','internal_billing_error','po_not_raised',
    'approval_bottleneck','budget_cycle_delay','disputed_deliverable','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'send_payment_reminder','schedule_collection_call','issue_credit_note',
    'resolve_dispute_meeting','escalate_to_management','initiate_legal_notice',
    'restructure_payment_plan','write_off_bad_debt','correct_invoice_reissue','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'gst_compliance_risk','revenue_recognition_impact','none',
    'internal_only','audit_finding','provisioning_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ar_aging_capa_actions_r3169 enable row level security;

create index if not exists idx_ar_aging_capa_r3169_ar on public.ar_aging_capa_actions_r3169(ar_aging_id);
create index if not exists idx_ar_aging_capa_r3169_status on public.ar_aging_capa_actions_r3169(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 14 AR aging rows across real Indian hospitals
  insert into public.ar_aging_r3169 (
    organization_id, customer_name, customer_segment, invoice_number, invoice_amount_rupees,
    invoice_date, due_date, days_overdue, aging_bucket, payment_terms,
    collection_status, dispute_flag, dispute_reason, dso_days, amount_collected_rupees,
    collection_verdict, last_contact_date, notes
  )
  select v_org_id, q.cust, q.seg, q.inv, q.amt,
    q.idate::date, q.ddate::date, q.dov, q.bucket, q.terms,
    q.cstat, q.disp, q.dreason, q.dso, q.coll,
    q.verdict, q.lcontact::date, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','corporate_hospital','INV-APL-2401',850000.00,
     '2026-06-20','2026-07-05',13,'current_0_30','net_15',
     'reminder_sent',false,'none',28,0.00,'on_track','2026-07-15','AMC Q2 invoice — first reminder emailed to accounts'),
    ('Apollo Hyderabad Jubilee Hills','corporate_hospital','INV-APL-2388',1250000.00,
     '2026-05-10','2026-06-09',39,'overdue_31_60','net_30',
     'follow_up_call',false,'none',45,0.00,'watch','2026-07-14','Ventilator supply invoice — PO confirmed, release awaited'),
    ('Fortis Bannerghatta Bengaluru','corporate_hospital','INV-FRT-1902',620000.00,
     '2026-04-15','2026-05-15',64,'overdue_61_90','net_30',
     'promise_to_pay',false,'none',70,200000.00,'at_risk','2026-07-10','Partial paid — balance promised by month-end'),
    ('Fortis Bannerghatta Bengaluru','corporate_hospital','INV-FRT-1855',480000.00,
     '2026-03-01','2026-03-31',109,'overdue_90_plus','net_30',
     'escalated_legal',true,'pricing_dispute',120,0.00,'doubtful_debt','2026-07-08','Spares pricing disputed — legal notice drafted'),
    ('Manipal Whitefield Bengaluru','corporate_hospital','INV-MNP-3310',340000.00,
     '2026-06-28','2026-07-13',5,'current_0_30','net_15',
     'not_started',false,'none',20,0.00,'on_track',null,'Recent invoice, well within credit terms'),
    ('Manipal Whitefield Bengaluru','corporate_hospital','INV-MNP-3255',910000.00,
     '2026-04-30','2026-06-14',34,'overdue_31_60','net_45',
     'follow_up_call',true,'documentation_missing',55,0.00,'at_risk','2026-07-12','GRN copy missing — resending documentation'),
    ('AIIMS New Delhi Ansari Nagar','government_hospital','INV-AIM-5501',1580000.00,
     '2026-03-20','2026-06-18',30,'current_0_30','net_90',
     'promise_to_pay',false,'none',95,0.00,'watch','2026-07-11','Govt tender payment — treasury processing in queue'),
    ('AIIMS New Delhi Ansari Nagar','government_hospital','INV-AIM-5470',720000.00,
     '2026-02-10','2026-05-11',68,'overdue_61_90','net_90',
     'escalated_legal',false,'none',110,0.00,'critical','2026-07-09','Budget sanction delayed — escalated to finance dept'),
    ('KIMS Secunderabad','corporate_hospital','INV-KIM-2201',265000.00,
     '2026-06-01','2026-07-01',17,'current_0_30','net_30',
     'reminder_sent',false,'none',25,0.00,'on_track','2026-07-16','First reminder sent, response awaited'),
    ('KIMS Secunderabad','corporate_hospital','INV-KIM-2140',530000.00,
     '2026-01-15','2026-02-14',154,'overdue_90_plus','net_30',
     'escalated_legal',true,'service_quality',175,0.00,'write_off_recommended','2026-07-05','Service complaint linked — recovery doubtful'),
    ('Care Hospitals Banjara Hills','trust_hospital','INV-CAR-1780',415000.00,
     '2026-05-25','2026-06-24',24,'current_0_30','net_30',
     'follow_up_call',false,'none',32,0.00,'on_track','2026-07-13','Trust finance committee approval pending'),
    ('Yashoda Somajiguda Hyderabad','corporate_hospital','INV-YSH-4020',1120000.00,
     '2026-04-05','2026-05-20',59,'overdue_31_60','net_45',
     'partial_received',false,'none',68,500000.00,'at_risk','2026-07-12','Half received — balance under active follow-up'),
    ('St John''s Bengaluru','trust_hospital','INV-STJ-0912',380000.00,
     '2026-06-10','2026-07-10',8,'current_0_30','net_30',
     'not_started',false,'none',18,0.00,'on_track',null,'Within terms — no collection action needed yet'),
    ('Rainbow Children''s Hyderabad','standalone_clinic','INV-RBW-0655',175000.00,
     '2026-02-28','2026-03-30',110,'overdue_90_plus','net_30',
     'settled_full',false,'none',130,175000.00,'recovered','2026-07-06','Fully settled after prolonged follow-up')
  ) as q(cust, seg, inv, amt, idate, ddate, dov, bucket, terms, cstat, disp, dreason, dso, coll, verdict, lcontact, nt);

  -- CAPA seed — attach to specific invoices by invoice number
  insert into public.ar_aging_capa_actions_r3169 (
    ar_aging_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.cstat, q.ri, q.tcd::date, q.acd::date, q.cost, q.nt
  from (values
    ('INV-FRT-1855','invoice_dispute','pricing_disagreement','resolve_dispute_meeting',
     'in_progress','revenue_recognition_impact','2026-07-25',null,15000.00,'Pricing dispute meeting scheduled with procurement head'),
    ('INV-KIM-2140','write_off_candidate','service_quality_issue','write_off_bad_debt',
     'escalated','provisioning_required','2026-07-30',null,530000.00,'Recommend full provisioning as doubtful debt'),
    ('INV-AIM-5470','budget_freeze_customer','budget_cycle_delay','escalate_to_management',
     'open','none','2026-08-05',null,8000.00,'Govt budget sanction stuck — CFO escalation raised'),
    ('INV-MNP-3255','documentation_gap','missing_documentation','correct_invoice_reissue',
     'closed','internal_only','2026-07-22','2026-07-16',2500.00,'GRN attached and invoice reissued to customer'),
    ('INV-YSH-4020','payment_delay','customer_cash_flow','restructure_payment_plan',
     'in_progress','none','2026-07-28',null,5000.00,'Agreed 2-installment plan for outstanding balance'),
    ('INV-FRT-1902','collection_process_gap','approval_bottleneck','schedule_collection_call',
     'overdue','audit_finding','2026-07-15',null,3000.00,'Follow-up call SLA missed — flagged in internal audit')
  ) as q(inv_key, fc, rc, ca, cstat, ri, tcd, acd, cost, nt)
  join public.ar_aging_r3169 e
    on e.organization_id = v_org_id and e.invoice_number = q.inv_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Collection verdict distribution
create or replace function public.founder_r3169_collection_verdict_rollup()
returns table(collection_verdict text, invoices bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ar_aging_r3169)
  select l.collection_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ar_aging_r3169 l
  group by l.collection_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3169_collection_verdict_rollup() from public, anon;
grant execute on function public.founder_r3169_collection_verdict_rollup() to authenticated;

-- 2) Customer-level collection scorecard
create or replace function public.founder_r3169_customer_scorecard()
returns table(
  customer_name text,
  total_invoices bigint,
  total_outstanding numeric,
  overdue_90_plus bigint,
  disputed bigint,
  avg_days_overdue numeric,
  collected numeric,
  recovery_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_name,
    count(*)::bigint,
    coalesce(sum(l.invoice_amount_rupees - coalesce(l.amount_collected_rupees,0)),0)::numeric,
    count(*) filter (where l.aging_bucket = 'overdue_90_plus')::bigint,
    count(*) filter (where l.dispute_flag)::bigint,
    round(avg(l.days_overdue), 1),
    coalesce(sum(l.amount_collected_rupees),0)::numeric,
    round(100.0 * coalesce(sum(l.amount_collected_rupees),0)::numeric / nullif(sum(l.invoice_amount_rupees),0), 1)
  from public.ar_aging_r3169 l
  group by l.customer_name
  order by coalesce(sum(l.invoice_amount_rupees - coalesce(l.amount_collected_rupees,0)),0) desc;
end;
$$;

revoke execute on function public.founder_r3169_customer_scorecard() from public, anon;
grant execute on function public.founder_r3169_customer_scorecard() to authenticated;

-- 3) Aging bucket × customer segment matrix
create or replace function public.founder_r3169_bucket_segment_matrix()
returns table(aging_bucket text, customer_segment text, invoices bigint, outstanding_rupees numeric, avg_days_overdue numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.aging_bucket, l.customer_segment, count(*)::bigint,
    coalesce(sum(l.invoice_amount_rupees - coalesce(l.amount_collected_rupees,0)),0)::numeric,
    round(avg(l.days_overdue), 1)
  from public.ar_aging_r3169 l
  group by l.aging_bucket, l.customer_segment
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3169_bucket_segment_matrix() from public, anon;
grant execute on function public.founder_r3169_bucket_segment_matrix() to authenticated;

-- 4) Invoice date trend (billed vs collected)
create or replace function public.founder_r3169_invoice_date_trend()
returns table(invoice_date date, invoices bigint, invoiced_rupees numeric, collected_rupees numeric, disputed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.invoice_date,
    count(*)::bigint,
    coalesce(sum(l.invoice_amount_rupees),0)::numeric,
    coalesce(sum(l.amount_collected_rupees),0)::numeric,
    count(*) filter (where l.dispute_flag)::bigint
  from public.ar_aging_r3169 l
  group by l.invoice_date
  order by l.invoice_date desc;
end;
$$;

revoke execute on function public.founder_r3169_invoice_date_trend() from public, anon;
grant execute on function public.founder_r3169_invoice_date_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3169_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
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
  from public.ar_aging_capa_actions_r3169 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3169_capa_status_board() from public, anon;
grant execute on function public.founder_r3169_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3169_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ar_aging_capa_actions_r3169)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ar_aging_capa_actions_r3169 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3169_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3169_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3169_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.ar_aging_capa_actions_r3169 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3169_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3169_regulatory_impact_digest() to authenticated;

-- 8) Priority collection queue (high-risk receivables)
create or replace function public.founder_r3169_priority_collection_queue()
returns table(
  customer_name text,
  invoice_number text,
  invoice_amount_rupees numeric,
  due_date date,
  days_overdue int,
  aging_bucket text,
  collection_status text,
  collection_verdict text,
  dispute_flag boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_name, l.invoice_number, l.invoice_amount_rupees, l.due_date,
    l.days_overdue, l.aging_bucket, l.collection_status, l.collection_verdict, l.dispute_flag, l.notes
  from public.ar_aging_r3169 l
  where l.collection_verdict in ('at_risk','critical','doubtful_debt','write_off_recommended')
     or l.dispute_flag
     or l.aging_bucket = 'overdue_90_plus'
  order by l.days_overdue desc, l.customer_name;
end;
$$;

revoke execute on function public.founder_r3169_priority_collection_queue() from public, anon;
grant execute on function public.founder_r3169_priority_collection_queue() to authenticated;
