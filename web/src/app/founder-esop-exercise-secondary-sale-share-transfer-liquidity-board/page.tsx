import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { transaction_verdict: string; transactions: number; pct: number };
type HolderRow = {
  holder_type: string;
  total_transactions: number;
  completed: number;
  in_progress: number;
  blocked: number;
  expiring: number;
  lapsed: number;
  total_notional_gain_rupees: number;
  completed_pct: number;
};
type MatrixRow = {
  holder_type: string;
  transaction_type: string;
  transactions: number;
  completed: number;
  avg_notional_gain_rupees: number;
  avg_tax_withholding_rupees: number;
};
type TrendRow = {
  transaction_date: string;
  transactions: number;
  completed: number;
  blocked: number;
  expiring: number;
  total_notional_gain_rupees: number;
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
  holder_name: string;
  holder_type: string;
  transaction_type: string;
  transaction_date: string;
  transaction_verdict: string;
  board_approval_status: string | null;
  settlement_status: string | null;
  vesting_status: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    holderRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3301_transaction_verdict_rollup'),
    supabase.rpc('founder_r3301_holder_scorecard'),
    supabase.rpc('founder_r3301_holder_transaction_matrix'),
    supabase.rpc('founder_r3301_daily_transaction_trend'),
    supabase.rpc('founder_r3301_capa_status_board'),
    supabase.rpc('founder_r3301_root_cause_pareto'),
    supabase.rpc('founder_r3301_regulatory_impact_digest'),
    supabase.rpc('founder_r3301_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const holderRows: HolderRow[] = (holderRes.data as HolderRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'transaction_verdict', header: 'Verdict' },
    { key: 'transactions', header: 'Transactions' },
    { key: 'pct', header: 'Share %' },
  ];

  const holderCols: Column<HolderRow>[] = [
    { key: 'holder_type', header: 'Holder Type' },
    { key: 'total_transactions', header: 'Transactions' },
    { key: 'completed', header: 'Completed' },
    { key: 'in_progress', header: 'In Progress' },
    { key: 'blocked', header: 'Blocked' },
    { key: 'expiring', header: 'Expiring' },
    { key: 'lapsed', header: 'Lapsed' },
    { key: 'total_notional_gain_rupees', header: 'Notional Gain (INR)' },
    { key: 'completed_pct', header: 'Completed %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'holder_type', header: 'Holder Type' },
    { key: 'transaction_type', header: 'Transaction Type' },
    { key: 'transactions', header: 'Transactions' },
    { key: 'completed', header: 'Completed' },
    { key: 'avg_notional_gain_rupees', header: 'Avg Notional Gain (INR)' },
    { key: 'avg_tax_withholding_rupees', header: 'Avg TDS (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'transaction_date', header: 'Date' },
    { key: 'transactions', header: 'Transactions' },
    { key: 'completed', header: 'Completed' },
    { key: 'blocked', header: 'Blocked' },
    { key: 'expiring', header: 'Expiring' },
    { key: 'total_notional_gain_rupees', header: 'Notional Gain (INR)' },
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
    { key: 'holder_name', header: 'Holder' },
    { key: 'holder_type', header: 'Type' },
    { key: 'transaction_type', header: 'Transaction' },
    { key: 'transaction_date', header: 'Date' },
    { key: 'transaction_verdict', header: 'Verdict' },
    { key: 'board_approval_status', header: 'Board Approval' },
    { key: 'settlement_status', header: 'Settlement' },
    { key: 'vesting_status', header: 'Vesting' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder ESOP Exercise, Secondary-Sale &amp; Share-Transfer Liquidity Governance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Cap-table liquidity log — holder type &times; transaction type &times; options/shares &times;
        strike price &times; 409A FMV &times; exercise cost &times; notional gain &times; TDS
        withholding &times; vesting status &times; board approval &times; settlement &amp; CAPA closure.
        Founder-gated view: transaction verdicts, holder scorecards, root-cause pareto, and
        regulatory-impact digest across SEBI, RBI/FEMA &amp; income-tax surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Transaction verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No liquidity transactions logged yet."
          rowKey={(r, i) => String(r.transaction_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Holder-type liquidity scorecard</h2>
        <DataTable
          rows={holderRows}
          columns={holderCols}
          emptyMessage="No holder rollups."
          rowKey={(r, i) => String(r.holder_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Holder-type &times; transaction-type matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No transactions by holder and type."
          rowKey={(r, i) => `${r.holder_type}-${r.transaction_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily transaction trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.transaction_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk liquidity queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk transactions."
          rowKey={(r, i) => `${r.holder_name}-${r.transaction_date}-${i}`}
        />
      </section>
    </main>
  );
}
