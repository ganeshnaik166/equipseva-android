import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [reopensRes, highRes, recentRes] = await Promise.all([
    sb.rpc('list_reopens_r2095'),
    sb.rpc('high_count_r2095'),
    sb.rpc('recent_actions_r2095'),
  ]);

  const reopens: any[] = Array.isArray(reopensRes.data) ? reopensRes.data : [];
  const high: any[] = Array.isArray(highRes.data) ? highRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const reopenCols: Column<any>[] = [
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'original_repair_job_id', header: 'Original Job', render: (r: any) => String(r.original_repair_job_id ?? '').slice(0, 8) },
    { key: 'reopen_reason', header: 'Reason', render: (r: any) => String(r.reopen_reason ?? '') },
    { key: 'reopen_count', header: 'Count', render: (r: any) => String(r.reopen_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const highCols: Column<any>[] = [
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'reopen_count', header: 'Reopen Count', render: (r: any) => String(r.reopen_count ?? 0) },
    { key: 'reopen_reason', header: 'Reason', render: (r: any) => String(r.reopen_reason ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'reopen_id', header: 'Reopen', render: (r: any) => String(r.reopen_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Repair Job Re-Open Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track repair jobs that get re-opened. Flag hospitals with high re-open counts and log founder follow-up actions.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Re-Opens</h2>
        <DataTable rows={reopens} columns={reopenCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>High Re-Open Count (two or more)</h2>
        <DataTable rows={high} columns={highCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Founder Actions</h2>
        <DataTable rows={recent} columns={actionCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
