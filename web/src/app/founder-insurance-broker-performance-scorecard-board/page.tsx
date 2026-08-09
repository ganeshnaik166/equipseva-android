import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { performance_status: string; scorecards: number; pct: number };
type BrokerRow = {
  broker_name: string;
  scorecards: number;
  policies_placed: number;
  avg_placement_tat_days: number;
  avg_renewals_on_time_pct: number;
  avg_claim_support_score: number;
  avg_benchmark_variance_pct: number;
  service_issues: number;
  healthy_pct: number;
};
type MatrixRow = {
  lob_class: string;
  performance_status: string;
  scorecards: number;
  policies_placed: number;
  avg_placement_tat_days: number;
};
type TrendRow = {
  period_month: string;
  scorecards: number;
  policies_placed: number;
  avg_placement_tat_days: number;
  avg_endorsements_tat_days: number;
  service_issues: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_premium_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_premium_impact_rupees: number;
  pct: number;
};
type VarianceRow = {
  lob_class: string;
  scorecards: number;
  avg_benchmark_variance_pct: number;
  worst_benchmark_variance_pct: number;
  avg_renewals_on_time_pct: number;
  service_issues: number;
};
type RiskRow = {
  broker_name: string;
  scorecard_code: string;
  line_of_business: string;
  period_month: string;
  lob_class: string;
  performance_status: string;
  trend_dir: string;
  placement_tat_days: number | null;
  premium_benchmark_variance_pct: number | null;
  service_issues: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    brokerRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    varianceRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3708_performance_status_rollup'),
    supabase.rpc('founder_r3708_broker_scorecard'),
    supabase.rpc('founder_r3708_lob_status_matrix'),
    supabase.rpc('founder_r3708_monthly_tat_trend'),
    supabase.rpc('founder_r3708_capa_status_board'),
    supabase.rpc('founder_r3708_root_cause_pareto'),
    supabase.rpc('founder_r3708_benchmark_variance_digest'),
    supabase.rpc('founder_r3708_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const brokerRows: BrokerRow[] = (brokerRes.data as BrokerRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const varianceRows: VarianceRow[] = (varianceRes.data as VarianceRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'performance_status', header: 'Performance Status' },
    { key: 'scorecards', header: 'Scorecards' },
    { key: 'pct', header: 'Share %' },
  ];

  const brokerCols: Column<BrokerRow>[] = [
    { key: 'broker_name', header: 'Broker' },
    { key: 'scorecards', header: 'Scorecards' },
    { key: 'policies_placed', header: 'Policies Placed' },
    { key: 'avg_placement_tat_days', header: 'Avg Placement TAT (d)' },
    { key: 'avg_renewals_on_time_pct', header: 'Renewals On-Time %' },
    { key: 'avg_claim_support_score', header: 'Claims Support Score' },
    { key: 'avg_benchmark_variance_pct', header: 'Benchmark Var %' },
    { key: 'service_issues', header: 'Service Issues' },
    { key: 'healthy_pct', header: 'Healthy %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'lob_class', header: 'LOB Class' },
    { key: 'performance_status', header: 'Status' },
    { key: 'scorecards', header: 'Scorecards' },
    { key: 'policies_placed', header: 'Policies Placed' },
    { key: 'avg_placement_tat_days', header: 'Avg Placement TAT (d)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'scorecards', header: 'Scorecards' },
    { key: 'policies_placed', header: 'Policies Placed' },
    { key: 'avg_placement_tat_days', header: 'Avg Placement TAT (d)' },
    { key: 'avg_endorsements_tat_days', header: 'Avg Endorsement TAT (d)' },
    { key: 'service_issues', header: 'Service Issues' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_premium_impact_rupees', header: 'Avg Premium Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_premium_impact_rupees', header: 'Total Premium Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const varianceCols: Column<VarianceRow>[] = [
    { key: 'lob_class', header: 'LOB Class' },
    { key: 'scorecards', header: 'Scorecards' },
    { key: 'avg_benchmark_variance_pct', header: 'Avg Benchmark Var %' },
    { key: 'worst_benchmark_variance_pct', header: 'Worst Benchmark Var %' },
    { key: 'avg_renewals_on_time_pct', header: 'Renewals On-Time %' },
    { key: 'service_issues', header: 'Service Issues' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'broker_name', header: 'Broker' },
    { key: 'scorecard_code', header: 'Scorecard' },
    { key: 'line_of_business', header: 'Line of Business' },
    { key: 'period_month', header: 'Month' },
    { key: 'lob_class', header: 'LOB Class' },
    { key: 'performance_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'placement_tat_days', header: 'Placement TAT (d)' },
    { key: 'premium_benchmark_variance_pct', header: 'Benchmark Var %' },
    { key: 'service_issues', header: 'Service Issues' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Insurance-Broker Performance Scorecard Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Insurance-broker service quality — broker &times; line of business (asset &amp; property,
        liability, marine transit, employee health, cyber) &times; placement TAT &times; renewals
        on time &times; claims settlement support &times; premium benchmark variance &times;
        endorsement TAT &times; service issues &amp; CAPA closure. Founder-gated view: status
        distribution, broker scorecards, LOB &times; status matrix, monthly TAT trends,
        root-cause pareto, benchmark-variance digest, and the review-replacement queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Performance status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No broker scorecards logged yet."
          rowKey={(r, i) => String(r.performance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Broker performance scorecard</h2>
        <DataTable
          rows={brokerRows}
          columns={brokerCols}
          emptyMessage="No broker rollups."
          rowKey={(r, i) => String(r.broker_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. LOB class &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No scorecards by LOB class."
          rowKey={(r, i) => `${r.lob_class}-${r.performance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly TAT trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Benchmark-variance digest</h2>
        <DataTable
          rows={varianceRows}
          columns={varianceCols}
          emptyMessage="No benchmark-variance rollups."
          rowKey={(r, i) => String(r.lob_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk broker queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk scorecards."
          rowKey={(r, i) => `${r.scorecard_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
