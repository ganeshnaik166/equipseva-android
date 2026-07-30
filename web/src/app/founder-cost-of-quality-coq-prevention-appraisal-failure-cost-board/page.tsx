import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { coq_status: string; records: number; total_coq_rupees: number; pct: number };
type BuRow = {
  business_unit: string;
  records: number;
  total_prevention_rupees: number;
  total_appraisal_rupees: number;
  total_internal_failure_rupees: number;
  total_external_failure_rupees: number;
  total_coq_rupees: number;
  avg_coq_pct_revenue: number;
};
type MatrixRow = {
  business_unit: string;
  coq_status: string;
  records: number;
  total_coq_rupees: number;
  avg_coq_pct_revenue: number;
};
type TrendRow = {
  period_month: string;
  records: number;
  total_coq_rupees: number;
  prevention_rupees: number;
  appraisal_rupees: number;
  internal_failure_rupees: number;
  external_failure_rupees: number;
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
  business_unit: string;
  records: number;
  total_internal_failure_rupees: number;
  total_external_failure_rupees: number;
  total_copq_rupees: number;
  total_cogq_rupees: number;
  copq_share_pct: number;
};
type RiskRow = {
  business_unit: string;
  coq_code: string;
  period_month: string;
  total_coq_rupees: number;
  coq_as_pct_revenue: number | null;
  target_coq_pct: number | null;
  cost_of_poor_quality_rupees: number | null;
  coq_status: string;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    buRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3607_coq_status_rollup'),
    supabase.rpc('founder_r3607_business_unit_scorecard'),
    supabase.rpc('founder_r3607_bu_status_matrix'),
    supabase.rpc('founder_r3607_monthly_coq_trend'),
    supabase.rpc('founder_r3607_capa_status_board'),
    supabase.rpc('founder_r3607_root_cause_pareto'),
    supabase.rpc('founder_r3607_poor_quality_cost_digest'),
    supabase.rpc('founder_r3607_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const buRows: BuRow[] = (buRes.data as BuRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'coq_status', header: 'COQ Status' },
    { key: 'records', header: 'Records' },
    { key: 'total_coq_rupees', header: 'Total COQ (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const buCols: Column<BuRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'records', header: 'Records' },
    { key: 'total_prevention_rupees', header: 'Prevention (INR)' },
    { key: 'total_appraisal_rupees', header: 'Appraisal (INR)' },
    { key: 'total_internal_failure_rupees', header: 'Internal Failure (INR)' },
    { key: 'total_external_failure_rupees', header: 'External Failure (INR)' },
    { key: 'total_coq_rupees', header: 'Total COQ (INR)' },
    { key: 'avg_coq_pct_revenue', header: 'Avg COQ % Rev' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'coq_status', header: 'COQ Status' },
    { key: 'records', header: 'Records' },
    { key: 'total_coq_rupees', header: 'Total COQ (INR)' },
    { key: 'avg_coq_pct_revenue', header: 'Avg COQ % Rev' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'total_coq_rupees', header: 'Total COQ (INR)' },
    { key: 'prevention_rupees', header: 'Prevention (INR)' },
    { key: 'appraisal_rupees', header: 'Appraisal (INR)' },
    { key: 'internal_failure_rupees', header: 'Internal Failure (INR)' },
    { key: 'external_failure_rupees', header: 'External Failure (INR)' },
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
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'records', header: 'Records' },
    { key: 'total_internal_failure_rupees', header: 'Internal Failure (INR)' },
    { key: 'total_external_failure_rupees', header: 'External Failure (INR)' },
    { key: 'total_copq_rupees', header: 'COPQ (INR)' },
    { key: 'total_cogq_rupees', header: 'COGQ (INR)' },
    { key: 'copq_share_pct', header: 'COPQ Share %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'coq_code', header: 'COQ Code' },
    { key: 'period_month', header: 'Month' },
    { key: 'total_coq_rupees', header: 'Total COQ (INR)' },
    { key: 'coq_as_pct_revenue', header: 'COQ % Rev' },
    { key: 'target_coq_pct', header: 'Target %' },
    { key: 'cost_of_poor_quality_rupees', header: 'COPQ (INR)' },
    { key: 'coq_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Cost of Quality (COQ) &mdash; Prevention / Appraisal / Failure Cost Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder cost-of-quality ledger across business units (AMC services, spare parts, projects,
        diagnostics, rentals) &times; month &times; the four COQ buckets &mdash; prevention &amp;
        appraisal (cost of good quality) versus internal-failure &amp; external-failure (cost of poor
        quality) &mdash; with total COQ (INR), COQ as a percentage of revenue against target, and CAPA
        closure. Founder-gated view: COQ-status distribution, business-unit scorecards, root-cause
        pareto, poor-quality-cost digest, and a failure-heavy &amp; critical high-risk queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. COQ status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No COQ records logged yet."
          rowKey={(r, i) => String(r.coq_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-unit scorecard</h2>
        <DataTable
          rows={buRows}
          columns={buCols}
          emptyMessage="No business-unit rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Business unit &times; COQ status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.business_unit}-${r.coq_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly COQ trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Poor-quality-cost digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No poor-quality-cost rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk COQ queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No failure-heavy or critical records."
          rowKey={(r, i) => `${r.coq_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
