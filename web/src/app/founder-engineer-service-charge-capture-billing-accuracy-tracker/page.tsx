import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { capture_verdict: string; jobs: number; pct: number };
type EngineerRow = {
  engineer_name: string;
  total_jobs: number;
  accurate: number;
  minor_leak: number;
  major_leak: number;
  not_invoiced: number;
  total_gap_rupees: number;
  accuracy_pct: number;
};
type MatrixRow = {
  service_type: string;
  contract_coverage: string;
  jobs: number;
  accurate: number;
  total_gap_rupees: number;
  avg_gap_rupees: number;
};
type TrendRow = {
  job_close_date: string;
  jobs: number;
  accurate: number;
  leaks: number;
  not_invoiced: number;
  total_gap_rupees: number;
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
type RevRow = {
  revenue_impact: string;
  findings: number;
  open_findings: number;
  total_recovery_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  region: string;
  job_code: string;
  service_type: string;
  job_close_date: string;
  contract_coverage: string;
  capture_verdict: string;
  gap_reason: string | null;
  billing_gap_rupees: number | null;
  invoice_raised: boolean | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    engineerRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    revRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3280_capture_verdict_rollup'),
    supabase.rpc('founder_r3280_engineer_scorecard'),
    supabase.rpc('founder_r3280_service_coverage_matrix'),
    supabase.rpc('founder_r3280_daily_billing_trend'),
    supabase.rpc('founder_r3280_capa_status_board'),
    supabase.rpc('founder_r3280_root_cause_pareto'),
    supabase.rpc('founder_r3280_revenue_impact_digest'),
    supabase.rpc('founder_r3280_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const engineerRows: EngineerRow[] = (engineerRes.data as EngineerRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const revRows: RevRow[] = (revRes.data as RevRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'capture_verdict', header: 'Capture Verdict' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'pct', header: 'Share %' },
  ];

  const engineerCols: Column<EngineerRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_jobs', header: 'Jobs' },
    { key: 'accurate', header: 'Accurate' },
    { key: 'minor_leak', header: 'Minor Leak' },
    { key: 'major_leak', header: 'Major Leak' },
    { key: 'not_invoiced', header: 'Not Invoiced' },
    { key: 'total_gap_rupees', header: 'Total Gap (INR)' },
    { key: 'accuracy_pct', header: 'Accuracy %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'service_type', header: 'Service Type' },
    { key: 'contract_coverage', header: 'Coverage' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'accurate', header: 'Accurate' },
    { key: 'total_gap_rupees', header: 'Total Gap (INR)' },
    { key: 'avg_gap_rupees', header: 'Avg Gap (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'job_close_date', header: 'Close Date' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'accurate', header: 'Accurate' },
    { key: 'leaks', header: 'Leaks' },
    { key: 'not_invoiced', header: 'Not Invoiced' },
    { key: 'total_gap_rupees', header: 'Total Gap (INR)' },
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

  const revCols: Column<RevRow>[] = [
    { key: 'revenue_impact', header: 'Revenue Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_recovery_rupees', header: 'Total Recovery (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'region', header: 'Region' },
    { key: 'job_code', header: 'Job' },
    { key: 'service_type', header: 'Service Type' },
    { key: 'job_close_date', header: 'Close Date' },
    { key: 'contract_coverage', header: 'Coverage' },
    { key: 'capture_verdict', header: 'Verdict' },
    { key: 'gap_reason', header: 'Gap Reason' },
    { key: 'billing_gap_rupees', header: 'Gap (INR)' },
    { key: 'invoice_raised', header: 'Invoiced' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Field-Service Charge-Capture &amp; Billing-Accuracy Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Revenue-integrity log — per completed job: parts &amp; labour &amp; visit charges captured
        &times; contract coverage &times; invoice status &times; billing-gap leak detection &times;
        capture verdict &amp; CAPA recovery. Founder-gated view: engineer scorecards,
        service-type &times; coverage matrix, root-cause pareto, and revenue-impact recovery digest
        across leaked, un-invoiced &amp; misclassified jobs.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Capture verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No jobs logged yet."
          rowKey={(r, i) => String(r.capture_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer charge-capture scorecard</h2>
        <DataTable
          rows={engineerRows}
          columns={engineerCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Service type &times; coverage matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No jobs by type."
          rowKey={(r, i) => `${r.service_type}-${r.contract_coverage}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily billing-accuracy trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.job_close_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Revenue-impact recovery digest</h2>
        <DataTable
          rows={revRows}
          columns={revCols}
          emptyMessage="No revenue-impact rollups."
          rowKey={(r, i) => String(r.revenue_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk billing-leak queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk jobs."
          rowKey={(r, i) => `${r.job_code}-${r.job_close_date}-${i}`}
        />
      </section>
    </main>
  );
}
