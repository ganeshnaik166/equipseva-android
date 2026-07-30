import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { clearing_status: string; accounts: number; pct: number };
type ScorecardRow = {
  account_type: string;
  total_accounts: number;
  cleared: number;
  clearing: number;
  aged: number;
  stale: number;
  unexplained: number;
  avg_cleared_pct: number;
  total_unexplained_rupees: number;
};
type MatrixRow = {
  account_type: string;
  clearing_status: string;
  accounts: number;
  total_unexplained_rupees: number;
  avg_oldest_item_days: number;
};
type TrendRow = {
  period_month: string;
  accounts: number;
  cleared: number;
  aged_or_stale: number;
  avg_cleared_pct: number;
  total_unexplained_rupees: number;
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
  materiality: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  account_code: string;
  account_name: string;
  account_type: string;
  period_month: string;
  clearing_status: string;
  closing_balance_rupees: number;
  items_count: number;
  oldest_item_days: number;
  unexplained_rupees: number;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    scoreRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3630_clearing_status_rollup'),
    supabase.rpc('founder_r3630_account_type_scorecard'),
    supabase.rpc('founder_r3630_account_type_status_matrix'),
    supabase.rpc('founder_r3630_monthly_clearing_trend'),
    supabase.rpc('founder_r3630_capa_status_board'),
    supabase.rpc('founder_r3630_root_cause_pareto'),
    supabase.rpc('founder_r3630_unexplained_impact_digest'),
    supabase.rpc('founder_r3630_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const scoreRows: ScorecardRow[] = (scoreRes.data as ScorecardRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'clearing_status', header: 'Clearing Status' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'pct', header: 'Share %' },
  ];

  const scoreCols: Column<ScorecardRow>[] = [
    { key: 'account_type', header: 'Account Type' },
    { key: 'total_accounts', header: 'Accounts' },
    { key: 'cleared', header: 'Cleared' },
    { key: 'clearing', header: 'Clearing' },
    { key: 'aged', header: 'Aged' },
    { key: 'stale', header: 'Stale' },
    { key: 'unexplained', header: 'Unexplained' },
    { key: 'avg_cleared_pct', header: 'Avg Cleared %' },
    { key: 'total_unexplained_rupees', header: 'Unexplained (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'account_type', header: 'Account Type' },
    { key: 'clearing_status', header: 'Clearing Status' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'total_unexplained_rupees', header: 'Unexplained (INR)' },
    { key: 'avg_oldest_item_days', header: 'Avg Oldest Item (days)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'cleared', header: 'Cleared / Clearing' },
    { key: 'aged_or_stale', header: 'Aged / Stale / Unexpl.' },
    { key: 'avg_cleared_pct', header: 'Avg Cleared %' },
    { key: 'total_unexplained_rupees', header: 'Unexplained (INR)' },
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
    { key: 'materiality', header: 'Materiality' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'account_code', header: 'Account' },
    { key: 'account_name', header: 'Name' },
    { key: 'account_type', header: 'Type' },
    { key: 'period_month', header: 'Month' },
    { key: 'clearing_status', header: 'Status' },
    { key: 'closing_balance_rupees', header: 'Closing Bal (INR)' },
    { key: 'items_count', header: 'Items' },
    { key: 'oldest_item_days', header: 'Oldest (days)' },
    { key: 'unexplained_rupees', header: 'Unexplained (INR)' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Suspense / Clearing-Account Unreconciled-Items Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated finance view of suspense &amp; clearing-account discipline — account type
        (bank suspense, payment-gateway clearing, GST input clearing, inter-company, payroll, GRN /
        inventory, customer &amp; vendor advance clearing) &times; clearing status &times; opening /
        debit / credit / closing balances &times; item count &times; oldest-item aging &times;
        cleared-within-month % &times; unexplained exposure &times; trend direction &amp; CAPA
        closure. Surfaces status distribution, account-type scorecards, root-cause pareto, and the
        stale / unexplained high-risk queue where closing balance &gt; unexplained residual.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Clearing-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No clearing accounts logged yet."
          rowKey={(r, i) => String(r.clearing_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Account-type scorecard</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No account-type rollups."
          rowKey={(r, i) => String(r.account_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Account type &times; clearing-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No accounts by type."
          rowKey={(r, i) => `${r.account_type}-${r.clearing_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly clearing trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Unexplained-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No impact rollups."
          rowKey={(r, i) => String(r.materiality ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk (stale / unexplained) queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk accounts."
          rowKey={(r, i) => `${r.account_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
