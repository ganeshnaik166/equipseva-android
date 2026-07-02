-- Round 2985: Founder Quarterly Strategic Mid-Year Engineering Roadmap Variance Audit
-- Two tables (_r2985), seven RPCs, founder-gated.

create table if not exists engineering_roadmap_items_r2985 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  initiative_code text not null unique,
  initiative_name text not null,
  pillar text not null check (pillar in ('platform','mobile','infra','data','growth','reliability','ai')),
  owner_squad text not null,
  quarter text not null check (quarter in ('Q1','Q2','Q3','Q4')),
  planned_story_points int not null check (planned_story_points between 1 and 500),
  actual_story_points int not null check (actual_story_points between 0 and 800),
  planned_start_date date not null,
  planned_end_date date not null,
  actual_start_date date,
  actual_end_date date,
  status text not null check (status in ('on_track','at_risk','slipping','blocked','completed','descoped')),
  rag text not null check (rag in ('red','amber','green')),
  strategic_weight numeric(4,2) not null check (strategic_weight between 0 and 5),
  notes text
);

create table if not exists engineering_roadmap_variance_findings_r2985 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  initiative_code text not null references engineering_roadmap_items_r2985(initiative_code) on delete cascade,
  finding_kind text not null check (finding_kind in ('scope_drift','timeline_slip','capacity_gap','dependency_block','quality_regression','reprioritization')),
  severity text not null check (severity in ('p0','p1','p2','p3')),
  variance_days int not null check (variance_days between -120 and 365),
  variance_points int not null check (variance_points between -200 and 400),
  identified_on date not null,
  resolved_on date,
  remediation text not null,
  is_open boolean not null default true
);

alter table engineering_roadmap_items_r2985 enable row level security;
alter table engineering_roadmap_variance_findings_r2985 enable row level security;

drop policy if exists eng_roadmap_items_r2985_sel on engineering_roadmap_items_r2985;
create policy eng_roadmap_items_r2985_sel on engineering_roadmap_items_r2985 for select using (is_founder());

drop policy if exists eng_roadmap_var_r2985_sel on engineering_roadmap_variance_findings_r2985;
create policy eng_roadmap_var_r2985_sel on engineering_roadmap_variance_findings_r2985 for select using (is_founder());

revoke all on engineering_roadmap_items_r2985 from public, anon;
revoke all on engineering_roadmap_variance_findings_r2985 from public, anon;
grant select on engineering_roadmap_items_r2985 to authenticated;
grant select on engineering_roadmap_variance_findings_r2985 to authenticated;

-- Seed roadmap items (18)
insert into engineering_roadmap_items_r2985
  (initiative_code, initiative_name, pillar, owner_squad, quarter, planned_story_points, actual_story_points, planned_start_date, planned_end_date, actual_start_date, actual_end_date, status, rag, strategic_weight, notes)
