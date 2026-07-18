import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { pm_verdict: string; pm_checks: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_checks: number;
  passed: number;
  quarantined: number;
  recalls: number;
  tv_fail: number;
  fio2_fail: number;
  alarm_fail: number;
  compliance_pct: number;
};
type MatrixRow = {
  ventilation_mode_tested: string;
  tidal_volume_verdict: string;
  checks: number;
  passed: number;
  avg_tv_accuracy: number;
};
type TrendRow = {
  pm_date: string;
  apnoea_pass: number;
  apnoea_fail: number;
  disconnect_pass: number;
  disconnect_fail: number;
  leak_fail: number;
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
  icu_unit_code: string;
  ventilator_asset_tag: string;
  pm_date: string;
  pm_verdict: string;
  tidal_volume_verdict: string | null;
  fio2_verdict: string | null;
  apnoea_alarm_test: string | null;
  disconnect_alarm_test: string | null;
  leak_test_result: string | null;
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
    supabase.rpc('founder_r3142_pm_verdict_rollup'),
    supabase.rpc('founder_r3142_hospital_scorecard'),
    supabase.rpc('founder_r3142_mode_accuracy_matrix'),
    supabase.rpc('founder_r3142_alarm_daily_trend'),
    supabase.rpc('founder_r3142_capa_status_board'),
    supabase.rpc('founder_r3142_root_cause_pareto'),
    supabase.rpc('founder_r3142_regulatory_impact_digest'),
    supabase.rpc('founder_r3142_high_risk_checks'),
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
    { key: 'pm_verdict', header: 'PM Verdict' },
    { key: 'pm_checks', header: 'Checks' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'recalls', header: 'Recalls' },
    { key: 'tv_fail', header: 'TV Fail' },
    { key: 'fio2_fail', header: 'FiO2 Fail' },
    { key: 'alarm_fail', header: 'Alarm Fail' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'ventilation_mode_tested', header: 'Ventilation Mode' },
    { key: 'tidal_volume_verdict', header: 'TV Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'avg_tv_accuracy', header: 'Avg TV Acc %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'pm_date', header: 'Date' },
    { key: 'apnoea_pass', header: 'Apnoea Pass' },
    { key: 'apnoea_fail', header: 'Apnoea Fail' },
    { key: 'disconnect_pass', header: 'Disconnect Pass' },
    { key: 'disconnect_fail', header: 'Disconnect Fail' },
    { key: 'leak_fail', header: 'Leak Fail/Borderline' },
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
    { key: 'icu_unit_code', header: 'ICU' },
    { key: 'ventilator_asset_tag', header: 'Asset' },
    { key: 'pm_date', header: 'Date' },
    { key: 'pm_verdict', header: 'Verdict' },
    { key: 'tidal_volume_verdict', header: 'TV' },
    { key: 'fio2_verdict', header: 'FiO2' },
    { key: 'apnoea_alarm_test', header: 'Apnoea' },
    { key: 'disconnect_alarm_test', header: 'Disconnect' },
    { key: 'leak_test_result', header: 'Leak' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital ICU Ventilator Preventive-Maintenance &amp; Alarm-Test Compliance Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        ICU ventilator PM log — ventilation mode &times; tidal-volume / PEEP / FiO2 accuracy &times;
        leak test &times; alarm battery &times; HME filter &times; apnoea &amp; disconnect alarm test &amp; CAPA closure.
        Founder-gated view: PM verdicts, hospital scorecards, mode-accuracy matrix, root-cause pareto, and
        regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. PM verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No PM checks logged yet."
          rowKey={(r, i) => String(r.pm_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital compliance scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Ventilation mode &times; TV verdict matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by mode."
          rowKey={(r, i) => `${r.ventilation_mode_tested}-${r.tidal_volume_verdict}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Apnoea, disconnect &amp; leak daily trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.pm_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk PM queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk checks."
          rowKey={(r, i) => `${r.ventilator_asset_tag}-${r.pm_date}-${i}`}
        />
      </section>
    </main>
  );
}
