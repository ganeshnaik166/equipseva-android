import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { cycle_status: string; cycles: number; pct: number };
type FunctionRow = {
  requesting_function: string;
  total_cycles: number;
  on_track: number;
  slow: number;
  bottlenecked: number;
  broken: number;
  avg_total_cycle_days: number;
  avg_three_way_match_pass_pct: number;
};
type MatrixRow = {
  stage_class: string;
  cycle_status: string;
  cycles: number;
  avg_total_cycle_days: number;
};
type TrendRow = {
  period_month: string;
  cycles: number;
  avg_total_cycle_days: number;
  avg_po_to_grn_days: number;
  emergency_pos: number;
  avg_three_way_match_pass_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_impact_rupees: number;
  pct: number;
};
type BottleneckRow = {
  category: string;
  cycles: number;
  bottlenecked: number;
  broken: number;
  avg_po_to_grn_days: number;
  avg_grn_to_invoice_match_days: number;
};
type RiskRow = {
  category: string;
  requesting_function: string;
  cycle_ref: string;
  period_month: string;
  stage_class: string;
  cycle_status: string;
  total_cycle_days: number;
  target_cycle_days: number;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    functionRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    bottleneckRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3715_cycle_status_rollup'),
    supabase.rpc('founder_r3715_function_scorecard'),
    supabase.rpc('founder_r3715_stage_cycle_matrix'),
    supabase.rpc('founder_r3715_monthly_cycle_trend'),
    supabase.rpc('founder_r3715_capa_status_board'),
    supabase.rpc('founder_r3715_root_cause_pareto'),
    supabase.rpc('founder_r3715_bottleneck_digest'),
    supabase.rpc('founder_r3715_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const functionRows: FunctionRow[] = (functionRes.data as FunctionRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const bottleneckRows: BottleneckRow[] = (bottleneckRes.data as BottleneckRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'cycle_status', header: 'Cycle Status' },
    { key: 'cycles', header: 'Cycles' },
    { key: 'pct', header: 'Share %' },
  ];

  const functionCols: Column<FunctionRow>[] = [
    { key: 'requesting_function', header: 'Function' },
    { key: 'total_cycles', header: 'Cycles' },
    { key: 'on_track', header: 'On Track' },
    { key: 'slow', header: 'Slow' },
    { key: 'bottlenecked', header: 'Bottlenecked' },
    { key: 'broken', header: 'Broken' },
    { key: 'avg_total_cycle_days', header: 'Avg Cycle Days' },
    { key: 'avg_three_way_match_pass_pct', header: '3-Way Match %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'stage_class', header: 'Stage' },
    { key: 'cycle_status', header: 'Status' },
    { key: 'cycles', header: 'Cycles' },
    { key: 'avg_total_cycle_days', header: 'Avg Cycle Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'cycles', header: 'Cycles' },
    { key: 'avg_total_cycle_days', header: 'Avg Cycle Days' },
    { key: 'avg_po_to_grn_days', header: 'Avg PO->GRN Days' },
    { key: 'emergency_pos', header: 'Emergency POs' },
    { key: 'avg_three_way_match_pass_pct', header: '3-Way Match %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_impact_rupees', header: 'Avg Cost Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_impact_rupees', header: 'Total Cost Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const bottleneckCols: Column<BottleneckRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'cycles', header: 'Cycles' },
    { key: 'bottlenecked', header: 'Bottlenecked' },
    { key: 'broken', header: 'Broken' },
    { key: 'avg_po_to_grn_days', header: 'Avg PO->GRN Days' },
    { key: 'avg_grn_to_invoice_match_days', header: 'Avg GRN->Match Days' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'requesting_function', header: 'Function' },
    { key: 'cycle_ref', header: 'Cycle Ref' },
    { key: 'period_month', header: 'Month' },
    { key: 'stage_class', header: 'Stage' },
    { key: 'cycle_status', header: 'Status' },
    { key: 'total_cycle_days', header: 'Total Days' },
    { key: 'target_cycle_days', header: 'Target Days' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Procure-to-Pay Requisition&rarr;PO&rarr;GRN Cycle-Time Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        P2P cycle-time log — category &times; requesting function &times; requisition-to-approval
        &times; approval-to-PO &times; PO-to-GRN &times; GRN-to-invoice-match stage days &times;
        target cycle days &times; emergency POs &times; three-way-match pass rate &amp; CAPA
        closure. Founder-gated view: cycle-status rollups, function scorecards, root-cause pareto,
        and bottleneck digests across the requisition&ndash;PO&ndash;GRN&ndash;payment chain.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Cycle status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No P2P cycles logged yet."
          rowKey={(r, i) => String(r.cycle_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Requesting-function scorecard</h2>
        <DataTable
          rows={functionRows}
          columns={functionCols}
          emptyMessage="No function rollups."
          rowKey={(r, i) => String(r.requesting_function ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Stage &times; cycle status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No cycles by stage."
          rowKey={(r, i) => `${r.stage_class}-${r.cycle_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly cycle trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA findings."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Bottleneck digest</h2>
        <DataTable
          rows={bottleneckRows}
          columns={bottleneckCols}
          emptyMessage="No bottleneck rollups."
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk cycle queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk cycles."
          rowKey={(r, i) => `${r.cycle_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
