import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { test_verdict: string; tests: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_tests: number;
  passed: number;
  failed: number;
  quarantined: number;
  retest_required: number;
  avg_earth_bond_ohm: number | null;
  avg_equipment_leakage_ua: number | null;
  pass_pct: number;
};
type MatrixRow = {
  device_type: string;
  protection_class: string;
  tests: number;
  passed: number;
  avg_equipment_leakage_ua: number | null;
};
type TrendRow = {
  test_date: string;
  tests: number;
  passed: number;
  failed: number;
  quarantined: number;
  retest_required: number;
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
  department: string;
  device_asset_tag: string;
  device_type: string;
  test_date: string;
  test_verdict: string;
  earth_bond_resistance_ohm: number | null;
  insulation_resistance_mohm: number | null;
  equipment_leakage_ua: number | null;
  applied_part_leakage_ua: number | null;
  next_due_date: string | null;
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
    supabase.rpc('founder_r3152_verdict_rollup'),
    supabase.rpc('founder_r3152_hospital_scorecard'),
    supabase.rpc('founder_r3152_device_class_matrix'),
    supabase.rpc('founder_r3152_test_daily_trend'),
    supabase.rpc('founder_r3152_capa_status_board'),
    supabase.rpc('founder_r3152_root_cause_pareto'),
    supabase.rpc('founder_r3152_regulatory_impact_digest'),
    supabase.rpc('founder_r3152_high_risk_tests'),
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
    { key: 'test_verdict', header: 'Verdict' },
    { key: 'tests', header: 'Tests' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_tests', header: 'Tests' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'retest_required', header: 'Retest' },
    { key: 'avg_earth_bond_ohm', header: 'Avg Earth-Bond Ω' },
    { key: 'avg_equipment_leakage_ua', header: 'Avg Eq. Leak µA' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'device_type', header: 'Device Type' },
    { key: 'protection_class', header: 'Protection Class' },
    { key: 'tests', header: 'Tests' },
    { key: 'passed', header: 'Passed' },
    { key: 'avg_equipment_leakage_ua', header: 'Avg Eq. Leak µA' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'test_date', header: 'Date' },
    { key: 'tests', header: 'Tests' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'retest_required', header: 'Retest' },
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
    { key: 'department', header: 'Dept' },
    { key: 'device_asset_tag', header: 'Asset' },
    { key: 'device_type', header: 'Device' },
    { key: 'test_date', header: 'Date' },
    { key: 'test_verdict', header: 'Verdict' },
    { key: 'earth_bond_resistance_ohm', header: 'Earth-Bond Ω' },
    { key: 'insulation_resistance_mohm', header: 'Insul. MΩ' },
    { key: 'equipment_leakage_ua', header: 'Eq. Leak µA' },
    { key: 'applied_part_leakage_ua', header: 'AP Leak µA' },
    { key: 'next_due_date', header: 'Next Due' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Electrical-Safety Test (IEC 62353) PASS/FAIL Register
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Biomedical electrical-safety log — device class (I/II &amp; type B/BF/CF) &times; earth-bond
        resistance &times; insulation resistance &times; equipment &amp; applied-part leakage &times; verdict
        &amp; next-due date. Founder-gated view: verdict rollup, hospital scorecards, root-cause pareto, and
        regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Test verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No electrical-safety tests logged yet."
          rowKey={(r, i) => String(r.test_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital electrical-safety scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Device type &times; protection class matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No tests by device class."
          rowKey={(r, i) => `${r.device_type}-${r.protection_class}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily test trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk / priority test queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk tests."
          rowKey={(r, i) => `${r.device_asset_tag}-${r.test_date}-${i}`}
        />
      </section>
    </main>
  );
}
