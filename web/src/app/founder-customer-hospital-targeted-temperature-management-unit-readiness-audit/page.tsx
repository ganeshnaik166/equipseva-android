import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { readiness_verdict: string; checks: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_checks: number;
  mission_ready: number;
  conditional: number;
  not_ready: number;
  probe_issues: number;
  alarm_fail: number;
  disinfection_lapse: number;
  ready_pct: number;
};
type MatrixRow = {
  system_type: string;
  icu_unit: string;
  checks: number;
  mission_ready: number;
  avg_setpoint_error_c: number | null;
};
type TrendRow = {
  check_date: string;
  checks: number;
  mission_ready: number;
  not_ready: number;
  probe_issues: number;
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
  icu_unit: string;
  unit_code: string;
  check_date: string;
  readiness_verdict: string;
  pad_blanket_stock: string | null;
  tubing_condition: string | null;
  patient_temp_probe_ok: string | null;
  alarm_function_test: string | null;
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
    supabase.rpc('founder_r3259_readiness_verdict_rollup'),
    supabase.rpc('founder_r3259_hospital_scorecard'),
    supabase.rpc('founder_r3259_system_icu_matrix'),
    supabase.rpc('founder_r3259_daily_check_trend'),
    supabase.rpc('founder_r3259_capa_status_board'),
    supabase.rpc('founder_r3259_root_cause_pareto'),
    supabase.rpc('founder_r3259_regulatory_impact_digest'),
    supabase.rpc('founder_r3259_high_risk_queue'),
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
    { key: 'readiness_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'mission_ready', header: 'Mission-Ready' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'not_ready', header: 'Not Ready' },
    { key: 'probe_issues', header: 'Probe Issues' },
    { key: 'alarm_fail', header: 'Alarm Fail' },
    { key: 'disinfection_lapse', header: 'Disinfection Lapse' },
    { key: 'ready_pct', header: 'Ready %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'system_type', header: 'System Type' },
    { key: 'icu_unit', header: 'ICU Unit' },
    { key: 'checks', header: 'Checks' },
    { key: 'mission_ready', header: 'Mission-Ready' },
    { key: 'avg_setpoint_error_c', header: 'Avg Setpoint Err C' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date' },
    { key: 'checks', header: 'Checks' },
    { key: 'mission_ready', header: 'Mission-Ready' },
    { key: 'not_ready', header: 'Not Ready' },
    { key: 'probe_issues', header: 'Probe Issues' },
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
    { key: 'icu_unit', header: 'ICU' },
    { key: 'unit_code', header: 'Unit' },
    { key: 'check_date', header: 'Date' },
    { key: 'readiness_verdict', header: 'Verdict' },
    { key: 'pad_blanket_stock', header: 'Pad/Blanket Stock' },
    { key: 'tubing_condition', header: 'Tubing' },
    { key: 'patient_temp_probe_ok', header: 'Temp Probe' },
    { key: 'alarm_function_test', header: 'Alarm Test' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Targeted-Temperature-Management Unit Readiness Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        ICU TTM readiness log — system type &times; setpoint accuracy &deg;C &times; water level
        &times; pad/blanket stock &times; tubing condition &times; patient temp probe &times;
        alarm function test &times; disinfection cycle &amp; response drill compliance with CAPA
        closure. Founder-gated view: readiness verdicts, hospital scorecards, root-cause pareto,
        and regulatory-impact digest across NABH &amp; CDSCO surfaces.
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. System type &times; ICU unit matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by system type."
          rowKey={(r, i) => `${r.system_type}-${r.icu_unit}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily readiness check trend</h2>
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
          emptyMessage="No high-risk checks."
          rowKey={(r, i) => `${r.unit_code}-${r.check_date}-${i}`}
        />
      </section>
    </main>
  );
}
