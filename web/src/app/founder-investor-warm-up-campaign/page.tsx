import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

export default async function FounderInvestorWarmUpCampaignPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let overview: any = null;
  let campaigns: any[] = [];
  let touchpoints: any[] = [];
  let due: any[] = [];
  let hottest: any[] = [];

  try {
    const r = await sb.rpc('founder_warm_campaign_overview');
    overview = (r.data && r.data[0]) || null;
  } catch {}
  try {
    const r = await sb.rpc('founder_warm_campaign_list');
    campaigns = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_warm_touchpoint_recent');
    touchpoints = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_warm_due_actions');
    due = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_warm_hottest_leads');
    hottest = r.data || [];
  } catch {}

  const kpis: Kpi[] = [
    { label: 'Total campaigns', value: String(overview?.total_campaigns ?? 0) },
    { label: 'Active', value: String(overview?.active_campaigns ?? 0) },
    { label: 'Warm', value: String(overview?.warm_campaigns ?? 0) },
    { label: 'Intro asked', value: String(overview?.intro_asked ?? 0) },
    { label: 'Meeting booked', value: String(overview?.meeting_booked ?? 0) },
    { label: 'Avg temperature', value: String(overview?.avg_temperature ?? 0) },
    { label: 'Hottest score', value: String(overview?.hottest_score ?? 0) },
    { label: 'Total touchpoints', value: String(overview?.total_touchpoints ?? 0) },
    { label: 'Touchpoints 7d', value: String(overview?.touchpoints_last_7d ?? 0) },
    { label: 'Responded', value: String(overview?.responded_touchpoints ?? 0) },
    { label: 'Positive', value: String(overview?.positive_touchpoints ?? 0) },
    { label: 'Due 24h', value: String(overview?.due_next_24h ?? 0) },
    { label: 'Overdue', value: String(overview?.overdue_actions ?? 0) },
    { label: 'Planned', value: String(overview?.campaigns_planned ?? 0) },
    { label: 'Closed won', value: String(overview?.campaigns_closed_won ?? 0) },
    { label: 'Passed', value: String(overview?.campaigns_passed ?? 0) },
  ];

  const campaignCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => r.investor_firm ?? '—' },
    { key: 'campaign_status', header: 'Status', render: (r: any) => r.campaign_status ?? '—' },
    { key: 'warm_temperature_score', header: 'Temp', render: (r: any) => String(r.warm_temperature_score ?? 0) },
    { key: 'completed_touchpoints', header: 'Done', render: (r: any) => String(r.completed_touchpoints ?? 0) + '/' + String(r.planned_touchpoints ?? 0) },
    { key: 'next_action_at', header: 'Next action', render: (r: any) => r.next_action_at ? new Date(r.next_action_at).toLocaleString() : '—' },
  ];

  const touchCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'touchpoint_kind', header: 'Kind', render: (r: any) => r.touchpoint_kind ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
    { key: 'temperature_delta', header: 'Delta', render: (r: any) => String(r.temperature_delta ?? 0) },
    { key: 'executed_at', header: 'When', render: (r: any) => r.executed_at ? new Date(r.executed_at).toLocaleString() : '—' },
    { key: 'content_snippet', header: 'Snippet', render: (r: any) => r.content_snippet ?? '—' },
  ];

  const dueCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => r.investor_firm ?? '—' },
    { key: 'campaign_status', header: 'Status', render: (r: any) => r.campaign_status ?? '—' },
    { key: 'warm_temperature_score', header: 'Temp', render: (r: any) => String(r.warm_temperature_score ?? 0) },
    { key: 'next_action_at', header: 'Due', render: (r: any) => r.next_action_at ? new Date(r.next_action_at).toLocaleString() : '—' },
    { key: 'hours_until', header: 'Hours', render: (r: any) => r.hours_until != null ? Number(r.hours_until).toFixed(1) : '—' },
  ];

  const hotCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => r.investor_firm ?? '—' },
    { key: 'warm_temperature_score', header: 'Temp', render: (r: any) => String(r.warm_temperature_score ?? 0) },
    { key: 'campaign_status', header: 'Status', render: (r: any) => r.campaign_status ?? '—' },
    { key: 'touchpoint_count', header: 'Touches', render: (r: any) => String(r.touchpoint_count ?? 0) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Investor warm-up campaigns</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>Plan multi-touchpoint warm-ups for cold investors. Track per-investor warm-temperature across Twitter, LinkedIn, email, and intro asks.</p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: 12, marginBottom: 24 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.4 }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>All campaigns</h2>
        <DataTable columns={campaignCols} rows={campaigns} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent touchpoints</h2>
        <DataTable columns={touchCols} rows={touchpoints} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Due actions</h2>
        <DataTable columns={dueCols} rows={due} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Hottest leads</h2>
        <DataTable columns={hotCols} rows={hottest} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