values
  ('RM-101','AMC pricing v2 engine','platform','billing-core','Q1', 80, 92, '2026-01-06'::date,'2026-03-20'::date,'2026-01-08'::date,'2026-03-28'::date,'completed','amber',4.50,'10% point overrun, 6d slip'),
  ('RM-102','Engineer mobile offline mode','mobile','field-app','Q1',120,140,'2026-01-13'::date,'2026-03-31'::date,'2026-01-15'::date,'2026-04-18'::date,'completed','red',4.80,'18d slip — sync conflicts'),
  ('RM-103','Hospital admin chain dashboards','platform','hospital-portal','Q2', 60, 55,'2026-04-01'::date,'2026-05-30'::date,'2026-04-03'::date,'2026-05-25'::date,'completed','green',3.50,'Ahead of schedule'),
  ('RM-104','Razorpay payouts hardening','infra','payments','Q1', 45, 70,'2026-02-10'::date,'2026-03-25'::date,'2026-02-12'::date,'2026-04-22'::date,'completed','red',4.90,'PCI rescope mid-quarter'),
  ('RM-105','Founder console v2 IA','platform','founder-tools','Q2', 90, 88,'2026-04-08'::date,'2026-06-18'::date,'2026-04-10'::date,null,'on_track','green',4.10,'Tracking to date'),
  ('RM-106','Spot audit cron + rotation','reliability','quality-ops','Q2', 35, 42,'2026-04-15'::date,'2026-05-10'::date,'2026-04-18'::date,'2026-05-22'::date,'completed','amber',3.80,'Cron JWT gotcha'),
  ('RM-107','AI triage classifier','ai','intelligence','Q2',110, 65,'2026-04-01'::date,'2026-06-30'::date,'2026-04-22'::date,null,'slipping','red',4.60,'Training data gap'),
  ('RM-108','DPDP grievance auto-routing','reliability','compliance','Q1', 50, 48,'2026-02-01'::date,'2026-03-15'::date,'2026-02-03'::date,'2026-03-12'::date,'completed','green',4.20,'Closed clean'),
  ('RM-109','GST e-invoicing','data','billing-core','Q1', 70, 95,'2026-01-20'::date,'2026-03-30'::date,'2026-01-25'::date,'2026-05-02'::date,'completed','red',4.70,'IRP integration drift'),
  ('RM-110','Engineer payout reaper v3','infra','payments','Q2', 30, 32,'2026-04-05'::date,'2026-04-30'::date,'2026-04-07'::date,'2026-05-01'::date,'completed','green',3.20,'Minor 1d slip'),
  ('RM-111','Investor data room v2','growth','founder-tools','Q2', 65, 38,'2026-05-01'::date,'2026-06-25'::date,'2026-05-12'::date,null,'at_risk','amber',3.90,'KYC blockers'),
  ('RM-112','Bonded parts provenance','platform','supply-chain','Q1', 85, 110,'2026-01-15'::date,'2026-03-31'::date,'2026-01-18'::date,'2026-04-25'::date,'completed','red',4.40,'Counterfeit-detection rescope'),
  ('RM-113','Tier-1 founder home','platform','founder-tools','Q2', 40, 44,'2026-04-20'::date,'2026-05-25'::date,'2026-04-22'::date,'2026-05-30'::date,'completed','amber',3.60,'5d slip'),
  ('RM-114','Weekly board pack auto-gen','data','founder-tools','Q2', 25, 30,'2026-04-10'::date,'2026-05-05'::date,'2026-04-12'::date,'2026-05-10'::date,'completed','amber',3.30,'PDF rendering rework'),
  ('RM-115','Spare-part order tamper guard','reliability','supply-chain','Q1', 20, 18,'2026-02-15'::date,'2026-03-05'::date,'2026-02-16'::date,'2026-03-03'::date,'completed','green',4.00,'Audit-2 critical closed'),
  ('RM-116','Hospital chain bulk ops','platform','hospital-portal','Q2', 55, 25,'2026-05-15'::date,'2026-06-30'::date,'2026-06-02'::date,null,'blocked','red',4.30,'Awaiting org-hierarchy table'),
  ('RM-117','Cashfree payouts at scale','infra','payments','Q2', 75,  0,'2026-04-01'::date,'2026-06-30'::date,null,null,'blocked','red',4.50,'KYC pending externally'),
  ('RM-118','Founder priority actions write-layer','platform','founder-tools','Q1', 28, 30,'2026-03-01'::date,'2026-03-25'::date,'2026-03-03'::date,'2026-03-28'::date,'completed','green',3.70,'On time, slight overrun');

-- Seed variance findings (22)
insert into engineering_roadmap_variance_findings_r2985
  (initiative_code, finding_kind, severity, variance_days, variance_points, identified_on, resolved_on, remediation, is_open)
