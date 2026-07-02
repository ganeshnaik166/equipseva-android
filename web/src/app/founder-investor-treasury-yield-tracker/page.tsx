import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const yieldsRes = await sb.rpc('list_yields_r2161');
  const recentYieldsRes = await sb.rpc('recent_yields_r2161', { p_limit: 25 });
  const recentActionsRes = await sb.rpc('recent_actions_r2161', { p_limit: 50 });

  const yields: any[] = Array.isArray(yieldsRes.data) ? yieldsRes.data : [];
  const recentYields: any[] = Array.isArray(recentYieldsRes.data) ? recentYieldsRes.data : [];
  const recentActions: any[] = Array.isArray(recentActionsRes.data) ? recentActionsRes.data : [];

  const yieldCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'treasury_balance_rupees', header: 'Treasury Balance', render: (r: any) => `₹${Number(r.treasury_balance_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'yield_pct', header: 'Yield Pct', render: (r: any) => `${Number(r.yield_pct ?? 0).toFixed(2)}%` },
    { key: 'yield_amount_rupees', header: 'Yield Amount', render: (r: any) => `₹${Number(r.yield_amount_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString('en-IN') : '' },
  ];

  const recentYieldCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'yield_pct', header: 'Yield Pct', render: (r: any) => `${Number(r.yield_pct ?? 0).toFixed(2)}%` },
    { key: 'yield_amount_rupees', header: 'Yield Amount', render: (r: any) => `₹${Number(r.yield_amount_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString('en-IN') : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'yield_id', header: 'Yield ID', render: (r: any) => String(r.yield_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => `₹${Number(r.amount_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString('en-IN') : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Investor Treasury Yield Tracker</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Track yield on company treasury across periods. Log reinvestments, withdrawals, and escalations.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Yield Periods</h2>
        <DataTable rows={yields} columns={yieldCols} rowKey={(r: any, i: number) => String(r?.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Yields (last 25)</h2>
        <DataTable rows={recentYields} columns={recentYieldCols} rowKey={(r: any, i: number) => String(r?.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions (last 50)</h2>
        <DataTable rows={recentActions} columns={actionCols} rowKey={(r: any, i: number) => String(r?.id ?? i)} />
      </section>
    </main>
  );
}
