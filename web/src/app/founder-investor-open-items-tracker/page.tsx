import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorOpenItemsTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [itemsRes, summaryRes, topRes] = await Promise.all([
    sb.rpc('r1861_list_items', { p_status: null }),
    sb.rpc('r1861_open_items_summary'),
    sb.rpc('r1861_top_priority_open', { p_limit: 10 }),
  ]);

  const items: any[] = Array.isArray(itemsRes.data) ? itemsRes.data : [];
  const summary: any = Array.isArray(summaryRes.data) ? summaryRes.data[0] : summaryRes.data;
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];

  const anyErr = itemsRes.error || summaryRes.error || topRes.error;

  const itemCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => <span>{r.investor_email ?? '—'}</span> },
    { key: 'item_title', header: 'Item', render: (r: any) => <span>{r.item_title ?? '—'}</span> },
    { key: 'request_type', header: 'Type', render: (r: any) => <span>{r.request_type ?? '—'}</span> },
    { key: 'priority', header: 'Priority', render: (r: any) => <span>{r.priority ?? '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status ?? '—'}</span> },
    { key: 'requested_at', header: 'Requested', render: (r: any) => <span>{r.requested_at ? new Date(r.requested_at).toLocaleDateString() : '—'}</span> },
    { key: 'updates_count', header: 'Updates', render: (r: any) => <span>{r.updates_count ?? 0}</span> },
    { key: 'closed_at', header: 'Closed', render: (r: any) => <span>{r.closed_at ? new Date(r.closed_at).toLocaleDateString() : '—'}</span> },
  ];

  const topCols: Column<any>[] = [
    { key: 'priority', header: 'Priority', render: (r: any) => <span>{r.priority ?? '—'}</span> },
    { key: 'investor_email', header: 'Investor', render: (r: any) => <span>{r.investor_email ?? '—'}</span> },
    { key: 'item_title', header: 'Item', render: (r: any) => <span>{r.item_title ?? '—'}</span> },
    { key: 'request_type', header: 'Type', render: (r: any) => <span>{r.request_type ?? '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status ?? '—'}</span> },
    { key: 'days_open', header: 'Days Open', render: (r: any) => <span>{r.days_open ?? 0}</span> },
    { key: 'requested_at', header: 'Requested', render: (r: any) => <span>{r.requested_at ? new Date(r.requested_at).toLocaleDateString() : '—'}</span> },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>Investor Open Items Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track ongoing requests & asks from each investor until closed (r1861).
      </p>

      {anyErr ? (
        <div style={{ padding: 12, background: '#fee', border: '1px solid #fcc', borderRadius: 6, marginBottom: 16, color: '#900' }}>
          Error loading data: {String(anyErr.message ?? anyErr)}
        </div>
      ) : null}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: 12 }}>
          <div style={{ padding: 12, background: '#f6f8fa', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Items</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary?.total_items ?? 0}</div>
          </div>
          <div style={{ padding: 12, background: '#f6f8fa', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Open</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary?.open_count ?? 0}</div>
          </div>
          <div style={{ padding: 12, background: '#f6f8fa', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#666' }}>In Progress</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary?.in_progress_count ?? 0}</div>
          </div>
          <div style={{ padding: 12, background: '#f6f8fa', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Closed</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary?.closed_count ?? 0}</div>
          </div>
          <div style={{ padding: 12, background: '#f6f8fa', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Blocked</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary?.blocked_count ?? 0}</div>
          </div>
          <div style={{ padding: 12, background: '#fff5f5', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#900' }}>Critical Open</div>
            <div style={{ fontSize: 22, fontWeight: 700, color: '#900' }}>{summary?.critical_open ?? 0}</div>
          </div>
          <div style={{ padding: 12, background: '#fffbeb', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#854d0e' }}>High Open</div>
            <div style={{ fontSize: 22, fontWeight: 700, color: '#854d0e' }}>{summary?.high_open ?? 0}</div>
          </div>
          <div style={{ padding: 12, background: '#f6f8fa', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Avg Days to Close</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary?.avg_days_to_close ?? '—'}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Priority Open Items</h2>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Open Items</h2>
        <DataTable rows={items} columns={itemCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
