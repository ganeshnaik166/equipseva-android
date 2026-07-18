import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { readiness_verdict: string; chambers: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_checks: number;
  mission_ready: number;
  conditional: number;
  not_ready: number;
  out_of_service: number;
  fire_suppression_gaps: number;
  pressure_test_fail: number;
  gauge_cal_overdue: number;
  ready_pct: number;
};
type MatrixRow = {
  chamber_type: string;
  department: string;
  checks: number;
  mission_ready: number;
  not_ready: number;
  ready_pct: number;
};
type TrendRow = {
  check_date: string;
  checks: number;
  mission_ready: number;
  not_ready: number;
  out_of_service: number;
  fire_suppression_gaps: number;
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
  chamber_code: string;
  chamber_type: string;
  department: string;
  check_date: string;
  readiness_verdict: string;
  fire_suppression_ready: boolean | null;
  pressure_test_ok: boolean | null;
  o2_concentration_control_ok: boolean | null;
  acrylic_hull_inspection: string | null;
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
    supabase.rpc('founder_r3298_readiness_verdict_rollup'),
    supabase.rpc('founder_r3298_hospital_scorecard'),
    supabase.rpc('founder_r3298_chamber_type_department_matrix'),
    supabase.rpc('founder_r3298_daily_readiness_trend'),
    supabase.rpc('founder_r3298_capa_status_board'),
    supabase.rpc('founder_r3298_root_cause_pareto'),
    supabase.rpc('founder_r3298_regulatory_impact_digest'),
    supabase.rpc('founder_r3298_high_risk_queue'),
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
    { key: 'chambers', header: 'Chambers' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'mission_ready', header: 'Mission-Ready' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'not_ready', header: 'Not-Ready' },
    { key: 'out_of_service', header: 'Out-of-Service' },
    { key: 'fire_suppression_gaps', header: 'Fire-Suppression Gaps' },
    { key: 'pressure_test_fail', header: 'Pressure Fail' },
    { key: 'gauge_cal_overdue', header: 'Gauge-Cal Overdue' },
    { key: 'ready_pct', header: 'Ready %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'chamber_type', header: 'Chamber Type' },
    { key: 'department', header: 'Department' },
    { key: 'checks', header: 'Checks' },
    { key: 'mission_ready', header: 'Mission-Ready' },
    { key: 'not_ready', header: 'Not-Ready / OOS' },
    { key: 'ready_pct', header: 'Ready %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date' },
    { key: 'checks', header: 'Checks' },
    { key: 'mission_ready', header: 'Mission-Ready' },
    { key: 'not_ready', header: 'Not-Ready' },
    { key: 'out_of_service', header: 'Out-of-Service' },
    { key: 'fire_suppression_gaps', header: 'Fire-Suppression Gaps' },
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
    { key: 'chamber_code', header: 'Chamber' },
    { key: 'chamber_type', header: 'Type' },
    { key: 'department', header: 'Department' },
    { key: 'check_date', header: 'Date' },
    { key: 'readiness_verdict', header: 'Verdict' },
    { key: 'fire_suppression_ready', header: 'Fire-Suppression' },
    { key: 'pressure_test_ok', header: 'Pressure Test' },
    { key: 'o2_concentration_control_ok', header: 'O2 Control' },
    { key: 'acrylic_hull_inspection', header: 'Acrylic Hull' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital HBOT Hyperbaric-Chamber Safety &amp; Readiness Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Fire-risk-critical readiness log for pressurized-O2 hyperbaric chambers — chamber type &times;
        pressure-hold test &times; O2-concentration control &times; deluge fire-suppression &times;
        grounding/antistatic &times; prohibited-items screening &times; comms &times; emergency
        decompression drill &times; acrylic-hull inspection &times; ventilation air-break &times;
        gauge calibration &amp; CAPA closure. Founder-gated view: readiness verdicts, hospital
        scorecards, root-cause pareto, and regulatory-impact digest across NFPA-99, PESO &amp; NABH
        surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Readiness verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No chamber checks logged yet."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Chamber type &times; department matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by type."
          rowKey={(r, i) => `${r.chamber_type}-${r.department}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily readiness trend</h2>
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
          emptyMessage="No high-risk chambers."
          rowKey={(r, i) => `${r.hospital_name}-${r.chamber_code}-${i}`}
        />
      </section>
    </main>
  );
}