values
  ('RM-101','timeline_slip','p2',  8, 12,'2026-03-15'::date,'2026-03-28'::date,'Pair with billing-core sr eng', false),
  ('RM-101','scope_drift','p3',   0,  8,'2026-02-20'::date,'2026-03-28'::date,'Trim refund-edge cases', false),
  ('RM-102','timeline_slip','p1', 18, 20,'2026-03-25'::date,'2026-04-18'::date,'Resolve sync-conflict CRDT', false),
  ('RM-102','quality_regression','p2', 0, 10,'2026-04-05'::date,'2026-04-18'::date,'Add device-matrix smoke tests', false),
  ('RM-104','scope_drift','p1', 28, 25,'2026-03-01'::date,'2026-04-22'::date,'PCI tokenization rescope', false),
  ('RM-104','dependency_block','p2', 14, 0,'2026-03-10'::date,'2026-04-01'::date,'Webhook signing key rotation', false),
  ('RM-107','capacity_gap','p1', 30,-45,'2026-05-10'::date,null,'Hire ML eng + label vendor', true),
  ('RM-107','dependency_block','p2', 15,  0,'2026-05-22'::date,null,'Awaiting clean training set', true),
  ('RM-109','scope_drift','p1', 33, 25,'2026-03-05'::date,'2026-05-02'::date,'IRP API contract change', false),
  ('RM-109','timeline_slip','p2', 12,  0,'2026-04-01'::date,'2026-05-02'::date,'Add buffer for IRP retries', false),
  ('RM-111','capacity_gap','p2',  0,-27,'2026-05-25'::date,null,'Loan investor-relations PM', true),
  ('RM-111','reprioritization','p3', 5,  0,'2026-06-01'::date,null,'Defer non-IC document types', true),
  ('RM-112','scope_drift','p1', 25, 25,'2026-02-25'::date,'2026-04-25'::date,'Counterfeit signature added', false),
  ('RM-113','timeline_slip','p3',  5,  4,'2026-05-20'::date,'2026-05-30'::date,'Compress QA window', false),
  ('RM-114','quality_regression','p3', 5,  5,'2026-05-01'::date,'2026-05-10'::date,'PDF lib pinned', false),
  ('RM-116','dependency_block','p0', 21,-30,'2026-05-25'::date,null,'Build org-hierarchy table', true),
  ('RM-116','reprioritization','p1', 0,  0,'2026-06-02'::date,null,'Push to Q3 if unblocked', true),
  ('RM-117','dependency_block','p0', 90,-75,'2026-04-15'::date,null,'External Cashfree KYC', true),
  ('RM-106','timeline_slip','p3', 12,  7,'2026-05-08'::date,'2026-05-22'::date,'Fix pg_cron JWT gate', false),
  ('RM-105','capacity_gap','p3',  0,  0,'2026-05-20'::date,null,'Borrow design from growth', true),
  ('RM-103','reprioritization','p3', -5, -5,'2026-05-15'::date,'2026-05-25'::date,'Pulled-in chain dashboards', false),
  ('RM-110','quality_regression','p3', 1,  2,'2026-04-28'::date,'2026-05-01'::date,'Retry-budget patch', false);

