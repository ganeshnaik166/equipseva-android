import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [distributionsRes, viewLogRes, expiringRes, topViewedRes] = await Promise.all([
    sb.rpc('list_distributions_r1817'),
    sb.rpc('list_view_log_r1817', { p_distribution_id: null }),
    sb.rpc('expiring_distributions_r1817'),
    sb.rpc('top_viewed_materials_r1817'),
  ]);

  const distributions: any[] = Array.isArray(distributionsRes.data) ? distributionsRes.data : [];
  const viewLog: any[] = Array.isArray(viewLogRes.data) ? viewLogRes.data : [];
  const expiring: any[] = Array.isArray(expiringRes.data) ? expiringRes.data : [];
  const topViewed: any[] = Array.isArray(topViewedRes.data) ? topViewedRes.data : [];

  const totalDistributions = distributions.length;
  const activeCount = distributions.filter((d) => d.status === 'active').length;
  const revokedCount = distributions.filter((d) => d.status === 'revoked').length;
  const accessedCount = distributions.filter((d) => d.accessed === true).length;

  const distributionColumns: Column<any>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => <span className="font-mono text-xs">{String(r.investor_id ?? '').slice(0, 8)}</span> },
    { key: 'material_type', header: 'Material', render: (r: any) => <span className="text-sm">{r.material_type ?? '-'}</span> },
    { key: 'version_label', header: 'Version', render: (r: any) => <span className="text-sm font-medium">{r.version_label ?? '-'}</span> },
    { key: 'shared_at', header: 'Shared', render: (r: any) => <span className="text-xs">{r.shared_at ? new Date(r.shared_at).toLocaleDateString() : '-'}</span> },
    { key: 'expires_at', header: 'Expires', render: (r: any) => <span className="text-xs">{r.expires_at ? new Date(r.expires_at).toLocaleDateString() : 'never'}</span> },
    { key: 'accessed', header: 'Accessed', render: (r: any) => <span className={`text-xs ${r.accessed ? 'text-green-700' : 'text-gray-500'}`}>{r.accessed ? 'yes' : 'no'}</span> },
    { key: 'view_count', header: 'Views', render: (r: any) => <span className="text-sm font-semibold">{r.view_count ?? 0}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className={`text-xs px-2 py-0.5 rounded ${r.status === 'active' ? 'bg-green-100 text-green-800' : r.status === 'revoked' ? 'bg-red-100 text-red-800' : 'bg-gray-100 text-gray-700'}`}>{r.status ?? '-'}</span> },
    { key: 'watermark', header: 'Watermark', render: (r: any) => <span className="text-xs text-gray-600">{r.watermark ?? '-'}</span> },
  ];

  const viewLogColumns: Column<any>[] = [
    { key: 'viewed_at', header: 'Viewed', render: (r: any) => <span className="text-xs">{r.viewed_at ? new Date(r.viewed_at).toLocaleString() : '-'}</span> },
    { key: 'viewer_email', header: 'Viewer', render: (r: any) => <span className="text-sm">{r.viewer_email ?? '-'}</span> },
    { key: 'distribution_id', header: 'Dist ID', render: (r: any) => <span className="font-mono text-xs">{String(r.distribution_id ?? '').slice(0, 8)}</span> },
    { key: 'ip_address', header: 'IP', render: (r: any) => <span className="text-xs font-mono">{r.ip_address ?? '-'}</span> },
    { key: 'geo_location', header: 'Geo', render: (r: any) => <span className="text-xs">{r.geo_location ?? '-'}</span> },
    { key: 'view_duration_sec', header: 'Duration (s)', render: (r: any) => <span className="text-sm">{r.view_duration_sec ?? 0}</span> },
  ];

  const expiringColumns: Column<any>[] = [
    { key: 'material_type', header: 'Material', render: (r: any) => <span className="text-sm">{r.material_type ?? '-'}</span> },
    { key: 'version_label', header: 'Version', render: (r: any) => <span className="text-sm">{r.version_label ?? '-'}</span> },
    { key: 'investor_id', header: 'Investor', render: (r: any) => <span className="font-mono text-xs">{String(r.investor_id ?? '').slice(0, 8)}</span> },
    { key: 'expires_at', header: 'Expires', render: (r: any) => <span className="text-xs">{r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '-'}</span> },
    { key: 'days_until_expiry', header: 'Days Left', render: (r: any) => <span className={`text-sm font-semibold ${(r.days_until_expiry ?? 0) <= 3 ? 'text-red-700' : 'text-amber-700'}`}>{r.days_until_expiry ?? 0}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs">{r.status ?? '-'}</span> },
  ];

  const topViewedColumns: Column<any>[] = [
    { key: 'material_type', header: 'Material', render: (r: any) => <span className="text-sm">{r.material_type ?? '-'}</span> },
    { key: 'version_label', header: 'Version', render: (r: any) => <span className="text-sm font-medium">{r.version_label ?? '-'}</span> },
    { key: 'view_count', header: 'Views', render: (r: any) => <span className="text-sm font-semibold">{r.view_count ?? 0}</span> },
    { key: 'total_view_duration_sec', header: 'Total Time (s)', render: (r: any) => <span className="text-sm">{r.total_view_duration_sec ?? 0}</span> },
    { key: 'last_viewed_at', header: 'Last Viewed', render: (r: any) => <span className="text-xs">{r.last_viewed_at ? new Date(r.last_viewed_at).toLocaleString() : '-'}</span> },
    { key: 'distribution_id', header: 'Dist ID', render: (r: any) => <span className="font-mono text-xs">{String(r.distribution_id ?? '').slice(0, 8)}</span> },
  ];

  return (
    <div className="max-w-7xl mx-auto p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Investor Confidential Pitch Material Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track which investors received which pitch versions for diligence audit. Monitor access & revoke materials.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase">Total Distributions</div>
          <div className="text-2xl font-bold mt-1">{totalDistributions}</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase">Active</div>
          <div className="text-2xl font-bold mt-1 text-green-700">{activeCount}</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase">Accessed</div>
          <div className="text-2xl font-bold mt-1 text-blue-700">{accessedCount}</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase">Revoked</div>
          <div className="text-2xl font-bold mt-1 text-red-700">{revokedCount}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All Distributions</h2>
        <DataTable
          rows={distributions}
          columns={distributionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Expiring Soon (&lt; 14 days)</h2>
        <DataTable
          rows={expiring}
          columns={expiringColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top Viewed Materials</h2>
        <DataTable
          rows={topViewed}
          columns={topViewedColumns}
          rowKey={(r: any, i: number) => String(r.distribution_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent View Log</h2>
        <DataTable
          rows={viewLog}
          columns={viewLogColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
