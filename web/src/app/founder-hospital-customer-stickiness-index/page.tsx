import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const indicesRes = await sb.rpc('list_stickiness_indices_r2155');
  const indices: any[] = Array.isArray(indicesRes.data) ? indicesRes.data : [];

  const verySticky = await sb.rpc('very_sticky_stickiness_r2155');
  const verySticky_rows: any[] = Array.isArray(verySticky.data) ? verySticky.data : [];

  const recent = await sb.rpc('recent_stickiness_actions_r2155');
  const recent_rows: any[] = Array.isArray(recent.data) ? recent.data : [];

  const indexColumns: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'stickiness_score', header: 'Score', render: (r: any) => String(r.stickiness_score ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const veryStickyColumns: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'stickiness_score', header: 'Score', render: (r: any) => String(r.stickiness_score ?? '') },
    { key: 'retention_factors_md', header: 'Factors', render: (r: any) => String(r.retention_factors_md ?? '').slice(0, 80) },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Customer Stickiness Index</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track customer stickiness over time. Scores range from zero to one hundred. Status buckets: very sticky, sticky, loose, at risk, lost.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Stickiness Indices</h2>
        <DataTable rows={indices} columns={indexColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Very Sticky Customers</h2>
        <DataTable rows={verySticky_rows} columns={veryStickyColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Stickiness Actions</h2>
        <DataTable rows={recent_rows} columns={actionColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
