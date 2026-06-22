import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const trendsRes = await sb.rpc('list_trends_r2131');
  const decliningRes = await sb.rpc('declining_r2131');
  const recentRes = await sb.rpc('recent_actions_r2131');

  const trends: any[] = Array.isArray(trendsRes.data) ? trendsRes.data : [];
  const declining: any[] = Array.isArray(decliningRes.data) ? decliningRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const trendCols: Column<any>[] = [
    { key: 'week_label', header: 'Week', render: (r: any) => String(r.week_label ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'health_index_score', header: 'Score', render: (r: any) => String(r.health_index_score ?? '') },
    { key: 'trend_direction', header: 'Direction', render: (r: any) => String(r.trend_direction ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => String(r.captured_at ?? '').slice(0, 10) },
  ];

  const decliningCols: Column<any>[] = [
    { key: 'week_label', header: 'Week', render: (r: any) => String(r.week_label ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'health_index_score', header: 'Score', render: (r: any) => String(r.health_index_score ?? '') },
    { key: 'trend_direction', header: 'Direction', render: (r: any) => String(r.trend_direction ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'trend_id', header: 'Trend', render: (r: any) => String(r.trend_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => String(r.taken_at ?? '').slice(0, 16) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Hospital Customer Health-Trend Index</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Trend index of customer health across hospitals. Track rising, stable, declining and sharp-drop directions plus thriving, healthy, at-risk and critical statuses.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All trends</h2>
        <DataTable rows={trends} columns={trendCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Declining and sharp-drop</h2>
        <DataTable rows={declining} columns={decliningCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent actions</h2>
        <DataTable rows={recent} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
