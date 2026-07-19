import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { qc_verdict: string; plants: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_plants: number;
  passed: number;
  conditional: number;
  failed: number;
  dew_point_issues: number;
  air_purity_fail: number;
  duplex_fail: number;
  pass_pct: number;
};
type MatrixRow = {
  plant_type: string;
  dew_point_ok: string;
  plants: number;
  passed: number;
  avg_reserve_bank_days: number;
};
type TrendRow = {
  check_date: string;
  plants: number;
  passed: number;
  failed: number;
  shutdown_risk: number;
  dew_point_issues: number;
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
  plant_code: string;
  plant_type: string;
  location: string;
  check_date: string;
  qc_verdict: string;
  dew_point_ok: string | null;
  alarm_panel_test: string | null;
  filter_condition: string | null;
  reserve_bank_days: number | null;
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
    supabase.rpc('founder_r3370_qc_verdict_rollup'),
    supabase.rpc('founder_r3370_hospital_scorecard'),
    supabase.rpc('founder_r3370_plant_dewpoint_matrix'),
    supabase.rpc('founder_r3370_daily_qc_trend'),
    supabase.rpc('founder_r3370_capa_status_board'),
    supabase.rpc('founder_r3370_root_cause_pareto'),
    supabase.rpc('founder_r3370_regulatory_impact_digest'),
    supabase.rpc('founder_r3370_high_risk_queue'),
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
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'plants', header: 'Plants' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_plants', header: 'Plants' },
    { key: 'passed', header: 'Passed' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'failed', header: 'Failed' },
    { key: 'dew_point_issues', header: 'Dew-Point Issues' },
    { key: 'air_purity_fail', header: 'Air-Purity Fail' },
    { key: 'duplex_fail', header: 'Duplex Fail' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'plant_type', header: 'Plant Type' },
    { key: 'dew_point_ok', header: 'Dew-Point' },
    { key: 'plants', header: 'Plants' },
    { key: 'passed', header: 'Passed' },
    { key: 'avg_reserve_bank_days', header: 'Avg Reserve (days)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date' },
    { key: 'plants', header: 'Plants' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'shutdown_risk', header: 'Shutdown Risk' },
    { key: 'dew_point_issues', header: 'Dew-Point Issues' },
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
    { key: 'plant_code', header: 'Plant' },
    { key: 'plant_type', header: 'Type' },
    { key: 'location', header: 'Location' },
    { key: 'check_date', header: 'Date' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'dew_point_ok', header: 'Dew-Point' },
    { key: 'alarm_panel_test', header: 'Alarm Panel' },
    { key: 'filter_condition', header: 'Filter' },
    { key: 'reserve_bank_days', header: 'Reserve (days)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Central Medical-Gas Plant (Air / Vacuum / Manifold) QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Source-side plant QA log — plant type &times; pressure setpoint &times; dew-point &times; air
        purity (CO / oil / particulate) &times; duplex auto-changeover &times; reserve-bank days
        &times; alarm-panel test &times; non-return valve &times; filter condition &times; plant-room
        ventilation &amp; CAPA closure. Founder-gated view: QC verdicts, hospital scorecards,
        root-cause pareto, and regulatory-impact digest across NABH, CDSCO &amp; ISO 7396-1 surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. QC verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No plant QC checks logged yet."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Plant type &times; dew-point matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No plants by type."
          rowKey={(r, i) => `${r.plant_type}-${r.dew_point_ok}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk plant QC queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk plants."
          rowKey={(r, i) => `${r.plant_code}-${r.check_date}-${i}`}
        />
      </section>
    </main>
  );
}
