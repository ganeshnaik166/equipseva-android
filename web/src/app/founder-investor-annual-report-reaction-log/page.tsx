import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorAnnualReportReactionLogPage() {
  const sb = await getSupabaseServerClient();

  const [reactionsRes, actionsRes, concernsRes, recentRes] = await Promise.all([
    sb.rpc('list_investor_annual_report_reactions_r2129'),
    sb.rpc('list_investor_reaction_actions_r2129'),
    sb.rpc('list_investor_reaction_concerns_r2129'),
    sb.rpc('list_investor_reaction_recent_actions_r2129'),
  ]);

  const reactions: any[] = Array.isArray(reactionsRes.data) ? reactionsRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  const concerns: any[] = Array.isArray(concernsRes.data) ? concernsRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const fmt = (v: any) => {
    if (!v) return '—';
    try { return new Date(v).toLocaleString(); } catch { return String(v); }
  };

  const reactionCols: Column<any>[] = [
    { key: 'report_year', header: 'Year', render: (r: any) => r.report_year ?? '—' },
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'reaction_type', header: 'Reaction', render: (r: any) => r.reaction_type ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'reaction_md', header: 'Notes', render: (r: any) => (r.reaction_md ? String(r.reaction_md).slice(0, 80) : '—') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => fmt(r.captured_at) },
  ];

  const concernCols: Column<any>[] = [
    { key: 'report_year', header: 'Year', render: (r: any) => r.report_year ?? '—' },
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'reaction_type', header: 'Reaction', render: (r: any) => r.reaction_type ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'reaction_md', header: 'Notes', render: (r: any) => (r.reaction_md ? String(r.reaction_md).slice(0, 80) : '—') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => fmt(r.captured_at) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => (r.notes_md ? String(r.notes_md).slice(0, 80) : '—') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => fmt(r.taken_at) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => (r.notes_md ? String(r.notes_md).slice(0, 80) : '—') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => fmt(r.taken_at) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Annual Report Reaction Log</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track investor reactions to annual reports. Flag concerns and critical feedback for follow-up.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          All Reactions ({reactions.length})
        </h2>
        <DataTable
          rows={reactions}
          columns={reactionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Concerns and Critical ({concerns.length})
        </h2>
        <DataTable
          rows={concerns}
          columns={concernCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Recent Actions (last 14 days) ({recent.length})
        </h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          All Actions ({actions.length})
        </h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
