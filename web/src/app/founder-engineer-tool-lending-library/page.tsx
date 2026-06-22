import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [toolsRes, actionsRes, lowRes, recentRes] = await Promise.all([
    sb.rpc('list_tools_r2064'),
    sb.rpc('list_actions_r2064'),
    sb.rpc('low_inventory_r2064'),
    sb.rpc('recent_actions_r2064', { p_limit: 50 }),
  ]);

  const tools: any[] = Array.isArray(toolsRes.data) ? toolsRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  const low: any[] = Array.isArray(lowRes.data) ? lowRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const toolCols: Column<any>[] = [
    { key: 'tool_label', header: 'Tool', render: (r: any) => String(r.tool_label ?? '') },
    { key: 'tool_category', header: 'Category', render: (r: any) => String(r.tool_category ?? '') },
    { key: 'total_inventory', header: 'Total', render: (r: any) => String(r.total_inventory ?? 0) },
    { key: 'borrowed_count', header: 'Borrowed', render: (r: any) => String(r.borrowed_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const lowCols: Column<any>[] = [
    { key: 'tool_label', header: 'Tool', render: (r: any) => String(r.tool_label ?? '') },
    { key: 'tool_category', header: 'Category', render: (r: any) => String(r.tool_category ?? '') },
    { key: 'available', header: 'Available', render: (r: any) => String(Number(r.total_inventory ?? 0) - Number(r.borrowed_count ?? 0)) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'tool_id', header: 'Tool Id', render: (r: any) => String(r.tool_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => r.engineer_user_id ? String(r.engineer_user_id).slice(0, 8) : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Engineer Tool Lending Library</h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Track diagnostic, specialized, measurement, safety, and lifting tools loaned out to field engineers.
      </p>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Tool Inventory</h2>
        <DataTable rows={tools} columns={toolCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Low Inventory and All Borrowed</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>Tools with one or fewer available units, or in maintenance.</p>
        <DataTable rows={low} columns={lowCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Actions</h2>
        <DataTable rows={recent} columns={actionCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Action Log</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
