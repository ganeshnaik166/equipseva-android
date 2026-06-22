import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [records, exceptional, recent] = await Promise.all([
    sb.rpc('r2176_list_records'),
    sb.rpc('r2176_exceptional'),
    sb.rpc('r2176_recent_actions'),
  ]);

  const rows = (records.data ?? []) as any[];
  const exc = (exceptional.data ?? []) as any[];
  const acts = (recent.data ?? []) as any[];

  const recordCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'repeat_jobs_count', header: 'Repeat', render: (r: any) => String(r.repeat_jobs_count ?? 0) },
    { key: 'total_jobs_count', header: 'Total', render: (r: any) => String(r.total_jobs_count ?? 0) },
    { key: 'repeat_rate_pct', header: 'Rate %', render: (r: any) => `${Number(r.repeat_rate_pct ?? 0).toFixed(1)}%` },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '—' },
  ];

  const excCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'repeat_jobs_count', header: 'Repeat', render: (r: any) => String(r.repeat_jobs_count ?? 0) },
    { key: 'total_jobs_count', header: 'Total', render: (r: any) => String(r.total_jobs_count ?? 0) },
    { key: 'repeat_rate_pct', header: 'Rate %', render: (r: any) => `${Number(r.repeat_rate_pct ?? 0).toFixed(1)}%` },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '—' },
  ];

  const actCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '—' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Engineer Repeat Customer Builder v2</h1>
        <p className="text-sm text-gray-500">Track repeat-customer rate per engineer-hospital pair. Coach builders, celebrate exceptional, intervene declining.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">All records</h2>
        <DataTable rows={rows} columns={recordCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Exceptional pairs</h2>
        <DataTable rows={exc} columns={excCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent actions</h2>
        <DataTable rows={acts} columns={actCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
