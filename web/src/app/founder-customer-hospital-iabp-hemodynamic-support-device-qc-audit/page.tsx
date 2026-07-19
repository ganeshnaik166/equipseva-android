import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { readiness_verdict: string; devices: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_checks: number;
  mission_ready: number;
  conditional: number;
  not_ready: number;
  out_of_service: number;
  alarm_fail: number;
  transducer_fail: number;
  self_test_fail: number;
  ready_pct: number;
};
type MatrixRow = {
  device_type: string;
  unit: string;
  checks: number;
  mission_ready: number;
  not_ready_or_oos: number;
  avg_battery_minutes: number;
};
type TrendRow = {
  check_date: string;
  checks: number;
  mission_ready: number;
  not_ready: number;
  out_of_service: number;
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
  unit: string;
  check_date: string;
  readiness_verdict: string;
  augmentation_pressure_ok: string | null;
  alarm_test: string | null;
  battery_backup_minutes: number | null;
  self_test_pass: boolean | null;
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
    supabase.rpc('founder_r3318_readiness_verdict_rollup'),
    supabase.rpc('founder_r3318_hospital_scorecard'),
    supabase.rpc('founder_r3318_device_unit_matrix'),
    supabase.rpc('founder_r3318_daily_check_trend'),
    supabase.rpc('founder_r3318_capa_status_board'),
    supabase.rpc('founder_r3318_root_cause_pareto'),
    supabase.rpc('founder_r3318_regulatory_impact_digest'),
    supabase.rpc('founder_r3318_high_risk_queue'),
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
    { key: 'readiness_verdict', header: 'Readiness Verdict' },
    { key: 'devices', header: 'Devices' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'mission_ready', header: 'Mission Ready' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'not_ready', header: 'Not Ready' },
    { key: 'out_of_service', header: 'Out of Service' },
    { key: 'alarm_fail', header: 'Alarm Fail' },
    { key: 'transducer_fail', header: 'Transducer Fail' },
    { key: 'self_test_fail', header: 'Self-Test Fail' },
    { key: 'ready_pct', header: 'Ready %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'device_type', header: 'Device Type' },
    { key: 'unit', header: 'Unit' },
    { key: 'checks', header: 'Checks' },
    { key: 'mission_ready', header: 'Mission Ready' },
    { key: 'not_ready_or_oos', header: 'Not Ready / OOS' },
    { key: 'avg_battery_minutes', header: 'Avg Battery Min' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date' },
    { key: 'checks', header: 'Checks' },
    { key: 'mission_ready', header: 'Mission Ready' },
    { key: 'not_ready', header: 'Not Ready' },
    { key: 'out_of_service', header: 'Out of Service' },
    { key: 'alarm_fail', header: 'Alarm Fail' },
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
    { key: 'device_type', header: 'Type' },
    { key: 'unit', header: 'Unit' },
    { key: 'check_date', header: 'Date' },
    { key: 'readiness_verdict', header: 'Verdict' },
    { key: 'augmentation_pressure_ok', header: 'Augmentation' },
    { key: 'alarm_test', header: 'Alarm Test' },
    { key: 'battery_backup_minutes', header: 'Battery Min' },
    { key: 'self_test_pass', header: 'Self-Test' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital IABP &amp; Hemodynamic-Support Device QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Cardiac support-device readiness log — device type &times; unit &times; helium supply &times;
        timing-trigger accuracy &times; augmentation pressure &times; purge cycle &times; battery
        backup minutes &times; alarm test &times; transducer calibration &times; self-test &times;
        readiness verdict &amp; CAPA closure. Founder-gated view: readiness verdicts, hospital
        scorecards, device &times; unit matrix, root-cause pareto, and regulatory-impact digest
        across NABH &amp; CDSCO surfaces for IABP, Impella-type PVAD, and cardiac-output monitors.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Readiness verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No readiness checks logged yet."
          rowKey={(r, i) => String(r.readiness_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital readiness scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Device type &times; unit matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by device and unit."
          rowKey={(r, i) => `${r.device_type}-${r.unit}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily readiness-check trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk readiness queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk devices."
          rowKey={(r, i) => `${r.device_code}-${r.check_date}-${i}`}
        />
      </section>
    </main>
  );
}
