import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  yield_status: string;
  instruments: number;
  total_principal_rupees: number;
  pct: number;
};
type InstRow = {
  institution: string;
  deposits: number;
  total_principal_rupees: number;
  total_accrued_rupees: number;
  below_benchmark: number;
  idle_surplus: number;
  avg_yield_spread_pct: number;
};
type MatrixRow = {
  maturity_bucket: string;
  yield_status: string;
  instruments: number;
  total_principal_rupees: number;
  avg_yield_spread_pct: number;
};
type TrendRow = {
  period_month: string;
  deposits: number;
  total_principal_rupees: number;
  avg_interest_rate_pct: number;
  avg_benchmark_yield_pct: number;
  avg_yield_spread_pct: number;
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
type IdleRow = {
  institution: string;
  idle_surplus_instruments: number;
  below_benchmark_instruments: number;
  idle_principal_rupees: number;
  avg_yield_spread_pct: number;
};
type RiskRow = {
  instrument_code: string;
  instrument_name: string;
  institution: string;
  period_month: string;
  principal_rupees: number;
  interest_rate_pct: number;
  benchmark_yield_pct: number;
  yield_spread_pct: number;
  maturity_bucket: string;
  yield_status: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    instRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    idleRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3628_yield_status_rollup'),
    supabase.rpc('founder_r3628_institution_scorecard'),
    supabase.rpc('founder_r3628_bucket_status_matrix'),
    supabase.rpc('founder_r3628_monthly_yield_trend'),
    supabase.rpc('founder_r3628_capa_status_board'),
    supabase.rpc('founder_r3628_root_cause_pareto'),
    supabase.rpc('founder_r3628_idle_surplus_digest'),
    supabase.rpc('founder_r3628_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const instRows: InstRow[] = (instRes.data as InstRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const idleRows: IdleRow[] = (idleRes.data as IdleRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'yield_status', header: 'Yield Status' },
    { key: 'instruments', header: 'Instruments' },
    { key: 'total_principal_rupees', header: 'Total Principal (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const instCols: Column<InstRow>[] = [
    { key: 'institution', header: 'Institution' },
    { key: 'deposits', header: 'Deposits' },
    { key: 'total_principal_rupees', header: 'Total Principal (INR)' },
    { key: 'total_accrued_rupees', header: 'Accrued Interest (INR)' },
    { key: 'below_benchmark', header: 'Below Benchmark' },
    { key: 'idle_surplus', header: 'Idle Surplus' },
    { key: 'avg_yield_spread_pct', header: 'Avg Spread %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'maturity_bucket', header: 'Maturity Bucket' },
    { key: 'yield_status', header: 'Yield Status' },
    { key: 'instruments', header: 'Instruments' },
    { key: 'total_principal_rupees', header: 'Total Principal (INR)' },
    { key: 'avg_yield_spread_pct', header: 'Avg Spread %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'deposits', header: 'Deposits' },
    { key: 'total_principal_rupees', header: 'Total Principal (INR)' },
    { key: 'avg_interest_rate_pct', header: 'Avg Rate %' },
    { key: 'avg_benchmark_yield_pct', header: 'Avg Benchmark %' },
    { key: 'avg_yield_spread_pct', header: 'Avg Spread %' },
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

  const idleCols: Column<IdleRow>[] = [
    { key: 'institution', header: 'Institution' },
    { key: 'idle_surplus_instruments', header: 'Idle Surplus' },
    { key: 'below_benchmark_instruments', header: 'Below Benchmark' },
    { key: 'idle_principal_rupees', header: 'Idle Principal (INR)' },
    { key: 'avg_yield_spread_pct', header: 'Avg Spread %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'instrument_code', header: 'Instrument' },
    { key: 'instrument_name', header: 'Name' },
    { key: 'institution', header: 'Institution' },
    { key: 'period_month', header: 'Month' },
    { key: 'principal_rupees', header: 'Principal (INR)' },
    { key: 'interest_rate_pct', header: 'Rate %' },
    { key: 'benchmark_yield_pct', header: 'Benchmark %' },
    { key: 'yield_spread_pct', header: 'Spread %' },
    { key: 'maturity_bucket', header: 'Bucket' },
    { key: 'yield_status', header: 'Status' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Fixed-Deposit / Treasury-Investment Maturity &amp; Yield Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Fixed-deposit &amp; treasury-investment ladder &mdash; instrument &times; institution &times;
        principal &times; interest rate &times; accrued interest &times; maturity value &times;
        days-to-maturity &times; benchmark yield &times; yield spread &times; lien flag &times;
        maturity bucket &amp; CAPA closure. Founder-gated view: yield-status verdicts, institution
        scorecards, maturity-bucket &times; yield-status matrix, root-cause pareto, and idle-surplus
        digest across RBI deposit, Companies Act &amp; TDS surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Yield-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No treasury instruments logged yet."
          rowKey={(r, i) => String(r.yield_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Institution scorecard</h2>
        <DataTable
          rows={instRows}
          columns={instCols}
          emptyMessage="No institution rollups."
          rowKey={(r, i) => String(r.institution ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Maturity bucket &times; yield status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No instruments by maturity bucket."
          rowKey={(r, i) => `${r.maturity_bucket}-${r.yield_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly yield trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Idle-surplus digest</h2>
        <DataTable
          rows={idleRows}
          columns={idleCols}
          emptyMessage="No idle-surplus exposure."
          rowKey={(r, i) => String(r.institution ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk yield queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk instruments."
          rowKey={(r, i) => `${r.instrument_code}-${i}`}
        />
      </section>
    </main>
  );
}
