import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  margin_verdict: string;
  jobs: number;
  total_margin_rupees: number;
  pct: number;
};
type HospRow = {
  hospital_name: string;
  jobs: number;
  total_revenue_rupees: number;
  total_payout_rupees: number;
  total_margin_rupees: number;
  avg_margin_pct: number;
  negative_margin_jobs: number;
  avg_take_rate_pct: number;
};
type MatrixRow = {
  job_category: string;
  pricing_model: string;
  jobs: number;
  total_revenue_rupees: number;
  total_margin_rupees: number;
  avg_margin_pct: number;
};
type TrendRow = {
  job_date: string;
  jobs: number;
  total_revenue_rupees: number;
  total_margin_rupees: number;
  avg_margin_pct: number;
  avg_take_rate_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_or_escalated: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type QueueRow = {
  hospital_name: string;
  job_code: string;
  job_date: string;
  job_category: string;
  revenue_rupees: number;
  contribution_margin_rupees: number;
  margin_pct: number;
  margin_verdict: string;
  payment_status: string;
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
    regRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3189_margin_verdict_rollup'),
    supabase.rpc('founder_r3189_hospital_scorecard'),
    supabase.rpc('founder_r3189_category_pricing_matrix'),
    supabase.rpc('founder_r3189_daily_margin_trend'),
    supabase.rpc('founder_r3189_capa_status_board'),
    supabase.rpc('founder_r3189_root_cause_pareto'),
    supabase.rpc('founder_r3189_regulatory_impact_digest'),
    supabase.rpc('founder_r3189_priority_margin_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'margin_verdict', header: 'Verdict' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'total_margin_rupees', header: 'Total Margin (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'total_payout_rupees', header: 'Payout (INR)' },
    { key: 'total_margin_rupees', header: 'Margin (INR)' },
    { key: 'avg_margin_pct', header: 'Avg Margin %' },
    { key: 'negative_margin_jobs', header: 'Negative Jobs' },
    { key: 'avg_take_rate_pct', header: 'Avg Take-Rate %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'job_category', header: 'Category' },
    { key: 'pricing_model', header: 'Pricing Model' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'total_margin_rupees', header: 'Margin (INR)' },
    { key: 'avg_margin_pct', header: 'Avg Margin %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'job_date', header: 'Date' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'total_margin_rupees', header: 'Margin (INR)' },
    { key: 'avg_margin_pct', header: 'Avg Margin %' },
    { key: 'avg_take_rate_pct', header: 'Avg Take-Rate %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_or_escalated', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'job_code', header: 'Job' },
    { key: 'job_date', header: 'Date' },
    { key: 'job_category', header: 'Category' },
    { key: 'revenue_rupees', header: 'Revenue (INR)' },
    { key: 'contribution_margin_rupees', header: 'Margin (INR)' },
    { key: 'margin_pct', header: 'Margin %' },
    { key: 'margin_verdict', header: 'Verdict' },
    { key: 'payment_status', header: 'Payment' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Unit-Economics Per-Job Contribution-Margin Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per-job economics — job category &times; revenue &times; engineer payout &times; parts
        &times; travel &times; platform fee &times; contribution margin &amp; take-rate.
        Founder-gated view: margin verdicts, hospital scorecards, category &times; pricing matrix,
        root-cause pareto, and the priority queue of thin or negative-margin jobs with CAPA closure.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Margin verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No jobs logged yet."
          rowKey={(r, i) => String(r.margin_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital unit-economics scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category &times; pricing model matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No jobs by category."
          rowKey={(r, i) => `${r.job_category}-${r.pricing_model}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily margin trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.job_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Priority margin-risk queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No margin-risk jobs."
          rowKey={(r, i) => `${r.job_code}-${r.job_date}-${i}`}
        />
      </section>
    </main>
  );
}
