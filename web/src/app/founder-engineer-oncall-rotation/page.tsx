import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [rotationsRes, calloutsRes, summaryRes, perEngRes, topRes] = await Promise.all([
    sb.rpc('r1744_list_rotations', { p_limit: 50 }),
    sb.rpc('r1744_list_callouts', { p_rotation_id: null, p_limit: 100 }),
    sb.rpc('r1744_rotation_summary'),
    sb.rpc('r1744_response_time_per_engineer'),
    sb.rpc('r1744_top_response_engineers', { p_limit: 10 }),
  ]);

  const rotations = (rotationsRes.data ?? []) as any[];
  const callouts = (calloutsRes.data ?? []) as any[];
  const summary = ((summaryRes.data ?? [])[0] ?? {}) as any;
  const perEng = (perEngRes.data ?? []) as any[];
  const top = (topRes.data ?? []) as any[];

  const rotCols: Column<any>[] = [
    { key: 'rotation_week', header: 'Week', render: (r: any) => String(r.rotation_week ?? '') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? r.engineer_user_id ?? '') },
    { key: 'oncall_days', header: 'Days', render: (r: any) => Array.isArray(r.oncall_days) ? r.oncall_days.join(', ') : '' },
    { key: 'emergency_jobs_handled', header: 'Jobs', render: (r: any) => String(r.emergency_jobs_handled ?? 0) },
    { key: 'multiplier_applied', header: 'Multiplier', render: (r: any) => String(r.multiplier_applied ?? 1) },
    { key: 'total_oncall_payout_rupees', header: 'Payout (Rs)', render: (r: any) => String(r.total_oncall_payout_rupees ?? 0) },
  ];

  const calloutCols: Column<any>[] = [
    { key: 'call_time', header: 'Call Time', render: (r: any) => r.call_time ? new Date(r.call_time).toLocaleString() : '' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? r.hospital_id ?? '') },
    { key: 'response_time_min', header: 'Response (min)', render: (r: any) => String(r.response_time_min ?? 0) },
    { key: 'was_resolved', header: 'Resolved', render: (r: any) => r.was_resolved ? 'Yes' : 'No' },
    { key: 'escalation_note', header: 'Note', render: (r: any) => String(r.escalation_note ?? '') },
  ];

  const perEngCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? r.engineer_user_id ?? '') },
    { key: 'callouts_count', header: 'Call-outs', render: (r: any) => String(r.callouts_count ?? 0) },
    { key: 'avg_response_min', header: 'Avg Response (min)', render: (r: any) => String(r.avg_response_min ?? 0) },
    { key: 'resolved_count', header: 'Resolved', render: (r: any) => String(r.resolved_count ?? 0) },
  ];

  const topCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? r.engineer_user_id ?? '') },
    { key: 'callouts_count', header: 'Call-outs', render: (r: any) => String(r.callouts_count ?? 0) },
    { key: 'avg_response_min', header: 'Avg Response (min)', render: (r: any) => String(r.avg_response_min ?? 0) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer On-Call Rotation</h1>
        <p className="text-sm text-gray-600">Track on-call rotation & payout multiplier. Fastest response wins.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Summary</h2>
        <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
          <div className="p-3 rounded border">
            <div className="text-xs text-gray-500">Rotations</div>
            <div className="text-xl font-bold">{String(summary.total_rotations ?? 0)}</div>
          </div>
          <div className="p-3 rounded border">
            <div className="text-xs text-gray-500">Call-outs</div>
            <div className="text-xl font-bold">{String(summary.total_callouts ?? 0)}</div>
          </div>
          <div className="p-3 rounded border">
            <div className="text-xs text-gray-500">Resolved</div>
            <div className="text-xl font-bold">{String(summary.resolved_callouts ?? 0)}</div>
          </div>
          <div className="p-3 rounded border">
            <div className="text-xs text-gray-500">Avg Resp (min)</div>
            <div className="text-xl font-bold">{String(summary.avg_response_min ?? 0)}</div>
          </div>
          <div className="p-3 rounded border">
            <div className="text-xs text-gray-500">Total Payout (Rs)</div>
            <div className="text-xl font-bold">{String(summary.total_payout_rupees ?? 0)}</div>
          </div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Rotations</h2>
        <DataTable rows={rotations} columns={rotCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Call-outs</h2>
        <DataTable rows={callouts} columns={calloutCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Per-Engineer Response</h2>
        <DataTable rows={perEng} columns={perEngCols} rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Response Engineers (fastest)</h2>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)} />
      </section>
    </main>
  );
}
