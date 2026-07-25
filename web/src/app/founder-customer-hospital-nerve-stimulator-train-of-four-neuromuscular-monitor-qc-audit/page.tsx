import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { qc_verdict: string; checks: number; pct: number };
type ScoreRow = {
  stim_mode: string;
  total_checks: number;
  passed: number;
  conditional: number;
  failed: number;
  out_of_tol: number;
  battery_fail: number;
  avg_tof_ratio_pct: number | null;
  pass_pct: number;
};
type MatrixRow = {
  stim_mode: string;
  qc_verdict: string;
  checks: number;
  avg_tof_ratio_pct: number | null;
  avg_current_error_ma: number | null;
};
type TrendRow = {
  cal_month: string;
  checks: number;
  passed: number;
  failed: number;
  out_of_tol: number;
  battery_fail: number;
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
type DigestRow = {
  device_model: string;
  checks: number;
  avg_set_current_ma: number | null;
  avg_measured_current_ma: number | null;
  avg_abs_current_error_ma: number | null;
  worst_current_error_ma: number | null;
  out_of_tol: number;
};
type RiskRow = {
  hospital_name: string;
  device_code: string;
  device_model: string;
  stim_mode: string;
  calibration_date: string;
  qc_verdict: string;
  set_current_ma: number | null;
  measured_current_ma: number | null;
  tof_ratio_pct: number | null;
  electrode_impedance_kohm: number | null;
  output_within_tol: boolean | null;
  battery_ok: boolean | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    scoreRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3430_qc_verdict_rollup'),
    supabase.rpc('founder_r3430_stim_mode_scorecard'),
    supabase.rpc('founder_r3430_stim_mode_verdict_matrix'),
    supabase.rpc('founder_r3430_monthly_calibration_trend'),
    supabase.rpc('founder_r3430_capa_status_board'),
    supabase.rpc('founder_r3430_root_cause_pareto'),
    supabase.rpc('founder_r3430_output_accuracy_impact_digest'),
    supabase.rpc('founder_r3430_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'pct', header: 'Share %' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'stim_mode', header: 'Stim Mode' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'failed', header: 'Failed' },
    { key: 'out_of_tol', header: 'Out of Tol' },
    { key: 'battery_fail', header: 'Battery Fail' },
    { key: 'avg_tof_ratio_pct', header: 'Avg TOF Ratio %' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'stim_mode', header: 'Stim Mode' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'avg_tof_ratio_pct', header: 'Avg TOF Ratio %' },
    { key: 'avg_current_error_ma', header: 'Avg Current Err mA' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'cal_month', header: 'Cal Month' },
    { key: 'checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'out_of_tol', header: 'Out of Tol' },
    { key: 'battery_fail', header: 'Battery Fail' },
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

  const digestCols: Column<DigestRow>[] = [
    { key: 'device_model', header: 'Device Model' },
    { key: 'checks', header: 'Checks' },
    { key: 'avg_set_current_ma', header: 'Avg Set mA' },
    { key: 'avg_measured_current_ma', header: 'Avg Measured mA' },
    { key: 'avg_abs_current_error_ma', header: 'Avg Abs Err mA' },
    { key: 'worst_current_error_ma', header: 'Worst Err mA' },
    { key: 'out_of_tol', header: 'Out of Tol' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'device_code', header: 'Device' },
    { key: 'device_model', header: 'Model' },
    { key: 'stim_mode', header: 'Stim Mode' },
    { key: 'calibration_date', header: 'Cal Date' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'set_current_ma', header: 'Set mA' },
    { key: 'measured_current_ma', header: 'Measured mA' },
    { key: 'tof_ratio_pct', header: 'TOF %' },
    { key: 'electrode_impedance_kohm', header: 'Impedance kOhm' },
    { key: 'output_within_tol', header: 'In Tol' },
    { key: 'battery_ok', header: 'Battery OK' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Nerve-Stimulator / Train-of-Four (TOF) Neuromuscular-Monitor QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Peripheral-nerve-stimulator &amp; TOF neuromuscular-monitor QA log — stim mode (single-twitch,
        train-of-four, tetanic, double-burst, post-tetanic-count) &times; set vs measured output current mA
        &times; pulse width &micro;s &times; TOF ratio % &times; electrode impedance k&Omega; &times; output
        tolerance &times; battery health &times; calibration date &amp; CAPA closure. Founder-gated view: QC
        verdicts, stim-mode scorecards, output-accuracy impact digest, root-cause pareto, and a high-risk
        (out-of-tolerance / failed) queue across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. QC verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No QC checks logged yet."
          rowKey={(r, i) => String(r.qc_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Stim-mode QC scorecard</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No stim-mode rollups."
          rowKey={(r, i) => String(r.stim_mode ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Stim-mode &times; verdict matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by stim mode."
          rowKey={(r, i) => `${r.stim_mode}-${r.qc_verdict}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly calibration trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.cal_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Output-accuracy impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No output-accuracy rollups."
          rowKey={(r, i) => String(r.device_model ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk QC queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk checks."
          rowKey={(r, i) => `${r.device_code}-${r.calibration_date}-${i}`}
        />
      </section>
    </main>
  );
}
