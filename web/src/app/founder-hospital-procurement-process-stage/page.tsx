import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [processesRes, stalledRes, recentRes] = await Promise.all([
    sb.rpc('list_procurement_processes_r2083'),
    sb.rpc('stalled_procurement_processes_r2083'),
    sb.rpc('recent_procurement_progress_r2083'),
  ]);

  const processes: any[] = Array.isArray(processesRes.data) ? processesRes.data : [];
  const stalled: any[] = Array.isArray(stalledRes.data) ? stalledRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const processCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_id ?? '—' },
    { key: 'current_stage', header: 'Stage', render: (r: any) => r.current_stage ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'stage_entered_at', header: 'Entered', render: (r: any) => r.stage_entered_at ? new Date(r.stage_entered_at).toLocaleDateString() : '—' },
    { key: 'expected_completion_date', header: 'Expected', render: (r: any) => r.expected_completion_date ?? '—' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleDateString() : '—' },
  ];

  const stalledCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_id ?? '—' },
    { key: 'current_stage', header: 'Stage', render: (r: any) => r.current_stage ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'stage_entered_at', header: 'Stuck Since', render: (r: any) => r.stage_entered_at ? new Date(r.stage_entered_at).toLocaleDateString() : '—' },
    { key: 'expected_completion_date', header: 'Expected', render: (r: any) => r.expected_completion_date ?? '—' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '—' },
    { key: 'stage_id', header: 'Stage', render: (r: any) => r.stage_id ?? '—' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Procurement Process Stage</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track every stage of hospital procurement workflows from needs assessment through contract signed. Spot stalled deals early.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Procurement Processes</h2>
        <DataTable rows={processes} columns={processCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Stalled and Escalated</h2>
        <DataTable rows={stalled} columns={stalledCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Progress Log</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
