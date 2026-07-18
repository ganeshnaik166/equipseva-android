import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [debtRes, actionsRes, focusRes, kindRes, statusRes, trendRes, summaryRes] = await Promise.all([
    supabase.rpc('list_debt_r2660'),
    supabase.rpc('list_close_actions_r2660'),
    supabase.rpc('top_debt_focus_r2660'),
    supabase.rpc('debt_kind_distribution_r2660'),
    supabase.rpc('status_funnel_r2660'),
    supabase.rpc('quarterly_debt_trend_r2660'),
    supabase.rpc('total_cost_summary_r2660'),
  ]);

  const debt: any[] = (debtRes.data as any[]) ?? [];
  const actions: any[] = (actionsRes.data as any[]) ?? [];
  const focus: any[] = (focusRes.data as any[]) ?? [];
  const kinds: any[] = (kindRes.data as any[]) ?? [];
  const statuses: any[] = (statusRes.data as any[]) ?? [];
  const trend: any[] = (trendRes.data as any[]) ?? [];
  const summary: any = (summaryRes.data as any[])?.[0] ?? {};

  const fmtRupees = (n: number) =>
    `₹${Number(n ?? 0).toLocaleString('en-IN')}`;

  const debtCols: Column<any>[] = [
    { key: 'quarter', header: 'Quarter', render: (r: any) => <span className="font-mono">{r.quarter_label}</span> },
    { key: 'hospital', header: 'Hospital', render: (r: any) => <span>{r.hospital_email ?? r.hospital_user_id?.slice(0, 8)}</span> },
    { key: 'kind', header: 'Kind', render: (r: any) => <span className="rounded bg-amber-50 px-2 py-0.5 text-xs">{r.debt_kind}</span> },
    { key: 'sev', header: 'Severity', render: (r: any) => {
      const map: Record<string, string> = {
        critical: 'bg-red-100 text-red-800',
        high: 'bg-orange-100 text-orange-800',
        medium: 'bg-yellow-100 text-yellow-800',
        low: 'bg-gray-100 text-gray-700',
      };
      return <span className={`rounded px-2 py-0.5 text-xs ${map[r.debt_severity] ?? ''}`}>{r.debt_severity}</span>;
    } },
    { key: 'cost', header: 'Cost to Close', render: (r: any) => <span className="font-mono tabular-nums">{fmtRupees(r.cost_to_close_rupees)}</span> },
    { key: 'owner', header: 'Owner', render: (r: any) => <span className="text-xs">{r.owner_email ?? '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs">{r.status}</span> },
    { key: 'notes', header: 'Notes', render: (r: any) => <span className="text-xs text-gray-600">{r.notes ?? ''}</span> },
  ];

  const actionCols: Column<any>[] = [
    { key: 'at', header: 'Action At', render: (r: any) => <span className="font-mono text-xs">{new Date(r.action_at).toLocaleString('en-IN')}</span> },
    { key: 'quarter', header: 'Quarter', render: (r: any) => <span className="font-mono">{r.quarter_label}</span> },
    { key: 'dkind', header: 'Debt Kind', render: (r: any) => <span className="text-xs">{r.debt_kind}</span> },
    { key: 'akind', header: 'Action', render: (r: any) => <span className="rounded bg-blue-50 px-2 py-0.5 text-xs">{r.action_kind}</span> },
    { key: 'outcome', header: 'Outcome', render: (r: any) => <span className="text-xs">{r.outcome}</span> },
    { key: 'owner', header: 'Owner', render: (r: any) => <span className="text-xs">{r.owner_email ?? '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs">{r.status}</span> },
    { key: 'notes', header: 'Notes', render: (r: any) => <span className="text-xs text-gray-600">{r.notes ?? ''}</span> },
  ];

  const focusCols: Column<any>[] = [
    { key: 'quarter', header: 'Quarter', render: (r: any) => <span className="font-mono">{r.quarter_label}</span> },
    { key: 'kind', header: 'Kind', render: (r: any) => <span className="text-xs">{r.debt_kind}</span> },
    { key: 'sev', header: 'Severity', render: (r: any) => <span className="text-xs font-semibold">{r.debt_severity}</span> },
    { key: 'cost', header: 'Cost', render: (r: any) => <span className="font-mono tabular-nums">{fmtRupees(r.cost_to_close_rupees)}</span> },
    { key: 'owner', header: 'Owner', render: (r: any) => <span className="text-xs">{r.owner_email ?? '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs">{r.status}</span> },
    { key: 'notes', header: 'Notes', render: (r: any) => <span className="text-xs text-gray-600">{r.notes ?? ''}</span> },
  ];

  const kindCols: Column<any>[] = [
    { key: 'kind', header: 'Kind', render: (r: any) => <span>{r.debt_kind}</span> },
    { key: 'cnt', header: 'Count', render: (r: any) => <span className="font-mono tabular-nums">{r.cnt}</span> },
    { key: 'cost', header: 'Total Cost', render: (r: any) => <span className="font-mono tabular-nums">{fmtRupees(r.total_cost_rupees)}</span> },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
    { key: 'cnt', header: 'Count', render: (r: any) => <span className="font-mono tabular-nums">{r.cnt}</span> },
    { key: 'cost', header: 'Total Cost', render: (r: any) => <span className="font-mono tabular-nums">{fmtRupees(r.total_cost_rupees)}</span> },
  ];

  const trendCols: Column<any>[] = [
    { key: 'q', header: 'Quarter', render: (r: any) => <span className="font-mono">{r.quarter_label}</span> },
    { key: 'cnt', header: 'Total', render: (r: any) => <span className="font-mono tabular-nums">{r.cnt}</span> },
    { key: 'open', header: 'Open', render: (r: any) => <span className="font-mono tabular-nums text-amber-700">{r.open_cnt}</span> },
    { key: 'closed', header: 'Closed', render: (r: any) => <span className="font-mono tabular-nums text-emerald-700">{r.closed_cnt}</span> },
    { key: 'cost', header: 'Total Cost', render: (r: any) => <span className="font-mono tabular-nums">{fmtRupees(r.total_cost_rupees)}</span> },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-bold tracking-tight">Customer Quarterly Implementation Debt Tracker</h1>
        <p className="text-sm text-gray-600">
          Track unkept promises, workarounds, missing features, training skips & process gaps per hospital per quarter.
          Close-out actions show what we did to retire each debt item.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div className="rounded-lg border bg-white p-4 shadow-sm">
          <div className="text-[11px] uppercase text-gray-500">Total Debt</div>
          <div className="mt-1 text-2xl font-bold">{summary.total_debt_count ?? 0}</div>
        </div>
        <div className="rounded-lg border bg-white p-4 shadow-sm">
          <div className="text-[11px] uppercase text-gray-500">Open</div>
          <div className="mt-1 text-2xl font-bold text-amber-700">{summary.open_count ?? 0}</div>
        </div>
        <div className="rounded-lg border bg-white p-4 shadow-sm">
          <div className="text-[11px] uppercase text-gray-500">Critical Open</div>
          <div className="mt-1 text-2xl font-bold text-red-700">{summary.critical_open_count ?? 0}</div>
        </div>
        <div className="rounded-lg border bg-white p-4 shadow-sm">
          <div className="text-[11px] uppercase text-gray-500">Open Cost</div>
          <div className="mt-1 text-xl font-bold font-mono tabular-nums">{fmtRupees(summary.open_cost_rupees ?? 0)}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Top 10 Focus (Open & In-Progress)</h2>
        <DataTable rows={focus} columns={focusCols} emptyMessage="No open debt items." rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="grid gap-6 lg:grid-cols-2">
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Debt Kind Distribution</h2>
          <DataTable rows={kinds} columns={kindCols} emptyMessage="No data." rowKey={(r: any, i: number) => String(r.debt_kind ?? i)} />
        </div>
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Status Funnel</h2>
          <DataTable rows={statuses} columns={statusCols} emptyMessage="No data." rowKey={(r: any, i: number) => String(r.status ?? i)} />
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Quarterly Trend</h2>
        <DataTable rows={trend} columns={trendCols} emptyMessage="No quarters." rowKey={(r: any, i: number) => String(r.quarter_label ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All Debt Items</h2>
        <DataTable rows={debt} columns={debtCols} emptyMessage="No debt logged." rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Close-Out Actions</h2>
        <DataTable rows={actions} columns={actionCols} emptyMessage="No actions logged." rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
