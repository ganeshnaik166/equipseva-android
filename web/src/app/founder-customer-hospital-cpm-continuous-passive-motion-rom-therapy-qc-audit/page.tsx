import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { qc_verdict: string; checks: number; pct: number };
type JointRow = {
  joint: string;
  total_checks: number;
  passed: number;
  conditional: number;
  failed: number;
  estop_fail: number;
  avg_rom_deviation_deg: number;
  pass_pct: number;
};
type MatrixRow = {
  joint: string;
  qc_verdict: string;
  checks: number;
  avg_rom_deviation_deg: number;
  avg_speed_deviation_cpm: number;
};
type TrendRow = {
  cal_month: string;
  checks: number;
  passed: number;
  failed: number;
  estop_fail: number;
  avg_rom_deviation_deg: number;
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
  accuracy_band: string;
  checks: number;
  avg_rom_deviation_deg: number;
  avg_speed_deviation_cpm: number;
  failed: number;
};
type RiskRow = {
  hospital_name: string;
  device_code: string;
  device_model: string;
  joint: string;
  calibration_date: string;
  qc_verdict: string;
  set_rom_deg: number | null;
  measured_rom_deg: number | null;
  rom_deviation_deg: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    jointRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3434_qc_verdict_rollup'),
    supabase.rpc('founder_r3434_joint_scorecard'),
    supabase.rpc('founder_r3434_joint_verdict_matrix'),
    supabase.rpc('founder_r3434_monthly_calibration_trend'),
    supabase.rpc('founder_r3434_capa_status_board'),
    supabase.rpc('founder_r3434_root_cause_pareto'),
    supabase.rpc('founder_r3434_rom_accuracy_impact_digest'),
    supabase.rpc('founder_r3434_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const jointRows: JointRow[] = (jointRes.data as JointRow[]) ?? [];
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

  const jointCols: Column<JointRow>[] = [
    { key: 'joint', header: 'Joint' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'failed', header: 'Failed' },
    { key: 'estop_fail', header: 'E-Stop Fail' },
    { key: 'avg_rom_deviation_deg', header: 'Avg ROM Dev deg' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'joint', header: 'Joint' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'avg_rom_deviation_deg', header: 'Avg ROM Dev deg' },
    { key: 'avg_speed_deviation_cpm', header: 'Avg Speed Dev cpm' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'cal_month', header: 'Cal Month' },
    { key: 'checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'estop_fail', header: 'E-Stop Fail' },
    { key: 'avg_rom_deviation_deg', header: 'Avg ROM Dev deg' },
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
    { key: 'accuracy_band', header: 'Accuracy Band' },
    { key: 'checks', header: 'Checks' },
    { key: 'avg_rom_deviation_deg', header: 'Avg ROM Dev deg' },
    { key: 'avg_speed_deviation_cpm', header: 'Avg Speed Dev cpm' },
    { key: 'failed', header: 'Failed' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'device_code', header: 'Device' },
    { key: 'device_model', header: 'Model' },
    { key: 'joint', header: 'Joint' },
    { key: 'calibration_date', header: 'Cal Date' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'set_rom_deg', header: 'Set ROM deg' },
    { key: 'measured_rom_deg', header: 'Meas ROM deg' },
    { key: 'rom_deviation_deg', header: 'ROM Dev deg' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        CPM (Continuous Passive Motion) ROM-Therapy QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Continuous passive motion rehab machine QA log — joint (knee, shoulder, elbow, hip, ankle,
        wrist) &times; set vs measured ROM angle &times; ROM deviation &times; set vs measured speed
        (cpm) &times; force limit (N) &times; emergency-stop test &times; calibration date &amp; CAPA
        closure. Founder-gated view: QC verdicts, joint scorecards, joint &times; verdict matrix,
        monthly calibration trend, root-cause pareto, ROM-accuracy impact digest, and the high-risk
        out-of-tolerance queue across NABH &amp; CDSCO surfaces.
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Joint QC scorecard</h2>
        <DataTable
          rows={jointRows}
          columns={jointCols}
          emptyMessage="No joint rollups."
          rowKey={(r, i) => String(r.joint ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Joint &times; verdict matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by joint."
          rowKey={(r, i) => `${r.joint}-${r.qc_verdict}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. ROM-accuracy impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No accuracy-band data."
          rowKey={(r, i) => String(r.accuracy_band ?? i)}
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
