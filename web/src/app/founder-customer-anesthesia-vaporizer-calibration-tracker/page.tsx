import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { status: string; log_count: number; avg_deviation: number };
type AgentRow = { vaporizer_agent: string; log_count: number; avg_set: number; avg_delivered: number; avg_abs_deviation: number };
type TrendRow = { month_label: string; log_count: number; out_of_tol_count: number; critical_count: number };
type ModelRow = { workstation_model: string; units: number; within_tol: number; out_of_tol: number; critical_units: number; avg_abs_dev: number };
type HotRow = { workstation_serial: string; workstation_model: string; vaporizer_agent: string; deviation_pct: number; status: string; calibrated_at: string };
type CapaRow = { capa_state: string; capa_count: number; total_cost: number };
type RootRow = { root_cause: string; capa_count: number; avg_cost: number };
type DueRow = { workstation_serial: string; workstation_model: string; vaporizer_agent: string; next_due_at: string; days_to_due: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [statusRes, agentRes, trendRes, modelRes, hotRes, capaRes, rootRes, dueRes] = await Promise.all([
    sb.rpc('rpc_r3096_status_summary'),
    sb.rpc('rpc_r3096_agent_breakdown'),
    sb.rpc('rpc_r3096_monthly_trend'),
    sb.rpc('rpc_r3096_model_scorecard'),
    sb.rpc('rpc_r3096_hotlist'),
    sb.rpc('rpc_r3096_capa_summary'),
    sb.rpc('rpc_r3096_root_cause_breakdown'),
    sb.rpc('rpc_r3096_due_soon'),
  ]);

  const statusRows = (statusRes.data ?? []) as StatusRow[];
  const agentRows = (agentRes.data ?? []) as AgentRow[];
  const trendRows = (trendRes.data ?? []) as TrendRow[];
  const modelRows = (modelRes.data ?? []) as ModelRow[];
  const hotRows = (hotRes.data ?? []) as HotRow[];
  const capaRows = (capaRes.data ?? []) as CapaRow[];
  const rootRows = (rootRes.data ?? []) as RootRow[];
  const dueRows = (dueRes.data ?? []) as DueRow[];

  const statusCols: Column<StatusRow>[] = [
    { key: 'status', header: 'Status' },
    { key: 'log_count', header: 'Logs' },
    { key: 'avg_deviation', header: 'Avg |deviation %|' },
  ];

  const agentCols: Column<AgentRow>[] = [
    { key: 'vaporizer_agent', header: 'Agent' },
    { key: 'log_count', header: 'Logs' },
    { key: 'avg_set', header: 'Avg set %' },
    { key: 'avg_delivered', header: 'Avg delivered %' },
    { key: 'avg_abs_deviation', header: 'Avg |dev %|' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'month_label', header: 'Month' },
    { key: 'log_count', header: 'Logs' },
    { key: 'out_of_tol_count', header: 'Out-of-tol' },
    { key: 'critical_count', header: 'Critical' },
  ];

  const modelCols: Column<ModelRow>[] = [
    { key: 'workstation_model', header: 'Model' },
    { key: 'units', header: 'Units' },
    { key: 'within_tol', header: 'Within tol' },
    { key: 'out_of_tol', header: 'Out-of-tol' },
    { key: 'critical_units', header: 'Critical' },
    { key: 'avg_abs_dev', header: 'Avg |dev %|' },
  ];

  const hotCols: Column<HotRow>[] = [
    { key: 'workstation_serial', header: 'Workstation' },
    { key: 'workstation_model', header: 'Model' },
    { key: 'vaporizer_agent', header: 'Agent' },
    { key: 'deviation_pct', header: 'Deviation %' },
    { key: 'status', header: 'Status' },
    { key: 'calibrated_at', header: 'Calibrated' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_state', header: 'CAPA state' },
    { key: 'capa_count', header: 'Open #' },
    { key: 'total_cost', header: 'Total cost (INR)' },
  ];

  const rootCols: Column<RootRow>[] = [
    { key: 'root_cause', header: 'Root cause' },
    { key: 'capa_count', header: 'CAPAs' },
    { key: 'avg_cost', header: 'Avg cost (INR)' },
  ];

  const dueCols: Column<DueRow>[] = [
    { key: 'workstation_serial', header: 'Workstation' },
    { key: 'workstation_model', header: 'Model' },
    { key: 'vaporizer_agent', header: 'Agent' },
    { key: 'next_due_at', header: 'Next due' },
    { key: 'days_to_due', header: 'Days to due' },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700 }}>r3096 — Vaporizer Output Concentration Calibration Tracker</h1>
      <p style={{ color: '#555', marginTop: 6 }}>
        Quarterly engineer-led calibration of anesthesia workstation vaporizers. Status, agent breakdown, monthly trend,
        model scorecard, hotlist, CAPA queue, root-cause analysis, and upcoming due dates. Tolerance band typically
        ±5% delivered vs set; &gt;10% =&gt; critical.
      </p>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600 }}>1. Status summary</h2>
        <DataTable rows={statusRows} columns={statusCols} emptyMessage="No calibration logs." rowKey={(r, i) => String((r as StatusRow).status ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600 }}>2. Agent breakdown</h2>
        <DataTable rows={agentRows} columns={agentCols} emptyMessage="No agent data." rowKey={(r, i) => String((r as AgentRow).vaporizer_agent ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600 }}>3. Monthly trend</h2>
        <DataTable rows={trendRows} columns={trendCols} emptyMessage="No monthly data." rowKey={(r, i) => String((r as TrendRow).month_label ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600 }}>4. Workstation model scorecard</h2>
        <DataTable rows={modelRows} columns={modelCols} emptyMessage="No model data." rowKey={(r, i) => String((r as ModelRow).workstation_model ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600 }}>5. Hotlist (deviation &gt;= tolerance)</h2>
        <DataTable rows={hotRows} columns={hotCols} emptyMessage="No hotlist entries." rowKey={(r, i) => String((r as HotRow).workstation_serial ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600 }}>6. CAPA queue</h2>
        <DataTable rows={capaRows} columns={capaCols} emptyMessage="No CAPA rows." rowKey={(r, i) => String((r as CapaRow).capa_state ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600 }}>7. Root-cause breakdown</h2>
        <DataTable rows={rootRows} columns={rootCols} emptyMessage="No root-cause data." rowKey={(r, i) => String((r as RootRow).root_cause ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600 }}>8. Upcoming due (&lt;= 60 days)</h2>
        <DataTable rows={dueRows} columns={dueCols} emptyMessage="No upcoming calibrations." rowKey={(r, i) => String((r as DueRow).workstation_serial ?? i)} />
      </section>
    </main>
  );
}
