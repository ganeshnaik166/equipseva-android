import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type PanelOverview = { panel_type: string; panels_count: number; total_cost_rupees: number; avg_cog_score: number; red_or_orange: number };
type StatusDist = { result_status: string; panels_count: number; share_pct: number; avg_cog: number };
type Trend = { trend_vs_last_year: string; panels_count: number; panel_types: string };
type FollowUp = { panel_date: string; panel_type: string; headline_metric: string; follow_up_by: string; days_until: number; result_status: string };
type Recovery = { action_category: string; actions_count: number; avg_adherence: number; monthly_cost_rupees: number; sum_burnout_impact: number; sum_cog_impact: number };
type Priority = { priority: string; actions_count: number; on_track_count: number; off_track_count: number; avg_adherence: number };
type AtRisk = { panel_date: string; panel_type: string; headline_metric: string; headline_value: number; reference_high: number; unit: string; result_status: string; trend: string };
type Vendor = { vendor_lab: string; vendor_city: string; panels_count: number; total_spend_rupees: number; last_visit: string };
type CogTimeline = { panel_date: string; panel_type: string; cognitive_reserve_score: number; result_status: string; trend: string };

export default async function FounderPersonalHealthCognitiveReservePage() {
  const supabase = await getSupabaseServerClient();

  const [overviewR, statusR, trendR, followUpR, recoveryR, priorityR, atRiskR, vendorR, cogR] = await Promise.all([
    supabase.rpc('r3105_panels_overview'),
    supabase.rpc('r3105_status_distribution'),
    supabase.rpc('r3105_trend_breakdown'),
    supabase.rpc('r3105_follow_ups_due'),
    supabase.rpc('r3105_recovery_action_rollup'),
    supabase.rpc('r3105_priority_actions'),
    supabase.rpc('r3105_top_at_risk_metrics'),
    supabase.rpc('r3105_vendor_spend'),
    supabase.rpc('r3105_cognitive_reserve_timeline'),
  ]);

  const overview: PanelOverview[] = (overviewR.data ?? []) as PanelOverview[];
  const statuses: StatusDist[] = (statusR.data ?? []) as StatusDist[];
  const trends: Trend[] = (trendR.data ?? []) as Trend[];
  const followUps: FollowUp[] = (followUpR.data ?? []) as FollowUp[];
  const recovery: Recovery[] = (recoveryR.data ?? []) as Recovery[];
  const priorities: Priority[] = (priorityR.data ?? []) as Priority[];
  const atRisk: AtRisk[] = (atRiskR.data ?? []) as AtRisk[];
  const vendors: Vendor[] = (vendorR.data ?? []) as Vendor[];
  const cogTimeline: CogTimeline[] = (cogR.data ?? []) as CogTimeline[];

  const overviewCols: Column<PanelOverview>[] = [
    { key: 'panel_type', header: 'Panel Type', render: (r) => r.panel_type },
    { key: 'panels_count', header: 'Panels', render: (r) => String(r.panels_count) },
    { key: 'total_cost_rupees', header: 'Spend (Rs)', render: (r) => `Rs ${Number(r.total_cost_rupees).toLocaleString('en-IN')}` },
    { key: 'avg_cog_score', header: 'Avg Cog Reserve', render: (r) => String(r.avg_cog_score) },
    { key: 'red_or_orange', header: 'Red/Orange', render: (r) => String(r.red_or_orange) },
  ];

  const statusCols: Column<StatusDist>[] = [
    { key: 'result_status', header: 'Status', render: (r) => r.result_status },
    { key: 'panels_count', header: 'Panels', render: (r) => String(r.panels_count) },
    { key: 'share_pct', header: 'Share %', render: (r) => `${r.share_pct}%` },
    { key: 'avg_cog', header: 'Avg Cog Reserve', render: (r) => String(r.avg_cog) },
  ];

  const trendCols: Column<Trend>[] = [
    { key: 'trend_vs_last_year', header: 'Trend YoY', render: (r) => r.trend_vs_last_year },
    { key: 'panels_count', header: 'Panels', render: (r) => String(r.panels_count) },
    { key: 'panel_types', header: 'Panel Types', render: (r) => r.panel_types },
  ];

  const followUpCols: Column<FollowUp>[] = [
    { key: 'panel_date', header: 'Panel Date', render: (r) => r.panel_date },
    { key: 'panel_type', header: 'Type', render: (r) => r.panel_type },
    { key: 'headline_metric', header: 'Metric', render: (r) => r.headline_metric },
    { key: 'follow_up_by', header: 'Follow-up By', render: (r) => r.follow_up_by },
    { key: 'days_until', header: 'Days Until', render: (r) => String(r.days_until) },
    { key: 'result_status', header: 'Status', render: (r) => r.result_status },
  ];

  const recoveryCols: Column<Recovery>[] = [
    { key: 'action_category', header: 'Category', render: (r) => r.action_category },
    { key: 'actions_count', header: 'Actions', render: (r) => String(r.actions_count) },
    { key: 'avg_adherence', header: 'Avg Adherence %', render: (r) => `${r.avg_adherence}%` },
    { key: 'monthly_cost_rupees', header: 'Monthly Cost (Rs)', render: (r) => `Rs ${Number(r.monthly_cost_rupees).toLocaleString('en-IN')}` },
    { key: 'sum_burnout_impact', header: 'Burnout Impact', render: (r) => String(r.sum_burnout_impact) },
    { key: 'sum_cog_impact', header: 'Cog Impact', render: (r) => String(r.sum_cog_impact) },
  ];

  const priorityCols: Column<Priority>[] = [
    { key: 'priority', header: 'Priority', render: (r) => r.priority },
    { key: 'actions_count', header: 'Actions', render: (r) => String(r.actions_count) },
    { key: 'on_track_count', header: 'On Track', render: (r) => String(r.on_track_count) },
    { key: 'off_track_count', header: 'Off Track', render: (r) => String(r.off_track_count) },
    { key: 'avg_adherence', header: 'Avg Adherence %', render: (r) => `${r.avg_adherence}%` },
  ];

  const atRiskCols: Column<AtRisk>[] = [
    { key: 'panel_date', header: 'Date', render: (r) => r.panel_date },
    { key: 'panel_type', header: 'Panel', render: (r) => r.panel_type },
    { key: 'headline_metric', header: 'Metric', render: (r) => r.headline_metric },
    { key: 'headline_value', header: 'Value', render: (r) => `${r.headline_value} ${r.unit}` },
    { key: 'reference_high', header: 'Ref High', render: (r) => r.reference_high != null ? String(r.reference_high) : '-' },
    { key: 'result_status', header: 'Status', render: (r) => r.result_status },
    { key: 'trend', header: 'Trend', render: (r) => r.trend },
  ];

  const vendorCols: Column<Vendor>[] = [
    { key: 'vendor_lab', header: 'Lab', render: (r) => r.vendor_lab },
    { key: 'vendor_city', header: 'City', render: (r) => r.vendor_city },
    { key: 'panels_count', header: 'Panels', render: (r) => String(r.panels_count) },
    { key: 'total_spend_rupees', header: 'Spend (Rs)', render: (r) => `Rs ${Number(r.total_spend_rupees).toLocaleString('en-IN')}` },
    { key: 'last_visit', header: 'Last Visit', render: (r) => r.last_visit },
  ];

  const cogCols: Column<CogTimeline>[] = [
    { key: 'panel_date', header: 'Date', render: (r) => r.panel_date },
    { key: 'panel_type', header: 'Panel', render: (r) => r.panel_type },
    { key: 'cognitive_reserve_score', header: 'Cog Reserve (0-100)', render: (r) => String(r.cognitive_reserve_score) },
    { key: 'result_status', header: 'Status', render: (r) => r.result_status },
    { key: 'trend', header: 'Trend YoY', render: (r) => r.trend },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, margin: 0 }}>Founder Personal Health & Cognitive Reserve</h1>
        <p style={{ color: '#666', marginTop: '8px' }}>
          r3105 — annual blood panel × cardiac × cognitive battery × sleep × burnout × recovery plan.
          Founder is the company's key-person risk. Health &gt;= revenue.
        </p>
      </header>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Panel Overview by Type</h2>
        <DataTable rows={overview} columns={overviewCols} emptyMessage="No panel data" rowKey={(r, i) => String((r as PanelOverview).panel_type ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Result Status Distribution</h2>
        <DataTable rows={statuses} columns={statusCols} emptyMessage="No status data" rowKey={(r, i) => String((r as StatusDist).result_status ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Year-over-Year Trend Breakdown</h2>
        <DataTable rows={trends} columns={trendCols} emptyMessage="No trend data" rowKey={(r, i) => String((r as Trend).trend_vs_last_year ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Follow-ups Due</h2>
        <DataTable rows={followUps} columns={followUpCols} emptyMessage="No follow-ups scheduled" rowKey={(r, i) => String((r as FollowUp).panel_date + (r as FollowUp).headline_metric ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Recovery Actions by Category</h2>
        <DataTable rows={recovery} columns={recoveryCols} emptyMessage="No recovery actions" rowKey={(r, i) => String((r as Recovery).action_category ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Action Priority Rollup</h2>
        <DataTable rows={priorities} columns={priorityCols} emptyMessage="No priority data" rowKey={(r, i) => String((r as Priority).priority ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Top At-Risk Metrics</h2>
        <DataTable rows={atRisk} columns={atRiskCols} emptyMessage="No at-risk metrics — green across the board" rowKey={(r, i) => String((r as AtRisk).panel_date + (r as AtRisk).headline_metric ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Vendor / Lab Spend</h2>
        <DataTable rows={vendors} columns={vendorCols} emptyMessage="No vendor data" rowKey={(r, i) => String((r as Vendor).vendor_lab ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Cognitive Reserve Timeline</h2>
        <DataTable rows={cogTimeline} columns={cogCols} emptyMessage="No cognitive timeline data" rowKey={(r, i) => String((r as CogTimeline).panel_date + (r as CogTimeline).panel_type ?? i)} />
      </section>
    </main>
  );
}