-- RPC 1: portfolio summary by quarter
create or replace function founder_r2985_portfolio_summary()
returns table(quarter text, items int, completed int, slipping int, blocked int, total_planned_pts int, total_actual_pts int, pct_overrun numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorised'; end if;
  return query
    select i.quarter,
           count(*)::int,
           (count(*) filter (where i.status = 'completed'))::int,
           (count(*) filter (where i.status = 'slipping'))::int,
           (count(*) filter (where i.status = 'blocked'))::int,
           sum(i.planned_story_points)::int,
           sum(i.actual_story_points)::int,
           round((sum(i.actual_story_points)::numeric - sum(i.planned_story_points))/nullif(sum(i.planned_story_points),0) * 100, 2)
    from engineering_roadmap_items_r2985 i
    group by i.quarter
    order by i.quarter;
end $$;

-- RPC 2: pillar variance
create or replace function founder_r2985_pillar_variance()
returns table(pillar text, items int, avg_strategic_weight numeric, planned_pts int, actual_pts int, point_variance int, red_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorised'; end if;
  return query
    select i.pillar,
           count(*)::int,
           round(avg(i.strategic_weight)::numeric, 2),
           sum(i.planned_story_points)::int,
           sum(i.actual_story_points)::int,
           (sum(i.actual_story_points) - sum(i.planned_story_points))::int,
           (count(*) filter (where i.rag = 'red'))::int
    from engineering_roadmap_items_r2985 i
    group by i.pillar
    order by sum(i.actual_story_points) - sum(i.planned_story_points) desc;
end $$;

-- RPC 3: top slippages
create or replace function founder_r2985_top_slippages()
returns table(initiative_code text, initiative_name text, owner_squad text, days_slipped int, points_over int, rag text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorised'; end if;
  return query
    select i.initiative_code, i.initiative_name, i.owner_squad,
           coalesce((i.actual_end_date - i.planned_end_date), (current_date - i.planned_end_date))::int as days_slipped,
           (i.actual_story_points - i.planned_story_points)::int as points_over,
           i.rag
    from engineering_roadmap_items_r2985 i
    where i.status in ('slipping','blocked','at_risk') or i.actual_end_date > i.planned_end_date
    order by coalesce((i.actual_end_date - i.planned_end_date), (current_date - i.planned_end_date)) desc nulls last
    limit 10;
end $$;

-- RPC 4: open findings by severity
create or replace function founder_r2985_open_findings_by_severity()
returns table(severity text, open_count int, total_count int, avg_variance_days numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorised'; end if;
  return query
    select v.severity,
           (count(*) filter (where v.is_open))::int,
           count(*)::int,
           round(avg(v.variance_days)::numeric, 1)
    from engineering_roadmap_variance_findings_r2985 v
    group by v.severity
    order by v.severity;
end $$;

-- RPC 5: finding kind breakdown
create or replace function founder_r2985_finding_kind_breakdown()
returns table(finding_kind text, total int, open_count int, resolved_count int, avg_points_var numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorised'; end if;
  return query
    select v.finding_kind,
           count(*)::int,
           (count(*) filter (where v.is_open))::int,
           (count(*) filter (where not v.is_open))::int,
           round(avg(v.variance_points)::numeric, 1)
    from engineering_roadmap_variance_findings_r2985 v
    group by v.finding_kind
    order by count(*) desc;
end $$;

-- RPC 6: squad scorecard
create or replace function founder_r2985_squad_scorecard()
returns table(owner_squad text, items int, completed int, open_findings int, planned_pts int, actual_pts int, overrun_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorised'; end if;
  return query
    select i.owner_squad,
           count(*)::int,
           (count(*) filter (where i.status = 'completed'))::int,
           coalesce((select count(*) from engineering_roadmap_variance_findings_r2985 v
                     where v.initiative_code in (select ii.initiative_code from engineering_roadmap_items_r2985 ii where ii.owner_squad = i.owner_squad)
                     and v.is_open), 0)::int,
           sum(i.planned_story_points)::int,
           sum(i.actual_story_points)::int,
           round((sum(i.actual_story_points)::numeric - sum(i.planned_story_points)) / nullif(sum(i.planned_story_points),0) * 100, 2)
    from engineering_roadmap_items_r2985 i
    group by i.owner_squad
    order by sum(i.actual_story_points) - sum(i.planned_story_points) desc;
end $$;

-- RPC 7: blocked initiatives
create or replace function founder_r2985_blocked_initiatives()
returns table(initiative_code text, initiative_name text, pillar text, owner_squad text, strategic_weight numeric, blocker_count int, top_remediation text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorised'; end if;
  return query
    select i.initiative_code, i.initiative_name, i.pillar, i.owner_squad, i.strategic_weight,
           (select count(*)::int from engineering_roadmap_variance_findings_r2985 v
            where v.initiative_code = i.initiative_code and v.is_open),
           (select v2.remediation from engineering_roadmap_variance_findings_r2985 v2
            where v2.initiative_code = i.initiative_code and v2.is_open
            order by case v2.severity when 'p0' then 0 when 'p1' then 1 when 'p2' then 2 else 3 end
            limit 1)
    from engineering_roadmap_items_r2985 i
    where i.status in ('blocked','at_risk','slipping')
    order by i.strategic_weight desc;
end $$;

-- RPC 8: strategic risk index
create or replace function founder_r2985_strategic_risk_index()
returns table(pillar text, weighted_risk numeric, red_initiatives int, p0_p1_findings int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorised'; end if;
  return query
    select i.pillar,
           round(sum(case when i.rag = 'red' then i.strategic_weight * 2
                          when i.rag = 'amber' then i.strategic_weight * 1
                          else 0 end)::numeric, 2),
           (count(*) filter (where i.rag = 'red'))::int,
           (select count(*)::int from engineering_roadmap_variance_findings_r2985 v
            where v.severity in ('p0','p1') and v.is_open
            and v.initiative_code in (select ii.initiative_code from engineering_roadmap_items_r2985 ii where ii.pillar = i.pillar))
    from engineering_roadmap_items_r2985 i
    group by i.pillar
    order by sum(case when i.rag = 'red' then i.strategic_weight * 2 when i.rag = 'amber' then i.strategic_weight * 1 else 0 end) desc;
end $$;

revoke all on function founder_r2985_portfolio_summary() from public, anon;
revoke all on function founder_r2985_pillar_variance() from public, anon;
revoke all on function founder_r2985_top_slippages() from public, anon;
revoke all on function founder_r2985_open_findings_by_severity() from public, anon;
revoke all on function founder_r2985_finding_kind_breakdown() from public, anon;
revoke all on function founder_r2985_squad_scorecard() from public, anon;
revoke all on function founder_r2985_blocked_initiatives() from public, anon;
revoke all on function founder_r2985_strategic_risk_index() from public, anon;

grant execute on function founder_r2985_portfolio_summary() to authenticated;
grant execute on function founder_r2985_pillar_variance() to authenticated;
grant execute on function founder_r2985_top_slippages() to authenticated;
grant execute on function founder_r2985_open_findings_by_severity() to authenticated;
grant execute on function founder_r2985_finding_kind_breakdown() to authenticated;
grant execute on function founder_r2985_squad_scorecard() to authenticated;
grant execute on function founder_r2985_blocked_initiatives() to authenticated;
grant execute on function founder_r2985_strategic_risk_index() to authenticated;
