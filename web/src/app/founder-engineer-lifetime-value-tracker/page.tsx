import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type LtvRow = {
  id: string;
  engineer_user_id: string;
  period_label: string;
  total_revenue_attributed_rupees: number;
  total_jobs_completed: number;
  retention_months: number;
  status: string;
  captured_at: string;
};

type ActionRow = {
  id: string;
  ltv_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [ltvs, top, recent] = await Promise.all([
    sb.rpc('list_ltvs_r2140'),
    sb.rpc('top_ltv_r2140'),
    sb.rpc('recent_ltv_actions_r2140'),
  ]);

  const ltvRows: LtvRow[] = (ltvs.data ?? []) as LtvRow[];
  const topRows: LtvRow[] = (top.data ?? []) as LtvRow[];
  const recentRows: ActionRow[] = (recent.data ?? []) as ActionRow[];

  const ltvCols: Column<LtvRow>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'total_revenue_attributed_rupees', header: 'Revenue (rupees)', render: (r: any) => String(r.total_revenue_attributed_rupees ?? 0) },
    { key: 'total_jobs_completed', header: 'Jobs done', render: (r: any) => String(r.total_jobs_completed ?? 0) },
    { key: 'retention_months', header: 'Months retained', render: (r: any) => String(r.retention_months ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Engineer Lifetime Value Tracker</h1>
        <p style={{ color: '#666' }}>Per-engineer LTV with revenue attribution, retention months, and intervention log.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All LTV snapshots</h2>
        <DataTable rows={ltvRows} columns={ltvCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top revenue engineers</h2>
        <DataTable rows={topRows} columns={ltvCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent actions</h2>
        <DataTable rows={recentRows} columns={actionCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
