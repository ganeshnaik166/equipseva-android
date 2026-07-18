import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { readiness_verdict: string; stations: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_stations: number;
  fully_ready: number;
  not_ready: number;
  blender_drift: number;
  suction_issues: number;
  mask_gaps: number;
  readiness_pct: number;
};
type LocRow = {
  station_location: string;
  stations: number;
  fully_ready: number;
  tpiece_within_target: number;
  blender_accurate: number;
  avg_suction_mmhg: number;
};
type TrendRow = {
  audit_date: string;
  stations_audited: number;
  fully_ready: number;
  ready_with_gaps: number;
  conditional_or_worse: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_or_escalated: number;
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
  station_location: string;
  audit_date: string;
  readiness_verdict: string;
  blender_accuracy_verdict: string | null;
  suction_verdict: string | null;
  laryngoscope_light_status: string | null;
  apgar_timer_status: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    locRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3207_readiness_verdict_rollup'),
    supabase.rpc('founder_r3207_hospital_scorecard'),
    supabase.rpc('founder_r3207_location_check_matrix'),
    supabase.rpc('founder_r3207_daily_readiness_trend'),
    supabase.rpc('founder_r3207_capa_status_board'),
    supabase.rpc('founder_r3207_root_cause_pareto'),
    supabase.rpc('founder_r3207_regulatory_impact_digest'),
    supabase.rpc('founder_r3207_high_risk_stations'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const locRows: LocRow[] = (locRes.data as LocRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'readiness_verdict', header: 'Verdict' },
    { key: 'stations', header: 'Stations' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_stations', header: 'Stations' },
    { key: 'fully_ready', header: 'Fully Ready' },
    { key: 'not_ready', header: 'Not Ready / OOS' },
    { key: 'blender_drift', header: 'Blender Drift' },
    { key: 'suction_issues', header: 'Suction Issues' },
    { key: 'mask_gaps', header: 'Mask Gaps' },
    { key: 'readiness_pct', header: 'Readiness %' },
  ];

  const locCols: Column<LocRow>[] = [
    { key: 'station_location', header: 'Location' },
    { key: 'stations', header: 'Stations' },
    { key: 'fully_ready', header: 'Fully Ready' },
    { key: 'tpiece_within_target', header: 'T-Piece OK' },
    { key: 'blender_accurate', header: 'Blender Accurate' },
    { key: 'avg_suction_mmhg', header: 'Avg Suction mmHg' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'stations_audited', header: 'Audited' },
    { key: 'fully_ready', header: 'Fully Ready' },
    { key: 'ready_with_gaps', header: 'Ready w/ Gaps' },
    { key: 'conditional_or_worse', header: 'Conditional or Worse' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_or_escalated', header: 'Overdue / Escalated' },
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
    { key: 'station_location', header: 'Location' },
    { key: 'audit_date', header: 'Date' },
    { key: 'readiness_verdict', header: 'Verdict' },
    { key: 'blender_accuracy_verdict', header: 'Blender' },
    { key: 'suction_verdict', header: 'Suction' },
    { key: 'laryngoscope_light_status', header: 'Laryngoscope' },
    { key: 'apgar_timer_status', header: 'Apgar Timer' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Infant Warmer T-Piece Resuscitator &amp; Apgar Station Readiness Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Resuscitation station readiness log — location &times; T-piece PIP/PEEP &times; blender
        FiO2 accuracy &times; suction &times; laryngoscope &times; masks &times; Apgar timer &amp;
        CAPA closure. Founder-gated view: readiness verdicts, hospital scorecards, root-cause
        pareto, and regulatory-impact digest across NABH, NRP &amp; LaQshya surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Readiness verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No station audits logged yet."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Station location &times; check matrix</h2>
        <DataTable
          rows={locRows}
          columns={locCols}
          emptyMessage="No location rollups."
          rowKey={(r, i) => String(r.station_location ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily readiness trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.audit_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk stations queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk stations."
          rowKey={(r, i) => `${r.station_code}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
