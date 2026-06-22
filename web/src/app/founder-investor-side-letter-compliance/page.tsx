import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [obligationsRes, overdueRes, recentRes] = await Promise.all([
    sb.rpc('list_obligations_r1941'),
    sb.rpc('overdue_obligations_r1941'),
    sb.rpc('recent_actions_r1941'),
  ]);

  const obligations = (obligationsRes.data ?? []) as any[];
  const overdue = (overdueRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];

  const obligationCols: Column<any>[] = [
    { key: 'label', header: 'Side Letter', render: (r: any) => String(r.side_letter_label ?? '') },
    { key: 'type', header: 'Type', render: (r: any) => String(r.obligation_type ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'due', header: 'Due', render: (r: any) => r.due_date ? String(r.due_date) : 'none' },
    { key: 'met', header: 'Met At', render: (r: any) => r.met_at ? new Date(r.met_at).toLocaleDateString() : 'pending' },
    { key: 'obligation', header: 'Obligation', render: (r: any) => String(r.obligation_md ?? '').slice(0, 80) },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'label', header: 'Side Letter', render: (r: any) => String(r.side_letter_label ?? '') },
    { key: 'type', header: 'Type', render: (r: any) => String(r.obligation_type ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'due', header: 'Due Date', render: (r: any) => String(r.due_date ?? '') },
    { key: 'days', header: 'Days Overdue', render: (r: any) => String(r.days_overdue ?? 0) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 100) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'ui-sans-serif, system-ui' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Side Letter Compliance</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track obligations across investor side letters. Reporting, governance, financial, operational, and info rights.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Overdue Obligations ({overdue.length})
        </h2>
        <DataTable rows={overdue} columns={overdueCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          All Obligations ({obligations.length})
        </h2>
        <DataTable rows={obligations} columns={obligationCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Recent Actions ({recent.length})
        </h2>
        <DataTable rows={recent} columns={actionCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
