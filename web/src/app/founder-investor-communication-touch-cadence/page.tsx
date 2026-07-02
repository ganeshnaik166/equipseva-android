import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [cadencesRes, overdueRes, recentRes] = await Promise.all([
    sb.rpc('list_cadences_r2029'),
    sb.rpc('overdue_cadences_r2029'),
    sb.rpc('recent_touches_r2029'),
  ]);

  const cadences: any[] = Array.isArray(cadencesRes.data) ? cadencesRes.data : [];
  const overdue: any[] = Array.isArray(overdueRes.data) ? overdueRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const cadenceCols: Column<any>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'current_cadence_days', header: 'Cadence (days)', render: (r: any) => String(r.current_cadence_days ?? '') },
    { key: 'last_touched_at', header: 'Last Touch', render: (r: any) => r.last_touched_at ? new Date(r.last_touched_at).toLocaleDateString() : 'never' },
    { key: 'next_due_at', header: 'Next Due', render: (r: any) => r.next_due_at ? new Date(r.next_due_at).toLocaleDateString() : '—' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleDateString() : '' },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'current_cadence_days', header: 'Cadence (days)', render: (r: any) => String(r.current_cadence_days ?? '') },
    { key: 'last_touched_at', header: 'Last Touch', render: (r: any) => r.last_touched_at ? new Date(r.last_touched_at).toLocaleDateString() : 'never' },
    { key: 'next_due_at', header: 'Was Due', render: (r: any) => r.next_due_at ? new Date(r.next_due_at).toLocaleDateString() : '—' },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => String(r.days_overdue ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'touch_type', header: 'Type', render: (r: any) => String(r.touch_type ?? '') },
    { key: 'cadence_id', header: 'Cadence', render: (r: any) => String(r.cadence_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'outcome_md', header: 'Outcome', render: (r: any) => String(r.outcome_md ?? '').slice(0, 80) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Investor Communication Touch Cadence</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track cadence with every investor. Stay on top of who is due, who is overdue, and who got the last update.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Cadences ({cadences.length})</h2>
        <DataTable rows={cadences} columns={cadenceCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Overdue ({overdue.length})</h2>
        <p style={{ color: '#666', marginBottom: 12 }}>
          Investors past their next-due timestamp. Reach out today.
        </p>
        <DataTable rows={overdue} columns={overdueCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Touches ({recent.length})</h2>
        <p style={{ color: '#666', marginBottom: 12 }}>
          Latest 200 touch-log entries across every investor.
        </p>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
