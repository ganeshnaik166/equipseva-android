import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { qc_verdict: string; checks: number; pct: number };
type ScorecardRow = {
  defib_type: string;
  total_checks: number;
  passed: number;
  conditional: number;
  failed: number;
  sync_fail: number;
  expired_pad: number;
  low_battery: number;
  avg_deviation_pct: number;
  pass_pct: number;
};
type MatrixRow = {
  defib_type: string;
  qc_verdict: string;
  checks: number;
  avg_deviation_pct: number;
  avg_charge_time_sec: number;
};
type TrendRow = {
  cal_month: string;
  checks: number;
  passed: number;
  failed: number;
  avg_deviation_pct: number;
  avg_battery_health: number;
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
  defib_type: string;
  checks: number;
  avg_set_joules: number;
  avg_delivered_joules: number;
  avg_deviation_pct: number;
  out_of_tolerance: number;
};
type RiskRow = {
  hospital_name: string;
  device_code: string;
  device_model: string;
  defib_type: string;
  calibration_date: string | null;
  qc_verdict: string;
  energy_deviation_pct: number | null;
  charge_time_sec: number | null;
  battery_health_pct: number | null;
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
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3435_qc_verdict_rollup'),
    supabase.rpc('founder_r3435_defib_type_scorecard'),
    supabase.rpc('founder_r3435_defib_type_verdict_matrix'),
    supabase.rpc('founder_r3435_monthly_calibration_trend'),
    supabase.rpc('founder_r3435_capa_status_board'),
    supabase.rpc('founder_r3435_root_cause_pareto'),
    supabase.rpc('founder_r3435_energy_accuracy_digest'),
    supabase.rpc('founder_r3435_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const scorecardRows: ScorecardRow[] = (scorecardRes.data as ScorecardRow[]) ?? [];
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

  const scorecardCols: Column<ScorecardRow>[] = [
    { key: 'defib_type', header: 'Defib Type' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'failed', header: 'Failed' },
    { key: 'sync_fail', header: 'Sync Fail' },
    { key: 'expired_pad', header: 'Expired Pad' },
    { key: 'low_battery', header: 'Low Battery' },
    { key: 'avg_deviation_pct', header: 'Avg Deviation %' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'defib_type', header: 'Defib Type' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'avg_deviation_pct', header: 'Avg Deviation %' },
    { key: 'avg_charge_time_sec', header: 'Avg Charge Time s' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'cal_month', header: 'Cal Month' },
    { key: 'checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'avg_deviation_pct', header: 'Avg Deviation %' },
    { key: 'avg_battery_health', header: 'Avg Battery %' },
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
    { key: 'defib_type', header: 'Defib Type' },
    { key: 'checks', header: 'Checks' },
    { key: 'avg_set_joules', header: 'Avg Set (J)' },
    { key: 'avg_delivered_joules', header: 'Avg Delivered (J)' },
    { key: 'avg_deviation_pct', header: 'Avg Deviation %' },
    { key: 'out_of_tolerance', header: 'Out of Tolerance' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'device_code', header: 'Device' },
    { key: 'device_model', header: 'Model' },
    { key: 'defib_type', header: 'Type' },
    { key: 'calibration_date', header: 'Cal Date' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'energy_deviation_pct', header: 'Deviation %' },
    { key: 'charge_time_sec', header: 'Charge s' },
    { key: 'battery_health_pct', header: 'Battery %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Defibrillator Energy-Delivery / AED Pad QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Hospital defibrillator &amp; AED energy-delivery QA log — defib type (manual, AED,
        biphasic manual, wearable cardioverter) &times; set vs delivered joules &times; energy
        deviation &times; charge time &times; sync mode &times; pad expiry &times; battery health
        &times; ECG recorder &times; calibration date &amp; CAPA closure. Founder-gated view: QC
        verdicts, defib-type scorecards, energy-accuracy digest, root-cause pareto, and
        regulatory-impact CAPA board across NABH &amp; CDSCO surfaces.
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Defib-type scorecard</h2>
        <DataTable
          rows={scorecardRows}
          columns={scorecardCols}
          emptyMessage="No defib-type rollups."
          rowKey={(r, i) => String(r.defib_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Defib type &times; verdict matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by defib type."
          rowKey={(r, i) => `${r.defib_type}-${r.qc_verdict}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Energy-accuracy impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No energy-accuracy data."
          rowKey={(r, i) => String(r.defib_type ?? i)}
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
