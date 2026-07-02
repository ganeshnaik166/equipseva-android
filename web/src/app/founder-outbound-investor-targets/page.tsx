import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type TargetRow = { id: string; target_name: string; target_segment: string; priority: string; status: string; captured_at: string };
type CriticalRow = { id: string; target_name: string; target_segment: string; status: string; captured_at: string };
type RecentRow = { action_id: string; target_name: string; action_type: string; taken_at: string; by_email: string | null };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [targetsRes, criticalRes, recentRes] = await Promise.all([
    sb.rpc('list_outbound_targets_r2106'),
    sb.rpc('critical_outbound_targets_r2106'),
    sb.rpc('recent_outbound_actions_r2106'),
  ]);

  const targets = (targetsRes.data ?? []) as TargetRow[];
  const critical = (criticalRes.data ?? []) as CriticalRow[];
  const recent = (recentRes.data ?? []) as RecentRow[];

  const targetCols: Column<TargetRow>[] = [
    { key: 'target_name', header: 'Target', render: (r: any) => r.target_name },
    { key: 'target_segment', header: 'Segment', render: (r: any) => r.target_segment },
    { key: 'priority', header: 'Priority', render: (r: any) => r.priority },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleDateString() },
  ];

  const criticalCols: Column<CriticalRow>[] = [
    { key: 'target_name', header: 'Target', render: (r: any) => r.target_name },
    { key: 'target_segment', header: 'Segment', render: (r: any) => r.target_segment },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleDateString() },
  ];

  const recentCols: Column<RecentRow>[] = [
    { key: 'target_name', header: 'Target', render: (r: any) => r.target_name },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'taken_at', header: 'Taken', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Outbound Investor Targets</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Outbound targeting of new investors. Track priority, segment, status, and recent actions.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Critical priority targets ({critical.length})</h2>
        <DataTable rows={critical} columns={criticalCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All targets ({targets.length})</h2>
        <DataTable rows={targets} columns={targetCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent outbound actions</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.action_id ?? i)} />
      </section>
    </main>
  );
}
