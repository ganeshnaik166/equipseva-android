import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  o2c_verdict: string;
  entries: number;
  total_billable_rupees: number;
  total_outstanding_rupees: number;
  pct: number;
};
type HospRow = {
  hospital_name: string;
  periods: number;
  jobs_completed: number;
  billable_value_rupees: number;
  invoiced_value_rupees: number;
  unbilled_value_rupees: number;
  collected_value_rupees: number;
  outstanding_value_rupees: number;
  avg_dso_days: number;
};
type MatrixRow = {
  revenue_segment: string;
  period_month: string;
  entries: number;
  billable_value_rupees: number;
  unbilled_value_rupees: number;
  outstanding_value_rupees: number;
  avg_invoice_lag_days: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  billable_value_rupees: number;
  invoiced_value_rupees: number;
  collected_value_rupees: number;
  unbilled_value_rupees: number;
  outstanding_value_rupees: number;
  avg_dso_days: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_recovery_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_recovery_rupees: number;
  pct: number;
};
type ImpactRow = {
  revenue_impact: string;
  findings: number;
  open_findings: number;
  total_recovery_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  revenue_segment: string;
  period_month: string;
  unbilled_value_rupees: number;
  outstanding_value_rupees: number;
  dso_days: number;
  disputed_value_rupees: number;
  o2c_stage_bottleneck: string;
  o2c_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3345_o2c_verdict_rollup'),
    supabase.rpc('founder_r3345_hospital_scorecard'),
    supabase.rpc('founder_r3345_segment_period_matrix'),
    supabase.rpc('founder_r3345_period_trend'),
    supabase.rpc('founder_r3345_capa_status_board'),
    supabase.rpc('founder_r3345_root_cause_pareto'),
    supabase.rpc('founder_r3345_revenue_impact_digest'),
    supabase.rpc('founder_r3345_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'o2c_verdict', header: 'O2C Verdict' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_billable_rupees', header: 'Billable (INR)' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'periods', header: 'Periods' },
    { key: 'jobs_completed', header: 'Jobs Done' },
    { key: 'billable_value_rupees', header: 'Billable (INR)' },
    { key: 'invoiced_value_rupees', header: 'Invoiced (INR)' },
    { key: 'unbilled_value_rupees', header: 'Unbilled (INR)' },
    { key: 'collected_value_rupees', header: 'Collected (INR)' },
    { key: 'outstanding_value_rupees', header: 'Outstanding (INR)' },
    { key: 'avg_dso_days', header: 'Avg DSO Days' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'revenue_segment', header: 'Revenue Segment' },
    { key: 'period_month', header: 'Period' },
    { key: 'entries', header: 'Entries' },
    { key: 'billable_value_rupees', header: 'Billable (INR)' },
    { key: 'unbilled_value_rupees', header: 'Unbilled (INR)' },
    { key: 'outstanding_value_rupees', header: 'Outstanding (INR)' },
    { key: 'avg_invoice_lag_days', header: 'Avg Invoice Lag Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'entries', header: 'Entries' },
    { key: 'billable_value_rupees', header: 'Billable (INR)' },
    { key: 'invoiced_value_rupees', header: 'Invoiced (INR)' },
    { key: 'collected_value_rupees', header: 'Collected (INR)' },
    { key: 'unbilled_value_rupees', header: 'Unbilled (INR)' },
    { key: 'outstanding_value_rupees', header: 'Outstanding (INR)' },
    { key: 'avg_dso_days', header: 'Avg DSO Days' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_recovery_rupees', header: 'Avg Recovery (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_recovery_rupees', header: 'Total Recovery (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'revenue_impact', header: 'Revenue Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_recovery_rupees', header: 'Total Recovery (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'revenue_segment', header: 'Segment' },
    { key: 'period_month', header: 'Period' },
    { key: 'unbilled_value_rupees', header: 'Unbilled (INR)' },
    { key: 'outstanding_value_rupees', header: 'Outstanding (INR)' },
    { key: 'dso_days', header: 'DSO Days' },
    { key: 'disputed_value_rupees', header: 'Disputed (INR)' },
    { key: 'o2c_stage_bottleneck', header: 'Bottleneck' },
    { key: 'o2c_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Order-to-Cash, Unbilled-Revenue &amp; Invoice-to-Collection Governance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        O2C revenue log — hospital &times; revenue segment &times; period &times; jobs completed
        &times; billable value &times; invoiced &times; unbilled &times; invoice lag &times; collected
        &times; outstanding &times; DSO &times; disputed &times; stage bottleneck &times; O2C verdict
        &amp; CAPA closure. Founder-gated view: verdict rollups, hospital scorecards, segment &times;
        period matrix, root-cause pareto, and revenue-impact digest surfacing unbilled work and
        collection delays.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. O2C verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No O2C revenue rows logged yet."
          rowKey={(r, i) => String(r.o2c_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital O2C scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Revenue segment &times; period matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No rows by segment."
          rowKey={(r, i) => `${r.revenue_segment}-${r.period_month}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Period trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Revenue impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No revenue-impact rollups."
          rowKey={(r, i) => String(r.revenue_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk O2C queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk O2C rows."
          rowKey={(r, i) => `${r.hospital_name}-${r.revenue_segment}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
