import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { qc_verdict: string; checks: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_checks: number;
  passed: number;
  conditional: number;
  failed: number;
  cutoff_fail: number;
  alarm_fail: number;
  calibration_overdue: number;
  pass_pct: number;
};
type MatrixRow = {
  device_type: string;
  department: string;
  checks: number;
  passed: number;
  avg_temp_error_c: number;
  cutoff_fail: number;
};
type TrendRow = {
  check_date: string;
  checks: number;
  passed: number;
  failed: number;
  cutoff_fail: number;
  alarm_fail: number;
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
  device_code: string;
  device_type: string;
  department: string;
  check_date: string;
  qc_verdict: string;
  over_temp_cutoff_ok: boolean | null;
  airflow_filter_condition: string | null;
  hose_blanket_condition: string | null;
  alarm_test: string | null;
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
    supabase.rpc('founder_r3366_qc_verdict_rollup'),
    supabase.rpc('founder_r3366_hospital_scorecard'),
    supabase.rpc('founder_r3366_device_type_department_matrix'),
    supabase.rpc('founder_r3366_daily_qc_trend'),
    supabase.rpc('founder_r3366_capa_status_board'),
    supabase.rpc('founder_r3366_root_cause_pareto'),
    supabase.rpc('founder_r3366_regulatory_impact_digest'),
    supabase.rpc('founder_r3366_high_risk_queue'),
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
    { key: 'qc_verdict', header: 'Verdict', render: (r) => r.qc_verdict },
    { key: 'checks', header: 'Checks', render: (r) => r.checks },
    { key: 'pct', header: 'Share %', render: (r) => r.pct },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'total_checks', header: 'Checks', render: (r) => r.total_checks },
    { key: 'passed', header: 'Passed', render: (r) => r.passed },
    { key: 'conditional', header: 'Conditional', render: (r) => r.conditional },
    { key: 'failed', header: 'Failed', render: (r) => r.failed },
    { key: 'cutoff_fail', header: 'Cutoff Fail', render: (r) => r.cutoff_fail },
    { key: 'alarm_fail', header: 'Alarm Fail', render: (r) => r.alarm_fail },
    { key: 'calibration_overdue', header: 'Calib Overdue', render: (r) => r.calibration_overdue },
    { key: 'pass_pct', header: 'Pass %', render: (r) => r.pass_pct },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'device_type', header: 'Device Type', render: (r) => r.device_type },
    { key: 'department', header: 'Department', render: (r) => r.department },
    { key: 'checks', header: 'Checks', render: (r) => r.checks },
    { key: 'passed', header: 'Passed', render: (r) => r.passed },
    { key: 'avg_temp_error_c', header: 'Avg Temp Err C', render: (r) => r.avg_temp_error_c },
    { key: 'cutoff_fail', header: 'Cutoff Fail', render: (r) => r.cutoff_fail },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date', render: (r) => r.check_date },
    { key: 'checks', header: 'Checks', render: (r) => r.checks },
    { key: 'passed', header: 'Passed', render: (r) => r.passed },
    { key: 'failed', header: 'Failed', render: (r) => r.failed },
    { key: 'cutoff_fail', header: 'Cutoff Fail', render: (r) => r.cutoff_fail },
    { key: 'alarm_fail', header: 'Alarm Fail', render: (r) => r.alarm_fail },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status', render: (r) => r.capa_status },
    { key: 'findings', header: 'Findings', render: (r) => r.findings },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)', render: (r) => r.avg_cost_rupees },
    { key: 'overdue_flag', header: 'Overdue / Escalated', render: (r) => r.overdue_flag },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause', render: (r) => r.root_cause },
    { key: 'occurrences', header: 'Occurrences', render: (r) => r.occurrences },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)', render: (r) => r.total_cost_rupees },
    { key: 'pct', header: 'Share %', render: (r) => r.pct },
  ];

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact', render: (r) => r.regulatory_impact },
    { key: 'findings', header: 'Findings', render: (r) => r.findings },
    { key: 'open_findings', header: 'Open', render: (r) => r.open_findings },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)', render: (r) => r.total_cost_rupees },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'device_code', header: 'Device', render: (r) => r.device_code },
    { key: 'device_type', header: 'Type', render: (r) => r.device_type },
    { key: 'department', header: 'Department', render: (r) => r.department },
    { key: 'check_date', header: 'Date', render: (r) => r.check_date },
    { key: 'qc_verdict', header: 'Verdict', render: (r) => r.qc_verdict },
    { key: 'over_temp_cutoff_ok', header: 'Cutoff OK', render: (r) => (r.over_temp_cutoff_ok === null ? '' : r.over_temp_cutoff_ok ? 'yes' : 'no') },
    { key: 'airflow_filter_condition', header: 'Filter', render: (r) => r.airflow_filter_condition },
    { key: 'hose_blanket_condition', header: 'Hose / Blanket', render: (r) => r.hose_blanket_condition },
    { key: 'alarm_test', header: 'Alarm', render: (r) => r.alarm_test },
    { key: 'notes', header: 'Notes', render: (r) => r.notes },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Perioperative Patient-Warming Device QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Perioperative warming QA log — device type &times; temperature-accuracy error C &times;
        over-temp cutoff &times; airflow-filter condition &times; hose/blanket condition &times;
        burn-risk assessment &times; cabinet setpoint &times; alarm test &times; hygiene &times;
        calibration currency &amp; CAPA closure. Founder-gated view: QC verdicts, hospital
        scorecards, root-cause pareto, and regulatory-impact digest across NABH &amp; CDSCO
        surfaces for forced-air warmers, warming cabinets &amp; conductive mattresses.
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital QC scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Device type &times; department matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by device type."
          rowKey={(r, i) => `${r.device_type}-${r.department}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily QC trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.check_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk QC queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk checks."
          rowKey={(r, i) => `${r.device_code}-${r.check_date}-${i}`}
        />
      </section>
    </main>
  );
}
