import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type MonthlyOverview = { audit_month: string; sites_audited: number; sleeves_inspected: number; sleeves_failed: number; failure_rate_pct: number };
type SiteLeader = { customer_site: string; city: string; total_inspected: number; total_failed: number; failure_rate_pct: number };
type FailureMix = { failure_mode: string; audits: number; total_failed: number; share_pct: number };
type Severity = { severity: string; audits: number; open_audits: number; escalated_audits: number };
type Engineer = { engineer_name: string; audits: number; sleeves_inspected: number; clean_audits: number };
type OpenAction = { customer_site: string; action_type: string; owner: string; due_date: string | null; action_status: string };
type CostSummary = { action_type: string; actions: number; total_cost_rupees: number; closed_actions: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [monthly, sites, mix, severity, engineers, openActions, cost] = await Promise.all([
    sb.rpc('fn_r3030_monthly_overview'),
    sb.rpc('fn_r3030_site_failure_leaderboard'),
    sb.rpc('fn_r3030_failure_mode_mix'),
    sb.rpc('fn_r3030_severity_breakdown'),
    sb.rpc('fn_r3030_engineer_throughput'),
    sb.rpc('fn_r3030_open_actions_queue'),
    sb.rpc('fn_r3030_remediation_cost_summary'),
  ]);

  const monthlyCols: Column<MonthlyOverview>[] = [
    { key: 'audit_month', label: 'Month' },
    { key: 'sites_audited', label: 'Sites' },
    { key: 'sleeves_inspected', label: 'Inspected' },
    { key: 'sleeves_failed', label: 'Failed' },
    { key: 'failure_rate_pct', label: 'Failure %' },
  ];
  const siteCols: Column<SiteLeader>[] = [
    { key: 'customer_site', label: 'Site' },
    { key: 'city', label: 'City' },
    { key: 'total_inspected', label: 'Inspected' },
    { key: 'total_failed', label: 'Failed' },
    { key: 'failure_rate_pct', label: 'Failure %' },
  ];
  const mixCols: Column<FailureMix>[] = [
    { key: 'failure_mode', label: 'Failure mode' },
    { key: 'audits', label: 'Audits' },
    { key: 'total_failed', label: 'Failed' },
    { key: 'share_pct', label: 'Share %' },
  ];
  const sevCols: Column<Severity>[] = [
    { key: 'severity', label: 'Severity' },
    { key: 'audits', label: 'Audits' },
    { key: 'open_audits', label: 'Open' },
    { key: 'escalated_audits', label: 'Escalated' },
  ];
  const engCols: Column<Engineer>[] = [
    { key: 'engineer_name', label: 'Engineer' },
    { key: 'audits', label: 'Audits' },
    { key: 'sleeves_inspected', label: 'Inspected' },
    { key: 'clean_audits', label: 'Clean audits' },
  ];
  const openCols: Column<OpenAction>[] = [
    { key: 'customer_site', label: 'Site' },
    { key: 'action_type', label: 'Action' },
    { key: 'owner', label: 'Owner' },
    { key: 'due_date', label: 'Due' },
    { key: 'action_status', label: 'Status' },
  ];
  const costCols: Column<CostSummary>[] = [
    { key: 'action_type', label: 'Action' },
    { key: 'actions', label: 'Count' },
    { key: 'total_cost_rupees', label: 'Cost (rupees)' },
    { key: 'closed_actions', label: 'Closed' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">SCD Sleeve Monthly Audit — r3030</h1>
        <p className="text-sm text-gray-600">Monthly customer-site sequential compression device sleeve inspection audit.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly overview</h2>
        <DataTable<MonthlyOverview>
          rows={(monthly.data ?? []) as MonthlyOverview[]}
          columns={monthlyCols}
          emptyMessage="No months"
          rowKey={(r, i) => String(r.audit_month ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Site failure leaderboard</h2>
        <DataTable<SiteLeader>
          rows={(sites.data ?? []) as SiteLeader[]}
          columns={siteCols}
          emptyMessage="No sites"
          rowKey={(r, i) => String(r.customer_site ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Failure mode mix</h2>
        <DataTable<FailureMix>
          rows={(mix.data ?? []) as FailureMix[]}
          columns={mixCols}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.failure_mode ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Severity breakdown</h2>
        <DataTable<Severity>
          rows={(severity.data ?? []) as Severity[]}
          columns={sevCols}
          emptyMessage="No severity rows"
          rowKey={(r, i) => String(r.severity ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer throughput</h2>
        <DataTable<Engineer>
          rows={(engineers.data ?? []) as Engineer[]}
          columns={engCols}
          emptyMessage="No engineers"
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open actions queue</h2>
        <DataTable<OpenAction>
          rows={(openActions.data ?? []) as OpenAction[]}
          columns={openCols}
          emptyMessage="No open actions"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Remediation cost summary</h2>
        <DataTable<CostSummary>
          rows={(cost.data ?? []) as CostSummary[]}
          columns={costCols}
          emptyMessage="No cost rows"
          rowKey={(r, i) => String(r.action_type ?? i)}
        />
      </section>
    </div>
  );
}
