import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [decisionsRes, topRes, recentRes, aggRes] = await Promise.all([
    sb.rpc('list_strategic_decisions_r2217', { p_limit: 200 }),
    sb.rpc('top_strategic_decisions_r2217', { p_limit: 10 }),
    sb.rpc('recent_actions_strategic_decisions_r2217', { p_limit: 50 }),
    sb.rpc('aggregate_strategic_decisions_r2217'),
  ]);

  const decisions = (decisionsRes.data ?? []) as any[];
  const top = (topRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];
  const agg = ((aggRes.data ?? [])[0] ?? {}) as any;

  const decisionCols: Column<any>[] = [
    { key: 'decided', header: 'Decided', render: (r: any) => new Date(r.decided_at).toLocaleDateString() },
    { key: 'type', header: 'Type', render: (r: any) => String(r.decision_type ?? '-') },
    { key: 'title', header: 'Title', render: (r: any) => String(r.title ?? '-') },
    { key: 'stakes', header: 'Stakes', render: (r: any) => String(r.stakes ?? '-') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'review_in', header: 'Review In', render: (r: any) => (r.days_until_review ?? 0) + ' days' },
    { key: 'decided_by', header: 'Decided By', render: (r: any) => String(r.decided_by_email ?? '-') },
    { key: 'rationale', header: 'Rationale', render: (r: any) => String(r.rationale ?? '').slice(0, 80) },
  ];

  const topCols: Column<any>[] = [
    { key: 'type', header: 'Type', render: (r: any) => String(r.decision_type ?? '-') },
    { key: 'total', header: 'Total', render: (r: any) => String(r.total ?? 0) },
    { key: 'active', header: 'Active', render: (r: any) => String(r.active_count ?? 0) },
    { key: 'reversed', header: 'Reversed', render: (r: any) => String(r.reversed_count ?? 0) },
    { key: 'high_stakes', header: 'High Stakes', render: (r: any) => String(r.high_stakes_count ?? 0) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'when', header: 'When', render: (r: any) => new Date(r.created_at).toLocaleString() },
    { key: 'op', header: 'Op', render: (r: any) => String(r.op_name ?? '-') },
    { key: 'actor', header: 'Actor', render: (r: any) => String(r.actor_email ?? '-') },
    { key: 'payload', header: 'Payload', render: (r: any) => JSON.stringify(r.after_value ?? {}).slice(0, 90) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Founder Strategic Decision Ledger
      </h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Major decisions logged with rationale, expected outcome, and 90-day retrospective.
        Hire, fire, pivot, kill — all tracked so we learn from wins and losses.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <Stat label="Total" value={String(agg.total_decisions ?? 0)} />
        <Stat label="Active" value={String(agg.active_decisions ?? 0)} />
        <Stat label="Reviewed" value={String(agg.reviewed_decisions ?? 0)} />
        <Stat label="Reversed" value={String(agg.reversed_decisions ?? 0)} />
        <Stat label="High Stakes" value={String(agg.high_stakes_decisions ?? 0)} />
        <Stat label="Overdue Review" value={String(agg.overdue_review_count ?? 0)} />
        <Stat label="Modal Grade" value={String(agg.avg_grade ?? '-')} />
        <Stat label="Would Repeat %" value={String(agg.would_repeat_rate_pct ?? 0) + '%'} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Decisions by Type</h2>
        <DataTable<any> columns={topCols} rows={top} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Decisions</h2>
        <DataTable<any> columns={decisionCols} rows={decisions} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Actions</h2>
        <DataTable<any> columns={recentCols} rows={recent} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280' }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}
