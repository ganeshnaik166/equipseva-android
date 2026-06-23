import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCapTableDilutionProjectionPage() {
  const supabase = await getSupabaseServerClient();

  const [
    scenariosRes,
    employeeImpactRes,
    topDilutedRes,
    scenarioCompareRes,
    retentionSummaryRes,
    ownershipTrajectoryRes,
    esopRefreshRes,
  ] = await Promise.all([
    supabase.rpc('list_scenarios_r2421'),
    supabase.rpc('list_employee_impact_r2421'),
    supabase.rpc('top_diluted_employees_r2421'),
    supabase.rpc('scenario_compare_r2421'),
    supabase.rpc('retention_risk_summary_r2421'),
    supabase.rpc('founder_ownership_trajectory_r2421'),
    supabase.rpc('esop_refresh_summary_r2421'),
  ]);

  const scenarios = scenariosRes.data ?? [];
  const employeeImpact = employeeImpactRes.data ?? [];
  const topDiluted = topDilutedRes.data ?? [];
  const scenarioCompare = scenarioCompareRes.data ?? [];
  const retentionSummary = retentionSummaryRes.data ?? [];
  const ownershipTrajectory = ownershipTrajectoryRes.data ?? [];
  const esopRefresh = esopRefreshRes.data ?? [];

  const fmtCrores = (n: number | null | undefined) =>
    n == null ? '—' : `₹${(Number(n) / 10000000).toFixed(2)} Cr`;
  const fmtPct = (n: number | null | undefined) =>
    n == null ? '—' : `${Number(n).toFixed(2)}%`;
  const fmtDate = (s: string | null | undefined) =>
    s ? new Date(s).toLocaleDateString('en-IN', { year: 'numeric', month: 'short', day: 'numeric' }) : '—';

  const scenarioCols: Column<any>[] = [
    { key: 'scenario_name', header: 'Scenario', render: (r: any) => r.scenario_name },
    { key: 'scenario_kind', header: 'Kind', render: (r: any) => r.scenario_kind },
    { key: 'pre_money', header: 'Pre-money', render: (r: any) => fmtCrores(r.pre_money_rupees) },
    { key: 'raise', header: 'Raise', render: (r: any) => fmtCrores(r.raise_amount_rupees) },
    { key: 'post_money', header: 'Post-money', render: (r: any) => fmtCrores(r.post_money_rupees) },
    { key: 'founder_pre', header: 'Founder Pre', render: (r: any) => fmtPct(r.founder_pre_pct) },
    { key: 'founder_post', header: 'Founder Post', render: (r: any) => fmtPct(r.founder_post_pct) },
    { key: 'esop_refresh', header: 'ESOP Refresh', render: (r: any) => fmtPct(r.esop_refresh_pct) },
    { key: 'lead', header: 'Lead', render: (r: any) => r.lead_investor ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.term_sheet_status },
    { key: 'close', header: 'Expected Close', render: (r: any) => fmtDate(r.expected_close_at) },
  ];

  const employeeCols: Column<any>[] = [
    { key: 'name', header: 'Employee', render: (r: any) => r.employee_name },
    { key: 'email', header: 'Email', render: (r: any) => r.employee_email },
    { key: 'scenario', header: 'Scenario', render: (r: any) => r.scenario_name },
    { key: 'current', header: 'Current Shares', render: (r: any) => Number(r.current_shares).toLocaleString('en-IN') },
    { key: 'post', header: 'Post-Dilution', render: (r: any) => Number(r.post_dilution_shares).toLocaleString('en-IN') },
    { key: 'dilution', header: 'Dilution', render: (r: any) => fmtPct(r.dilution_pct) },
    { key: 'risk', header: 'Risk', render: (r: any) => r.retention_risk },
    { key: 'action', header: 'Action', render: (r: any) => r.retention_action ?? '—' },
  ];

  const topDilutedCols: Column<any>[] = [
    { key: 'name', header: 'Employee', render: (r: any) => r.employee_name },
    { key: 'scenario', header: 'Scenario', render: (r: any) => r.scenario_name },
    { key: 'dilution', header: 'Dilution', render: (r: any) => fmtPct(r.dilution_pct) },
    { key: 'lost', header: 'Shares Lost', render: (r: any) => Number(r.shares_lost).toLocaleString('en-IN') },
    { key: 'risk', header: 'Risk', render: (r: any) => r.retention_risk },
    { key: 'action', header: 'Action', render: (r: any) => r.retention_action ?? '—' },
  ];

  const compareCols: Column<any>[] = [
    { key: 'scenario', header: 'Scenario', render: (r: any) => r.scenario_name },
    { key: 'kind', header: 'Kind', render: (r: any) => r.scenario_kind },
    { key: 'raise', header: 'Raise (Cr)', render: (r: any) => `₹${Number(r.raise_amount_crores).toFixed(2)} Cr` },
    { key: 'post', header: 'Post-money (Cr)', render: (r: any) => `₹${Number(r.post_money_crores).toFixed(2)} Cr` },
    { key: 'dilution', header: 'Founder Dilution', render: (r: any) => fmtPct(r.dilution_pct) },
    { key: 'founder_post', header: 'Founder Post', render: (r: any) => fmtPct(r.founder_post_pct) },
    { key: 'esop', header: 'ESOP Refresh', render: (r: any) => fmtPct(r.esop_refresh_pct) },
    { key: 'status', header: 'Status', render: (r: any) => r.term_sheet_status },
  ];

  const retentionCols: Column<any>[] = [
    { key: 'risk', header: 'Risk Tier', render: (r: any) => r.retention_risk },
    { key: 'count', header: 'Employees', render: (r: any) => Number(r.employee_count) },
    { key: 'avg', header: 'Avg Dilution', render: (r: any) => fmtPct(r.avg_dilution_pct) },
    { key: 'lost', header: 'Total Shares Lost', render: (r: any) => Number(r.total_shares_lost).toLocaleString('en-IN') },
  ];

  const trajectoryCols: Column<any>[] = [
    { key: 'scenario', header: 'Scenario', render: (r: any) => r.scenario_name },
    { key: 'kind', header: 'Kind', render: (r: any) => r.scenario_kind },
    { key: 'close', header: 'Expected Close', render: (r: any) => fmtDate(r.expected_close_at) },
    { key: 'pre', header: 'Founder Pre', render: (r: any) => fmtPct(r.founder_pre_pct) },
    { key: 'post', header: 'Founder Post', render: (r: any) => fmtPct(r.founder_post_pct) },
    { key: 'delta', header: 'Delta', render: (r: any) => fmtPct(r.delta_pct) },
    { key: 'status', header: 'Status', render: (r: any) => r.term_sheet_status },
  ];

  const refreshCols: Column<any>[] = [
    { key: 'kind', header: 'Scenario Kind', render: (r: any) => r.scenario_kind },
    { key: 'count', header: 'Scenarios', render: (r: any) => Number(r.scenario_count) },
    { key: 'avg', header: 'Avg ESOP Refresh', render: (r: any) => fmtPct(r.avg_refresh_pct) },
    { key: 'total', header: 'Total Raise', render: (r: any) => `₹${Number(r.total_raise_crores).toFixed(2)} Cr` },
    { key: 'emp', header: 'Avg Employee Dilution', render: (r: any) => fmtPct(r.avg_employee_dilution_pct) },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-bold">Cap Table & Dilution Projection</h1>
        <p className="text-sm text-gray-600 mt-1">
          Round-by-round modelling — pre/post money, founder ownership, ESOP refresh & employee impact.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">Scenarios</h2>
        <DataTable
          rows={scenarios}
          columns={scenarioCols}
          emptyMessage="No scenarios modelled yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Scenario Comparison</h2>
        <DataTable
          rows={scenarioCompare}
          columns={compareCols}
          emptyMessage="No scenarios to compare."
          rowKey={(r: any, i: number) => String(r.scenario_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Founder Ownership Trajectory</h2>
        <DataTable
          rows={ownershipTrajectory}
          columns={trajectoryCols}
          emptyMessage="No trajectory data."
          rowKey={(r: any, i: number) => String(r.scenario_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">ESOP Refresh Summary by Round Kind</h2>
        <DataTable
          rows={esopRefresh}
          columns={refreshCols}
          emptyMessage="No ESOP data."
          rowKey={(r: any, i: number) => String(r.scenario_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Employee Impact</h2>
        <DataTable
          rows={employeeImpact}
          columns={employeeCols}
          emptyMessage="No employee impact modelled."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top Diluted Employees</h2>
        <DataTable
          rows={topDiluted}
          columns={topDilutedCols}
          emptyMessage="No employees diluted > threshold."
          rowKey={(r: any, i: number) => String(r.employee_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Retention Risk Summary</h2>
        <DataTable
          rows={retentionSummary}
          columns={retentionCols}
          emptyMessage="No retention risk data."
          rowKey={(r: any, i: number) => String(r.retention_risk ?? i)}
        />
      </section>
    </div>
  );
}
