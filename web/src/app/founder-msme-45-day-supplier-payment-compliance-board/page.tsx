import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; suppliers: number; pct: number };
type CatRow = {
  msme_category: string;
  total_lines: number;
  compliant: number;
  at_risk: number;
  breached: number;
  interest_accruing: number;
  total_interest_rupees: number;
  avg_compliance_pct: number;
};
type MatrixRow = {
  msme_category: string;
  compliance_status: string;
  lines: number;
  invoice_value_rupees: number;
  interest_liability_rupees: number;
};
type TrendRow = {
  period_month: string;
  lines: number;
  compliant: number;
  breached: number;
  interest_accruing: number;
  total_interest_rupees: number;
  avg_compliance_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_interest_exposure_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_exposure_rupees: number;
  pct: number;
};
type DigestRow = {
  business_unit: string;
  lines: number;
  total_interest_rupees: number;
  total_overdue_rupees: number;
  at_risk_lines: number;
};
type RiskRow = {
  supplier_name: string;
  supplier_code: string;
  msme_category: string;
  business_unit: string;
  period_month: string;
  compliance_status: string;
  days_outstanding: number | null;
  overdue_beyond_45_rupees: number | null;
  interest_liability_rupees: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    catRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3622_compliance_status_rollup'),
    supabase.rpc('founder_r3622_msme_category_scorecard'),
    supabase.rpc('founder_r3622_category_status_matrix'),
    supabase.rpc('founder_r3622_monthly_compliance_trend'),
    supabase.rpc('founder_r3622_capa_status_board'),
    supabase.rpc('founder_r3622_root_cause_pareto'),
    supabase.rpc('founder_r3622_interest_exposure_digest'),
    supabase.rpc('founder_r3622_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const catRows: CatRow[] = (catRes.data as CatRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'pct', header: 'Share %' },
  ];

  const catCols: Column<CatRow>[] = [
    { key: 'msme_category', header: 'MSME Category' },
    { key: 'total_lines', header: 'Lines' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'breached', header: 'Breached' },
    { key: 'interest_accruing', header: 'Interest Accruing' },
    { key: 'total_interest_rupees', header: 'Total Interest (INR)' },
    { key: 'avg_compliance_pct', header: 'Avg Compliance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'msme_category', header: 'MSME Category' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'invoice_value_rupees', header: 'Invoice Value (INR)' },
    { key: 'interest_liability_rupees', header: 'Interest Liability (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'lines', header: 'Lines' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'breached', header: 'Breached' },
    { key: 'interest_accruing', header: 'Interest Accruing' },
    { key: 'total_interest_rupees', header: 'Total Interest (INR)' },
    { key: 'avg_compliance_pct', header: 'Avg Compliance %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_interest_exposure_rupees', header: 'Avg Exposure (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_exposure_rupees', header: 'Total Exposure (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'lines', header: 'Lines' },
    { key: 'total_interest_rupees', header: 'Total Interest (INR)' },
    { key: 'total_overdue_rupees', header: 'Total Overdue (INR)' },
    { key: 'at_risk_lines', header: 'At-Risk Lines' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'supplier_code', header: 'Code' },
    { key: 'msme_category', header: 'Category' },
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'period_month', header: 'Month' },
    { key: 'compliance_status', header: 'Status' },
    { key: 'days_outstanding', header: 'Days Outstanding' },
    { key: 'overdue_beyond_45_rupees', header: 'Overdue (INR)' },
    { key: 'interest_liability_rupees', header: 'Interest (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        MSME 45-Day Supplier-Payment Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        MSMED-Act Section 15 45-day supplier-payment compliance &amp; interest-liability exposure —
        supplier &times; MSME category (micro, small, medium) &times; business unit &times; invoice value
        &times; due &amp; paid within 45 days &times; overdue beyond 45 days &times; days outstanding
        &times; interest liability &times; average payment days &times; compliance % &amp; CAPA closure.
        Founder-gated view: compliance-status mix, MSME-category scorecards, root-cause pareto, and
        interest-exposure digest across amc_services, spare_parts, projects, diagnostics, installation
        &amp; consumables business units.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No supplier-payment lines logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. MSME-category scorecard</h2>
        <DataTable
          rows={catRows}
          columns={catCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => String(r.msme_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category &times; compliance-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No lines by category."
          rowKey={(r, i) => `${r.msme_category}-${r.compliance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly compliance trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Interest-exposure digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No interest-exposure rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk supplier queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk suppliers."
          rowKey={(r, i) => `${r.supplier_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
