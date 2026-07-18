import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { safety_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  passed: number;
  failed: number;
  quarantined: number;
  cutout_fail: number;
  probe_issues: number;
  alarm_issues: number;
  pass_pct: number;
};
type MatrixRow = {
  device_type: string;
  control_mode: string;
  audits: number;
  passed: number;
  avg_temp_error: number;
};
type TrendRow = {
  test_date: string;
  audits: number;
  passed: number;
  failed: number;
  cutout_fail: number;
  alarm_issues: number;
  avg_temp_error: number;
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
  nicu_unit_code: string;
  device_asset_tag: string;
  device_type: string;
  test_date: string;
  safety_verdict: string;
  temperature_error_c: number | null;
  over_temp_cutout_test: string | null;
  skin_probe_accuracy: string | null;
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
    supabase.rpc('founder_r3166_safety_verdict_rollup'),
    supabase.rpc('founder_r3166_hospital_scorecard'),
    supabase.rpc('founder_r3166_device_control_matrix'),
    supabase.rpc('founder_r3166_thermal_daily_trend'),
    supabase.rpc('founder_r3166_capa_status_board'),
    supabase.rpc('founder_r3166_root_cause_pareto'),
    supabase.rpc('founder_r3166_regulatory_impact_digest'),
    supabase.rpc('founder_r3166_high_risk_devices'),
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
    { key: 'safety_verdict', header: 'Verdict' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'cutout_fail', header: 'Cutout Fail' },
    { key: 'probe_issues', header: 'Probe Issues' },
    { key: 'alarm_issues', header: 'Alarm Issues' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'device_type', header: 'Device Type' },
    { key: 'control_mode', header: 'Control Mode' },
    { key: 'audits', header: 'Audits' },
    { key: 'passed', header: 'Passed' },
    { key: 'avg_temp_error', header: 'Avg |Temp Err| °C' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'test_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'cutout_fail', header: 'Cutout Fail' },
    { key: 'alarm_issues', header: 'Alarm Issues' },
    { key: 'avg_temp_error', header: 'Avg |Temp Err| °C' },
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
    { key: 'nicu_unit_code', header: 'NICU' },
    { key: 'device_asset_tag', header: 'Asset' },
    { key: 'device_type', header: 'Device' },
    { key: 'test_date', header: 'Date' },
    { key: 'safety_verdict', header: 'Verdict' },
    { key: 'temperature_error_c', header: 'Temp Err °C' },
    { key: 'over_temp_cutout_test', header: 'Cutout' },
    { key: 'skin_probe_accuracy', header: 'Probe' },
    { key: 'alarm_test', header: 'Alarm' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital NICU Incubator &amp; Radiant-Warmer Thermal-Safety Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        NICU thermal QA log — device &times; set/measured temp &times; temperature error &times;
        skin-probe accuracy &times; over-temp cutout &times; humidity &times; alarm test &amp; CAPA
        closure. Founder-gated view: safety verdicts, hospital scorecards, root-cause pareto, and
        regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Safety verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No audits logged yet."
          rowKey={(r, i) => String(r.safety_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital thermal-safety scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Device type &times; control mode matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No audits by device."
          rowKey={(r, i) => `${r.device_type}-${r.control_mode}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily thermal-safety trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.test_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk devices queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk devices."
          rowKey={(r, i) => `${r.device_asset_tag}-${r.test_date}-${i}`}
        />
      </section>
    </main>
  );
}
