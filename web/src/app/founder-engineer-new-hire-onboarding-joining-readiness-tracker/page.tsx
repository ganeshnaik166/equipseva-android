import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { onboarding_verdict: string; hires: number; pct: number };
type RegionRow = {
  region: string;
  total_hires: number;
  ready_for_solo: number;
  on_track_ahead: number;
  delayed: number;
  at_risk: number;
  docs_pending: number;
  training_incomplete: number;
  avg_readiness_pct: number;
};
type MatrixRow = {
  role: string;
  region: string;
  hires: number;
  ready_for_solo: number;
  avg_readiness_pct: number;
  avg_days_to_first_solo_visit: number;
};
type TrendRow = {
  joining_date: string;
  hires: number;
  ready_for_solo: number;
  delayed: number;
  at_risk: number;
  avg_readiness_pct: number;
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
type ImpactRow = {
  support_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  employee_name: string;
  employee_code: string;
  region: string;
  role: string;
  joining_date: string;
  onboarding_verdict: string;
  readiness_pct: number | null;
  documents_verified: boolean | null;
  product_training_modules_completed: number | null;
  product_training_total: number | null;
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
    supabase.rpc('founder_r3320_onboarding_verdict_rollup'),
    supabase.rpc('founder_r3320_region_scorecard'),
    supabase.rpc('founder_r3320_role_region_matrix'),
    supabase.rpc('founder_r3320_joining_trend'),
    supabase.rpc('founder_r3320_capa_status_board'),
    supabase.rpc('founder_r3320_root_cause_pareto'),
    supabase.rpc('founder_r3320_support_impact_digest'),
    supabase.rpc('founder_r3320_high_risk_queue'),
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
    { key: 'onboarding_verdict', header: 'Verdict' },
    { key: 'hires', header: 'Hires' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'total_hires', header: 'Hires' },
    { key: 'ready_for_solo', header: 'Ready for Solo' },
    { key: 'on_track_ahead', header: 'On-Track / Ahead' },
    { key: 'delayed', header: 'Delayed' },
    { key: 'at_risk', header: 'At-Risk' },
    { key: 'docs_pending', header: 'Docs Pending' },
    { key: 'training_incomplete', header: 'Training Incomplete' },
    { key: 'avg_readiness_pct', header: 'Avg Readiness %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'role', header: 'Role' },
    { key: 'region', header: 'Region' },
    { key: 'hires', header: 'Hires' },
    { key: 'ready_for_solo', header: 'Ready for Solo' },
    { key: 'avg_readiness_pct', header: 'Avg Readiness %' },
    { key: 'avg_days_to_first_solo_visit', header: 'Avg Days to Solo' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'joining_date', header: 'Joining Date' },
    { key: 'hires', header: 'Hires' },
    { key: 'ready_for_solo', header: 'Ready for Solo' },
    { key: 'delayed', header: 'Delayed' },
    { key: 'at_risk', header: 'At-Risk' },
    { key: 'avg_readiness_pct', header: 'Avg Readiness %' },
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

  const impactCols: Column<ImpactRow>[] = [
    { key: 'support_impact', header: 'Support Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'employee_name', header: 'Engineer' },
    { key: 'employee_code', header: 'Code' },
    { key: 'region', header: 'Region' },
    { key: 'role', header: 'Role' },
    { key: 'joining_date', header: 'Joining Date' },
    { key: 'onboarding_verdict', header: 'Verdict' },
    { key: 'readiness_pct', header: 'Readiness %' },
    { key: 'documents_verified', header: 'Docs OK' },
    { key: 'product_training_modules_completed', header: 'Modules Done' },
    { key: 'product_training_total', header: 'Modules Total' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer New-Hire Onboarding, Joining-Formalities &amp; Field-Readiness Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-engineer onboarding ramp — offer-accept to first productive solo visit. Onboarding
        verdict &times; region scorecard &times; role &times; region readiness matrix &times; joining-date
        trend &times; documents &amp; statutory setup &times; tool-kit &amp; credentials &times; product-training
        modules &times; buddy assignment &times; supervised visit &amp; CAPA expedite actions. Founder-gated
        view: verdict rollups, region scorecards, root-cause pareto, and attrition-risk / support-impact
        digest across all field regions.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Onboarding verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No onboarding records yet."
          rowKey={(r, i) => String(r.onboarding_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Region onboarding scorecard</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region rollups."
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Role &times; region readiness matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No hires by role."
          rowKey={(r, i) => `${r.role}-${r.region}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Joining-date trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.joining_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Support-impact &amp; attrition-risk digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No support-impact rollups."
          rowKey={(r, i) => String(r.support_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk onboarding queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk onboardings."
          rowKey={(r, i) => `${r.employee_code}-${i}`}
        />
      </section>
    </main>
  );
}
