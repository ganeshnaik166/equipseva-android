import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { verdict: string; tests: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_tests: number;
  passed: number;
  conditional: number;
  accuracy_fails: number;
  alarm_fails: number;
  quarantined: number;
  pass_pct: number;
};
type ParamRow = {
  parameter: string;
  reference_source: string;
  tests: number;
  passed: number;
  avg_error_pct: number;
};
type TrendRow = {
  test_date: string;
  tests: number;
  passed: number;
  accuracy_fails: number;
  alarm_fails: number;
  avg_error_pct: number;
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
  ward_or_unit: string;
  monitor_asset_tag: string;
  parameter: string;
  test_date: string;
  verdict: string;
  error_pct: number;
  alarm_limit_set: string;
  alarm_audible_test: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    paramRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3150_verdict_rollup'),
    supabase.rpc('founder_r3150_hospital_scorecard'),
    supabase.rpc('founder_r3150_parameter_matrix'),
    supabase.rpc('founder_r3150_daily_trend'),
    supabase.rpc('founder_r3150_capa_status_board'),
    supabase.rpc('founder_r3150_root_cause_pareto'),
    supabase.rpc('founder_r3150_regulatory_impact_digest'),
    supabase.rpc('founder_r3150_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const paramRows: ParamRow[] = (paramRes.data as ParamRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'verdict', header: 'Verdict' },
    { key: 'tests', header: 'Tests' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_tests', header: 'Tests' },
    { key: 'passed', header: 'Passed' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'accuracy_fails', header: 'Accuracy Fail' },
    { key: 'alarm_fails', header: 'Alarm Fail' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const paramCols: Column<ParamRow>[] = [
    { key: 'parameter', header: 'Parameter' },
    { key: 'reference_source', header: 'Reference Source' },
    { key: 'tests', header: 'Tests' },
    { key: 'passed', header: 'Passed' },
    { key: 'avg_error_pct', header: 'Avg Error %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'test_date', header: 'Date' },
    { key: 'tests', header: 'Tests' },
    { key: 'passed', header: 'Passed' },
    { key: 'accuracy_fails', header: 'Accuracy Fail' },
    { key: 'alarm_fails', header: 'Alarm Fail' },
    { key: 'avg_error_pct', header: 'Avg Error %' },
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
    { key: 'ward_or_unit', header: 'Unit' },
    { key: 'monitor_asset_tag', header: 'Asset' },
    { key: 'parameter', header: 'Parameter' },
    { key: 'test_date', header: 'Date' },
    { key: 'verdict', header: 'Verdict' },
    { key: 'error_pct', header: 'Error %' },
    { key: 'alarm_limit_set', header: 'Alarm Limits' },
    { key: 'alarm_audible_test', header: 'Audible Test' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Multiparameter Patient-Monitor Accuracy &amp; Alarm Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Bedside monitor QA log — parameter (ECG / SpO2 / NIBP / temp / EtCO2) &times; reference vs
        measured value &times; error % &times; alarm-limit set &times; alarm-audible test &times;
        waveform quality &amp; CAPA closure. Founder-gated view: verdict rollups, hospital
        scorecards, root-cause pareto, and regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No monitor checks logged yet."
          rowKey={(r, i) => String(r.verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital accuracy &amp; alarm scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Parameter &times; reference-source matrix</h2>
        <DataTable
          rows={paramRows}
          columns={paramCols}
          emptyMessage="No parameter breakdown."
          rowKey={(r, i) => `${r.parameter}-${r.reference_source}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily accuracy &amp; alarm trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk / priority queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk monitor checks."
          rowKey={(r, i) => `${r.monitor_asset_tag}-${r.parameter}-${i}`}
        />
      </section>
    </main>
  );
}
