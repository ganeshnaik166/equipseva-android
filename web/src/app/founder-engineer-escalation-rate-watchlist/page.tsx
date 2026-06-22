import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [watchlistRes, summaryRes] = await Promise.all([
    sb.rpc('r2298_list_watchlist'),
    sb.rpc('r2298_severity_summary'),
  ]);

  const watchlist: any[] = watchlistRes.data ?? [];
  const summary: any[] = summaryRes.data ?? [];

  const totalRows = watchlist.length;
  const redCount = watchlist.filter((r) => r.severity === 'red').length;
  const coachingCount = watchlist.filter((r) => r.watchlist_status === 'coaching').length;
  const avgDelta =
    totalRows > 0
      ? (watchlist.reduce((a, r) => a + Number(r.rate_delta_pct ?? 0), 0) / totalRows).toFixed(2)
      : '0.00';

  const watchCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => r.engineer_email ?? '—' },
    {
      key: 'rate',
      header: 'Escalation rate',
      render: (r) => `${Number(r.escalation_rate_pct ?? 0).toFixed(2)}%`,
    },
    {
      key: 'prior',
      header: 'Prior window',
      render: (r) => `${Number(r.prior_window_rate_pct ?? 0).toFixed(2)}%`,
    },
    {
      key: 'delta',
      header: 'Delta',
      render: (r) => {
        const d = Number(r.rate_delta_pct ?? 0);
        const sign = d > 0 ? '+' : '';
        return `${sign}${d.toFixed(2)}%`;
      },
    },
    {
      key: 'jobs',
      header: 'Jobs / escalations',
      render: (r) => `${r.total_jobs_in_window ?? 0} / ${r.escalations_in_window ?? 0}`,
    },
    { key: 'severity', header: 'Severity', render: (r) => r.severity ?? '—' },
    { key: 'watchlist_status', header: 'Status', render: (r) => r.watchlist_status ?? '—' },
    {
      key: 'last_reviewed_at',
      header: 'Last reviewed',
      render: (r) => (r.last_reviewed_at ? new Date(r.last_reviewed_at).toLocaleString() : '—'),
    },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'severity', header: 'Severity', render: (r) => r.severity ?? '—' },
    { key: 'watchlist_status', header: 'Status', render: (r) => r.watchlist_status ?? '—' },
    { key: 'n', header: 'Count', render: (r) => String(r.n ?? 0) },
    { key: 'avg_rate', header: 'Avg rate', render: (r) => `${Number(r.avg_rate ?? 0).toFixed(2)}%` },
    {
      key: 'avg_delta',
      header: 'Avg delta',
      render: (r) => `${Number(r.avg_delta ?? 0).toFixed(2)}%`,
    },
  ];

  return (
    <main className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-semibold">Engineer escalation-rate watchlist</h1>
        <p className="text-sm text-gray-600">
          Engineers whose customer-escalation rate is rising. Track coaching plans & outcomes.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Watchlist size</div>
          <div className="text-xl font-semibold">{totalRows}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Red severity</div>
          <div className="text-xl font-semibold">{redCount}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">In coaching</div>
          <div className="text-xl font-semibold">{coachingCount}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Avg rate delta</div>
          <div className="text-xl font-semibold">{avgDelta}%</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Severity breakdown</h2>
        <DataTable
          columns={summaryCols}
          rows={summary}
          rowKey={(r: any, i: number) => String(`${r.severity}-${r.watchlist_status}-${i}`)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Watchlist (top 200 by delta)</h2>
        <DataTable
          columns={watchCols}
          rows={watchlist}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
