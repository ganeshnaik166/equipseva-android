import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [dropsRes, byStageRes, recentRes] = await Promise.all([
    sb.rpc('list_drops_r2159'),
    sb.rpc('by_stage_r2159'),
    sb.rpc('recent_actions_r2159'),
  ]);

  const drops: any[] = Array.isArray(dropsRes.data) ? dropsRes.data : [];
  const byStage: any[] = Array.isArray(byStageRes.data) ? byStageRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const dropCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? r.hospital_id ?? '—' },
    { key: 'drop_off_stage', header: 'Stage', render: (r: any) => r.drop_off_stage ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'drop_off_reason_md', header: 'Reason', render: (r: any) => r.drop_off_reason_md ?? '—' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '—' },
  ];

  const stageCols: Column<any>[] = [
    { key: 'drop_off_stage', header: 'Stage', render: (r: any) => r.drop_off_stage ?? '—' },
    { key: 'total_count', header: 'Total', render: (r: any) => String(r.total_count ?? 0) },
    { key: 'active_count', header: 'Active', render: (r: any) => String(r.active_count ?? 0) },
    { key: 'recovered_count', header: 'Recovered', render: (r: any) => String(r.recovered_count ?? 0) },
    { key: 'lost_count', header: 'Lost', render: (r: any) => String(r.lost_count ?? 0) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '—' },
    { key: 'drop_id', header: 'Drop ID', render: (r: any) => r.drop_id ? String(r.drop_id).slice(0, 8) : '—' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Customer Onboarding Drop-Off</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track where hospital customers fall off the onboarding funnel and the recovery actions taken.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Funnel breakdown by stage</h2>
        <DataTable rows={byStage} columns={stageCols} rowKey={(r, i) => String(r.drop_off_stage ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent drop-offs</h2>
        <DataTable rows={drops} columns={dropCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent recovery actions</h2>
        <DataTable rows={recent} columns={actionCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
