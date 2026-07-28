import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  liquidity_status: string;
  accounts: number;
  total_balance_rupees: number;
  total_idle_cash_rupees: number;
  pct: number;
};
type ScorecardRow = {
  pool_type: string;
  accounts: number;
  optimal: number;
  surplus: number;
  at_risk: number;
  total_swept_rupees: number;
  total_interest_benefit_rupees: number;
  total_idle_cash_rupees: number;
  optimal_pct: number;
};
type MatrixRow = {
  pool_type: string;
  liquidity_status: string;
  accounts: number;
  total_balance_rupees: number;
  total_idle_cash_rupees: number;
};
type TrendRow = {
  period_month: string;
  accounts: number;
  total_swept_rupees: number;
  total_pool_contribution_rupees: number;
  total_interest_benefit_rupees: number;
  total_idle_cash_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type DigestRow = {
  bank_name: string;
  accounts: number;
  total_idle_cash_rupees: number;
  total_balance_rupees: number;
  total_interest_benefit_rupees: number;
  idle_pct: number;
};
type RiskRow = {
  entity_account: string;
  bank_name: string;
  pool_type: string;
  liquidity_status: string;
  account_balance_rupees: number;
  target_balance_rupees: number;
  idle_cash_rupees: number;
  swept_rupees: number;
  period_month: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    scorecardRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3541_liquidity_status_rollup'),
    supabase.rpc('founder_r3541_pool_type_scorecard'),
    supabase.rpc('founder_r3541_pool_type_status_matrix'),
    supabase.rpc('founder_r3541_monthly_sweep_trend'),
    supabase.rpc('founder_r3541_capa_status_board'),
    supabase.rpc('founder_r3541_root_cause_pareto'),
    supabase.rpc('founder_r3541_idle_cash_impact_digest'),
    supabase.rpc('founder_r3541_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const scorecardRows: ScorecardRow[] = (scorecardRes.data as ScorecardRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'liquidity_status', header: 'Liquidity Status' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'total_balance_rupees', header: 'Total Balance (INR)' },
    { key: 'total_idle_cash_rupees', header: 'Total Idle Cash (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const scorecardCols: Column<ScorecardRow>[] = [
    { key: 'pool_type', header: 'Pool Type' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'optimal', header: 'Optimal' },
    { key: 'surplus', header: 'Surplus' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'total_swept_rupees', header: 'Total Swept (INR)' },
    { key: 'total_interest_benefit_rupees', header: 'Interest Benefit (INR)' },
    { key: 'total_idle_cash_rupees', header: 'Idle Cash (INR)' },
    { key: 'optimal_pct', header: 'Optimal %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'pool_type', header: 'Pool Type' },
    { key: 'liquidity_status', header: 'Liquidity Status' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'total_balance_rupees', header: 'Total Balance (INR)' },
    { key: 'total_idle_cash_rupees', header: 'Idle Cash (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'total_swept_rupees', header: 'Total Swept (INR)' },
    { key: 'total_pool_contribution_rupees', header: 'Pool Contribution (INR)' },
    { key: 'total_interest_benefit_rupees', header: 'Interest Benefit (INR)' },
    { key: 'total_idle_cash_rupees', header: 'Idle Cash (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_impact_rupees', header: 'Avg Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'bank_name', header: 'Bank' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'total_idle_cash_rupees', header: 'Total Idle Cash (INR)' },
    { key: 'total_balance_rupees', header: 'Total Balance (INR)' },
    { key: 'total_interest_benefit_rupees', header: 'Interest Benefit (INR)' },
    { key: 'idle_pct', header: 'Idle %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'entity_account', header: 'Entity Account' },
    { key: 'bank_name', header: 'Bank' },
    { key: 'pool_type', header: 'Pool Type' },
    { key: 'liquidity_status', header: 'Status' },
    { key: 'account_balance_rupees', header: 'Balance (INR)' },
    { key: 'target_balance_rupees', header: 'Target (INR)' },
    { key: 'idle_cash_rupees', header: 'Idle Cash (INR)' },
    { key: 'swept_rupees', header: 'Swept (INR)' },
    { key: 'period_month', header: 'Month' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Cash-Pooling / Notional-Sweeping Liquidity-Management Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Treasury cash-pooling and notional-sweeping ledger per entity-account &mdash; pool type
        (physical sweep, notional pool, ZBA, target balance, manual) &times; bank &times; account
        balance &times; target balance &times; swept &amp; pool contribution &times; interest benefit
        &times; idle cash &times; liquidity status &amp; CAPA closure. Founder-gated view: liquidity
        distribution, pool-type scorecards, root-cause pareto, and idle-cash impact digest across the
        group banking stack.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Liquidity-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No liquidity positions logged yet."
          rowKey={(r, i) => String(r.liquidity_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Pool-type scorecard</h2>
        <DataTable
          rows={scorecardRows}
          columns={scorecardCols}
          emptyMessage="No pool-type rollups."
          rowKey={(r, i) => String(r.pool_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Pool-type &times; liquidity-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No positions by pool type."
          rowKey={(r, i) => `${r.pool_type}-${r.liquidity_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly sweep trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Idle-cash impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No idle-cash rollups."
          rowKey={(r, i) => String(r.bank_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk liquidity queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk positions."
          rowKey={(r, i) => `${r.entity_account}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
