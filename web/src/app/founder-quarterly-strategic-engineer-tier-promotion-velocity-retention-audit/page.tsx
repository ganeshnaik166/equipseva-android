import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type VelocityRow = { promotion_quarter: string; promotions: number; avg_velocity: number; avg_days_in_prior_tier: number; star_performers: number };
type MatrixRow = { from_tier: string; to_tier: string; transitions: number; avg_csat: number; avg_velocity: number };
type CohortRow = { cohort_quarter: string; tier: string; promoted: number; retained_90d: number; retained_180d: number; retention_90: number; retention_180: number };
type AtRiskRow = { engineer_code: string; engineer_name: string; to_tier: string; region: string; city: string; avg_csat: number; velocity: number };
type RegionRow = { region: string; promotions: number; star_performers: number; churned: number; avg_velocity: number };
type ChurnRow = { churn_reason: string; cohorts: number; intervention_recommended: string; avg_retention_90: number };
type TopRow = { engineer_code: string; engineer_name: string; from_tier: string; to_tier: string; velocity: number; days_in_prior_tier: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [velocity, matrix, cohort, atRisk, region, churn, top] = await Promise.all([
    supabase.rpc('r2973_promotion_velocity_overview'),
    supabase.rpc('r2973_tier_transition_matrix'),
    supabase.rpc('r2973_retention_cohort_summary'),
    supabase.rpc('r2973_at_risk_engineers'),
    supabase.rpc('r2973_region_promotion_breakdown'),
    supabase.rpc('r2973_churn_reasons_top'),
    supabase.rpc('r2973_top_velocity_promotions'),
  ]);

  const velocityRows: VelocityRow[] = velocity.data ?? [];
  const matrixRows: MatrixRow[] = matrix.data ?? [];
  const cohortRows: CohortRow[] = cohort.data ?? [];
  const atRiskRows: AtRiskRow[] = atRisk.data ?? [];
  const regionRows: RegionRow[] = region.data ?? [];
  const churnRows: ChurnRow[] = churn.data ?? [];
  const topRows: TopRow[] = top.data ?? [];

  const velocityCols: Column<VelocityRow>[] = [
    { header: 'Quarter', accessor: (r) => r.promotion_quarter },
    { header: 'Promotions', accessor: (r) => r.promotions },
    { header: 'Avg Velocity', accessor: (r) => r.avg_velocity },
    { header: 'Avg Days Prior Tier', accessor: (r) => r.avg_days_in_prior_tier },
    { header: 'Star Performers', accessor: (r) => r.star_performers },
  ];
  const matrixCols: Column<MatrixRow>[] = [
    { header: 'From', accessor: (r) => r.from_tier },
    { header: 'To', accessor: (r) => r.to_tier },
    { header: 'Transitions', accessor: (r) => r.transitions },
    { header: 'Avg CSAT', accessor: (r) => r.avg_csat },
    { header: 'Avg Velocity', accessor: (r) => r.avg_velocity },
  ];
  const cohortCols: Column<CohortRow>[] = [
    { header: 'Cohort Quarter', accessor: (r) => r.cohort_quarter },
    { header: 'Tier', accessor: (r) => r.tier },
    { header: 'Promoted', accessor: (r) => r.promoted },
    { header: 'Retained 90d', accessor: (r) => r.retained_90d },
    { header: 'Retained 180d', accessor: (r) => r.retained_180d },
    { header: 'Retention 90 %', accessor: (r) => r.retention_90 },
    { header: 'Retention 180 %', accessor: (r) => r.retention_180 },
  ];
  const atRiskCols: Column<AtRiskRow>[] = [
    { header: 'Code', accessor: (r) => r.engineer_code },
    { header: 'Name', accessor: (r) => r.engineer_name },
    { header: 'To Tier', accessor: (r) => r.to_tier },
    { header: 'Region', accessor: (r) => r.region },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Avg CSAT', accessor: (r) => r.avg_csat },
    { header: 'Velocity', accessor: (r) => r.velocity },
  ];
  const regionCols: Column<RegionRow>[] = [
    { header: 'Region', accessor: (r) => r.region },
    { header: 'Promotions', accessor: (r) => r.promotions },
    { header: 'Stars', accessor: (r) => r.star_performers },
    { header: 'Churned', accessor: (r) => r.churned },
    { header: 'Avg Velocity', accessor: (r) => r.avg_velocity },
  ];
  const churnCols: Column<ChurnRow>[] = [
    { header: 'Reason', accessor: (r) => r.churn_reason },
    { header: 'Cohorts', accessor: (r) => r.cohorts },
    { header: 'Intervention', accessor: (r) => r.intervention_recommended },
    { header: 'Avg Retention 90 %', accessor: (r) => r.avg_retention_90 },
  ];
  const topCols: Column<TopRow>[] = [
    { header: 'Code', accessor: (r) => r.engineer_code },
    { header: 'Name', accessor: (r) => r.engineer_name },
    { header: 'From', accessor: (r) => r.from_tier },
    { header: 'To', accessor: (r) => r.to_tier },
    { header: 'Velocity', accessor: (r) => r.velocity },
    { header: 'Days Prior Tier', accessor: (r) => r.days_in_prior_tier },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 28 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Quarterly Strategic Engineer-Tier Promotion Velocity & Retention Audit</h1>
        <p style={{ color: '#666', marginTop: 4 }}>Founder-only. Promotion velocity, tier transitions, retention cohorts & at-risk engineers.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Promotion Velocity by Quarter</h2>
        <DataTable rows={velocityRows} columns={velocityCols} emptyMessage="No velocity data." rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Tier Transition Matrix</h2>
        <DataTable rows={matrixRows} columns={matrixCols} emptyMessage="No transitions." rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Retention Cohort Summary</h2>
        <DataTable rows={cohortRows} columns={cohortCols} emptyMessage="No cohorts." rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>At-Risk & Churned Engineers</h2>
        <DataTable rows={atRiskRows} columns={atRiskCols} emptyMessage="No at-risk engineers." rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Region Promotion Breakdown</h2>
        <DataTable rows={regionRows} columns={regionCols} emptyMessage="No regions." rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Churn Reasons</h2>
        <DataTable rows={churnRows} columns={churnCols} emptyMessage="No churn data." rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Velocity Promotions</h2>
        <DataTable rows={topRows} columns={topCols} emptyMessage="No top performers." rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>
    </div>
  );
}
