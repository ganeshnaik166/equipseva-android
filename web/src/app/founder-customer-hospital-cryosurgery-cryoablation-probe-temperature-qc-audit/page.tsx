import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { qc_verdict: string; checks: number; pct: number };
type ProbeRow = {
  probe_type: string;
  total_checks: number;
  passed: number;
  conditional: number;
  failed: number;
  thermocouple_fail: number;
  jt_fail: number;
  avg_iceball_mm: number | null;
  pass_pct: number;
};
type MatrixRow = {
  gas_type: string;
  qc_verdict: string;
  checks: number;
  avg_target_temp_c: number | null;
  avg_achieved_min_temp_c: number | null;
  avg_iceball_mm: number | null;
};
type TrendRow = {
  cal_month: string;
  checks: number;
  passed: number;
  conditional: number;
  failed: number;
  thermocouple_fail: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number | null;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type ThermalRow = {
  probe_type: string;
  checks: number;
  avg_target_temp_c: number | null;
  avg_achieved_min_temp_c: number | null;
  avg_temp_gap_c: number | null;
  avg_freeze_cycle_sec: number | null;
  avg_iceball_mm: number | null;
  out_of_tolerance: number;
};
type RiskRow = {
  hospital_name: string;
  device_code: string;
  device_model: string;
  probe_type: string;
  gas_type: string;
  calibration_date: string | null;
  qc_verdict: string;
  target_temp_c: number | null;
  achieved_min_temp_c: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    probeRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    thermalRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3426_qc_verdict_rollup'),
    supabase.rpc('founder_r3426_probe_type_scorecard'),
    supabase.rpc('founder_r3426_gas_type_verdict_matrix'),
    supabase.rpc('founder_r3426_monthly_calibration_trend'),
    supabase.rpc('founder_r3426_capa_status_board'),
    supabase.rpc('founder_r3426_root_cause_pareto'),
    supabase.rpc('founder_r3426_thermal_impact_digest'),
    supabase.rpc('founder_r3426_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const probeRows: ProbeRow[] = (probeRes.data as ProbeRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const thermalRows: ThermalRow[] = (thermalRes.data as ThermalRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'pct', header: 'Share %' },
  ];

  const probeCols: Column<ProbeRow>[] = [
    { key: 'probe_type', header: 'Probe Type' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'failed', header: 'Failed' },
    { key: 'thermocouple_fail', header: 'Thermocouple Fail' },
    { key: 'jt_fail', header: 'Joule-Thomson Fail' },
    { key: 'avg_iceball_mm', header: 'Avg Iceball mm' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'gas_type', header: 'Gas Type' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'avg_target_temp_c', header: 'Avg Target C' },
    { key: 'avg_achieved_min_temp_c', header: 'Avg Achieved Min C' },
    { key: 'avg_iceball_mm', header: 'Avg Iceball mm' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'cal_month', header: 'Cal Month' },
    { key: 'checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'failed', header: 'Failed' },
    { key: 'thermocouple_fail', header: 'Thermocouple Fail' },
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

  const thermalCols: Column<ThermalRow>[] = [
    { key: 'probe_type', header: 'Probe Type' },
    { key: 'checks', header: 'Checks' },
    { key: 'avg_target_temp_c', header: 'Avg Target C' },
    { key: 'avg_achieved_min_temp_c', header: 'Avg Achieved Min C' },
    { key: 'avg_temp_gap_c', header: 'Avg Temp Gap C' },
    { key: 'avg_freeze_cycle_sec', header: 'Avg Freeze Sec' },
    { key: 'avg_iceball_mm', header: 'Avg Iceball mm' },
    { key: 'out_of_tolerance', header: 'Out of Tolerance' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'device_code', header: 'Device' },
    { key: 'device_model', header: 'Model' },
    { key: 'probe_type', header: 'Probe' },
    { key: 'gas_type', header: 'Gas' },
    { key: 'calibration_date', header: 'Cal Date' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'target_temp_c', header: 'Target C' },
    { key: 'achieved_min_temp_c', header: 'Achieved Min C' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Cryosurgery / Cryoablation Probe Temperature QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Hospital cryosurgery &amp; cryoablation probe temperature QA log — probe type (cryoprobe,
        cryoablation catheter, cryospray, cryo needle) &times; gas type (nitrous oxide, argon, CO2,
        liquid nitrogen) &times; target vs achieved minimum temperature &times; freeze/thaw cycle
        &times; iceball diameter &times; thermocouple verification &times; Joule-Thomson check &times;
        calibration currency &amp; CAPA closure. Founder-gated view: QC verdicts, probe-type
        scorecards, thermal-impact digest, root-cause pareto, and CAPA board across NABH &amp; CDSCO
        surfaces.
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Probe-type QC scorecard</h2>
        <DataTable
          rows={probeRows}
          columns={probeCols}
          emptyMessage="No probe-type rollups."
          rowKey={(r, i) => String(r.probe_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Gas type &times; verdict matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by gas type."
          rowKey={(r, i) => `${r.gas_type}-${r.qc_verdict}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly calibration trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No calibration trend data."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Thermal-impact digest</h2>
        <DataTable
          rows={thermalRows}
          columns={thermalCols}
          emptyMessage="No thermal-impact data."
          rowKey={(r, i) => String(r.probe_type ?? i)}
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
