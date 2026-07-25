import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { engagement_verdict: string; engagements: number; pct: number };
type SpecialistRow = {
  specialist_name: string;
  total_engagements: number;
  successful: number;
  needs_followup: number;
  delayed: number;
  coverage_gaps: number;
  users_trained: number;
  avg_satisfaction: number;
  on_schedule_pct: number;
};
type MatrixRow = {
  equipment_type: string;
  engagement_type: string;
  engagements: number;
  successful: number;
  delayed: number;
  avg_actual_hours: number;
};
type TrendRow = {
  engagement_date: string;
  engagements: number;
  successful: number;
  delayed: number;
  coverage_gaps: number;
  users_trained: number;
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
  coverage_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  specialist_name: string;
  hospital_name: string;
  region: string;
  equipment_type: string;
  engagement_type: string;
  engagement_date: string;
  engagement_verdict: string;
  customer_satisfaction: number | null;
  coverage_gap_flag: boolean | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    specialistRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3412_engagement_verdict_rollup'),
    supabase.rpc('founder_r3412_specialist_scorecard'),
    supabase.rpc('founder_r3412_equipment_engagement_matrix'),
    supabase.rpc('founder_r3412_daily_engagement_trend'),
    supabase.rpc('founder_r3412_capa_status_board'),
    supabase.rpc('founder_r3412_root_cause_pareto'),
    supabase.rpc('founder_r3412_coverage_impact_digest'),
    supabase.rpc('founder_r3412_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const specialistRows: SpecialistRow[] = (specialistRes.data as SpecialistRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'engagement_verdict', header: 'Verdict' },
    { key: 'engagements', header: 'Engagements' },
    { key: 'pct', header: 'Share %' },
  ];

  const specialistCols: Column<SpecialistRow>[] = [
    { key: 'specialist_name', header: 'Specialist' },
    { key: 'total_engagements', header: 'Engagements' },
    { key: 'successful', header: 'Successful' },
    { key: 'needs_followup', header: 'Needs Follow-up' },
    { key: 'delayed', header: 'Delayed/Partial' },
    { key: 'coverage_gaps', header: 'Coverage Gaps' },
    { key: 'users_trained', header: 'Users Trained' },
    { key: 'avg_satisfaction', header: 'Avg CSAT' },
    { key: 'on_schedule_pct', header: 'On-Schedule %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_type', header: 'Equipment Type' },
    { key: 'engagement_type', header: 'Engagement Type' },
    { key: 'engagements', header: 'Engagements' },
    { key: 'successful', header: 'Successful' },
    { key: 'delayed', header: 'Delayed/Partial' },
    { key: 'avg_actual_hours', header: 'Avg Actual Hours' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'engagement_date', header: 'Date' },
    { key: 'engagements', header: 'Engagements' },
    { key: 'successful', header: 'Successful' },
    { key: 'delayed', header: 'Delayed/Partial' },
    { key: 'coverage_gaps', header: 'Coverage Gaps' },
    { key: 'users_trained', header: 'Users Trained' },
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
    { key: 'coverage_impact', header: 'Coverage Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'specialist_name', header: 'Specialist' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'region', header: 'Region' },
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'engagement_type', header: 'Engagement' },
    { key: 'engagement_date', header: 'Date' },
    { key: 'engagement_verdict', header: 'Verdict' },
    { key: 'customer_satisfaction', header: 'CSAT' },
    { key: 'coverage_gap_flag', header: 'Coverage Gap' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Clinical Application Specialist Coverage &amp; Go-Live Support Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Clinical-application-specialist (CAS) coverage &amp; new-equipment go-live support log —
        specialist &times; hospital &times; region &times; equipment type (imaging, cath lab, lab
        analyzer, patient monitoring, dialysis, OT equipment, anesthesia) &times; engagement type
        (installation go-live, applications training, protocol optimization, refresher, escalation
        &amp; remote support) &times; planned vs actual hours &times; sessions delivered &times;
        clinical users trained &times; competency sign-off &times; go-live on-schedule &times;
        satisfaction &times; coverage-gap flag &amp; CAPA closure. Founder-gated view: engagement
        verdicts, specialist scorecards, root-cause pareto, and coverage-impact digest across coverage,
        training &amp; scheduling actions.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Engagement verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No engagements logged yet."
          rowKey={(r, i) => String(r.engagement_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Specialist coverage scorecard</h2>
        <DataTable
          rows={specialistRows}
          columns={specialistCols}
          emptyMessage="No specialist rollups."
          rowKey={(r, i) => String(r.specialist_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment type &times; engagement type matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No engagements by equipment type."
          rowKey={(r, i) => `${r.equipment_type}-${r.engagement_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily engagement trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.engagement_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Coverage impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No coverage-impact rollups."
          rowKey={(r, i) => String(r.coverage_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk coverage queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk engagements."
          rowKey={(r, i) => `${r.specialist_name}-${r.engagement_date}-${i}`}
        />
      </section>
    </main>
  );
}
