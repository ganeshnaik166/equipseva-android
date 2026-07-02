import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0';
  return new Intl.NumberFormat('en-IN').format(n);
}

export default async function FounderMarketIntelFeedPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpiRow: any = {};
  let openFeed: any[] = [];
  let byCategory: any[] = [];
  let byRelevance: any[] = [];
  let actionQueue: any[] = [];

  try {
    const { data } = await sb.rpc('founder_market_intel_kpis');
    kpiRow = Array.isArray(data) && data.length > 0 ? data[0] : {};
  } catch {
    kpiRow = {};
  }
  try {
    const { data } = await sb.rpc('founder_market_intel_open_feed');
    openFeed = Array.isArray(data) ? data : [];
  } catch {
    openFeed = [];
  }
  try {
    const { data } = await sb.rpc('founder_market_intel_by_category');
    byCategory = Array.isArray(data) ? data : [];
  } catch {
    byCategory = [];
  }
  try {
    const { data } = await sb.rpc('founder_market_intel_by_relevance');
    byRelevance = Array.isArray(data) ? data : [];
  } catch {
    byRelevance = [];
  }
  try {
    const { data } = await sb.rpc('founder_market_intel_action_queue');
    actionQueue = Array.isArray(data) ? data : [];
  } catch {
    actionQueue = [];
  }

  const kpis: Kpi[] = [
    { label: 'Total Items', value: fmtNum(kpiRow.total_items) },
    { label: 'Open Items', value: fmtNum(kpiRow.open_items) },
    { label: 'P0 Open', value: fmtNum(kpiRow.p0_open) },
    { label: 'P1 Open', value: fmtNum(kpiRow.p1_open) },
    { label: 'Triaged Today', value: fmtNum(kpiRow.triaged_today) },
    { label: 'Dismissed', value: fmtNum(kpiRow.dismissed_count) },
    { label: 'Escalated', value: fmtNum(kpiRow.escalated_count) },
    { label: 'Actions Pending', value: fmtNum(kpiRow.actions_pending) },
    { label: 'Actions In Progress', value: fmtNum(kpiRow.actions_in_progress) },
    { label: 'Actions Done', value: fmtNum(kpiRow.actions_done) },
    { label: 'Actions Overdue', value: fmtNum(kpiRow.actions_overdue) },
    { label: 'Tariff Items', value: fmtNum(kpiRow.tariff_count) },
    { label: 'Regulation Items', value: fmtNum(kpiRow.regulation_count) },
    { label: 'OEM Move Items', value: fmtNum(kpiRow.oem_move_count) },
    { label: 'Competitor Items', value: fmtNum(kpiRow.competitor_count) },
    { label: 'Last 7d Items', value: fmtNum(kpiRow.last_7d_items) },
  ];

  const feedCols: Column<any>[] = [
    { key: 'headline', header: 'Headline', render: (r: any) => r.headline ?? '—' },
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '—' },
    { key: 'priority', header: 'Priority', render: (r: any) => r.priority ?? '—' },
    { key: 'relevance_tag', header: 'Relevance', render: (r: any) => r.relevance_tag ?? '—' },
    { key: 'source_name', header: 'Source', render: (r: any) => r.source_name ?? '—' },
    { key: 'published_at', header: 'Published', render: (r: any) => r.published_at ? new Date(r.published_at).toLocaleString('en-IN') : '—' },
  ];

  const categoryCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '—' },
    { key: 'total', header: 'Total', render: (r: any) => fmtNum(r.total) },
    { key: 'open_count', header: 'Open', render: (r: any) => fmtNum(r.open_count) },
    { key: 'p0_p1_count', header: 'P0+P1', render: (r: any) => fmtNum(r.p0_p1_count) },
  ];

  const relevanceCols: Column<any>[] = [
    { key: 'relevance_tag', header: 'Relevance', render: (r: any) => r.relevance_tag ?? '—' },
    { key: 'total', header: 'Total', render: (r: any) => fmtNum(r.total) },
    { key: 'open_count', header: 'Open', render: (r: any) => fmtNum(r.open_count) },
    { key: 'escalated', header: 'Escalated', render: (r: any) => fmtNum(r.escalated) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_title', header: 'Action', render: (r: any) => r.action_title ?? '—' },
    { key: 'headline', header: 'Tied To', render: (r: any) => r.headline ?? '—' },
    { key: 'priority', header: 'Priority', render: (r: any) => r.priority ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'due_at', header: 'Due', render: (r: any) => r.due_at ? new Date(r.due_at).toLocaleString('en-IN') : '—' },
  ];

  return (
    <div style={{ padding: '24px', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>Founder Market Intel Feed</h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Aggregated biomedical equipment market news (tariffs, regulations, OEM moves) with per-item priority, relevance tagging, and founder action queue.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '12px', marginBottom: '32px' }}>
        {kpis.map((k, i) => (
          <div key={i} style={{ border: '1px solid #e5e5e5', borderRadius: '8px', padding: '12px', background: '#fafafa' }}>
            <div style={{ fontSize: '12px', color: '#666', marginBottom: '4px' }}>{k.label}</div>
            <div style={{ fontSize: '20px', fontWeight: 700 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Open Intel Feed (priority sorted)</h2>
        <DataTable rows={openFeed} columns={feedCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>By Category</h2>
        <DataTable rows={byCategory} columns={categoryCols} rowKey={(r: any) => r.category} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>By Relevance Tag</h2>
        <DataTable rows={byRelevance} columns={relevanceCols} rowKey={(r: any) => r.relevance_tag} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Founder Action Queue</h2>
        <DataTable rows={actionQueue} columns={actionCols} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
