-- Round 3305: Founder InfoSec, VAPT, ISO 27001 & DR/Backup Posture Board
-- Security posture log — system/control × domain × assessment type × open/critical findings × SLA × RTO/RPO × backup-restore × MFA × control maturity × posture verdict × CAPA

-- =============================================================================
-- TABLE 1: infosec_posture_r3305 — per system/control-area security posture
-- =============================================================================
create table if not exists public.infosec_posture_r3305 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  system_or_control text not null check (system_or_control in (
    'customer_portal','founder_console','supabase_backend','engineer_app',
    'payment_gateway','email_domain','vpn_access','backup_infrastructure'
  )),
  domain text not null check (domain in (
    'application_security','access_control','data_backup','disaster_recovery',
    'network_security','vendor_risk','endpoint_security'
  )),
  last_assessment_date date not null,
  assessment_type text not null check (assessment_type in (
    'vapt','iso27001_audit','dr_drill','backup_restore_test','access_review','config_review'
  )),
  open_findings int not null default 0,
  critical_findings int not null default 0,
  remediation_sla_met boolean not null default true,
  rto_hours numeric(6,2),
  rpo_hours numeric(6,2),
  last_backup_restore_verified date,
  mfa_enforced boolean not null default false,
  control_maturity text not null check (control_maturity in (
    'optimized','managed','defined','initial','ad_hoc'
  )),
  posture_verdict text not null check (posture_verdict in (
    'strong','adequate','gaps_present','high_risk','critical_exposure'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.infosec_posture_r3305 enable row level security;

create index if not exists idx_infosec_posture_r3305_org on public.infosec_posture_r3305(organization_id);
create index if not exists idx_infosec_posture_r3305_date on public.infosec_posture_r3305(last_assessment_date);
create index if not exists idx_infosec_posture_r3305_verdict on public.infosec_posture_r3305(posture_verdict);

-- =============================================================================
-- TABLE 2: infosec_posture_capa_actions_r3305 — remediation / hardening actions
-- =============================================================================
create table if not exists public.infosec_posture_capa_actions_r3305 (
  id uuid primary key default gen_random_uuid(),
  posture_id uuid not null references public.infosec_posture_r3305(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'mfa_gap','unpatched_vulnerability','rls_policy_gap','backup_restore_failure',
    'dr_rto_breach','access_review_overdue','insecure_config','vendor_compliance_gap','endpoint_hardening_needed'
  )),
  root_cause text not null check (root_cause in (
    'missing_mfa_policy','legacy_system_debt','patch_backlog','misconfigured_rls',
    'untested_backup','runbook_outdated','manual_access_provisioning','vendor_attestation_lapsed',
    'pending_investigation','no_mdm_tooling'
  )),
  corrective_action text not null check (corrective_action in (
    'enforce_mfa_all_accounts','apply_security_patch','fix_rls_policy','remediate_backup_pipeline',
    'update_dr_runbook','revoke_stale_access','harden_config','obtain_vendor_soc2',
    'deploy_mdm','decommission_legacy_vpn','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'dpdp_act_breach','iso27001_nonconformity','pci_dss_finding','cert_in_reportable','none','internal_only'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.infosec_posture_capa_actions_r3305 enable row level security;

create index if not exists idx_infosec_capa_r3305_posture on public.infosec_posture_capa_actions_r3305(posture_id);
create index if not exists idx_infosec_capa_r3305_status on public.infosec_posture_capa_actions_r3305(capa_status);

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

  -- 14 posture rows
  insert into public.infosec_posture_r3305 (
    organization_id, system_or_control, domain, last_assessment_date, assessment_type,
    open_findings, critical_findings, remediation_sla_met, rto_hours, rpo_hours,
    last_backup_restore_verified, mfa_enforced, control_maturity, posture_verdict, notes
  )
  select v_org_id, q.sys, q.dom, q.lad::date, q.atype,
    q.opf, q.crf, q.sla, q.rto, q.rpo,
    q.lbrv::date, q.mfa, q.mat, q.verdict, q.nt
  from (values
    ('customer_portal','application_security','2026-07-05','vapt',
     4,0,true,4.0,1.0,'2026-07-01',true,'managed','adequate',
     'OWASP Top-10 VAPT on Apollo Chennai tenant portal — 4 medium findings, all within SLA'),
    ('customer_portal','access_control','2026-06-28','access_review',
     2,0,true,4.0,1.0,'2026-07-01',true,'defined','adequate',
     'Quarterly tenant-admin access review — 2 stale Fortis Gurgaon logins disabled'),
    ('founder_console','access_control','2026-07-10','access_review',
     1,1,false,2.0,0.5,'2026-07-08',true,'managed','high_risk',
     'One founder-console service account without MFA — critical, remediation SLA breached'),
    ('supabase_backend','data_backup','2026-07-12','backup_restore_test',
     0,0,true,2.0,0.25,'2026-07-12',true,'optimized','strong',
     'PITR restore drill to staging passed; RPO 15 min verified end-to-end'),
    ('supabase_backend','application_security','2026-06-30','config_review',
     3,1,false,2.0,0.25,'2026-07-12',true,'managed','gaps_present',
     'RLS policy gaps on 2 ops tables; one critical tenant-isolation exposure patched mid-audit'),
    ('engineer_app','application_security','2026-07-03','vapt',
     5,1,false,6.0,2.0,'2026-06-20',true,'defined','high_risk',
     'Android engineer-app VAPT — insecure deep-link plus 1 critical token-leak, remediation overdue'),
    ('payment_gateway','vendor_risk','2026-07-08','iso27001_audit',
     2,0,true,4.0,1.0,'2026-07-05',true,'managed','adequate',
     'Razorpay PCI-DSS attestation reviewed; 2 minor vendor-risk observations'),
    ('payment_gateway','application_security','2026-06-25','vapt',
     1,0,true,4.0,1.0,'2026-07-05',true,'managed','strong',
     'Payment callback signature-verification hardened; clean VAPT pass'),
    ('email_domain','network_security','2026-07-06','config_review',
     2,0,true,8.0,4.0,null,true,'defined','adequate',
     'DMARC moved to reject policy; SPF and DKIM verified; no critical findings'),
    ('vpn_access','network_security','2026-06-22','access_review',
     3,2,false,6.0,2.0,null,false,'initial','critical_exposure',
     'Legacy VPN without MFA, 2 critical exposed ports — MFA rollout pending, CERT-In reportable'),
    ('backup_infrastructure','data_backup','2026-07-11','backup_restore_test',
     1,0,true,3.0,0.5,'2026-07-11',true,'managed','adequate',
     'Offsite backup restore verified for Manipal Bengaluru dataset; 1 medium retention-policy finding'),
    ('backup_infrastructure','disaster_recovery','2026-07-09','dr_drill',
     2,0,true,4.0,1.0,'2026-07-09',true,'defined','adequate',
     'DR failover drill — RTO 4h met; runbook documentation gaps noted'),
    ('founder_console','disaster_recovery','2026-05-30','dr_drill',
     4,1,false,8.0,2.0,'2026-05-28',true,'initial','high_risk',
     'DR drill overdue beyond 30 days; failover exceeded RTO; 1 critical runbook gap'),
    ('engineer_app','endpoint_security','2026-07-07','config_review',
     2,0,true,6.0,2.0,'2026-06-20',false,'ad_hoc','gaps_present',
     'Field-engineer devices lack MDM enforcement across AIIMS Delhi & CMC Vellore clusters; 2 endpoint findings')
  ) as q(sys, dom, lad, atype, opf, crf, sla, rto, rpo, lbrv, mfa, mat, verdict, nt);

  -- CAPA seed — attach to at-risk posture rows by (system_or_control, domain)
  insert into public.infosec_posture_capa_actions_r3305 (
    posture_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('founder_console','access_control','mfa_gap','missing_mfa_policy','enforce_mfa_all_accounts',
     'escalated','cert_in_reportable','2026-07-15',null,25000.00,'Founder-console service account MFA enforcement — CERT-In 6-hour reporting window logged'),
    ('supabase_backend','application_security','rls_policy_gap','misconfigured_rls','fix_rls_policy',
     'in_progress','dpdp_act_breach','2026-07-14',null,40000.00,'Two ops tables missing tenant RLS — DPDP data-isolation risk'),
    ('engineer_app','application_security','unpatched_vulnerability','patch_backlog','apply_security_patch',
     'overdue','iso27001_nonconformity','2026-07-01',null,60000.00,'Critical token-leak in Android deep-link handler; patch overdue'),
    ('vpn_access','network_security','mfa_gap','legacy_system_debt','decommission_legacy_vpn',
     'escalated','cert_in_reportable','2026-07-20',null,180000.00,'Legacy VPN two critical exposures — migrating to WireGuard with enforced MFA'),
    ('founder_console','disaster_recovery','dr_rto_breach','runbook_outdated','update_dr_runbook',
     'open','iso27001_nonconformity','2026-07-18',null,35000.00,'DR runbook failover step stale; RTO exceeded in May drill'),
    ('engineer_app','endpoint_security','endpoint_hardening_needed','no_mdm_tooling','deploy_mdm',
     'in_progress','internal_only','2026-07-25',null,220000.00,'MDM rollout for field-engineer devices across Manipal Bengaluru cluster'),
    ('payment_gateway','vendor_risk','vendor_compliance_gap','vendor_attestation_lapsed','obtain_vendor_soc2',
     'closed','pci_dss_finding','2026-07-10','2026-07-08',12000.00,'Razorpay SOC2 Type II obtained; PCI-DSS observation closed')
  ) as q(sys, dom, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.infosec_posture_r3305 e
    on e.organization_id = v_org_id and e.system_or_control = q.sys and e.domain = q.dom;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Posture verdict distribution
create or replace function public.founder_r3305_posture_verdict_rollup()
returns table(posture_verdict text, controls bigint, total_open_findings bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.infosec_posture_r3305)
  select p.posture_verdict, count(*)::bigint,
         coalesce(sum(p.open_findings),0)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.infosec_posture_r3305 p
  group by p.posture_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3305_posture_verdict_rollup() from public, anon;
grant execute on function public.founder_r3305_posture_verdict_rollup() to authenticated;

-- 2) System / control-area scorecard
create or replace function public.founder_r3305_system_scorecard()
returns table(
  system_or_control text,
  total_controls bigint,
  strong bigint,
  adequate bigint,
  at_risk bigint,
  total_open_findings bigint,
  total_critical_findings bigint,
  mfa_enforced_controls bigint,
  sla_met_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.system_or_control,
    count(*)::bigint,
    count(*) filter (where p.posture_verdict = 'strong')::bigint,
    count(*) filter (where p.posture_verdict = 'adequate')::bigint,
    count(*) filter (where p.posture_verdict in ('gaps_present','high_risk','critical_exposure'))::bigint,
    coalesce(sum(p.open_findings),0)::bigint,
    coalesce(sum(p.critical_findings),0)::bigint,
    count(*) filter (where p.mfa_enforced)::bigint,
    round(100.0 * count(*) filter (where p.remediation_sla_met)::numeric / nullif(count(*),0), 1)
  from public.infosec_posture_r3305 p
  group by p.system_or_control
  order by count(*) filter (where p.posture_verdict in ('gaps_present','high_risk','critical_exposure')) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3305_system_scorecard() from public, anon;
grant execute on function public.founder_r3305_system_scorecard() to authenticated;

-- 3) Domain × assessment-type matrix
create or replace function public.founder_r3305_domain_assessment_matrix()
returns table(domain text, assessment_type text, assessments bigint, open_findings bigint, critical_findings bigint, avg_rto_hours numeric, avg_rpo_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.domain, p.assessment_type, count(*)::bigint,
    coalesce(sum(p.open_findings),0)::bigint,
    coalesce(sum(p.critical_findings),0)::bigint,
    round(avg(p.rto_hours), 2),
    round(avg(p.rpo_hours), 2)
  from public.infosec_posture_r3305 p
  group by p.domain, p.assessment_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3305_domain_assessment_matrix() from public, anon;
grant execute on function public.founder_r3305_domain_assessment_matrix() to authenticated;

-- 4) Assessment-date trend
create or replace function public.founder_r3305_assessment_date_trend()
returns table(last_assessment_date date, assessments bigint, open_findings bigint, critical_findings bigint, sla_met bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.last_assessment_date,
    count(*)::bigint,
    coalesce(sum(p.open_findings),0)::bigint,
    coalesce(sum(p.critical_findings),0)::bigint,
    count(*) filter (where p.remediation_sla_met)::bigint
  from public.infosec_posture_r3305 p
  group by p.last_assessment_date
  order by p.last_assessment_date desc;
end;
$$;

revoke execute on function public.founder_r3305_assessment_date_trend() from public, anon;
grant execute on function public.founder_r3305_assessment_date_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3305_capa_status_board()
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
  from public.infosec_posture_capa_actions_r3305 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3305_capa_status_board() from public, anon;
grant execute on function public.founder_r3305_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3305_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.infosec_posture_capa_actions_r3305)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.infosec_posture_capa_actions_r3305 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3305_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3305_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3305_regulatory_impact_digest()
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
  from public.infosec_posture_capa_actions_r3305 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3305_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3305_regulatory_impact_digest() to authenticated;

-- 8) High-risk posture queue (top security concerns)
create or replace function public.founder_r3305_high_risk_queue()
returns table(
  system_or_control text,
  domain text,
  last_assessment_date date,
  assessment_type text,
  open_findings int,
  critical_findings int,
  sla_status text,
  mfa_status text,
  control_maturity text,
  posture_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.system_or_control, p.domain, p.last_assessment_date, p.assessment_type,
    p.open_findings, p.critical_findings,
    case when p.remediation_sla_met then 'met' else 'breached' end,
    case when p.mfa_enforced then 'enforced' else 'not_enforced' end,
    p.control_maturity, p.posture_verdict, p.notes
  from public.infosec_posture_r3305 p
  where p.posture_verdict in ('gaps_present','high_risk','critical_exposure')
     or p.critical_findings > 0
     or p.remediation_sla_met = false
     or p.mfa_enforced = false
  order by case p.posture_verdict
             when 'critical_exposure' then 0
             when 'high_risk' then 1
             when 'gaps_present' then 2
             else 3
           end,
           p.critical_findings desc,
           p.last_assessment_date desc;
end;
$$;

revoke execute on function public.founder_r3305_high_risk_queue() from public, anon;
grant execute on function public.founder_r3305_high_risk_queue() to authenticated;
