import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalRepairStatusRealtimePage() {
  const sb = await getSupabaseServerClient();

  const [statusRes, actionsRes, inFlightRes] = await Promise.all([
    sb.rpc('list_repair_status_r1967'),
    sb.rpc('recent_repair_status_actions_r1967', { p_limit: 50 }),
    sb.rpc('in_flight_repairs_r1967'),
  ]);

  const statusRows: any[] = (statusRes.data as any[]) ?? [];
  const actionRows: any[] = (actionsRes.data as any[]) ?? [];
  const inFlightRows: any[] = (inFlightRes.data as any[]) ?? [];

  const statusColumns: Column<any>[] = [
    { key: 'id', header: 'ID', render: (r: any) => <span className="font-mono text-xs">{String(r.id).slice(0, 8)}</span> },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => <span className="font-mono text-xs">{r.hospital_id ? String(r.hospital_id).slice(0, 8) : '—'}</span> },
    { key: 'repair_job_id', header: 'Repair Job', render: (r: any) => <span className="font-mono text-xs">{r.repair_job_id ? String(r.repair_job_id).slice(0, 8) : '—'}</span> },
    { key: 'status_phase', header: 'Phase', render: (r: any) => <span className="font-medium">{r.status_phase ?? '—'}</span> },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{r.engineer_user_id ? String(r.engineer_user_id).slice(0, 8) : '—'}</span> },
    { key: 'expected_finish_at', header: 'Expected Finish', render: (r: any) => <span>{r.expected_finish_at ? new Date(r.expected_finish_at).toLocaleString() : '—'}</span> },
    { key: 'last_ping_at', header: 'Last Ping', render: (r: any) => <span>{r.last_ping_at ? new Date(r.last_ping_at).toLocaleString() : '—'}</span> },
    { key: 'captured_at', header: 'Captured', render: (r: any) => <span>{r.captured_at ? new Date(r.captured_at).toLocaleString() : '—'}</span> },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'id', header: 'ID', render: (r: any) => <span className="font-mono text-xs">{String(r.id).slice(0, 8)}</span> },
    { key: 'status_id', header: 'Status', render: (r: any) => <span className="font-mono text-xs">{r.status_id ? String(r.status_id).slice(0, 8) : '—'}</span> },
    { key: 'action_type', header: 'Type', render: (r: any) => <span>{r.action_type ?? '—'}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => <span>{r.by_email ?? '—'}</span> },
    { key: 'taken_at', header: 'Taken', render: (r: any) => <span>{r.taken_at ? new Date(r.taken_at).toLocaleString() : '—'}</span> },
    { key: 'notes_md', header: 'Notes', render: (r: any) => <span className="text-xs">{r.notes_md ?? '—'}</span> },
  ];

  const inFlightColumns: Column<any>[] = [
    { key: 'status_phase', header: 'Phase', render: (r: any) => <span className="font-medium">{r.status_phase ?? '—'}</span> },
    { key: 'cnt', header: 'Active Count', render: (r: any) => <span>{r.cnt ?? 0}</span> },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 space-y-10">
      <header>
        <h1 className="text-2xl font-semibold">Hospital Real-Time Repair Status</h1>
        <p className="text-sm text-gray-600 mt-1">Live phase snapshots, action audit log, and in-flight repair counts across all hospital accounts.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">In-Flight Repairs by Phase</h2>
        <p className="text-sm text-gray-500 mb-3">Active repair jobs grouped by current phase (all phases other than complete).</p>
        <DataTable rows={inFlightRows} columns={inFlightColumns} rowKey={(r: any, i: number) => String(r.status_phase ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Live Repair Status Feed</h2>
        <p className="text-sm text-gray-500 mb-3">Most recent status snapshots showing phase, assigned engineer, and expected completion time.</p>
        <DataTable rows={statusRows} columns={statusColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Action Log</h2>
        <p className="text-sm text-gray-500 mb-3">Recent escalations, notifications, ETA revisions, and phase changes logged against active repairs.</p>
        <DataTable rows={actionRows} columns={actionColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
