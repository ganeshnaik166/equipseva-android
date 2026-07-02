import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderDecisionReversalLogPage() {
  const sb = await getSupabaseServerClient();

  const [reversalsRes, actionsRes, recentRevRes, recentActRes] = await Promise.all([
    sb.rpc('list_reversals_r2170'),
    sb.rpc('list_actions_r2170'),
    sb.rpc('recent_reversals_r2170'),
    sb.rpc('recent_actions_r2170'),
  ]);

  const reversals: any[] = Array.isArray(reversalsRes.data) ? reversalsRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  const recentRev: any[] = Array.isArray(recentRevRes.data) ? recentRevRes.data : [];
  const recentAct: any[] = Array.isArray(recentActRes.data) ? recentActRes.data : [];

  const reversalCols: Column<any>[] = [
    { key: 'label', header: 'Decision', render: (r: any) => String(r.original_decision_label ?? '') },
    { key: 'reason', header: 'Reason', render: (r: any) => String(r.reversal_reason ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'reversed', header: 'Reversed', render: (r: any) => r.reversed_at ? new Date(r.reversed_at).toLocaleString() : '' },
    { key: 'md', header: 'Notes', render: (r: any) => String(r.reversal_md ?? '').slice(0, 80) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'rev', header: 'Reversal', render: (r: any) => String(r.reversal_id ?? '').slice(0, 8) },
    { key: 'type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  const recentRevCols: Column<any>[] = [
    { key: 'label', header: 'Decision', render: (r: any) => String(r.original_decision_label ?? '') },
    { key: 'reason', header: 'Reason', render: (r: any) => String(r.reversal_reason ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'when', header: 'When', render: (r: any) => r.reversed_at ? new Date(r.reversed_at).toLocaleString() : '' },
  ];

  const recentActCols: Column<any>[] = [
    { key: 'rev', header: 'Reversal', render: (r: any) => String(r.reversal_id ?? '').slice(0, 8) },
    { key: 'type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'when', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Decision Reversal Log</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track decisions reversed due to new data, changing market, escalation, board input, or customer feedback.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Reversals</h2>
        <DataTable rows={reversals} columns={reversalCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Reversals (30d)</h2>
        <DataTable rows={recentRev} columns={recentRevCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions (30d)</h2>
        <DataTable rows={recentAct} columns={recentActCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
