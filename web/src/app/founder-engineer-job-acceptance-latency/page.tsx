import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [latencies, slow, recent] = await Promise.all([
    sb.rpc('list_latencies_r1976'),
    sb.rpc('slow_engineers_r1976'),
    sb.rpc('recent_actions_r1976'),
  ]);

  const latencyRows = (latencies.data ?? []) as any[];
  const slowRows = (slow.data ?? []) as any[];
  const recentRows = (recent.data ?? []) as any[];

  const latencyCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '-').slice(0, 8) },
    { key: 'repair_job_id', header: 'Job', render: (r: any) => String(r.repair_job_id ?? '-').slice(0, 8) },
    { key: 'offered_at', header: 'Offered', render: (r: any) => r.offered_at ? new Date(r.offered_at).toLocaleString() : '-' },
    { key: 'accepted_at', header: 'Accepted', render: (r: any) => r.accepted_at ? new Date(r.accepted_at).toLocaleString() : '-' },
    { key: 'latency_minutes', header: 'Latency (min)', render: (r: any) => r.latency_minutes ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'response_type', header: 'Response', render: (r: any) => r.response_type ?? '-' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '-' },
  ];

  const slowCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '-').slice(0, 8) },
    { key: 'avg_latency', header: 'Avg Latency (min)', render: (r: any) => r.avg_latency != null ? Number(r.avg_latency).toFixed(1) : '-' },
    { key: 'total_offers', header: 'Total Offers', render: (r: any) => r.total_offers ?? 0 },
    { key: 'slow_offers', header: 'Slow Offers', render: (r: any) => r.slow_offers ?? 0 },
  ];

  const actionCols: Column<any>[] = [
    { key: 'latency_id', header: 'Latency', render: (r: any) => String(r.latency_id ?? '-').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '-' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '-' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '-' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '-' },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 8 }}>Engineer Job Acceptance Latency</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Time from job offer to engineer accept. Slow responders flagged for follow-up and rotation.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent Acceptance Latencies</h2>
        <DataTable rows={latencyRows} columns={latencyCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Slowest Engineers</h2>
        <p style={{ color: '#777', fontSize: 13, marginBottom: 8 }}>
          Engineers ranked by average response time. Slow offers count delayed, very delayed and no response buckets.
        </p>
        <DataTable rows={slowRows} columns={slowCols} rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent Actions</h2>
        <DataTable rows={recentRows} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
