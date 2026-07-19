import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { qc_verdict: string; systems: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_systems: number;
  passed: number;
  conditional: number;
  failed: number;
  image_quality_fail: number;
  dose_exceedance: number;
  radiation_safety_fail: number;
  pass_pct: number;
};
type MatrixRow = {
  system_type: string;
  department: string;
  systems: number;
  passed: number;
  avg_dead_pixel_count: number | null;
  dose_exceedance: number;
};
type TrendRow = {
  check_date: string;
  systems: number;
  passed: number;
  failed: number;
  image_quality_fail: number;
  dose_exceedance: number;
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
  system_code: string;
  system_type: string;
  department: string;
  check_date: string;
  qc_verdict: string;
  image_quality_ok: string;
  flat_panel_dead_pixel_count: number;
  failed_checks: string | null;
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
    supabase.rpc('founder_r3350_qc_verdict_rollup'),
    supabase.rpc('founder_r3350_hospital_scorecard'),
    supabase.rpc('founder_r3350_system_department_matrix'),
    supabase.rpc('founder_r3350_daily_qc_trend'),
    supabase.rpc('founder_r3350_capa_status_board'),
    supabase.rpc('founder_r3350_root_cause_pareto'),
    supabase.rpc('founder_r3350_regulatory_impact_digest'),
    supabase.rpc('founder_r3350_high_risk_queue'),
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
    { key: 'systems', header: 'Systems' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_systems', header: 'Systems' },
    { key: 'passed', header: 'Passed' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'failed', header: 'Failed' },
    { key: 'image_quality_fail', header: 'Image-Quality Fail' },
    { key: 'dose_exceedance', header: 'Dose Exceedance' },
    { key: 'radiation_safety_fail', header: 'Radiation-Safety Fail' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'system_type', header: 'System Type' },
    { key: 'department', header: 'Department' },
    { key: 'systems', header: 'Systems' },
    { key: 'passed', header: 'Passed' },
    { key: 'avg_dead_pixel_count', header: 'Avg Dead Pixels' },
    { key: 'dose_exceedance', header: 'Dose Exceedance' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date' },
    { key: 'systems', header: 'Systems' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'image_quality_fail', header: 'Image-Quality Fail' },
    { key: 'dose_exceedance', header: 'Dose Exceedance' },
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
    { key: 'system_code', header: 'System' },
    { key: 'system_type', header: 'Type' },
    { key: 'department', header: 'Department' },
    { key: 'check_date', header: 'Date' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'image_quality_ok', header: 'Image Quality' },
    { key: 'flat_panel_dead_pixel_count', header: 'Dead Pixels' },
    { key: 'failed_checks', header: 'Failed Checks' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital DSA &amp; Biplane Angiography Imaging-Chain QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Interventional angio imaging-chain QA log — system type &times; image quality &times;
        flat-panel dead-pixel count &times; subtraction registration &times; dose-rate limit &times;
        contrast resolution &times; frame-rate accuracy &times; table/gantry movement &times; road-map
        function &times; radiation safety &times; calibration currency &amp; CAPA closure. Founder-gated
        view: QC verdicts, hospital scorecards, root-cause pareto, and regulatory-impact digest across
        NABH, CDSCO &amp; AERB surfaces.
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. System type &times; department matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No systems by type."
          rowKey={(r, i) => `${r.system_type}-${r.department}-${i}`}
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
          emptyMessage="No high-risk systems."
          rowKey={(r, i) => `${r.system_code}-${r.check_date}-${i}`}
        />
      </section>
    </main>
  );
}
