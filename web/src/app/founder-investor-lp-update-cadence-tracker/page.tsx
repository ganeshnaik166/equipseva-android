import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorLpUpdateCadenceTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [cadencesRes, dueRes, recentRes] = await Promise.all([
    sb.rpc('list_cadences_r1933'),
    sb.rpc('due_or_overdue_r1933'),
    sb.rpc('recent_sends_r1933', { p_limit: 50 }),
  ]);

  const cadences: any[] = Array.isArray(cadencesRes.data) ? cadencesRes.data : [];
  const due: any[] = Array.isArray(dueRes.data) ? dueRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const cadenceCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id ?? '—' },
    { key: 'cadence', header: 'Cadence', render: (r: any) => String(r.cadence ?? '—') },
    { key: 'last_sent_at', header: 'Last Sent', render: (r: any) => r.last_sent_at ? new Date(r.last_sent_at).toLocaleString() : '—' },
    { key: 'next_due_date', header: 'Next Due', render: (r: any) => r.next_due_date ? String(r.next_due_date) : '—' },
    { key: 'current_status', header: 'Status', render: (r: any) => String(r.current_status ?? '—') },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleDateString() : '—' },
  ];

  const dueCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id ?? '—' },
    { key: 'cadence', header: 'Cadence', render: (r: any) => String(r.cadence ?? '—') },
    { key: 'next_due_date', header: 'Due Date', render: (r: any) => r.next_due_date ? String(r.next_due_date) : '—' },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => String(r.days_overdue ?? 0) },
    { key: 'current_status', header: 'Status', render: (r: any) => String(r.current_status ?? '—') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'sent_at', header: 'Sent', render: (r: any) => r.sent_at ? new Date(r.sent_at).toLocaleString() : '—' },
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'send_type', header: 'Type', render: (r: any) => String(r.send_type ?? '—') },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'content_url', header: 'Content', render: (r: any) => r.content_url ?? '—' },
  ];

  const totalCadences = cadences.length;
  const totalDue = due.length;
  const totalRecent = recent.length;

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor LP Update Cadence Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track LP update sending cadence per investor. Monitor due and overdue communications.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, marginBottom: 32 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Cadences</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{totalCadences}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Due or Overdue</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: totalDue > 0 ? '#dc2626' : '#16a34a' }}>{totalDue}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Recent Sends</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{totalRecent}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Cadences</h2>
        <DataTable
          rows={cadences}
          columns={cadenceCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Due or Overdue</h2>
        <DataTable
          rows={due}
          columns={dueCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Sends</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
