import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [snapshotsRes, recentRes, categoriesRes, summaryRes] = await Promise.all([
    sb.rpc('list_cash_snapshots_r2201'),
    sb.rpc('recent_actions_r2201'),
    sb.rpc('top_burn_alert_categories_r2201'),
    sb.rpc('cash_position_summary_r2201'),
  ]);

  const snapshots = (snapshotsRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];
  const categories = (categoriesRes.data ?? []) as any[];
  const summary = ((summaryRes.data ?? [])[0] ?? {}) as any;

  const snapshotCols: Column<any>[] = [
    { key: 'snapshot_date', header: 'Date', render: (r: any) => String(r.snapshot_date ?? '') },
    { key: 'bank_balance_rupees', header: 'Bank (Rs)', render: (r: any) => String(r.bank_balance_rupees ?? '') },
    { key: 'mrr_rupees', header: 'MRR (Rs)', render: (r: any) => String(r.mrr_rupees ?? '') },
    { key: 'monthly_burn_rupees', header: 'Burn (Rs)', render: (r: any) => String(r.monthly_burn_rupees ?? '') },
    { key: 'runway_months', header: 'Runway (mo)', render: (r: any) => String(r.runway_months ?? '') },
    { key: 'ar_outstanding_rupees', header: 'AR (Rs)', render: (r: any) => String(r.ar_outstanding_rupees ?? '') },
    { key: 'ap_outstanding_rupees', header: 'AP (Rs)', render: (r: any) => String(r.ap_outstanding_rupees ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const categoryCols: Column<any>[] = [
    { key: 'alert_category', header: 'Category', render: (r: any) => String(r.alert_category ?? '') },
    { key: 'total_count', header: 'Total', render: (r: any) => String(r.total_count ?? '') },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count ?? '') },
    { key: 'critical_count', header: 'Critical', render: (r: any) => String(r.critical_count ?? '') },
    { key: 'last_raised_at', header: 'Last Raised', render: (r: any) => String(r.last_raised_at ?? '') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'created_at', header: 'When', render: (r: any) => String(r.created_at ?? '') },
    { key: 'actor_email', header: 'Actor', render: (r: any) => String(r.actor_email ?? '') },
    { key: 'op_name', header: 'Op', render: (r: any) => String(r.op_name ?? '') },
    { key: 'after_value', header: 'Payload', render: (r: any) => JSON.stringify(r.after_value) },
  ];

  return (
    <main className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Cash-Position Daily Snapshot</h1>
        <p className="text-sm text-gray-600">
          Bank balance & MRR run-rate & runway months & burn alerts — founder-only treasury console.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded border p-4 bg-white">
          <div className="text-xs text-gray-500">Latest Bank</div>
          <div className="text-2xl font-semibold">Rs {Number(summary.latest_bank_rupees ?? 0).toLocaleString('en-IN')}</div>
        </div>
        <div className="rounded border p-4 bg-white">
          <div className="text-xs text-gray-500">MRR</div>
          <div className="text-2xl font-semibold">Rs {Number(summary.latest_mrr_rupees ?? 0).toLocaleString('en-IN')}</div>
        </div>
        <div className="rounded border p-4 bg-white">
          <div className="text-xs text-gray-500">Monthly Burn</div>
          <div className="text-2xl font-semibold">Rs {Number(summary.latest_burn_rupees ?? 0).toLocaleString('en-IN')}</div>
        </div>
        <div className="rounded border p-4 bg-white">
          <div className="text-xs text-gray-500">Runway (months)</div>
          <div className="text-2xl font-semibold">{Number(summary.latest_runway_months ?? 0)}</div>
        </div>
        <div className="rounded border p-4 bg-white">
          <div className="text-xs text-gray-500">Snapshots (30d)</div>
          <div className="text-2xl font-semibold">{summary.snapshots_30d ?? 0}</div>
        </div>
        <div className="rounded border p-4 bg-white">
          <div className="text-xs text-gray-500">Avg Runway (30d)</div>
          <div className="text-2xl font-semibold">{Number(summary.avg_runway_30d ?? 0)}</div>
        </div>
        <div className="rounded border p-4 bg-white">
          <div className="text-xs text-gray-500">Open Alerts</div>
          <div className="text-2xl font-semibold">{summary.open_alerts ?? 0}</div>
        </div>
        <div className="rounded border p-4 bg-white">
          <div className="text-xs text-gray-500">Critical Alerts</div>
          <div className="text-2xl font-semibold">{summary.critical_alerts ?? 0}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Daily Snapshots</h2>
        <DataTable columns={snapshotCols} rows={snapshots} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Alert Categories</h2>
        <DataTable columns={categoryCols} rows={categories} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Actions</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}
