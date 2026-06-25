import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalChainQuarterlyCrossSellBundlePage() {
  const supabase = await getSupabaseServerClient();

  const [bundles, attachLog, topAttach, decisionDist, quarterTrend, revenueSummary, ownerLoad] = await Promise.all([
    supabase.rpc('list_bundles_r2611'),
    supabase.rpc('list_attach_log_r2611'),
    supabase.rpc('top_attach_rate_r2611'),
    supabase.rpc('decision_distribution_r2611'),
    supabase.rpc('quarterly_bundle_trend_r2611'),
    supabase.rpc('total_revenue_summary_r2611'),
    supabase.rpc('owner_load_r2611'),
  ]);

  const bundleCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'bundle_value_rupees', header: 'Bundle Value (Rs)', render: (r: any) => Number(r.bundle_value_rupees).toLocaleString('en-IN') },
    { key: 'attach_rate_pct', header: 'Attach %', render: (r: any) => `${r.attach_rate_pct}%` },
    { key: 'decision_kind', header: 'Decision', render: (r: any) => r.decision_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const attachLogCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'logged_at', header: 'Logged At', render: (r: any) => new Date(r.logged_at).toLocaleString('en-IN') },
    { key: 'item_label', header: 'Item', render: (r: any) => r.item_label },
    { key: 'attached', header: 'Attached', render: (r: any) => (r.attached ? 'yes' : 'no') },
    { key: 'revenue_rupees', header: 'Revenue (Rs)', render: (r: any) => Number(r.revenue_rupees).toLocaleString('en-IN') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topAttachCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'attach_rate_pct', header: 'Attach %', render: (r: any) => `${r.attach_rate_pct}%` },
    { key: 'bundle_value_rupees', header: 'Value (Rs)', render: (r: any) => Number(r.bundle_value_rupees).toLocaleString('en-IN') },
    { key: 'decision_kind', header: 'Decision', render: (r: any) => r.decision_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const decisionCols: Column<any>[] = [
    { key: 'decision_kind', header: 'Decision', render: (r: any) => r.decision_kind },
    { key: 'total_bundles', header: 'Bundles', render: (r: any) => r.total_bundles },
    { key: 'total_value_rupees', header: 'Total Value (Rs)', render: (r: any) => Number(r.total_value_rupees).toLocaleString('en-IN') },
    { key: 'avg_attach_rate', header: 'Avg Attach %', render: (r: any) => `${r.avg_attach_rate}%` },
  ];

  const quarterCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'total_bundles', header: 'Total', render: (r: any) => r.total_bundles },
    { key: 'won_bundles', header: 'Won', render: (r: any) => r.won_bundles },
    { key: 'total_value_rupees', header: 'Total Value (Rs)', render: (r: any) => Number(r.total_value_rupees).toLocaleString('en-IN') },
    { key: 'avg_attach_rate', header: 'Avg Attach %', render: (r: any) => `${r.avg_attach_rate}%` },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'metric_label', header: 'Metric', render: (r: any) => r.metric_label },
    { key: 'metric_value', header: 'Value', render: (r: any) => Number(r.metric_value).toLocaleString('en-IN') },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'total_bundles', header: 'Bundles', render: (r: any) => r.total_bundles },
    { key: 'won_bundles', header: 'Won', render: (r: any) => r.won_bundles },
    { key: 'total_value_rupees', header: 'Total Value (Rs)', render: (r: any) => Number(r.total_value_rupees).toLocaleString('en-IN') },
    { key: 'avg_attach_rate', header: 'Avg Attach %', render: (r: any) => `${r.avg_attach_rate}%` },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Cross-Sell Bundle</h1>
        <p className="text-sm text-gray-600 mt-1">
          Quarter-by-quarter cross-sell bundles per hospital chain & attach log — founder view.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Revenue Summary</h2>
        <DataTable
          rows={revenueSummary.data ?? []}
          columns={summaryCols}
          emptyMessage="No summary metrics."
          rowKey={(r: any, i: number) => String(r.metric_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Bundles</h2>
        <DataTable
          rows={bundles.data ?? []}
          columns={bundleCols}
          emptyMessage="No bundles."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Attach Rate</h2>
        <DataTable
          rows={topAttach.data ?? []}
          columns={topAttachCols}
          emptyMessage="No attach data."
          rowKey={(r: any, i: number) => String(`${r.chain_name}-${r.quarter_label}-${i}`)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Decision Distribution</h2>
        <DataTable
          rows={decisionDist.data ?? []}
          columns={decisionCols}
          emptyMessage="No decision data."
          rowKey={(r: any, i: number) => String(r.decision_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly Trend</h2>
        <DataTable
          rows={quarterTrend.data ?? []}
          columns={quarterCols}
          emptyMessage="No quarterly data."
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner Load</h2>
        <DataTable
          rows={ownerLoad.data ?? []}
          columns={ownerCols}
          emptyMessage="No owner data."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Attach Log</h2>
        <DataTable
          rows={attachLog.data ?? []}
          columns={attachLogCols}
          emptyMessage="No attach log entries."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
