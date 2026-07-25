import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { site_verdict: string; surveys: number; pct: number };
type RegionRow = {
  region: string;
  total_surveys: number;
  go_ready: number;
  minor_gaps: number;
  blocked: number;
  avg_readiness_pct: number;
  open_blockers: number;
  go_ready_pct: number;
};
type MatrixRow = {
  equipment_type: string;
  region: string;
  surveys: number;
  go_ready: number;
  at_risk: number;
  avg_readiness_pct: number;
};
type TrendRow = {
  survey_date: string;
  surveys: number;
  go_ready: number;
  blocked: number;
  open_blockers: number;
  avg_readiness_pct: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type ImpactRow = {
  go_live_impact: string;
  actions: number;
  open_actions: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  survey_code: string;
  equipment_type: string;
  region: string;
  survey_date: string;
  site_verdict: string;
  shielding_ready: string | null;
  blockers_open: number;
  readiness_pct: number | null;
  target_install_date: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    regionRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3424_verdict_rollup'),
    supabase.rpc('founder_r3424_region_scorecard'),
    supabase.rpc('founder_r3424_equipment_region_matrix'),
    supabase.rpc('founder_r3424_survey_date_trend'),
    supabase.rpc('founder_r3424_capa_status_board'),
    supabase.rpc('founder_r3424_root_cause_pareto'),
    supabase.rpc('founder_r3424_go_live_impact_digest'),
    supabase.rpc('founder_r3424_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const regionRows: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'site_verdict', header: 'Site Verdict' },
    { key: 'surveys', header: 'Surveys' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'total_surveys', header: 'Surveys' },
    { key: 'go_ready', header: 'Go Ready' },
    { key: 'minor_gaps', header: 'Minor Gaps' },
    { key: 'blocked', header: 'Blocked' },
    { key: 'avg_readiness_pct', header: 'Avg Readiness %' },
    { key: 'open_blockers', header: 'Open Blockers' },
    { key: 'go_ready_pct', header: 'Go Ready %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_type', header: 'Equipment Type' },
    { key: 'region', header: 'Region' },
    { key: 'surveys', header: 'Surveys' },
    { key: 'go_ready', header: 'Go Ready' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'avg_readiness_pct', header: 'Avg Readiness %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'survey_date', header: 'Survey Date' },
    { key: 'surveys', header: 'Surveys' },
    { key: 'go_ready', header: 'Go Ready' },
    { key: 'blocked', header: 'Blocked' },
    { key: 'open_blockers', header: 'Open Blockers' },
    { key: 'avg_readiness_pct', header: 'Avg Readiness %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'go_live_impact', header: 'Go-Live Impact' },
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'survey_code', header: 'Survey' },
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'region', header: 'Region' },
    { key: 'survey_date', header: 'Date' },
    { key: 'site_verdict', header: 'Verdict' },
    { key: 'shielding_ready', header: 'Shielding' },
    { key: 'blockers_open', header: 'Blockers' },
    { key: 'readiness_pct', header: 'Readiness %' },
    { key: 'target_install_date', header: 'Target Install' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Installation Site-Readiness &amp; Pre-Install Survey Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Pre-installation site-survey completeness and go-live-blocker management — equipment type (CT
        scanner, MRI, cath lab, linac, lab analyzer, dialysis fleet, OT integration) &times; region
        &times; power supply &times; HVAC cooling &times; shielding &times; floor loading &times;
        access route &times; civil works &times; utilities (water &amp; gas) &times; network readiness
        &times; open blockers &amp; CAPA blocker resolution. Founder-gated view: site verdicts, region
        scorecards, root-cause pareto, and go-live-impact digest across major-equipment installs.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Site-verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No site surveys logged yet."
          rowKey={(r, i) => String(r.site_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Region readiness scorecard</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region rollups."
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment type &times; region matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No surveys by equipment type."
          rowKey={(r, i) => `${r.equipment_type}-${r.region}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Survey-date readiness trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.survey_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA actions."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Go-live impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No go-live-impact rollups."
          rowKey={(r, i) => String(r.go_live_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk go-live-blocker queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk surveys."
          rowKey={(r, i) => `${r.survey_code}-${r.survey_date}-${i}`}
        />
      </section>
    </main>
  );
}
