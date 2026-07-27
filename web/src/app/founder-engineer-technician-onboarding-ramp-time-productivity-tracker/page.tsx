import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { ramp_status: string; technicians: number; pct: number };
type RegionRow = {
  region: string;
  technicians: number;
  ahead: number;
  on_track: number;
  lagging: number;
  at_risk: number;
  avg_days_to_stage: number;
  avg_cert_pass_pct: number;
  avg_first_time_fix_pct: number;
};
type MatrixRow = {
  onboarding_stage: string;
  ramp_status: string;
  technicians: number;
  avg_days_to_stage: number;
  avg_target_days: number;
};
type TrendRow = {
  hire_month: string;
  hires: number;
  ahead: number;
  on_track: number;
  lagging: number;
  at_risk: number;
  avg_days_to_stage: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_impact_days: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_days: number;
  pct: number;
};
type ImpactRow = {
  finding_category: string;
  findings: number;
  open_findings: number;
  total_impact_days: number;
  avg_impact_days: number;
};
type RiskRow = {
  engineer_name: string;
  engineer_code: string;
  region: string;
  onboarding_stage: string;
  hire_date: string;
  days_to_stage: number | null;
  target_days: number | null;
  cert_pass_pct: number | null;
  jobs_completed: number | null;
  first_time_fix_pct: number | null;
  ramp_status: string;
  mentor_name: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    regionRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3484_ramp_status_rollup'),
    supabase.rpc('founder_r3484_region_scorecard'),
    supabase.rpc('founder_r3484_stage_ramp_matrix'),
    supabase.rpc('founder_r3484_monthly_ramp_trend'),
    supabase.rpc('founder_r3484_capa_status_board'),
    supabase.rpc('founder_r3484_root_cause_pareto'),
    supabase.rpc('founder_r3484_ramp_impact_digest'),
    supabase.rpc('founder_r3484_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const regionRows: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'ramp_status', header: 'Ramp Status' },
    { key: 'technicians', header: 'Technicians' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'technicians', header: 'Technicians' },
    { key: 'ahead', header: 'Ahead' },
    { key: 'on_track', header: 'On Track' },
    { key: 'lagging', header: 'Lagging' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'avg_days_to_stage', header: 'Avg Days to Stage' },
    { key: 'avg_cert_pass_pct', header: 'Avg Cert Pass %' },
    { key: 'avg_first_time_fix_pct', header: 'Avg First-Time-Fix %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'onboarding_stage', header: 'Onboarding Stage' },
    { key: 'ramp_status', header: 'Ramp Status' },
    { key: 'technicians', header: 'Technicians' },
    { key: 'avg_days_to_stage', header: 'Avg Days to Stage' },
    { key: 'avg_target_days', header: 'Avg Target Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'hire_month', header: 'Hire Month' },
    { key: 'hires', header: 'Hires' },
    { key: 'ahead', header: 'Ahead' },
    { key: 'on_track', header: 'On Track' },
    { key: 'lagging', header: 'Lagging' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'avg_days_to_stage', header: 'Avg Days to Stage' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_impact_days', header: 'Avg Impact Days' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_days', header: 'Total Impact Days' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_days', header: 'Total Impact Days' },
    { key: 'avg_impact_days', header: 'Avg Impact Days' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Technician' },
    { key: 'engineer_code', header: 'Code' },
    { key: 'region', header: 'Region' },
    { key: 'onboarding_stage', header: 'Stage' },
    { key: 'hire_date', header: 'Hired' },
    { key: 'days_to_stage', header: 'Days to Stage' },
    { key: 'target_days', header: 'Target Days' },
    { key: 'cert_pass_pct', header: 'Cert Pass %' },
    { key: 'jobs_completed', header: 'Jobs' },
    { key: 'first_time_fix_pct', header: 'First-Time-Fix %' },
    { key: 'ramp_status', header: 'Ramp Status' },
    { key: 'mentor_name', header: 'Mentor' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Technician Onboarding Ramp-Time / Productivity Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        New field-technician onboarding ramp &mdash; from induction &amp; shadowing through supervised
        work, certification, solo-ready and full productivity. Tracks days-to-stage vs target &times;
        certification pass % &times; job throughput &times; first-time-fix % &times; region &times;
        mentor &amp; CAPA remediation. Founder-gated view: ramp-status distribution, region scorecards,
        stage &times; ramp matrix, hire-cohort trend, root-cause pareto and the high-risk queue for
        at-risk, lagging &amp; low-certification technicians.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Ramp status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No onboarding records logged yet."
          rowKey={(r, i) => String(r.ramp_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Region scorecard</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region rollups."
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Onboarding stage &times; ramp status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by stage."
          rowKey={(r, i) => `${r.onboarding_stage}-${r.ramp_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly ramp trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.hire_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Ramp-time impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk ramp queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk technicians."
          rowKey={(r, i) => `${r.engineer_code}-${i}`}
        />
      </section>
    </main>
  );
}
