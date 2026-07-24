import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { qc_verdict: string; checks: number; pct: number };
type ScoreRow = {
  hospital_name: string;
  total_checks: number;
  passed: number;
  conditional: number;
  failed: number;
  download_fail: number;
  battery_issue: number;
  calibration_overdue: number;
  pass_pct: number;
};
type MatrixRow = { device_type: string; department: string; checks: number; passed: number; failed: number; avg_pressure_error_pct: number };
type TrendRow = { check_date: string; checks: number; passed: number; failed: number; download_fail: number; battery_issue: number };
type CapaRow = { capa_status: string; findings: number; avg_cost_rupees: number; overdue_flag: number };
type CauseRow = { root_cause: string; occurrences: number; total_cost_rupees: number; pct: number };
type RegRow = { regulatory_impact: string; findings: number; open_findings: number; total_cost_rupees: number };
type RiskRow = {
  hospital_name: string;
  device_code: string;
  device_type: string;
  department: string;
  check_date: string;
  qc_verdict: string;
  catheter_probe_condition: string;
  image_capture_ok: string;
  pressure_channel_accuracy_error_pct: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [verdictRes, scoreRes, matrixRes, trendRes, capaRes, causeRes, regRes, riskRes] = await Promise.all([
    supabase.rpc('founder_r3391_qc_verdict_rollup'),
    supabase.rpc('founder_r3391_hospital_scorecard'),
    supabase.rpc('founder_r3391_device_department_matrix'),
    supabase.rpc('founder_r3391_daily_qc_trend'),
    supabase.rpc('founder_r3391_capa_status_board'),
    supabase.rpc('founder_r3391_root_cause_pareto'),
    supabase.rpc('founder_r3391_regulatory_impact_digest'),
    supabase.rpc('founder_r3391_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'pct', header: 'Share %' },
  ];
  const scoreCols: Column<ScoreRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'failed', header: 'Failed' },
    { key: 'download_fail', header: 'Download Fail' },
    { key: 'battery_issue', header: 'Battery Issue' },
    { key: 'calibration_overdue', header: 'Cal Overdue' },
    { key: 'pass_pct', header: 'Pass %' },
  ];
  const matrixCols: Column<MatrixRow>[] = [
    { key: 'device_type', header: 'Device Type' },
    { key: 'department', header: 'Department' },
    { key: 'checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'avg_pressure_error_pct', header: 'Avg Pressure Err %' },
  ];
  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date' },
    { key: 'checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'download_fail', header: 'Download Fail' },
    { key: 'battery_issue', header: 'Battery Issue' },
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
    { key: 'device_code', header: 'Device' },
    { key: 'device_type', header: 'Device Type' },
    { key: 'department', header: 'Department' },
    { key: 'check_date', header: 'Date' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'catheter_probe_condition', header: 'Probe' },
    { key: 'image_capture_ok', header: 'Image' },
    { key: 'pressure_channel_accuracy_error_pct', header: 'Pressure Err %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        GI Capsule-Endoscopy &amp; Motility (Manometry) QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Capsule-endoscopy recorders, esophageal/anorectal manometry, pH-impedance &amp; breath-test analyzers
        &mdash; sensor cal &times; pressure-channel accuracy &times; battery &times; data download &times; probe
        &times; image capture &times; hygiene &amp; CAPA. Founder-gated view: verdict rollup, hospital scorecard,
        device &times; department matrix, and high-risk device queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. QC verdict distribution</h2>
        <DataTable rows={verdictRows} columns={verdictCols} emptyMessage="No devices checked yet." rowKey={(r, i) => String(r.qc_verdict ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital QC scorecard</h2>
        <DataTable rows={scoreRows} columns={scoreCols} emptyMessage="No hospital rollups." rowKey={(r, i) => String(r.hospital_name ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Device-type &times; department matrix</h2>
        <DataTable rows={matrixRows} columns={matrixCols} emptyMessage="No matrix data." rowKey={(r, i) => `${r.device_type}-${r.department}-${i}`} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily QC trend</h2>
        <DataTable rows={trendRows} columns={trendCols} emptyMessage="No trend data." rowKey={(r, i) => String(r.check_date ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable rows={capaRows} columns={capaCols} emptyMessage="No CAPA findings." rowKey={(r, i) => String(r.capa_status ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable rows={causeRows} columns={causeCols} emptyMessage="No root-cause data." rowKey={(r, i) => String(r.root_cause ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable rows={regRows} columns={regCols} emptyMessage="No regulatory-impact rollups." rowKey={(r, i) => String(r.regulatory_impact ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk device queue</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No high-risk devices." rowKey={(r, i) => `${r.device_code}-${i}`} />
      </section>
    </main>
  );
}
