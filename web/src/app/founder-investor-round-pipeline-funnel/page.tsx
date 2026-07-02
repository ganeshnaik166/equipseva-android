import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [funnelsRes, activeRes, recentRes] = await Promise.all([
    sb.rpc('list_funnels_r2041'),
    sb.rpc('active_funnels_r2041'),
    sb.rpc('recent_actions_r2041'),
  ]);

  const funnels: any[] = Array.isArray(funnelsRes.data) ? funnelsRes.data : [];
  const active: any[] = Array.isArray(activeRes.data) ? activeRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const funnelCols: Column<any>[] = [
    { key: 'round_label', header: 'Round', render: (r: any) => String(r.round_label ?? '-') },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '-').slice(0, 8) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'intro_date', header: 'Intro', render: (r: any) => (r.intro_date ? String(r.intro_date) : '-') },
    { key: 'qualified_date', header: 'Qualified', render: (r: any) => (r.qualified_date ? String(r.qualified_date) : '-') },
    { key: 'term_sheet_date', header: 'Term Sheet', render: (r: any) => (r.term_sheet_date ? String(r.term_sheet_date) : '-') },
    { key: 'closed_date', header: 'Closed', render: (r: any) => (r.closed_date ? String(r.closed_date) : '-') },
    { key: 'declined_date', header: 'Declined', render: (r: any) => (r.declined_date ? String(r.declined_date) : '-') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => (r.captured_at ? new Date(r.captured_at).toLocaleString() : '-') },
  ];

  const activeCols: Column<any>[] = [
    { key: 'round_label', header: 'Round', render: (r: any) => String(r.round_label ?? '-') },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '-').slice(0, 8) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'intro_date', header: 'Intro', render: (r: any) => (r.intro_date ? String(r.intro_date) : '-') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => (r.captured_at ? new Date(r.captured_at).toLocaleString() : '-') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '-') },
    { key: 'funnel_id', header: 'Funnel', render: (r: any) => String(r.funnel_id ?? '-').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '-') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => (r.taken_at ? new Date(r.taken_at).toLocaleString() : '-') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '-').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Round Pipeline Funnel</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Funnel from intro to closed round. Track qualified, term sheets, closes, declines, and walked-away.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Active Funnels ({active.length})
        </h2>
        <DataTable
          rows={active}
          columns={activeCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          All Funnels ({funnels.length})
        </h2>
        <DataTable
          rows={funnels}
          columns={funnelCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Recent Actions ({recent.length})
        </h2>
        <DataTable
          rows={recent}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
