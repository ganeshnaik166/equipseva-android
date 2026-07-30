import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  refinance_status: string;
  facilities: number;
  total_outstanding_rupees: number;
  pct: number;
};
type LenderRow = {
  lender: string;
  tranches: number;
  refinanced: number;
  committed: number;
  in_progress: number;
  at_risk: number;
  unaddressed: number;
  total_outstanding_rupees: number;
  avg_rollover_risk: number;
  addressed_pct: number;
};
type MatrixRow = {
  maturity_bucket: string;
  refinance_status: string;
  tranches: number;
  total_outstanding_rupees: number;
  avg_rollover_risk: number;
};
type TrendRow = {
  period_month: string;
  tranches: number;
  total_principal_due_rupees: number;
  total_outstanding_rupees: number;
  at_risk: number;
  avg_rollover_risk: number;
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
type DigestRow = {
  maturity_bucket: string;
  tranches: number;
  total_outstanding_rupees: number;
  total_principal_due_rupees: number;
  avg_rollover_risk: number;
  avg_covenant_headroom_pct: number;
  at_risk: number;
};
type RiskRow = {
  facility_name: string;
  lender: string;
  tranche_code: string;
  period_month: string;
  maturity_bucket: string;
  refinance_status: string;
  outstanding_rupees: number | null;
  rollover_risk_score: number | null;
  covenant_headroom_pct: number | null;
  next_reset_date: string | null;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    lenderRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3610_refinance_status_rollup'),
    supabase.rpc('founder_r3610_lender_scorecard'),
    supabase.rpc('founder_r3610_bucket_status_matrix'),
    supabase.rpc('founder_r3610_monthly_maturity_trend'),
    supabase.rpc('founder_r3610_capa_status_board'),
    supabase.rpc('founder_r3610_root_cause_pareto'),
    supabase.rpc('founder_r3610_rollover_risk_digest'),
    supabase.rpc('founder_r3610_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const lenderRows: LenderRow[] = (lenderRes.data as LenderRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'refinance_status', header: 'Refinance Status' },
    { key: 'facilities', header: 'Facilities' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const lenderCols: Column<LenderRow>[] = [
    { key: 'lender', header: 'Lender' },
    { key: 'tranches', header: 'Tranches' },
    { key: 'refinanced', header: 'Refinanced' },
    { key: 'committed', header: 'Committed' },
    { key: 'in_progress', header: 'In Progress' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'unaddressed', header: 'Unaddressed' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'avg_rollover_risk', header: 'Avg Rollover Risk' },
    { key: 'addressed_pct', header: 'Addressed %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'maturity_bucket', header: 'Maturity Bucket' },
    { key: 'refinance_status', header: 'Refinance Status' },
    { key: 'tranches', header: 'Tranches' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'avg_rollover_risk', header: 'Avg Rollover Risk' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period Month' },
    { key: 'tranches', header: 'Tranches' },
    { key: 'total_principal_due_rupees', header: 'Principal Due (INR)' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'avg_rollover_risk', header: 'Avg Rollover Risk' },
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

  const digestCols: Column<DigestRow>[] = [
    { key: 'maturity_bucket', header: 'Maturity Bucket' },
    { key: 'tranches', header: 'Tranches' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'total_principal_due_rupees', header: 'Principal Due (INR)' },
    { key: 'avg_rollover_risk', header: 'Avg Rollover Risk' },
    { key: 'avg_covenant_headroom_pct', header: 'Avg Covenant Headroom %' },
    { key: 'at_risk', header: 'At Risk' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'facility_name', header: 'Facility' },
    { key: 'lender', header: 'Lender' },
    { key: 'tranche_code', header: 'Tranche' },
    { key: 'period_month', header: 'Period' },
    { key: 'maturity_bucket', header: 'Bucket' },
    { key: 'refinance_status', header: 'Status' },
    { key: 'outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'rollover_risk_score', header: 'Rollover Risk' },
    { key: 'covenant_headroom_pct', header: 'Headroom %' },
    { key: 'next_reset_date', header: 'Next Reset' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Debt Maturity Ladder / Refinancing Profile Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated debt maturity ladder &amp; refinancing profile — per-facility outstanding,
        interest-rate reset exposure, principal due, rollover-risk score &amp; covenant headroom
        &times; lender &times; maturity bucket (0&ndash;6 months &rarr; over 5 years) &times; refinance
        status (refinanced, committed, in progress, at risk, unaddressed) &amp; CAPA closure. Views:
        status distribution, lender scorecards, bucket &times; status matrix, monthly maturity trend,
        root-cause pareto, rollover-risk digest, and the high-risk refinancing queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Refinance status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No debt facilities logged yet."
          rowKey={(r, i) => String(r.refinance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Lender scorecard</h2>
        <DataTable
          rows={lenderRows}
          columns={lenderCols}
          emptyMessage="No lender rollups."
          rowKey={(r, i) => String(r.lender ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Maturity bucket &times; refinance status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.maturity_bucket}-${r.refinance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly maturity trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Rollover-risk digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No rollover-risk rollups."
          rowKey={(r, i) => String(r.maturity_bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk refinancing queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk facilities."
          rowKey={(r, i) => `${r.tranche_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
