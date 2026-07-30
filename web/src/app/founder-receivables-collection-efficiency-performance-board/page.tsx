import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { collection_status: string; lines: number; pct: number };
type SegRow = {
  customer_segment: string;
  lines: number;
  total_billed_rupees: number;
  total_collected_rupees: number;
  avg_collection_efficiency_pct: number;
  total_overdue_rupees: number;
  avg_dso_days: number;
  avg_promises_kept_pct: number;
};
type MatrixRow = {
  customer_segment: string;
  collection_status: string;
  lines: number;
  total_billed_rupees: number;
  total_overdue_rupees: number;
};
type TrendRow = {
  period_month: string;
  lines: number;
  total_billed_rupees: number;
  total_collected_rupees: number;
  avg_collection_efficiency_pct: number;
  total_overdue_rupees: number;
  avg_dso_days: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  total_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type OverdueRow = {
  customer_segment: string;
  lines: number;
  total_overdue_rupees: number;
  avg_overdue_pct: number;
  high_risk_lines: number;
};
type RiskRow = {
  customer_segment: string;
  collection_ref: string;
  period_month: string;
  collection_status: string;
  collection_efficiency_pct: number | null;
  overdue_rupees: number | null;
  overdue_pct: number | null;
  dso_days: number | null;
  promises_kept_pct: number | null;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    segRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    overdueRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3604_collection_status_rollup'),
    supabase.rpc('founder_r3604_segment_scorecard'),
    supabase.rpc('founder_r3604_segment_status_matrix'),
    supabase.rpc('founder_r3604_monthly_efficiency_trend'),
    supabase.rpc('founder_r3604_capa_status_board'),
    supabase.rpc('founder_r3604_root_cause_pareto'),
    supabase.rpc('founder_r3604_overdue_impact_digest'),
    supabase.rpc('founder_r3604_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const segRows: SegRow[] = (segRes.data as SegRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const overdueRows: OverdueRow[] = (overdueRes.data as OverdueRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'collection_status', header: 'Collection Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'pct', header: 'Share %' },
  ];

  const segCols: Column<SegRow>[] = [
    { key: 'customer_segment', header: 'Segment' },
    { key: 'lines', header: 'Lines' },
    { key: 'total_billed_rupees', header: 'Billed (INR)' },
    { key: 'total_collected_rupees', header: 'Collected (INR)' },
    { key: 'avg_collection_efficiency_pct', header: 'Avg Efficiency %' },
    { key: 'total_overdue_rupees', header: 'Overdue (INR)' },
    { key: 'avg_dso_days', header: 'Avg DSO Days' },
    { key: 'avg_promises_kept_pct', header: 'Avg Promises Kept %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'customer_segment', header: 'Segment' },
    { key: 'collection_status', header: 'Collection Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'total_billed_rupees', header: 'Billed (INR)' },
    { key: 'total_overdue_rupees', header: 'Overdue (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'lines', header: 'Lines' },
    { key: 'total_billed_rupees', header: 'Billed (INR)' },
    { key: 'total_collected_rupees', header: 'Collected (INR)' },
    { key: 'avg_collection_efficiency_pct', header: 'Avg Efficiency %' },
    { key: 'total_overdue_rupees', header: 'Overdue (INR)' },
    { key: 'avg_dso_days', header: 'Avg DSO Days' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'total_impact_rupees', header: 'Impact Value (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Impact Value (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const overdueCols: Column<OverdueRow>[] = [
    { key: 'customer_segment', header: 'Segment' },
    { key: 'lines', header: 'Lines' },
    { key: 'total_overdue_rupees', header: 'Overdue (INR)' },
    { key: 'avg_overdue_pct', header: 'Avg Overdue %' },
    { key: 'high_risk_lines', header: 'Poor / Critical Lines' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'customer_segment', header: 'Segment' },
    { key: 'collection_ref', header: 'Ref' },
    { key: 'period_month', header: 'Month' },
    { key: 'collection_status', header: 'Status' },
    { key: 'collection_efficiency_pct', header: 'Efficiency %' },
    { key: 'overdue_rupees', header: 'Overdue (INR)' },
    { key: 'overdue_pct', header: 'Overdue %' },
    { key: 'dso_days', header: 'DSO Days' },
    { key: 'promises_kept_pct', header: 'Promises Kept %' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Receivables Collection-Efficiency Performance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated receivables view — customer segment (AMC services, spare parts, projects,
        diagnostics, rentals, government &amp; private hospitals, corporate accounts) &times; period
        &times; billed vs collected &times; collection-efficiency % &times; opening / closing
        receivables &times; overdue &amp; overdue % &times; DSO days &times; promises-kept % &times;
        collection status &amp; trend, with CAPA recovery-action closure. Rollups cover status
        distribution, segment scorecards, root-cause pareto, and the overdue-impact digest across the
        book.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Collection-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No collection lines logged yet."
          rowKey={(r, i) => String(r.collection_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Customer-segment scorecard</h2>
        <DataTable
          rows={segRows}
          columns={segCols}
          emptyMessage="No segment rollups."
          rowKey={(r, i) => String(r.customer_segment ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Segment &times; collection-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No lines by segment."
          rowKey={(r, i) => `${r.customer_segment}-${r.collection_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly collection-efficiency trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Overdue-impact digest</h2>
        <DataTable
          rows={overdueRows}
          columns={overdueCols}
          emptyMessage="No overdue-impact rollups."
          rowKey={(r, i) => String(r.customer_segment ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk collection queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk lines."
          rowKey={(r, i) => `${r.collection_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
