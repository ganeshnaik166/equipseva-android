import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { mandate_status: string; mandates: number; pct: number };
type CustomerRow = {
  customer_name: string;
  mandates: number;
  active_healthy: number;
  active_bounce_risk: number;
  lapsed_or_revoked: number;
  debits_attempted_total: number;
  debits_successful_total: number;
  avg_debit_success_pct: number | null;
  amount_at_risk_total_rupees: number | null;
};
type MatrixRow = {
  mandate_class: string;
  mandate_status: string;
  mandates: number;
  avg_debit_success_pct: number | null;
  amount_at_risk_total_rupees: number | null;
};
type TrendRow = {
  period_month: string;
  mandates: number;
  debits_attempted_total: number;
  debits_successful_total: number;
  avg_debit_success_pct: number | null;
  bounced_debits_total: number;
};
type CapaRow = { capa_status: string; findings: number; overdue_flag: number };
type CauseRow = { root_cause: string; occurrences: number; pct: number };
type BounceRow = {
  customer_name: string;
  period_month: string;
  mandate_class: string;
  bounced_debits: number | null;
  bounce_reason: string | null;
  amount_at_risk_rupees: number | null;
  trend_dir: string;
};
type RiskRow = {
  customer_name: string;
  mandate_type: string;
  mandate_class: string;
  mandate_status: string;
  period_month: string;
  mandate_expiry_date: string | null;
  debit_success_pct: number | null;
  amount_at_risk_rupees: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    customerRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    bounceRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3751_mandate_status_rollup'),
    supabase.rpc('founder_r3751_customer_scorecard'),
    supabase.rpc('founder_r3751_mandate_class_status_matrix'),
    supabase.rpc('founder_r3751_monthly_success_rate_trend'),
    supabase.rpc('founder_r3751_capa_status_board'),
    supabase.rpc('founder_r3751_root_cause_pareto'),
    supabase.rpc('founder_r3751_bounce_digest'),
    supabase.rpc('founder_r3751_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const customerRows: CustomerRow[] = (customerRes.data as CustomerRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const bounceRows: BounceRow[] = (bounceRes.data as BounceRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'mandate_status', header: 'Mandate Status' },
    { key: 'mandates', header: 'Mandates' },
    { key: 'pct', header: 'Share %' },
  ];

  const customerCols: Column<CustomerRow>[] = [
    { key: 'customer_name', header: 'Customer' },
    { key: 'mandates', header: 'Mandates' },
    { key: 'active_healthy', header: 'Active Healthy' },
    { key: 'active_bounce_risk', header: 'Bounce Risk' },
    { key: 'lapsed_or_revoked', header: 'Lapsed/Revoked' },
    { key: 'debits_attempted_total', header: 'Debits Attempted' },
    { key: 'debits_successful_total', header: 'Debits Successful' },
    { key: 'avg_debit_success_pct', header: 'Avg Success %' },
    { key: 'amount_at_risk_total_rupees', header: 'Amount at Risk (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'mandate_class', header: 'Mandate Class' },
    { key: 'mandate_status', header: 'Mandate Status' },
    { key: 'mandates', header: 'Mandates' },
    { key: 'avg_debit_success_pct', header: 'Avg Success %' },
    { key: 'amount_at_risk_total_rupees', header: 'Amount at Risk (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'mandates', header: 'Mandates' },
    { key: 'debits_attempted_total', header: 'Debits Attempted' },
    { key: 'debits_successful_total', header: 'Debits Successful' },
    { key: 'avg_debit_success_pct', header: 'Avg Success %' },
    { key: 'bounced_debits_total', header: 'Bounced Debits' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const bounceCols: Column<BounceRow>[] = [
    { key: 'customer_name', header: 'Customer' },
    { key: 'period_month', header: 'Month' },
    { key: 'mandate_class', header: 'Mandate Class' },
    { key: 'bounced_debits', header: 'Bounced Debits' },
    { key: 'bounce_reason', header: 'Bounce Reason' },
    { key: 'amount_at_risk_rupees', header: 'Amount at Risk (INR)' },
    { key: 'trend_dir', header: 'Trend' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'customer_name', header: 'Customer' },
    { key: 'mandate_type', header: 'Mandate Type' },
    { key: 'mandate_class', header: 'Mandate Class' },
    { key: 'mandate_status', header: 'Mandate Status' },
    { key: 'period_month', header: 'Month' },
    { key: 'mandate_expiry_date', header: 'Expiry Date' },
    { key: 'debit_success_pct', header: 'Success %' },
    { key: 'amount_at_risk_rupees', header: 'Amount at Risk (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        NACH / Auto-Debit Mandate Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Customer AMC/EMI NACH auto-debit mandate compliance log — mandate registration &amp;
        expiry &times; debit success rate &times; bounce/reversal handling &times; amount at
        risk, tracking the payment-COLLECTION mechanism itself (distinct from generic AMC
        contract-renewal or price-escalation boards). Founder-gated view: mandate-status
        distribution, customer scorecards, class &times; status matrix, monthly success-rate
        trend, CAPA closure, root-cause pareto, a bounce digest, and a high-risk mandate queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Mandate-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No NACH mandate rows logged yet."
          rowKey={(r, i) => String(r.mandate_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Customer scorecard</h2>
        <DataTable
          rows={customerRows}
          columns={customerCols}
          emptyMessage="No customer rollups."
          rowKey={(r, i) => String(r.customer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Mandate class &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No mandates by class."
          rowKey={(r, i) => `${r.mandate_class}-${r.mandate_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly success-rate trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Bounce digest</h2>
        <DataTable
          rows={bounceRows}
          columns={bounceCols}
          emptyMessage="No bounced debits recorded."
          rowKey={(r, i) => `${r.customer_name}-${r.period_month}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk mandate queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk mandates."
          rowKey={(r, i) => `${r.customer_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
