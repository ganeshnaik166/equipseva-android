import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCrisisDrillLogPage() {
  const sb = await getSupabaseServerClient();

  const [drillsRes, recentDrillsRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_drills_r2142'),
    sb.rpc('recent_drills_r2142', { p_limit: 20 }),
    sb.rpc('recent_actions_r2142', { p_limit: 20 }),
  ]);

  const drills: any[] = Array.isArray(drillsRes.data) ? drillsRes.data : [];
  const recentDrills: any[] = Array.isArray(recentDrillsRes.data) ? recentDrillsRes.data : [];
  const recentActions: any[] = Array.isArray(recentActionsRes.data) ? recentActionsRes.data : [];

  const totalDrills = drills.length;
  const completed = drills.filter((d) => d.status === 'completed').length;
  const planned = drills.filter((d) => d.status === 'planned').length;
  const escalated = drills.filter((d) => d.status === 'escalated').length;

  const drillCols: Column<any>[] = [
    { key: 'drill_label', header: 'Label', render: (r: any) => String(r.drill_label ?? '') },
    { key: 'drill_type', header: 'Type', render: (r: any) => String(r.drill_type ?? '').replace(/_/g, ' ') },
    { key: 'drill_date', header: 'Date', render: (r: any) => String(r.drill_date ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const recentDrillCols: Column<any>[] = [
    { key: 'drill_label', header: 'Label', render: (r: any) => String(r.drill_label ?? '') },
    { key: 'drill_type', header: 'Type', render: (r: any) => String(r.drill_type ?? '').replace(/_/g, ' ') },
    { key: 'drill_date', header: 'Date', render: (r: any) => String(r.drill_date ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'drill_id', header: 'Drill ID', render: (r: any) => String(r.drill_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '').replace(/_/g, ' ') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Crisis Drill Log</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Log crisis drills and rehearsals across ransomware, data breach, key employee loss, legal action, customer revolt, and regulatory action scenarios.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16 }}>
          <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#888' }}>Total drills</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{totalDrills}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#888' }}>Completed</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{completed}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#888' }}>Planned</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{planned}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#888' }}>Escalated</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{escalated}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Drills</h2>
        <DataTable rows={drills} columns={drillCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Drills</h2>
        <DataTable rows={recentDrills} columns={recentDrillCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable rows={recentActions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
