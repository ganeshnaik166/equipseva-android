import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; distributions: number; pct: number };
type ClassRow = {
  shareholder_class: string;
  distributions: number;
  compliant: number;
  short_deducted: number;
  non_compliant: number;
  total_declared_rupees: number;
  total_tds_deducted_rupees: number;
  total_tds_deposited_rupees: number;
  compliant_pct: number;
};
type MatrixRow = {
  shareholder_class: string;
  compliance_status: string;
  distributions: number;
  total_tds_deductible_rupees: number;
  total_tds_deposited_rupees: number;
  avg_tds_rate_pct: number;
};
type TrendRow = {
  period_month: string;
  distributions: number;
  total_declared_rupees: number;
  total_tds_deducted_rupees: number;
  total_tds_deposited_rupees: number;
  deposit_gap_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_exposure_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_exposure_rupees: number;
  pct: number;
};
type DigestRow = {
  finding_category: string;
  findings: number;
  open_findings: number;
  total_exposure_rupees: number;
};
type RiskRow = {
  shareholder_class: string;
  distribution_ref: string;
  period_month: string;
  compliance_status: string;
  tds_rate_pct: number | null;
  tds_deductible_rupees: number | null;
  tds_deducted_rupees: number | null;
  tds_deposited_rupees: number | null;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    classRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3635_compliance_status_rollup'),
    supabase.rpc('founder_r3635_shareholder_class_scorecard'),
    supabase.rpc('founder_r3635_class_status_matrix'),
    supabase.rpc('founder_r3635_monthly_tds_trend'),
    supabase.rpc('founder_r3635_capa_status_board'),
    supabase.rpc('founder_r3635_root_cause_pareto'),
    supabase.rpc('founder_r3635_tds_exposure_digest'),
    supabase.rpc('founder_r3635_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const classRows: ClassRow[] = (classRes.data as ClassRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'distributions', header: 'Distributions' },
    { key: 'pct', header: 'Share %' },
  ];

  const classCols: Column<ClassRow>[] = [
    { key: 'shareholder_class', header: 'Shareholder Class' },
    { key: 'distributions', header: 'Distributions' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'short_deducted', header: 'Short Deducted' },
    { key: 'non_compliant', header: 'Non-Compliant' },
    { key: 'total_declared_rupees', header: 'Declared (INR)' },
    { key: 'total_tds_deducted_rupees', header: 'TDS Deducted (INR)' },
    { key: 'total_tds_deposited_rupees', header: 'TDS Deposited (INR)' },
    { key: 'compliant_pct', header: 'Compliant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'shareholder_class', header: 'Shareholder Class' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'distributions', header: 'Distributions' },
    { key: 'total_tds_deductible_rupees', header: 'TDS Deductible (INR)' },
    { key: 'total_tds_deposited_rupees', header: 'TDS Deposited (INR)' },
    { key: 'avg_tds_rate_pct', header: 'Avg TDS Rate %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'distributions', header: 'Distributions' },
    { key: 'total_declared_rupees', header: 'Declared (INR)' },
    { key: 'total_tds_deducted_rupees', header: 'TDS Deducted (INR)' },
    { key: 'total_tds_deposited_rupees', header: 'TDS Deposited (INR)' },
    { key: 'deposit_gap_rupees', header: 'Deposit Gap (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_exposure_rupees', header: 'Avg Exposure (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_exposure_rupees', header: 'Total Exposure (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_exposure_rupees', header: 'Total Exposure (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'shareholder_class', header: 'Class' },
    { key: 'distribution_ref', header: 'Distribution' },
    { key: 'period_month', header: 'Month' },
    { key: 'compliance_status', header: 'Status' },
    { key: 'tds_rate_pct', header: 'Rate %' },
    { key: 'tds_deductible_rupees', header: 'Deductible (INR)' },
    { key: 'tds_deducted_rupees', header: 'Deducted (INR)' },
    { key: 'tds_deposited_rupees', header: 'Deposited (INR)' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Dividend Distribution / Dividend-TDS (Sec-194) Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder dividend-distribution log &mdash; shareholder class &times; period month &times;
        dividend declared &amp; paid &times; TDS deductible &times; TDS deducted &times; TDS deposited
        (Section 194) &times; deduction rate &times; lower-deduction cases &amp; CAPA closure.
        Founder-gated view: compliance-status rollups, shareholder-class scorecards, class &times;
        status matrix, monthly TDS trend, root-cause pareto, and TDS-exposure digest across
        Companies Act &amp; income-tax surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No distributions logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Shareholder-class scorecard</h2>
        <DataTable
          rows={classRows}
          columns={classCols}
          emptyMessage="No shareholder-class rollups."
          rowKey={(r, i) => String(r.shareholder_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Shareholder-class &times; compliance-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No distributions by class."
          rowKey={(r, i) => `${r.shareholder_class}-${r.compliance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly TDS trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. TDS-exposure digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No exposure rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk distribution queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk distributions."
          rowKey={(r, i) => `${r.distribution_ref}-${i}`}
        />
      </section>
    </main>
  );
}
