import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [famRes, queueRes, recentRes] = await Promise.all([
    sb.rpc('list_familiarity_r1880'),
    sb.rpc('refresh_recommended_queue_r1880'),
    sb.rpc('recently_refreshed_r1880'),
  ]);

  const familiarity: any[] = Array.isArray(famRes.data) ? famRes.data : [];
  const queue: any[] = Array.isArray(queueRes.data) ? queueRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const famColumns: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? r.engineer_user_id ?? '') },
    { key: 'equipment_category', header: 'Equipment', render: (r: any) => String(r.equipment_category ?? '') },
    { key: 'last_serviced_at', header: 'Last Serviced', render: (r: any) => r.last_serviced_at ? new Date(r.last_serviced_at).toLocaleDateString() : '—' },
    { key: 'days_since_service', header: 'Days Since', render: (r: any) => String(r.days_since_service ?? 0) },
    { key: 'refresh_recommended', header: 'Rec?', render: (r: any) => r.refresh_recommended ? 'yes' : 'no' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '—' },
  ];

  const queueColumns: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? r.engineer_user_id ?? '') },
    { key: 'equipment_category', header: 'Equipment', render: (r: any) => String(r.equipment_category ?? '') },
    { key: 'days_since_service', header: 'Days Since', render: (r: any) => String(r.days_since_service ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '—' },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? r.engineer_user_id ?? '') },
    { key: 'equipment_category', header: 'Equipment', render: (r: any) => String(r.equipment_category ?? '') },
    { key: 'refresh_completed_at', header: 'Refreshed At', render: (r: any) => r.refresh_completed_at ? new Date(r.refresh_completed_at).toLocaleString() : '—' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const recCount = familiarity.filter((f) => f.status === 'refresh_recommended').length;
  const lostCount = familiarity.filter((f) => f.status === 'lost').length;
  const doneCount = familiarity.filter((f) => f.status === 'refresh_done').length;

  return (
    <main style={{ padding: 24, fontFamily: 'ui-sans-serif, system-ui' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Engineer Equipment Familiarity Refresh
      </h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Track when engineers need familiarity refresh on aging equipment (&gt;180 days since service).
      </p>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Summary</h2>
        <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap' }}>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8, minWidth: 140 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total tracked</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{familiarity.length}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8, minWidth: 140 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Refresh recommended</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{recCount}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8, minWidth: 140 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Refresh done</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{doneCount}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8, minWidth: 140 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Lost (&gt;365d)</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{lostCount}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Familiarity Records</h2>
        <DataTable
          rows={familiarity}
          columns={famColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Refresh-Recommended Queue
        </h2>
        <DataTable
          rows={queue}
          columns={queueColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Recently Refreshed (last 30 days)
        </h2>
        <DataTable
          rows={recent}
          columns={recentColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
