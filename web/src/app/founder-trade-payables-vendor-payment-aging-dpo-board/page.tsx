import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { payment_verdict: string; vendors: number; pct: number };
type ScorecardRow = {
  vendor_category: string;
  total_lines: number;
  outstanding_total_rupees: number;
  over_90_total_rupees: number;
  on_hold_count: number;
  discount_available_count: number;
  discount_captured_count: number;
  avg_dpo_days: number;
};
type MatrixRow = {
  vendor_category: string;
  criticality: string;
  vendors: number;
  outstanding_total_rupees: number;
  over_90_total_rupees: number;
  avg_dpo_days: number;
};
type TrendRow = {
  as_of_date: string;
  lines: number;
  outstanding_total_rupees: number;
  over_90_total_rupees: number;
  on_hold_count: number;
  avg_dpo_days: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_amount_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_amount_rupees: number;
  pct: number;
};
type RiskRow = {
  risk_impact: string;
  findings: number;
  open_findings: number;
  total_amount_rupees: number;
};
type QueueRow = {
  vendor_name: string;
  vendor_category: string;
  criticality: string;
  as_of_date: string;
  payment_verdict: string;
  outstanding_rupees: number;
  overdue_over_90_rupees: number;
  dpo_days: number;
  on_hold_dispute: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    scorecardRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    riskRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3333_payment_verdict_rollup'),
    supabase.rpc('founder_r3333_vendor_category_scorecard'),
    supabase.rpc('founder_r3333_category_criticality_matrix'),
    supabase.rpc('founder_r3333_payables_aging_trend'),
    supabase.rpc('founder_r3333_capa_status_board'),
    supabase.rpc('founder_r3333_root_cause_pareto'),
    supabase.rpc('founder_r3333_risk_impact_digest'),
    supabase.rpc('founder_r3333_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const scorecardRows: ScorecardRow[] = (scorecardRes.data as ScorecardRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'payment_verdict', header: 'Payment Verdict' },
    { key: 'vendors', header: 'Vendors' },
    { key: 'pct', header: 'Share %' },
  ];

  const scorecardCols: Column<ScorecardRow>[] = [
    { key: 'vendor_category', header: 'Vendor Category' },
    { key: 'total_lines', header: 'Lines' },
    { key: 'outstanding_total_rupees', header: 'Outstanding (INR)' },
    { key: 'over_90_total_rupees', header: 'Over-90 (INR)' },
    { key: 'on_hold_count', header: 'On Hold' },
    { key: 'discount_available_count', header: 'Discount Avail' },
    { key: 'discount_captured_count', header: 'Discount Taken' },
    { key: 'avg_dpo_days', header: 'Avg DPO Days' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'vendor_category', header: 'Vendor Category' },
    { key: 'criticality', header: 'Criticality' },
    { key: 'vendors', header: 'Vendors' },
    { key: 'outstanding_total_rupees', header: 'Outstanding (INR)' },
    { key: 'over_90_total_rupees', header: 'Over-90 (INR)' },
    { key: 'avg_dpo_days', header: 'Avg DPO Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'as_of_date', header: 'As-Of Date' },
    { key: 'lines', header: 'Lines' },
    { key: 'outstanding_total_rupees', header: 'Outstanding (INR)' },
    { key: 'over_90_total_rupees', header: 'Over-90 (INR)' },
    { key: 'on_hold_count', header: 'On Hold' },
    { key: 'avg_dpo_days', header: 'Avg DPO Days' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_amount_rupees', header: 'Avg Amount (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_amount_rupees', header: 'Total Amount (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'risk_impact', header: 'Risk Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_amount_rupees', header: 'Total Amount (INR)' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'vendor_name', header: 'Vendor' },
    { key: 'vendor_category', header: 'Category' },
    { key: 'criticality', header: 'Criticality' },
    { key: 'as_of_date', header: 'As-Of' },
    { key: 'payment_verdict', header: 'Verdict' },
    { key: 'outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'overdue_over_90_rupees', header: 'Over-90 (INR)' },
    { key: 'dpo_days', header: 'DPO Days' },
    { key: 'on_hold_dispute', header: 'On Hold' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Trade-Payables, Vendor-Payment Aging &amp; DPO Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Working-capital governance — vendor category &times; payment verdict &times; aging buckets
        (current / 31&ndash;60 / 61&ndash;90 / over-90) &times; days-payable-outstanding &times;
        early-pay discount capture &times; dispute holds &amp; CAPA closure. Founder-gated view:
        payment verdicts, category scorecards, root-cause pareto, and cash-risk digest across the
        EquipSeva vendor base.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Payment verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No payables logged yet."
          rowKey={(r, i) => String(r.payment_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Vendor-category payables scorecard</h2>
        <DataTable
          rows={scorecardRows}
          columns={scorecardCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => String(r.vendor_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Vendor category &times; criticality matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No payables by category."
          rowKey={(r, i) => `${r.vendor_category}-${r.criticality}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Payables aging trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.as_of_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Cash-risk impact digest</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No risk-impact rollups."
          rowKey={(r, i) => String(r.risk_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk payables queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No high-risk payables."
          rowKey={(r, i) => `${r.vendor_name}-${r.as_of_date}-${i}`}
        />
      </section>
    </main>
  );
}
