import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { qa_verdict: string; checks: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_checks: number;
  cleared: number;
  restricted: number;
  out_of_service: number;
  hu_out_of_tolerance: number;
  artifact_flagged: number;
  warmup_skipped: number;
  clearance_pct: number;
};
type ArtifactRow = {
  artifact_type: string;
  artifact_severity: string;
  checks: number;
  avg_noise_sd: number;
  avg_water_hu: number;
};
type TrendRow = {
  qa_date: string;
  checks: number;
  avg_water_hu: number;
  avg_noise_sd: number;
  avg_ctdivol_mgy: number;
  drl_breaches: number;
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
  ct_room_code: string;
  scanner_asset_tag: string;
  qa_date: string;
  qa_verdict: string;
  water_phantom_verdict: string | null;
  noise_verdict: string | null;
  artifact_type: string;
  slice_thickness_check: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    artifactRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3178_qa_verdict_rollup'),
    supabase.rpc('founder_r3178_hospital_scorecard'),
    supabase.rpc('founder_r3178_artifact_matrix'),
    supabase.rpc('founder_r3178_hu_dose_daily_trend'),
    supabase.rpc('founder_r3178_capa_status_board'),
    supabase.rpc('founder_r3178_root_cause_pareto'),
    supabase.rpc('founder_r3178_regulatory_impact_digest'),
    supabase.rpc('founder_r3178_high_risk_checks'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const artifactRows: ArtifactRow[] = (artifactRes.data as ArtifactRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'qa_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'cleared', header: 'Cleared' },
    { key: 'restricted', header: 'Restricted' },
    { key: 'out_of_service', header: 'Out of Service' },
    { key: 'hu_out_of_tolerance', header: 'HU Out' },
    { key: 'artifact_flagged', header: 'Artifacts' },
    { key: 'warmup_skipped', header: 'Warmup Skipped' },
    { key: 'clearance_pct', header: 'Clearance %' },
  ];

  const artifactCols: Column<ArtifactRow>[] = [
    { key: 'artifact_type', header: 'Artifact Type' },
    { key: 'artifact_severity', header: 'Severity' },
    { key: 'checks', header: 'Checks' },
    { key: 'avg_noise_sd', header: 'Avg Noise SD (HU)' },
    { key: 'avg_water_hu', header: 'Avg Water HU' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'qa_date', header: 'Date' },
    { key: 'checks', header: 'Checks' },
    { key: 'avg_water_hu', header: 'Avg Water HU' },
    { key: 'avg_noise_sd', header: 'Avg Noise SD' },
    { key: 'avg_ctdivol_mgy', header: 'Avg CTDIvol (mGy)' },
    { key: 'drl_breaches', header: 'DRL Breaches' },
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
    { key: 'ct_room_code', header: 'Room' },
    { key: 'scanner_asset_tag', header: 'Asset' },
    { key: 'qa_date', header: 'Date' },
    { key: 'qa_verdict', header: 'Verdict' },
    { key: 'water_phantom_verdict', header: 'Water HU' },
    { key: 'noise_verdict', header: 'Noise' },
    { key: 'artifact_type', header: 'Artifact' },
    { key: 'slice_thickness_check', header: 'Slice' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital CT-Scanner Tube-Warmup, HU-Calibration &amp; Artifact Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        CT scanner QA log — tube warmup &times; air-cal HU offset &times; water-phantom HU &times;
        noise SD &times; artifact type &times; slice thickness &times; CTDIvol dose &amp; CAPA closure.
        Founder-gated view: QA verdicts, hospital scorecards, artifact matrix, root-cause pareto,
        and regulatory-impact digest across AERB, NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. QA verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No QA checks logged yet."
          rowKey={(r, i) => String(r.qa_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital QA scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Artifact type &times; severity matrix</h2>
        <DataTable
          rows={artifactRows}
          columns={artifactCols}
          emptyMessage="No artifact data."
          rowKey={(r, i) => `${r.artifact_type}-${r.artifact_severity}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. HU calibration &amp; dose daily trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.qa_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk QA checks queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk checks."
          rowKey={(r, i) => `${r.scanner_asset_tag}-${r.qa_date}-${i}`}
        />
      </section>
    </main>
  );
}
