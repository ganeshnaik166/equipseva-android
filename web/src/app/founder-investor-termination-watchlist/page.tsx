import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorTerminationWatchlistPage() {
  const sb = await getSupabaseServerClient();

  const [watchesRes, highRiskRes, recentRes] = await Promise.all([
    sb.rpc('list_investor_termination_watches_r2065'),
    sb.rpc('high_risk_investor_terminations_r2065'),
    sb.rpc('recent_investor_termination_actions_r2065'),
  ]);

  const watches: any[] = Array.isArray(watchesRes.data) ? watchesRes.data : [];
  const highRisk: any[] = Array.isArray(highRiskRes.data) ? highRiskRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const watchCols: Column<any>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'watch_reason', header: 'Reason', render: (r: any) => String(r.watch_reason ?? '') },
    { key: 'risk_score', header: 'Risk', render: (r: any) => String(r.risk_score ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  const highRiskCols: Column<any>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'watch_reason', header: 'Reason', render: (r: any) => String(r.watch_reason ?? '') },
    { key: 'risk_score', header: 'Risk Score', render: (r: any) => String(r.risk_score ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'watch_id', header: 'Watch', render: (r: any) => String(r.watch_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>Investor Termination Watchlist</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track investors at risk of terminating involvement. Risk score scale runs 1 (low) through 10 (severe).
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>High Risk (score 7 or higher, active or escalated)</h2>
        <DataTable rows={highRisk} columns={highRiskCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>All Watches</h2>
        <DataTable rows={watches} columns={watchCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent Action Log</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
