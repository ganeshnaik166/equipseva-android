import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; contracts: number; pct: number };
type AuthorityRow = {
  contracting_authority: string;
  contracts: number;
  active_compliant: number;
  renewal_due: number;
  price_parity_breach: number;
  fulfillment_shortfall: number;
  delisted: number;
  total_orders_received: number;
  total_orders_fulfilled_on_time: number;
  avg_pbg_rupees: number | null;
};
type MatrixRow = {
  contract_class: string;
  compliance_status: string;
  contracts: number;
  avg_days_to_expiry: number | null;
};
type TrendRow = {
  period_month: string;
  contracts: number;
  total_orders_received: number;
  total_orders_fulfilled_on_time: number;
  fulfillment_rate_pct: number | null;
  price_parity_breaches: number;
  worsening_contracts: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  pct: number;
};
type PenaltyRow = {
  contract_class: string;
  contracts: number;
  penalty_clauses_total: number;
  price_parity_breaches: number;
  avg_pbg_rupees: number | null;
  renewal_not_filed: number;
};
type RiskRow = {
  contract_ref: string;
  contracting_authority: string;
  contract_class: string;
  period_month: string;
  compliance_status: string;
  days_to_expiry: number | null;
  orders_received: number | null;
  orders_fulfilled_on_time: number | null;
  penalty_clauses_triggered: number | null;
  renewal_filed: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    authorityRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    penaltyRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3736_compliance_status_rollup'),
    supabase.rpc('founder_r3736_contracting_authority_scorecard'),
    supabase.rpc('founder_r3736_contract_class_status_matrix'),
    supabase.rpc('founder_r3736_monthly_fulfillment_trend'),
    supabase.rpc('founder_r3736_capa_status_board'),
    supabase.rpc('founder_r3736_root_cause_pareto'),
    supabase.rpc('founder_r3736_penalty_digest'),
    supabase.rpc('founder_r3736_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const authorityRows: AuthorityRow[] = (authorityRes.data as AuthorityRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const penaltyRows: PenaltyRow[] = (penaltyRes.data as PenaltyRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'pct', header: 'Share %' },
  ];

  const authorityCols: Column<AuthorityRow>[] = [
    { key: 'contracting_authority', header: 'Contracting Authority' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'active_compliant', header: 'Active Compliant' },
    { key: 'renewal_due', header: 'Renewal Due' },
    { key: 'price_parity_breach', header: 'Price-Parity Breach' },
    { key: 'fulfillment_shortfall', header: 'Fulfillment Shortfall' },
    { key: 'delisted', header: 'Delisted' },
    { key: 'total_orders_received', header: 'Orders Received' },
    { key: 'total_orders_fulfilled_on_time', header: 'Orders On-Time' },
    { key: 'avg_pbg_rupees', header: 'Avg PBG (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'contract_class', header: 'Contract Class' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'avg_days_to_expiry', header: 'Avg Days to Expiry' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'total_orders_received', header: 'Orders Received' },
    { key: 'total_orders_fulfilled_on_time', header: 'Orders On-Time' },
    { key: 'fulfillment_rate_pct', header: 'Fulfillment Rate %' },
    { key: 'price_parity_breaches', header: 'Price-Parity Breaches' },
    { key: 'worsening_contracts', header: 'Worsening' },
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

  const penaltyCols: Column<PenaltyRow>[] = [
    { key: 'contract_class', header: 'Contract Class' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'penalty_clauses_total', header: 'Penalty Clauses' },
    { key: 'price_parity_breaches', header: 'Price-Parity Breaches' },
    { key: 'avg_pbg_rupees', header: 'Avg PBG (INR)' },
    { key: 'renewal_not_filed', header: 'Renewal Not Filed' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'contract_ref', header: 'Contract Ref' },
    { key: 'contracting_authority', header: 'Contracting Authority' },
    { key: 'contract_class', header: 'Contract Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'days_to_expiry', header: 'Days to Expiry' },
    { key: 'orders_received', header: 'Orders Received' },
    { key: 'orders_fulfilled_on_time', header: 'Orders On-Time' },
    { key: 'penalty_clauses_triggered', header: 'Penalty Clauses' },
    { key: 'renewal_filed', header: 'Renewal Filed' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Government / PSU Rate-Contract &amp; Framework-Agreement Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Government/PSU rate-contract and framework-agreement compliance log (GeM &amp; DGS&amp;D-style
        rate contracts, state PSU empanelments, CSD canteen-stores contracts, and institutional
        tenders) &mdash; empanelment validity &times; order fulfillment &times; price-parity
        maintenance &times; penalty clauses &times; performance bank guarantee &times; renewal
        filing &amp; CAPA closure. Distinct from any AMC/service-contract price-escalation board,
        which is customer-commercial, not the government rate-contract regime. Founder-gated view:
        compliance-status distribution, contracting-authority scorecards, a contract-class ×
        compliance-status matrix, monthly fulfillment trend, CAPA board, root-cause pareto, a
        penalty / price-parity-breach digest, and a high-risk queue of breached or delisted
        contracts.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No rate-contract rows logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Contracting-authority scorecard</h2>
        <DataTable
          rows={authorityRows}
          columns={authorityCols}
          emptyMessage="No contracting-authority rollups."
          rowKey={(r, i) => String(r.contracting_authority ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Contract class &times; compliance status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No contracts by class."
          rowKey={(r, i) => `${r.contract_class}-${r.compliance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly fulfillment trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Penalty / price-parity-breach digest</h2>
        <DataTable
          rows={penaltyRows}
          columns={penaltyCols}
          emptyMessage="No penalty or price-parity-breach exposure."
          rowKey={(r, i) => String(r.contract_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk contract queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk contracts."
          rowKey={(r, i) => `${r.contract_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
