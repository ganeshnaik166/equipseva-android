import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { card_verdict: string; cards: number; pct: number };
type DeptRow = {
  department: string;
  total_cards: number;
  healthy: number;
  high_util: number;
  policy_gaps: number;
  overdue: number;
  fraud_review: number;
  avg_utilization_pct: number;
  total_spent_rupees: number;
  total_flagged_rupees: number;
};
type MatrixRow = {
  card_type: string;
  department: string;
  cards: number;
  avg_utilization_pct: number;
  total_spent_rupees: number;
  flagged_rupees: number;
};
type TrendRow = {
  cycle_close_date: string;
  cards: number;
  total_spent_rupees: number;
  flagged_rupees: number;
  out_of_policy_txns: number;
  fraud_alerts: number;
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
type RiskImpactRow = {
  risk_impact: string;
  findings: number;
  open_findings: number;
  total_recovery_rupees: number;
};
type QueueRow = {
  cardholder_name: string;
  department: string;
  card_type: string;
  cycle_close_date: string;
  card_verdict: string;
  utilization_pct: number | null;
  payment_status: string;
  out_of_policy_txn_count: number;
  flagged_amount_rupees: number | null;
  fraud_alert: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    deptRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    riskImpactRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3269_card_verdict_rollup'),
    supabase.rpc('founder_r3269_department_scorecard'),
    supabase.rpc('founder_r3269_card_type_department_matrix'),
    supabase.rpc('founder_r3269_cycle_spend_trend'),
    supabase.rpc('founder_r3269_capa_status_board'),
    supabase.rpc('founder_r3269_root_cause_pareto'),
    supabase.rpc('founder_r3269_risk_impact_digest'),
    supabase.rpc('founder_r3269_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const deptRows: DeptRow[] = (deptRes.data as DeptRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const riskImpactRows: RiskImpactRow[] = (riskImpactRes.data as RiskImpactRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'card_verdict', header: 'Card Verdict' },
    { key: 'cards', header: 'Cards' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'total_cards', header: 'Cards' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'high_util', header: 'High Util' },
    { key: 'policy_gaps', header: 'Policy Gaps' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'fraud_review', header: 'Fraud / Suspend' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
    { key: 'total_spent_rupees', header: 'Spent (INR)' },
    { key: 'total_flagged_rupees', header: 'Flagged (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'card_type', header: 'Card Type' },
    { key: 'department', header: 'Department' },
    { key: 'cards', header: 'Cards' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
    { key: 'total_spent_rupees', header: 'Spent (INR)' },
    { key: 'flagged_rupees', header: 'Flagged (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'cycle_close_date', header: 'Cycle Close' },
    { key: 'cards', header: 'Cards' },
    { key: 'total_spent_rupees', header: 'Spent (INR)' },
    { key: 'flagged_rupees', header: 'Flagged (INR)' },
    { key: 'out_of_policy_txns', header: 'Out-of-Policy Txns' },
    { key: 'fraud_alerts', header: 'Fraud Alerts' },
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

  const riskImpactCols: Column<RiskImpactRow>[] = [
    { key: 'risk_impact', header: 'Risk Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_recovery_rupees', header: 'Total Recovery (INR)' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'cardholder_name', header: 'Cardholder' },
    { key: 'department', header: 'Department' },
    { key: 'card_type', header: 'Card Type' },
    { key: 'cycle_close_date', header: 'Cycle Close' },
    { key: 'card_verdict', header: 'Verdict' },
    { key: 'utilization_pct', header: 'Util %' },
    { key: 'payment_status', header: 'Payment' },
    { key: 'out_of_policy_txn_count', header: 'Out-of-Policy' },
    { key: 'flagged_amount_rupees', header: 'Flagged (INR)' },
    { key: 'fraud_alert', header: 'Fraud Alert' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Corporate-Card &amp; Purchase-Card Spend-Control Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Card spend governance &mdash; cardholder &times; department &times; card type &times; monthly
        limit &times; spend this cycle &times; utilization % &times; top merchant category &times;
        receipts attached % &times; out-of-policy transactions &times; flagged amount &times; payment
        status &times; fraud alert &amp; CAPA closure. Founder-gated view: spend verdicts, department
        scorecards, card-type &times; department matrix, root-cause pareto, and risk-impact digest
        across financial-leakage &amp; fraud-loss surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Card verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No cards logged yet."
          rowKey={(r, i) => String(r.card_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Department spend-control scorecard</h2>
        <DataTable
          rows={deptRows}
          columns={deptCols}
          emptyMessage="No department rollups."
          rowKey={(r, i) => String(r.department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Card type &times; department matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No cards by type."
          rowKey={(r, i) => `${r.card_type}-${r.department}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Cycle-close spend trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.cycle_close_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Risk-impact digest</h2>
        <DataTable
          rows={riskImpactRows}
          columns={riskImpactCols}
          emptyMessage="No risk-impact rollups."
          rowKey={(r, i) => String(r.risk_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk card queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No high-risk cards."
          rowKey={(r, i) => `${r.cardholder_name}-${r.cycle_close_date}-${i}`}
        />
      </section>
    </main>
  );
}
