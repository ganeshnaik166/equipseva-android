import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { review_verdict: string; reviews: number; pct: number };
type EngRow = {
  engineer_name: string;
  total_reviews: number;
  approved: number;
  needs_rework: number;
  rejected: number;
  rework_flagged: number;
  avg_doc_score: number;
  approval_pct: number;
};
type MatrixRow = {
  job_type: string;
  dsr_completeness: string;
  reviews: number;
  rework_count: number;
  avg_doc_score: number;
};
type TrendRow = {
  review_date: string;
  reviews: number;
  avg_doc_score: number;
  approved: number;
  needs_rework: number;
  rejected: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_flag: number;
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
type RiskRow = {
  hospital_name: string;
  engineer_name: string;
  job_reference: string;
  review_date: string;
  doc_score: number;
  review_verdict: string;
  dsr_completeness: string;
  customer_signature: string;
  rework_required: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    engRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3196_verdict_rollup'),
    supabase.rpc('founder_r3196_engineer_scorecard'),
    supabase.rpc('founder_r3196_job_dsr_matrix'),
    supabase.rpc('founder_r3196_daily_trend'),
    supabase.rpc('founder_r3196_capa_status_board'),
    supabase.rpc('founder_r3196_root_cause_pareto'),
    supabase.rpc('founder_r3196_regulatory_impact_digest'),
    supabase.rpc('founder_r3196_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const engRows: EngRow[] = (engRes.data as EngRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'review_verdict', header: 'Verdict' },
    { key: 'reviews', header: 'Reviews' },
    { key: 'pct', header: 'Share %' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_reviews', header: 'Reviews' },
    { key: 'approved', header: 'Approved' },
    { key: 'needs_rework', header: 'Needs Rework' },
    { key: 'rejected', header: 'Rejected' },
    { key: 'rework_flagged', header: 'Rework Flagged' },
    { key: 'avg_doc_score', header: 'Avg Doc Score' },
    { key: 'approval_pct', header: 'Approval %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'job_type', header: 'Job Type' },
    { key: 'dsr_completeness', header: 'DSR Completeness' },
    { key: 'reviews', header: 'Reviews' },
    { key: 'rework_count', header: 'Rework' },
    { key: 'avg_doc_score', header: 'Avg Doc Score' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'review_date', header: 'Date' },
    { key: 'reviews', header: 'Reviews' },
    { key: 'avg_doc_score', header: 'Avg Doc Score' },
    { key: 'approved', header: 'Approved' },
    { key: 'needs_rework', header: 'Needs Rework' },
    { key: 'rejected', header: 'Rejected' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
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

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'job_reference', header: 'Job Ref' },
    { key: 'review_date', header: 'Date' },
    { key: 'doc_score', header: 'Score' },
    { key: 'review_verdict', header: 'Verdict' },
    { key: 'dsr_completeness', header: 'DSR' },
    { key: 'customer_signature', header: 'Signature' },
    { key: 'rework_required', header: 'Rework' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Documentation-Quality (DSR / Photo / Checklist) Completeness Score Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per-job documentation reviews — DSR completeness &times; before/after photo evidence &times;
        checklist &times; customer signature &times; parts documentation &times; 0-100 doc score &amp;
        CAPA closure. Founder-gated view: verdict rollups, engineer scorecards, root-cause pareto,
        and regulatory-impact digest across NABH &amp; contract-compliance surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Review verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No documentation reviews logged yet."
          rowKey={(r, i) => String(r.review_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer documentation scorecard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Job type &times; DSR completeness matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No reviews by job type."
          rowKey={(r, i) => `${r.job_type}-${r.dsr_completeness}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily doc-score trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.review_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk documentation queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk documentation reviews."
          rowKey={(r, i) => `${r.job_reference}-${r.review_date}-${i}`}
        />
      </section>
    </main>
  );
}
