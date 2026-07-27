import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { absorption_status: string; lines: number; pct: number };
type ScorecardRow = {
  cost_center: string;
  total_lines: number;
  over_absorbed: number;
  fully_absorbed: number;
  under_absorbed: number;
  severely_under: number;
  avg_absorption_rate_pct: number;
  avg_capacity_utilization_pct: number;
  net_over_under_rupees: number;
};
type MatrixRow = {
  cost_center: string;
  absorption_status: string;
  lines: number;
  avg_absorption_rate_pct: number;
  net_over_under_rupees: number;
};
type TrendRow = {
  period_month: string;
  lines: number;
  applied_overhead_rupees: number;
  absorbed_rupees: number;
  net_over_under_rupees: number;
  avg_capacity_utilization_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type DigestRow = {
  absorption_status: string;
  lines: number;
  applied_overhead_rupees: number;
  absorbed_rupees: number;
  net_over_under_rupees: number;
  avg_absorption_rate_pct: number;
};
type RiskRow = {
  cost_center: string;
  line_ref: string;
  period_month: string;
  absorption_status: string;
  absorption_rate_pct: number | null;
  capacity_utilization_pct: number | null;
  over_under_absorbed_rupees: number | null;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    scorecardRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3489_absorption_status_rollup'),
    supabase.rpc('founder_r3489_cost_center_scorecard'),
    supabase.rpc('founder_r3489_cost_center_status_matrix'),
    supabase.rpc('founder_r3489_monthly_absorption_trend'),
    supabase.rpc('founder_r3489_capa_status_board'),
    supabase.rpc('founder_r3489_root_cause_pareto'),
    supabase.rpc('founder_r3489_over_under_impact_digest'),
    supabase.rpc('founder_r3489_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const scorecardRows: ScorecardRow[] = (scorecardRes.data as ScorecardRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'absorption_status', header: 'Absorption Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'pct', header: 'Share %' },
  ];

  const scorecardCols: Column<ScorecardRow>[] = [
    { key: 'cost_center', header: 'Cost Center' },
    { key: 'total_lines', header: 'Lines' },
    { key: 'over_absorbed', header: 'Over' },
    { key: 'fully_absorbed', header: 'Full' },
    { key: 'under_absorbed', header: 'Under' },
    { key: 'severely_under', header: 'Severe' },
    { key: 'avg_absorption_rate_pct', header: 'Avg Rate %' },
    { key: 'avg_capacity_utilization_pct', header: 'Avg Cap %' },
    { key: 'net_over_under_rupees', header: 'Net Over/Under (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'cost_center', header: 'Cost Center' },
    { key: 'absorption_status', header: 'Absorption Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'avg_absorption_rate_pct', header: 'Avg Rate %' },
    { key: 'net_over_under_rupees', header: 'Net Over/Under (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'lines', header: 'Lines' },
    { key: 'applied_overhead_rupees', header: 'Applied (INR)' },
    { key: 'absorbed_rupees', header: 'Absorbed (INR)' },
    { key: 'net_over_under_rupees', header: 'Net Over/Under (INR)' },
    { key: 'avg_capacity_utilization_pct', header: 'Avg Cap %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_impact_rupees', header: 'Avg Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'absorption_status', header: 'Absorption Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'applied_overhead_rupees', header: 'Applied (INR)' },
    { key: 'absorbed_rupees', header: 'Absorbed (INR)' },
    { key: 'net_over_under_rupees', header: 'Net Over/Under (INR)' },
    { key: 'avg_absorption_rate_pct', header: 'Avg Rate %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'cost_center', header: 'Cost Center' },
    { key: 'line_ref', header: 'Line Ref' },
    { key: 'period_month', header: 'Month' },
    { key: 'absorption_status', header: 'Status' },
    { key: 'absorption_rate_pct', header: 'Rate %' },
    { key: 'capacity_utilization_pct', header: 'Cap %' },
    { key: 'over_under_absorbed_rupees', header: 'Over/Under (INR)' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Fixed-Cost-Absorption / Overhead-Recovery Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated fixed-cost absorption &amp; overhead-recovery view &mdash; cost center &times;
        period month &times; fixed-cost pool &times; allocation base &times; applied overhead &times;
        absorbed rupees &times; over/under-absorbed &times; absorption rate &times; capacity
        utilization &times; trend direction &amp; CAPA closure. Surfaces absorption-status
        distribution, cost-center scorecards, root-cause pareto, and the severely-under &amp;
        worsening high-risk queue across EquipSeva service cost centers.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Absorption status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No absorption lines logged yet."
          rowKey={(r, i) => String(r.absorption_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Cost-center scorecard</h2>
        <DataTable
          rows={scorecardRows}
          columns={scorecardCols}
          emptyMessage="No cost-center rollups."
          rowKey={(r, i) => String(r.cost_center ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Cost center &times; absorption-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.cost_center}-${r.absorption_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly absorption trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Over/under-absorbed impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No impact-digest rollups."
          rowKey={(r, i) => String(r.absorption_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk absorption queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk lines."
          rowKey={(r, i) => `${r.line_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
