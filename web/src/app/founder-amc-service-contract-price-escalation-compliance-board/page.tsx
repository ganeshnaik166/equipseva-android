import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { escalation_status: string; contracts: number; pct: number };
type CustomerRow = {
  customer_name: string;
  contracts: number;
  applied_on_time: number;
  applied_late: number;
  pending: number;
  disputed: number;
  total_contract_value_rupees: number;
  total_leakage_rupees: number;
  avg_days_late: number | null;
};
type MatrixRow = {
  escalation_class: string;
  escalation_status: string;
  contracts: number;
  total_leakage_rupees: number;
  avg_days_late: number | null;
};
type TrendRow = {
  period_month: string;
  contracts: number;
  total_leakage_rupees: number;
  applied_late: number;
  disputed: number;
  worsening_contracts: number;
};
type CapaRow = { capa_status: string; actions: number; overdue_flag: number };
type CauseRow = { root_cause: string; occurrences: number; pct: number };
type DigestRow = {
  contracts_at_risk: number;
  total_leakage_rupees: number;
  undisclosed_leakage_rupees: number;
  unnotified_contracts: number;
  disputed_contracts: number;
  avg_days_late: number | null;
};
type RiskRow = {
  contract_ref: string;
  customer_name: string;
  period_month: string;
  escalation_class: string;
  escalation_status: string;
  escalation_due_date: string | null;
  days_late: number | null;
  revenue_leakage_rupees: number | null;
  customer_notified: boolean;
  customer_disputed: boolean;
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
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3722_escalation_status_rollup'),
    supabase.rpc('founder_r3722_customer_scorecard'),
    supabase.rpc('founder_r3722_escalation_class_status_matrix'),
    supabase.rpc('founder_r3722_monthly_leakage_trend'),
    supabase.rpc('founder_r3722_capa_status_board'),
    supabase.rpc('founder_r3722_root_cause_pareto'),
    supabase.rpc('founder_r3722_revenue_leakage_digest'),
    supabase.rpc('founder_r3722_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const customerRows: CustomerRow[] = (customerRes.data as CustomerRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'escalation_status', header: 'Escalation Status' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'pct', header: 'Share %' },
  ];

  const customerCols: Column<CustomerRow>[] = [
    { key: 'customer_name', header: 'Customer' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'applied_on_time', header: 'On Time' },
    { key: 'applied_late', header: 'Late' },
    { key: 'pending', header: 'Pending' },
    { key: 'disputed', header: 'Disputed' },
    { key: 'total_contract_value_rupees', header: 'Contract Value (INR)' },
    { key: 'total_leakage_rupees', header: 'Leakage (INR)' },
    { key: 'avg_days_late', header: 'Avg Days Late' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'escalation_class', header: 'Escalation Class' },
    { key: 'escalation_status', header: 'Escalation Status' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'total_leakage_rupees', header: 'Leakage (INR)' },
    { key: 'avg_days_late', header: 'Avg Days Late' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'total_leakage_rupees', header: 'Leakage (INR)' },
    { key: 'applied_late', header: 'Applied Late' },
    { key: 'disputed', header: 'Disputed' },
    { key: 'worsening_contracts', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'contracts_at_risk', header: 'Contracts at Risk' },
    { key: 'total_leakage_rupees', header: 'Total Leakage (INR)' },
    { key: 'undisclosed_leakage_rupees', header: 'Undisclosed Leakage (INR)' },
    { key: 'unnotified_contracts', header: 'Unnotified Contracts' },
    { key: 'disputed_contracts', header: 'Disputed Contracts' },
    { key: 'avg_days_late', header: 'Avg Days Late' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'contract_ref', header: 'Contract Ref' },
    { key: 'customer_name', header: 'Customer' },
    { key: 'period_month', header: 'Month' },
    { key: 'escalation_class', header: 'Class' },
    { key: 'escalation_status', header: 'Status' },
    { key: 'escalation_due_date', header: 'Due Date' },
    { key: 'days_late', header: 'Days Late' },
    { key: 'revenue_leakage_rupees', header: 'Leakage (INR)' },
    { key: 'customer_notified', header: 'Notified' },
    { key: 'customer_disputed', header: 'Disputed' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        AMC / Service-Contract Price-Escalation Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        AMC and service-contract price-escalation clause tracking &mdash; fixed-% and CPI-linked
        revisions &times; contract &times; customer &times; period month &times; whether the
        annual rate revision was applied on time, late, waived, or disputed &times; customer
        notification &times; revenue leakage from missed or delayed escalations. Distinct from
        renewal-pipeline boards: this tracks escalation-clause execution, not renewal timing.
        Founder-gated view: status distribution, customer scorecards, class &times; status matrix,
        monthly leakage trend, CAPA closure, root-cause pareto, a revenue-leakage digest, and a
        high-risk queue of pending/disputed/late escalations.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Escalation-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No escalation rows logged yet."
          rowKey={(r, i) => String(r.escalation_status ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Escalation class &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No escalation-class data."
          rowKey={(r, i) => `${r.escalation_class}-${r.escalation_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly leakage trend</h2>
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
          emptyMessage="No CAPA actions."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Revenue-leakage digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No leakage digest available."
          rowKey={(_r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk escalation queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk escalations."
          rowKey={(r, i) => `${r.contract_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
