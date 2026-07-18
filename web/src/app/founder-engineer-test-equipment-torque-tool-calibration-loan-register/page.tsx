import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { register_verdict: string; items: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_items: number;
  fit_for_use: number;
  quarantined: number;
  recalls: number;
  overdue_cal: number;
  on_loan: number;
  not_returned: number;
  ready_pct: number;
};
type MatrixRow = {
  instrument_type: string;
  cal_status: string;
  items: number;
  on_loan: number;
  avg_error_pct: number | null;
};
type TrendRow = {
  cal_due_date: string;
  items: number;
  in_tolerance: number;
  overdue: number;
  out_of_tol: number;
  awaiting: number;
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
  hospital_name: string;
  store_location_code: string;
  asset_tag: string;
  instrument_type: string;
  cal_due_date: string;
  cal_status: string;
  loan_status: string;
  condition_on_return: string | null;
  register_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3144_register_verdict_rollup'),
    supabase.rpc('founder_r3144_hospital_scorecard'),
    supabase.rpc('founder_r3144_instrument_status_matrix'),
    supabase.rpc('founder_r3144_calibration_due_trend'),
    supabase.rpc('founder_r3144_capa_status_board'),
    supabase.rpc('founder_r3144_root_cause_pareto'),
    supabase.rpc('founder_r3144_regulatory_impact_digest'),
    supabase.rpc('founder_r3144_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'register_verdict', header: 'Verdict' },
    { key: 'items', header: 'Items' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_items', header: 'Items' },
    { key: 'fit_for_use', header: 'Fit For Use' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'recalls', header: 'Recalls' },
    { key: 'overdue_cal', header: 'Overdue Cal' },
    { key: 'on_loan', header: 'On Loan' },
    { key: 'not_returned', header: 'Not Returned' },
    { key: 'ready_pct', header: 'Ready %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'instrument_type', header: 'Instrument' },
    { key: 'cal_status', header: 'Cal Status' },
    { key: 'items', header: 'Items' },
    { key: 'on_loan', header: 'On Loan' },
    { key: 'avg_error_pct', header: 'Avg Error %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'cal_due_date', header: 'Cal Due Date' },
    { key: 'items', header: 'Items' },
    { key: 'in_tolerance', header: 'In Tolerance' },
    { key: 'overdue', header: 'Overdue / Expired' },
    { key: 'out_of_tol', header: 'Out Of Tol' },
    { key: 'awaiting', header: 'Awaiting Cal' },
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
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'store_location_code', header: 'Store' },
    { key: 'asset_tag', header: 'Asset' },
    { key: 'instrument_type', header: 'Instrument' },
    { key: 'cal_due_date', header: 'Cal Due' },
    { key: 'cal_status', header: 'Cal Status' },
    { key: 'loan_status', header: 'Loan' },
    { key: 'condition_on_return', header: 'Condition' },
    { key: 'register_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Test-Equipment &amp; Torque-Tool Calibration Loan Register
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        BMET test-gear register — instrument &times; asset tag &times; cal-due &times; cal-status &times;
        loaned-to engineer &times; loan/return &times; condition &amp; verdict, with CAPA closure. Founder-gated
        view: register verdicts, hospital scorecards, calibration-due trend, root-cause pareto, and
        regulatory-impact digest across NABH, NABL &amp; CDSCO traceability surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Register verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No test equipment logged yet."
          rowKey={(r, i) => String(r.register_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital register scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Instrument &times; cal-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No instruments by status."
          rowKey={(r, i) => `${r.instrument_type}-${r.cal_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Calibration-due trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.cal_due_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk / priority queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk items."
          rowKey={(r, i) => `${r.asset_tag}-${r.cal_due_date}-${i}`}
        />
      </section>
    </main>
  );
}
