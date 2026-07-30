import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { payment_status: string; installments: number; pct: number };
type EntityRow = {
  entity_name: string;
  total_installments: number;
  paid_on_time: number;
  short_paid: number;
  interest_accruing: number;
  defaulted: number;
  total_liability_rupees: number;
  total_paid_rupees: number;
  total_interest_rupees: number;
  on_time_pct: number;
};
type MatrixRow = {
  quarter_label: string;
  payment_status: string;
  installments: number;
  total_shortfall_rupees: number;
  total_interest_rupees: number;
};
type TrendRow = {
  period_month: string;
  installments: number;
  total_due_rupees: number;
  total_paid_rupees: number;
  total_shortfall_rupees: number;
  total_interest_rupees: number;
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
  total_interest_exposure_rupees: number;
  pct: number;
};
type DigestRow = {
  finding_category: string;
  findings: number;
  open_findings: number;
  total_interest_exposure_rupees: number;
};
type RiskRow = {
  entity_name: string;
  installment_ref: string;
  quarter_label: string;
  period_month: string;
  payment_status: string;
  shortfall_rupees: number | null;
  interest_234b_rupees: number | null;
  interest_234c_rupees: number | null;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    entityRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3629_payment_status_rollup'),
    supabase.rpc('founder_r3629_entity_scorecard'),
    supabase.rpc('founder_r3629_quarter_status_matrix'),
    supabase.rpc('founder_r3629_monthly_trend'),
    supabase.rpc('founder_r3629_capa_status_board'),
    supabase.rpc('founder_r3629_root_cause_pareto'),
    supabase.rpc('founder_r3629_interest_exposure_digest'),
    supabase.rpc('founder_r3629_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const entityRows: EntityRow[] = (entityRes.data as EntityRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'payment_status', header: 'Payment Status' },
    { key: 'installments', header: 'Installments' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'total_installments', header: 'Installments' },
    { key: 'paid_on_time', header: 'On Time' },
    { key: 'short_paid', header: 'Short Paid' },
    { key: 'interest_accruing', header: 'Interest Accruing' },
    { key: 'defaulted', header: 'Defaulted' },
    { key: 'total_liability_rupees', header: 'Est Liability (INR)' },
    { key: 'total_paid_rupees', header: 'Paid (INR)' },
    { key: 'total_interest_rupees', header: 'Interest (INR)' },
    { key: 'on_time_pct', header: 'On-Time %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'quarter_label', header: 'Quarter' },
    { key: 'payment_status', header: 'Payment Status' },
    { key: 'installments', header: 'Installments' },
    { key: 'total_shortfall_rupees', header: 'Shortfall (INR)' },
    { key: 'total_interest_rupees', header: 'Interest (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'installments', header: 'Installments' },
    { key: 'total_due_rupees', header: 'Due (INR)' },
    { key: 'total_paid_rupees', header: 'Paid (INR)' },
    { key: 'total_shortfall_rupees', header: 'Shortfall (INR)' },
    { key: 'total_interest_rupees', header: 'Interest (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_interest_exposure_rupees', header: 'Avg Interest Exposure (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_interest_exposure_rupees', header: 'Total Interest Exposure (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_interest_exposure_rupees', header: 'Total Interest Exposure (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'installment_ref', header: 'Installment' },
    { key: 'quarter_label', header: 'Quarter' },
    { key: 'period_month', header: 'Month' },
    { key: 'payment_status', header: 'Status' },
    { key: 'shortfall_rupees', header: 'Shortfall (INR)' },
    { key: 'interest_234b_rupees', header: '234B (INR)' },
    { key: 'interest_234c_rupees', header: '234C (INR)' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Advance-Tax / 234B-234C Interest / TDS-Credit Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder advance-tax installment tracker across group entities (Medtech, Diagnostics LLP, Spares
        &amp; AMC, Projects &amp; founder personal) &mdash; estimated liability &times; advance-tax
        due/paid &times; TDS/TCS credit &times; shortfall &times; sec 234B interest &times; sec 234C
        interest &times; cumulative-paid %. Founder-gated view: payment-status distribution, entity
        scorecards, quarter &times; status matrix, monthly trend, CAPA board, root-cause pareto, and the
        interest-exposure digest across installments where interest is accruing &gt; 0 or payment has
        defaulted.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Payment-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No advance-tax installments logged yet."
          rowKey={(r, i) => String(r.payment_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Entity advance-tax scorecard</h2>
        <DataTable
          rows={entityRows}
          columns={entityCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.entity_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Quarter &times; payment-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No installments by quarter."
          rowKey={(r, i) => `${r.quarter_label}-${r.payment_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly advance-tax trend</h2>
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
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk installment queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk installments."
          rowKey={(r, i) => `${r.installment_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
