import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  transfer_status: string;
  instruments: number;
  total_due_rupees: number;
  pct: number;
};
type YearRow = {
  dividend_year: string;
  instruments: number;
  shareholders: number;
  total_unclaimed_rupees: number;
  total_claimed_rupees: number;
  total_due_rupees: number;
  transferred_rupees: number;
  overdue: number;
};
type MatrixRow = {
  dividend_year: string;
  transfer_status: string;
  instruments: number;
  total_due_rupees: number;
  shareholders: number;
};
type TrendRow = {
  period_month: string;
  instruments: number;
  total_transferred_rupees: number;
  total_due_rupees: number;
  shares_transfer_due: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_exposure_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_exposure_rupees: number;
  pct: number;
};
type ExposureRow = {
  trend_dir: string;
  instruments: number;
  total_unclaimed_rupees: number;
  total_due_rupees: number;
  total_transferred_rupees: number;
  shareholders: number;
};
type RiskRow = {
  dividend_year: string;
  instrument_ref: string;
  period_month: string;
  unclaimed_amount_rupees: number;
  due_for_transfer_rupees: number;
  shareholders_count: number;
  days_to_7yr_deadline: number;
  shares_transfer_due: number;
  transfer_status: string;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    yearRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    exposureRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3637_transfer_status_rollup'),
    supabase.rpc('founder_r3637_dividend_year_scorecard'),
    supabase.rpc('founder_r3637_year_status_matrix'),
    supabase.rpc('founder_r3637_monthly_transfer_trend'),
    supabase.rpc('founder_r3637_capa_status_board'),
    supabase.rpc('founder_r3637_root_cause_pareto'),
    supabase.rpc('founder_r3637_iepf_exposure_digest'),
    supabase.rpc('founder_r3637_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const yearRows: YearRow[] = (yearRes.data as YearRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const exposureRows: ExposureRow[] = (exposureRes.data as ExposureRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'transfer_status', header: 'Transfer Status' },
    { key: 'instruments', header: 'Instruments' },
    { key: 'total_due_rupees', header: 'Due for Transfer (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const yearCols: Column<YearRow>[] = [
    { key: 'dividend_year', header: 'Dividend Year' },
    { key: 'instruments', header: 'Instruments' },
    { key: 'shareholders', header: 'Shareholders' },
    { key: 'total_unclaimed_rupees', header: 'Unclaimed (INR)' },
    { key: 'total_claimed_rupees', header: 'Claimed (INR)' },
    { key: 'total_due_rupees', header: 'Due for Transfer (INR)' },
    { key: 'transferred_rupees', header: 'Transferred to IEPF (INR)' },
    { key: 'overdue', header: 'Overdue' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'dividend_year', header: 'Dividend Year' },
    { key: 'transfer_status', header: 'Transfer Status' },
    { key: 'instruments', header: 'Instruments' },
    { key: 'total_due_rupees', header: 'Due for Transfer (INR)' },
    { key: 'shareholders', header: 'Shareholders' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'instruments', header: 'Instruments' },
    { key: 'total_transferred_rupees', header: 'Transferred (INR)' },
    { key: 'total_due_rupees', header: 'Due for Transfer (INR)' },
    { key: 'shares_transfer_due', header: 'Shares Transfer Due' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_exposure_rupees', header: 'Avg Exposure (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_exposure_rupees', header: 'Total Exposure (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const exposureCols: Column<ExposureRow>[] = [
    { key: 'trend_dir', header: 'Trend' },
    { key: 'instruments', header: 'Instruments' },
    { key: 'total_unclaimed_rupees', header: 'Unclaimed (INR)' },
    { key: 'total_due_rupees', header: 'Due for Transfer (INR)' },
    { key: 'total_transferred_rupees', header: 'Transferred (INR)' },
    { key: 'shareholders', header: 'Shareholders' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'dividend_year', header: 'Year' },
    { key: 'instrument_ref', header: 'Instrument' },
    { key: 'period_month', header: 'Month' },
    { key: 'unclaimed_amount_rupees', header: 'Unclaimed (INR)' },
    { key: 'due_for_transfer_rupees', header: 'Due for Transfer (INR)' },
    { key: 'shareholders_count', header: 'Shareholders' },
    { key: 'days_to_7yr_deadline', header: 'Days to 7-yr Deadline' },
    { key: 'shares_transfer_due', header: 'Shares Due' },
    { key: 'transfer_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Unclaimed-Dividend / IEPF Transfer Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Unclaimed-dividend log &mdash; dividend year &times; instrument &times; unclaimed &amp;
        claimed &amp; transferred amounts &times; due-for-transfer &times; shareholders &times;
        days-to-7yr-deadline &times; shares-transfer-due &times; transfer status &amp; CAPA closure.
        Founder-gated view: transfer-status distribution, dividend-year scorecards, year &times;
        status matrix, root-cause pareto, and IEPF-exposure digest across Companies Act (IEPF rules)
        &amp; MCA-penalty surfaces &mdash; flagging instruments overdue or due for transfer to the
        Investor Education &amp; Protection Fund.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Transfer-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No instruments logged yet."
          rowKey={(r, i) => String(r.transfer_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Dividend-year scorecard</h2>
        <DataTable
          rows={yearRows}
          columns={yearCols}
          emptyMessage="No dividend-year rollups."
          rowKey={(r, i) => String(r.dividend_year ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Dividend-year &times; transfer-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No instruments by year."
          rowKey={(r, i) => `${r.dividend_year}-${r.transfer_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly transfer trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. IEPF-exposure digest</h2>
        <DataTable
          rows={exposureRows}
          columns={exposureCols}
          emptyMessage="No exposure rollups."
          rowKey={(r, i) => String(r.trend_dir ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk transfer queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk instruments."
          rowKey={(r, i) => `${r.instrument_ref}-${i}`}
        />
      </section>
    </main>
  );
}
