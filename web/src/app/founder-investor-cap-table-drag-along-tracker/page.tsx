import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [drags, threshold, recent] = await Promise.all([
    sb.rpc('list_drags_r2149'),
    sb.rpc('threshold_met_r2149'),
    sb.rpc('recent_actions_r2149'),
  ]);

  const dragRows: any[] = Array.isArray(drags.data) ? drags.data : [];
  const thresholdRows: any[] = Array.isArray(threshold.data) ? threshold.data : [];
  const recentRows: any[] = Array.isArray(recent.data) ? recent.data : [];

  const dragCols: Column<any>[] = [
    { key: 'drag_along_label', header: 'Label', render: (r: any) => String(r.drag_along_label ?? '') },
    { key: 'threshold_pct', header: 'Threshold pct', render: (r: any) => String(r.threshold_pct ?? '') },
    { key: 'shares_consented', header: 'Shares consented', render: (r: any) => String(r.shares_consented ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const thresholdCols: Column<any>[] = [
    { key: 'drag_along_label', header: 'Label', render: (r: any) => String(r.drag_along_label ?? '') },
    { key: 'threshold_pct', header: 'Threshold pct', render: (r: any) => String(r.threshold_pct ?? '') },
    { key: 'shares_consented', header: 'Shares', render: (r: any) => String(r.shares_consented ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'shares_count', header: 'Shares', render: (r: any) => String(r.shares_count ?? 0) },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Cap Table Drag-Along Tracker</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Track drag-along rights across investors. Threshold percentages, share consent counts,
        and lifecycle status (active, exercised, waived, expired).
      </p>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Drag-Along Rights</h2>
        <DataTable rows={dragRows} columns={dragCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Active (Threshold-Eligible)</h2>
        <DataTable rows={thresholdRows} columns={thresholdCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Actions</h2>
        <DataTable rows={recentRows} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
