import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/data-table';

export const dynamic = 'force-dynamic';

type PipelineRow = { filing_stage: string; patent_count: number; total_filing_cost_rupees: number; total_estimated_value_rupees: number; strategic_count: number };
type JurisdictionRow = { filing_jurisdiction: string; total_filings: number; granted_count: number; total_cost_rupees: number; avg_value_rupees: number };
type LeaderboardRow = { engineer_name: string; region: string; invention_count: number; patents_granted_count: number; recognition_tier: string; cash_award_rupees: number; total_revenue_impact_rupees: number };
type TierRow = { recognition_tier: string; inventor_count: number; total_cash_award_rupees: number; total_equity_units: number; hall_of_fame_count: number; total_revenue_impact_rupees: number };
type ActionRow = { invention_title: string; inventor_name: string; filing_stage: string; next_action_due_at: string; days_until_due: number; attorney_assigned: string };
type CategoryRow = { invention_category: string; filing_count: number; total_estimated_value_rupees: number; granted_count: number; strategic_count: number };
type StatusRow = { recognition_status: string; inventor_count: number; total_cash_award_rupees: number; avg_invention_count: number; pending_review_count: number };
type RegionRow = { region: string; inventor_count: number; total_inventions: number; total_grants: number; hall_of_fame_count: number; total_revenue_impact_rupees: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [pipeline, jurisdiction, leaderboard, tier, actions, category, status, region] = await Promise.all([
    sb.rpc('r3005_patent_pipeline_overview'),
    sb.rpc('r3005_jurisdiction_breakdown'),
    sb.rpc('r3005_inventor_leaderboard'),
    sb.rpc('r3005_recognition_tier_summary'),
    sb.rpc('r3005_upcoming_filing_actions'),
    sb.rpc('r3005_category_value_analysis'),
    sb.rpc('r3005_recognition_status_audit'),
    sb.rpc('r3005_regional_innovation_map'),
  ]);

  const pipelineRows: PipelineRow[] = pipeline.data ?? [];
  const jurisdictionRows: JurisdictionRow[] = jurisdiction.data ?? [];
  const leaderboardRows: LeaderboardRow[] = leaderboard.data ?? [];
  const tierRows: TierRow[] = tier.data ?? [];
  const actionRows: ActionRow[] = actions.data ?? [];
  const categoryRows: CategoryRow[] = category.data ?? [];
  const statusRows: StatusRow[] = status.data ?? [];
  const regionRows: RegionRow[] = region.data ?? [];

  const pipelineCols: Column<PipelineRow>[] = [
    { header: 'Filing Stage', accessor: (r) => r.filing_stage },
    { header: 'Patents', accessor: (r) => r.patent_count },
    { header: 'Filing Cost (Rs)', accessor: (r) => r.total_filing_cost_rupees?.toLocaleString() },
    { header: 'Est. Value (Rs)', accessor: (r) => r.total_estimated_value_rupees?.toLocaleString() },
    { header: 'Strategic', accessor: (r) => r.strategic_count },
  ];

  const jurisdictionCols: Column<JurisdictionRow>[] = [
    { header: 'Jurisdiction', accessor: (r) => r.filing_jurisdiction },
    { header: 'Filings', accessor: (r) => r.total_filings },
    { header: 'Granted', accessor: (r) => r.granted_count },
    { header: 'Cost (Rs)', accessor: (r) => r.total_cost_rupees?.toLocaleString() },
    { header: 'Avg Value (Rs)', accessor: (r) => r.avg_value_rupees?.toLocaleString() },
  ];

  const leaderboardCols: Column<LeaderboardRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Region', accessor: (r) => r.region },
    { header: 'Inventions', accessor: (r) => r.invention_count },
    { header: 'Grants', accessor: (r) => r.patents_granted_count },
    { header: 'Tier', accessor: (r) => r.recognition_tier },
    { header: 'Cash Award (Rs)', accessor: (r) => r.cash_award_rupees?.toLocaleString() },
    { header: 'Revenue Impact (Rs)', accessor: (r) => r.total_revenue_impact_rupees?.toLocaleString() },
  ];

  const tierCols: Column<TierRow>[] = [
    { header: 'Tier', accessor: (r) => r.recognition_tier },
    { header: 'Inventors', accessor: (r) => r.inventor_count },
    { header: 'Cash Award (Rs)', accessor: (r) => r.total_cash_award_rupees?.toLocaleString() },
    { header: 'Equity Units', accessor: (r) => r.total_equity_units?.toLocaleString() },
    { header: 'Hall of Fame', accessor: (r) => r.hall_of_fame_count },
    { header: 'Revenue Impact (Rs)', accessor: (r) => r.total_revenue_impact_rupees?.toLocaleString() },
  ];

  const actionCols: Column<ActionRow>[] = [
    { header: 'Invention', accessor: (r) => r.invention_title },
    { header: 'Inventor', accessor: (r) => r.inventor_name },
    { header: 'Stage', accessor: (r) => r.filing_stage },
    { header: 'Due Date', accessor: (r) => r.next_action_due_at },
    { header: 'Days Until Due', accessor: (r) => r.days_until_due },
    { header: 'Attorney', accessor: (r) => r.attorney_assigned ?? '-' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { header: 'Category', accessor: (r) => r.invention_category },
    { header: 'Filings', accessor: (r) => r.filing_count },
    { header: 'Est. Value (Rs)', accessor: (r) => r.total_estimated_value_rupees?.toLocaleString() },
    { header: 'Granted', accessor: (r) => r.granted_count },
    { header: 'Strategic', accessor: (r) => r.strategic_count },
  ];

  const statusCols: Column<StatusRow>[] = [
    { header: 'Status', accessor: (r) => r.recognition_status },
    { header: 'Inventors', accessor: (r) => r.inventor_count },
    { header: 'Cash Award (Rs)', accessor: (r) => r.total_cash_award_rupees?.toLocaleString() },
    { header: 'Avg Inventions', accessor: (r) => r.avg_invention_count },
    { header: 'Pending Review', accessor: (r) => r.pending_review_count },
  ];

  const regionCols: Column<RegionRow>[] = [
    { header: 'Region', accessor: (r) => r.region },
    { header: 'Inventors', accessor: (r) => r.inventor_count },
    { header: 'Inventions', accessor: (r) => r.total_inventions },
    { header: 'Grants', accessor: (r) => r.total_grants },
    { header: 'Hall of Fame', accessor: (r) => r.hall_of_fame_count },
    { header: 'Revenue Impact (Rs)', accessor: (r) => r.total_revenue_impact_rupees?.toLocaleString() },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Quarterly Strategic Engineer-Innovation Patent-Filing Pipeline & Inventor Recognition Audit</h1>
      <p style={{ color: '#6b7280', marginBottom: 24 }}>Founder console r3005 — patent IP portfolio & inventor recognition strategic review</p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Patent Pipeline Overview</h2>
        <DataTable rows={pipelineRows} columns={pipelineCols} emptyMessage="No pipeline data" rowKey={(r, i) => String((r as { filing_stage?: string }).filing_stage ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Jurisdiction Breakdown</h2>
        <DataTable rows={jurisdictionRows} columns={jurisdictionCols} emptyMessage="No jurisdiction data" rowKey={(r, i) => String((r as { filing_jurisdiction?: string }).filing_jurisdiction ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Inventor Leaderboard</h2>
        <DataTable rows={leaderboardRows} columns={leaderboardCols} emptyMessage="No inventors" rowKey={(r, i) => String((r as { engineer_name?: string }).engineer_name ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recognition Tier Summary</h2>
        <DataTable rows={tierRows} columns={tierCols} emptyMessage="No tier data" rowKey={(r, i) => String((r as { recognition_tier?: string }).recognition_tier ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Upcoming Filing Actions</h2>
        <DataTable rows={actionRows} columns={actionCols} emptyMessage="No upcoming actions" rowKey={(r, i) => String((r as { invention_title?: string }).invention_title ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Category Value Analysis</h2>
        <DataTable rows={categoryRows} columns={categoryCols} emptyMessage="No category data" rowKey={(r, i) => String((r as { invention_category?: string }).invention_category ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recognition Status Audit</h2>
        <DataTable rows={statusRows} columns={statusCols} emptyMessage="No status data" rowKey={(r, i) => String((r as { recognition_status?: string }).recognition_status ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Regional Innovation Map</h2>
        <DataTable rows={regionRows} columns={regionCols} emptyMessage="No regional data" rowKey={(r, i) => String((r as { region?: string }).region ?? i)} />
      </section>
    </div>
  );
}
