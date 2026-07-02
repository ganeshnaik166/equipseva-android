import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorDragAlongThresholdPage() {
  const sb = await getSupabaseServerClient();

  const [thresholdsRes, aboveRes, recentRes] = await Promise.all([
    sb.rpc('list_thresholds_r1897'),
    sb.rpc('thresholds_above_r1897'),
    sb.rpc('recent_consents_r1897', { p_limit: 50 }),
  ]);

  const thresholds: any[] = Array.isArray(thresholdsRes.data) ? thresholdsRes.data : [];
  const above: any[] = Array.isArray(aboveRes.data) ? aboveRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const thresholdCols: Column<any>[] = [
    { key: 'threshold_label', header: 'Label', render: (r: any) => String(r.threshold_label ?? '') },
    { key: 'total_shares_required', header: 'Total Shares Required', render: (r: any) => String(r.total_shares_required ?? 0) },
    { key: 'current_consenting_shares', header: 'Consenting Shares', render: (r: any) => String(r.current_consenting_shares ?? 0) },
    { key: 'threshold_pct', header: 'Threshold %', render: (r: any) => `${Number(r.threshold_pct ?? 0).toFixed(2)}%` },
    { key: 'current_pct', header: 'Current %', render: (r: any) => `${Number(r.current_pct ?? 0).toFixed(2)}%` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'last_assessed_at', header: 'Last Assessed', render: (r: any) => r.last_assessed_at ? new Date(r.last_assessed_at).toLocaleString() : '-' },
  ];

  const aboveCols: Column<any>[] = [
    { key: 'threshold_label', header: 'Label', render: (r: any) => String(r.threshold_label ?? '') },
    { key: 'threshold_pct', header: 'Threshold %', render: (r: any) => `${Number(r.threshold_pct ?? 0).toFixed(2)}%` },
    { key: 'current_pct', header: 'Current %', render: (r: any) => `${Number(r.current_pct ?? 0).toFixed(2)}%` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'last_assessed_at', header: 'Last Assessed', render: (r: any) => r.last_assessed_at ? new Date(r.last_assessed_at).toLocaleString() : '-' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'threshold_id', header: 'Threshold', render: (r: any) => String(r.threshold_id ?? '').slice(0, 8) },
    { key: 'shares_consented', header: 'Shares', render: (r: any) => String(r.shares_consented ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'consent_given_at', header: 'Granted At', render: (r: any) => r.consent_given_at ? new Date(r.consent_given_at).toLocaleString() : '-' },
    { key: 'created_at', header: 'Logged At', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '-' },
  ];

  const totalThresholds = thresholds.length;
  const aboveCount = above.length;
  const pendingCount = recent.filter((r: any) => r.status === 'pending').length;

  return (
    <main className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold">Investor Drag-Along Threshold</h1>
        <p className="text-sm text-gray-600">
          Track drag-along thresholds &amp; consent status across investor base. Threshold reached when consenting shares &gt;= threshold %.
        </p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="border rounded p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Total Thresholds</div>
          <div className="text-2xl font-semibold">{totalThresholds}</div>
        </div>
        <div className="border rounded p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">At or Above Threshold</div>
          <div className="text-2xl font-semibold">{aboveCount}</div>
        </div>
        <div className="border rounded p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Pending Consents (recent)</div>
          <div className="text-2xl font-semibold">{pendingCount}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All Thresholds</h2>
        <p className="text-xs text-gray-500">Rows show shares required vs consenting. Status flips to above_threshold when current % &gt;= threshold %.</p>
        <DataTable rows={thresholds} columns={thresholdCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">At or Above Threshold</h2>
        <p className="text-xs text-gray-500">Thresholds where drag-along trigger condition is met (current % &gt;= threshold %).</p>
        <DataTable rows={above} columns={aboveCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent Consents</h2>
        <p className="text-xs text-gray-500">Last 50 consent log entries (granted, pending, or withdrawn).</p>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
