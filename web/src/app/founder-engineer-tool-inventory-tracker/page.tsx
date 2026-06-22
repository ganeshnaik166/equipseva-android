import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerToolInventoryTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [toolsRes, needsReplacementRes, recentLifecycleRes] = await Promise.all([
    sb.rpc('list_tools_r1904'),
    sb.rpc('tools_needing_replacement_r1904'),
    sb.rpc('recent_lifecycle_r1904'),
  ]);

  const tools: any[] = Array.isArray(toolsRes.data) ? toolsRes.data : [];
  const needsReplacement: any[] = Array.isArray(needsReplacementRes.data) ? needsReplacementRes.data : [];
  const recentLifecycle: any[] = Array.isArray(recentLifecycleRes.data) ? recentLifecycleRes.data : [];

  const errors = [toolsRes.error, needsReplacementRes.error, recentLifecycleRes.error]
    .filter(Boolean)
    .map((e: any) => e?.message ?? String(e));

  const toolsColumns: Column<any>[] = [
    { key: 'tool_name', header: 'Tool', render: (r: any) => <span>{String(r.tool_name ?? '')}</span> },
    { key: 'tool_category', header: 'Category', render: (r: any) => <span>{String(r.tool_category ?? '')}</span> },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => <span>{String(r.engineer_email ?? '—')}</span> },
    { key: 'condition', header: 'Condition', render: (r: any) => <span>{String(r.condition ?? '')}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{String(r.status ?? '')}</span> },
    { key: 'last_used_at', header: 'Last used', render: (r: any) => <span>{r.last_used_at ? new Date(r.last_used_at).toLocaleString() : '—'}</span> },
    { key: 'captured_at', header: 'Captured', render: (r: any) => <span>{r.captured_at ? new Date(r.captured_at).toLocaleString() : '—'}</span> },
  ];

  const needsColumns: Column<any>[] = [
    { key: 'tool_name', header: 'Tool', render: (r: any) => <span>{String(r.tool_name ?? '')}</span> },
    { key: 'tool_category', header: 'Category', render: (r: any) => <span>{String(r.tool_category ?? '')}</span> },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => <span>{String(r.engineer_email ?? '—')}</span> },
    { key: 'condition', header: 'Condition', render: (r: any) => <span>{String(r.condition ?? '')}</span> },
    { key: 'last_used_at', header: 'Last used', render: (r: any) => <span>{r.last_used_at ? new Date(r.last_used_at).toLocaleString() : '—'}</span> },
  ];

  const lifecycleColumns: Column<any>[] = [
    { key: 'tool_name', header: 'Tool', render: (r: any) => <span>{String(r.tool_name ?? '—')}</span> },
    { key: 'action_type', header: 'Action', render: (r: any) => <span>{String(r.action_type ?? '')}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => <span>{String(r.by_email ?? '—')}</span> },
    { key: 'taken_at', header: 'Taken', render: (r: any) => <span>{r.taken_at ? new Date(r.taken_at).toLocaleString() : '—'}</span> },
    { key: 'notes_md', header: 'Notes', render: (r: any) => <span>{String(r.notes_md ?? '—')}</span> },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Engineer Tool Inventory Tracker</h1>
        <p style={{ color: '#666', marginTop: 8 }}>
          Track tools engineers carry per job — condition, lifecycle, and replacement signals.
        </p>
      </header>

      {errors.length > 0 && (
        <section style={{ marginBottom: 16, padding: 12, background: '#fee', border: '1px solid #f99', borderRadius: 8 }}>
          <strong>Errors:</strong>
          <ul>
            {errors.map((e, i) => (
              <li key={i}>{e}</li>
            ))}
          </ul>
        </section>
      )}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          All tools ({tools.length})
        </h2>
        <DataTable rows={tools} columns={toolsColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Tools needing replacement ({needsReplacement.length})
        </h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 14 }}>
          Active tools where condition is poor or needs_replacement.
        </p>
        <DataTable rows={needsReplacement} columns={needsColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Recent lifecycle events ({recentLifecycle.length})
        </h2>
        <DataTable rows={recentLifecycle} columns={lifecycleColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
