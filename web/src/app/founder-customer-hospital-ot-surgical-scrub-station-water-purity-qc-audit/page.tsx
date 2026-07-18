import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { qc_verdict: string; stations: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_stations: number;
  passed: number;
  conditional: number;
  failed: number;
  water_sample_fail: number;
  filter_overdue: number;
  timer_fault: number;
  pass_pct: number;
};
type MatrixRow = {
  tap_actuation_type: string;
  bacterial_filter_status: string;
  stations: number;
  passed: number;
  failed: number;
};
type TrendRow = {
  check_date: string;
  stations: number;
  passed: number;
  failed: number;
  water_sample_fail: number;
  filter_overdue: number;
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
  station_code: string;
  ot_number: string;
  check_date: string;
  qc_verdict: string;
  tap_actuation_type: string | null;
  bacterial_filter_status: string | null;
  water_sample_result: string | null;
  scrub_timer_ok: string | null;
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
    supabase.rpc('founder_r3290_qc_verdict_rollup'),
    supabase.rpc('founder_r3290_hospital_scorecard'),
    supabase.rpc('founder_r3290_tap_filter_matrix'),
    supabase.rpc('founder_r3290_daily_qc_trend'),
    supabase.rpc('founder_r3290_capa_status_board'),
    supabase.rpc('founder_r3290_root_cause_pareto'),
    supabase.rpc('founder_r3290_regulatory_impact_digest'),
    supabase.rpc('founder_r3290_high_risk_queue'),
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
    { key: 'stations', header: 'Stations' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_stations', header: 'Stations' },
    { key: 'passed', header: 'Passed' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'failed', header: 'Failed' },
    { key: 'water_sample_fail', header: 'Water Sample Fail' },
    { key: 'filter_overdue', header: 'Filter Overdue' },
    { key: 'timer_fault', header: 'Timer Fault' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'tap_actuation_type', header: 'Tap Actuation' },
    { key: 'bacterial_filter_status', header: 'Filter Status' },
    { key: 'stations', header: 'Stations' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date' },
    { key: 'stations', header: 'Stations' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'water_sample_fail', header: 'Water Sample Fail' },
    { key: 'filter_overdue', header: 'Filter Overdue' },
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
    { key: 'station_code', header: 'Station' },
    { key: 'ot_number', header: 'OT' },
    { key: 'check_date', header: 'Date' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'tap_actuation_type', header: 'Tap Actuation' },
    { key: 'bacterial_filter_status', header: 'Filter Status' },
    { key: 'water_sample_result', header: 'Water Sample' },
    { key: 'scrub_timer_ok', header: 'Scrub Timer' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital OT Surgical Scrub-Station Water-Purity QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Operating-theatre surgical hand-antisepsis QA log — scrub-station &times; tap-actuation type
        &times; tap function &times; water-temp stability &times; bacterial-filter status &times;
        water-sample TVC/pseudomonas result &times; scrub-timer &times; antiseptic dispenser &times;
        drainage hygiene &times; backsplash containment &amp; CAPA closure. Founder-gated view: QC
        verdicts, hospital scorecards, root-cause pareto, and regulatory-impact digest across NABH
        &amp; infection-control surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. QC verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No scrub-station QC checks logged yet."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Tap actuation &times; filter status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No stations by tap type."
          rowKey={(r, i) => `${r.tap_actuation_type}-${r.bacterial_filter_status}-${i}`}
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
          emptyMessage="No high-risk checks."
          rowKey={(r, i) => `${r.station_code}-${r.check_date}-${i}`}
        />
      </section>
    </main>
  );
}
