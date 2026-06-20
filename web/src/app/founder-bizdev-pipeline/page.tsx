import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function inr(n: number | null | undefined): string {
  if (n == null) return '—';
  return '₹' + Math.round(Number(n)).toLocaleString('en-IN');
}

function num(n: number | null | undefined): string {
  if (n == null) return '—';
  return Number(n).toLocaleString('en-IN');
}

export default async function FounderBizdevPipelinePage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let funnel: any[] = [];
  let activeDeals: any[] = [];
  let leaderboard: any[] = [];
  let summary: any = null;
  let recentActivity: any[] = [];

  try {
    const r = await sb.rpc('rpc_founder_bizdev_funnel_overview');
    funnel = (r.data as any[]) ?? [];
  } catch { funnel = []; }
  try {
    const r = await sb.rpc('rpc_founder_bizdev_active_deals', { p_limit: 50 });
    activeDeals = (r.data as any[]) ?? [];
  } catch { activeDeals = []; }
  try {
    const r = await sb.rpc('rpc_founder_bizdev_owner_leaderboard');
    leaderboard = (r.data as any[]) ?? [];
  } catch { leaderboard = []; }
  try {
    const r = await sb.rpc('rpc_founder_bizdev_forecast_summary');
    const rows = (r.data as any[]) ?? [];
    summary = rows[0] ?? null;
  } catch { summary = null; }
  try {
    const r = await sb.rpc('rpc_founder_bizdev_recent_activity', { p_limit: 30 });
    recentActivity = (r.data as any[]) ?? [];
  } catch { recentActivity = []; }

  const stageOf = (s: string) => funnel.find((f) => f.stage === s) ?? null;
  const leadStage = stageOf('lead');
  const qualStage = stageOf('qualified');
  const demoStage = stageOf('demo');
  const propStage = stageOf('proposal');
  const wonStage = stageOf('closed_won');

  const kpis: Kpi[] = [
    { label: 'Total deals', value: num(summary?.total_deals) },
    { label: 'Active deals', value: num(summary?.active_deals) },
    { label: 'Closed-won (all-time)', value: num(summary?.closed_won_alltime) },
    { label: 'Closed-lost (all-time)', value: num(summary?.closed_lost_alltime) },
    { label: 'Win rate', value: (summary?.win_rate_pct ?? '—') + '%' },
    { label: 'Weighted monthly forecast', value: inr(summary?.weighted_monthly_forecast_rupees) },
    { label: 'Unweighted pipeline', value: inr(summary?.unweighted_monthly_pipeline_rupees) },
    { label: 'Avg deal size', value: inr(summary?.avg_deal_size_rupees) },
    { label: 'Avg win probability', value: (summary?.avg_win_probability_pct ?? '—') + '%' },
    { label: 'Stage · Lead', value: num(leadStage?.deal_count) },
    { label: 'Stage · Qualified', value: num(qualStage?.deal_count) },
    { label: 'Stage · Demo', value: num(demoStage?.deal_count) },
    { label: 'Stage · Proposal', value: num(propStage?.deal_count) },
    { label: 'Stage · Closed-won', value: num(wonStage?.deal_count) },
    { label: 'AE owners active', value: num(leaderboard.filter((l) => l.ae_owner_email !== '(unassigned)').length) },
    { label: 'Recent activity (30)', value: num(recentActivity.length) }
  ];

  const funnelCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '—' },
    { key: 'deal_count', header: 'Deals', render: (r: any) => num(r.deal_count) },
    { key: 'total_expected_monthly_revenue_rupees', header: 'Expected monthly', render: (r: any) => inr(r.total_expected_monthly_revenue_rupees) },
    { key: 'weighted_forecast_rupees', header: 'Weighted forecast', render: (r: any) => inr(r.weighted_forecast_rupees) }
  ];

  const dealCols: Column<any>[] = [
    { key: 'clinic_name', header: 'Clinic', render: (r: any) => r.clinic_name ?? '—' },
    { key: 'clinic_city', header: 'City', render: (r: any) => r.clinic_city ?? '—' },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '—' },
    { key: 'ae_owner_email', header: 'AE', render: (r: any) => r.ae_owner_email ?? '—' },
    { key: 'expected_monthly_revenue_rupees', header: 'Monthly', render: (r: any) => inr(r.expected_monthly_revenue_rupees) },
    { key: 'win_probability_pct', header: 'Win %', render: (r: any) => (r.win_probability_pct ?? '—') + '%' },
    { key: 'expected_close_date', header: 'Close by', render: (r: any) => r.expected_close_date ?? '—' },
    { key: 'days_in_stage', header: 'Days in stage', render: (r: any) => r.days_in_stage ?? '—' }
  ];

  const leaderCols: Column<any>[] = [
    { key: 'ae_owner_email', header: 'Owner', render: (r: any) => r.ae_owner_email ?? '—' },
    { key: 'active_deals', header: 'Active', render: (r: any) => num(r.active_deals) },
    { key: 'closed_won_30d', header: 'Won (30d)', render: (r: any) => num(r.closed_won_30d) },
    { key: 'closed_lost_30d', header: 'Lost (30d)', render: (r: any) => num(r.closed_lost_30d) },
    { key: 'weighted_pipeline_rupees', header: 'Weighted pipeline', render: (r: any) => inr(r.weighted_pipeline_rupees) }
  ];

  const activityCols: Column<any>[] = [
    { key: 'occurred_at', header: 'When', render: (r: any) => r.occurred_at ?? '—' },
    { key: 'clinic_name', header: 'Clinic', render: (r: any) => r.clinic_name ?? '—' },
    { key: 'activity_type', header: 'Type', render: (r: any) => r.activity_type ?? '—' },
    { key: 'from_stage', header: 'From', render: (r: any) => r.from_stage ?? '—' },
    { key: 'to_stage', header: 'To', render: (r: any) => r.to_stage ?? '—' },
    { key: 'actor_email', header: 'Actor', render: (r: any) => r.actor_email ?? '—' }
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Founder · BizDev Pipeline</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Individual-clinic sales funnel (small deals, fast cycle). Separate from partnerships (r1456).
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: 12, marginBottom: 32 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 16, background: '#fff' }}>
            <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Funnel overview</h2>
        <DataTable<any> rows={funnel} columns={funnelCols} rowKey={(r: any) => r.stage} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Active deals</h2>
        <DataTable<any> rows={activeDeals} columns={dealCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Owner leaderboard (AE/CSM)</h2>
        <DataTable<any> rows={leaderboard} columns={leaderCols} rowKey={(r: any) => r.ae_owner_email} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent activity</h2>
        <DataTable<any> rows={recentActivity} columns={activityCols} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
