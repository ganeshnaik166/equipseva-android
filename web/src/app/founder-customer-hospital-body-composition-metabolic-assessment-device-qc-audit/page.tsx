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
  phantom_fail: number;
  impedance_fail: number;
  gas_flow_fail: number;
  pass_pct: number;
};
type MatrixRow = {
  device_type: string;
  department: string;
  checks: number;
  passed: number;
  avg_impedance_error_pct: number | null;
  calibration_current_pct: number;
};
type TrendRow = {
  check_date: string;
  checks: number;
  passed: number;
  failed: number;
  impedance_fail: number;
  gas_analyzer_fail: number;
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
  electrode_condition: string | null;
  impedance_accuracy_error_pct: number | null;
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
    supabase.rpc('founder_r3311_qc_verdict_rollup'),
    supabase.rpc('founder_r3311_hospital_scorecard'),
    supabase.rpc('founder_r3311_device_department_matrix'),
    supabase.rpc('founder_r3311_daily_qc_trend'),
    supabase.rpc('founder_r3311_capa_status_board'),
    supabase.rpc('founder_r3311_root_cause_pareto'),
    supabase.rpc('founder_r3311_regulatory_impact_digest'),
    supabase.rpc('founder_r3311_high_risk_queue'),
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
    { key: 'phantom_fail', header: 'Phantom Fail', render: (r) => r.phantom_fail },
    { key: 'impedance_fail', header: 'Impedance Fail', render: (r) => r.impedance_fail },
    { key: 'gas_flow_fail', header: 'Gas/Flow Fail', render: (r) => r.gas_flow_fail },
    { key: 'pass_pct', header: 'Pass %', render: (r) => r.pass_pct },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'device_type', header: 'Device Type', render: (r) => r.device_type },
    { key: 'department', header: 'Department', render: (r) => r.department },
    { key: 'checks', header: 'Checks', render: (r) => r.checks },
    { key: 'passed', header: 'Passed', render: (r) => r.passed },
    { key: 'avg_impedance_error_pct', header: 'Avg Impedance Err %', render: (r) => r.avg_impedance_error_pct ?? '—' },
    { key: 'calibration_current_pct', header: 'Cal Current %', render: (r) => r.calibration_current_pct },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date', render: (r) => r.check_date },
    { key: 'checks', header: 'Checks', render: (r) => r.checks },
    { key: 'passed', header: 'Passed', render: (r) => r.passed },
    { key: 'failed', header: 'Failed', render: (r) => r.failed },
    { key: 'impedance_fail', header: 'Impedance Fail', render: (r) => r.impedance_fail },
    { key: 'gas_analyzer_fail', header: 'Gas-Analyzer Fail', render: (r) => r.gas_analyzer_fail },
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
    { key: 'electrode_condition', header: 'Electrode', render: (r) => r.electrode_condition ?? '—' },
    { key: 'impedance_accuracy_error_pct', header: 'Impedance Err %', render: (r) => r.impedance_accuracy_error_pct ?? '—' },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Body-Composition &amp; Metabolic-Assessment Device QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Nutrition, endocrinology &amp; sports-medicine device QA — device type &times; phantom reference
        &times; impedance accuracy % &times; gas-analyzer calibration &times; flow-sensor calibration
        &times; electrode condition &times; reference-gas stock &times; software equations &times; hygiene
        &times; calibration currency &amp; CAPA closure. Founder-gated view: BIA analyzers, segmental BIA,
        metabolic carts, indirect calorimeters &amp; RMR hood systems across NABH &amp; CDSCO surfaces.
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
