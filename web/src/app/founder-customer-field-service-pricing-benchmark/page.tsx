import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  const email = user?.email ?? '';

  const [summary, benchmarks, flags, byCity, byClass, pending, recent] = await Promise.all([
    supabase.rpc('fspb_r2344_summary'),
    supabase.rpc('fspb_r2344_list_benchmarks'),
    supabase.rpc('fspb_r2344_undercut_flags'),
    supabase.rpc('fspb_r2344_by_city'),
    supabase.rpc('fspb_r2344_by_equipment_class'),
    supabase.rpc('fspb_r2344_pending_actions'),
    supabase.rpc('fspb_r2344_recent_actions'),
  ]);

  const s = (summary.data && summary.data[0]) || {};

  const benchmarkCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'equipment_class', header: 'Equipment', render: (r) => r.equipment_class },
    { key: 'service_type', header: 'Service', render: (r) => r.service_type },
    { key: 'our_price_rupees', header: 'Our Price', render: (r) => `₹${Number(r.our_price_rupees).toLocaleString('en-IN')}` },
    { key: 'competitor_avg_price_rupees', header: 'Competitor Avg', render: (r) => `₹${Number(r.competitor_avg_price_rupees).toLocaleString('en-IN')}` },
    { key: 'competitor_sample_size', header: 'Sample', render: (r) => r.competitor_sample_size },
    { key: 'delta_pct', header: 'Delta %', render: (r) => `${r.delta_pct ?? 0}%` },
    { key: 'market_position', header: 'Position', render: (r) => r.market_position },
    { key: 'benchmarked_at', header: 'When', render: (r) => new Date(r.benchmarked_at).toLocaleDateString() },
  ];

  const flagCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'equipment_class', header: 'Equipment', render: (r) => r.equipment_class },
    { key: 'service_type', header: 'Service', render: (r) => r.service_type },
    { key: 'our_price_rupees', header: 'Our', render: (r) => `₹${Number(r.our_price_rupees).toLocaleString('en-IN')}` },
    { key: 'competitor_avg_price_rupees', header: 'Competitor', render: (r) => `₹${Number(r.competitor_avg_price_rupees).toLocaleString('en-IN')}` },
    { key: 'delta_pct', header: 'Delta %', render: (r) => `${r.delta_pct ?? 0}%` },
    { key: 'flag', header: 'Flag', render: (r) => r.flag },
  ];

  const cityCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'benchmarks_count', header: 'Benchmarks', render: (r) => r.benchmarks_count },
    { key: 'avg_delta_pct', header: 'Avg Delta %', render: (r) => `${r.avg_delta_pct ?? 0}%` },
    { key: 'undercut_count', header: 'Undercut', render: (r) => r.undercut_count },
    { key: 'overcharge_count', header: 'Overcharge', render: (r) => r.overcharge_count },
  ];

  const classCols: Column<any>[] = [
    { key: 'equipment_class', header: 'Equipment Class', render: (r) => r.equipment_class },
    { key: 'benchmarks_count', header: 'Benchmarks', render: (r) => r.benchmarks_count },
    { key: 'avg_our_price', header: 'Avg Our Price', render: (r) => `₹${Number(r.avg_our_price).toLocaleString('en-IN')}` },
    { key: 'avg_competitor_price', header: 'Avg Competitor', render: (r) => `₹${Number(r.avg_competitor_price).toLocaleString('en-IN')}` },
    { key: 'avg_delta_pct', header: 'Avg Delta %', render: (r) => `${r.avg_delta_pct ?? 0}%` },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'equipment_class', header: 'Equipment', render: (r) => r.equipment_class },
    { key: 'action_type', header: 'Action', render: (r) => r.action_type },
    { key: 'recommended_new_price_rupees', header: 'Recommended', render: (r) => r.recommended_new_price_rupees ? `₹${Number(r.recommended_new_price_rupees).toLocaleString('en-IN')}` : '-' },
    { key: 'rationale', header: 'Rationale', render: (r) => r.rationale ?? '-' },
    { key: 'created_at', header: 'Created', render: (r) => new Date(r.created_at).toLocaleDateString() },
  ];

  const recentCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r) => r.city ?? '-' },
    { key: 'equipment_class', header: 'Equipment', render: (r) => r.equipment_class ?? '-' },
    { key: 'action_type', header: 'Action', render: (r) => r.action_type },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'decided_at', header: 'Decided', render: (r) => r.decided_at ? new Date(r.decided_at).toLocaleDateString() : '-' },
    { key: 'created_at', header: 'Created', render: (r) => new Date(r.created_at).toLocaleDateString() },
  ];

  return (
    <main className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Field Service Pricing Benchmark</h1>
        <p className="text-sm text-gray-600">Signed in as {email}. Compare our prices vs competitor benchmarks by city & equipment class.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Total benchmarks</div>
          <div className="text-xl font-semibold">{s.total_benchmarks ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Cities tracked</div>
          <div className="text-xl font-semibold">{s.total_cities ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Equipment classes</div>
          <div className="text-xl font-semibold">{s.total_equipment_classes ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Avg delta vs market</div>
          <div className="text-xl font-semibold">{s.avg_delta_pct ?? 0}%</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Undercut (&lt; 90%)</div>
          <div className="text-xl font-semibold">{s.undercut_count ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Overcharge (&gt; 110%)</div>
          <div className="text-xl font-semibold">{s.overcharge_count ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">In band</div>
          <div className="text-xl font-semibold">{s.in_band_count ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Pending actions</div>
          <div className="text-xl font-semibold">{s.pending_actions ?? 0}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Undercut / overcharge flags</h2>
        <DataTable
          columns={flagCols}
          rows={flags.data ?? []}
          rowKey={(r: any) => r.id}
          emptyMessage="No flagged pricing rows."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By city</h2>
        <DataTable
          columns={cityCols}
          rows={byCity.data ?? []}
          rowKey={(r: any) => r.city}
          emptyMessage="No city aggregation yet."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By equipment class</h2>
        <DataTable
          columns={classCols}
          rows={byClass.data ?? []}
          rowKey={(r: any) => r.equipment_class}
          emptyMessage="No equipment-class data yet."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All benchmarks (recent 500)</h2>
        <DataTable
          columns={benchmarkCols}
          rows={benchmarks.data ?? []}
          rowKey={(r: any) => r.id}
          emptyMessage="No benchmarks captured."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pending pricing actions</h2>
        <DataTable
          columns={pendingCols}
          rows={pending.data ?? []}
          rowKey={(r: any) => r.id}
          emptyMessage="No pending actions."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent action history</h2>
        <DataTable
          columns={recentCols}
          rows={recent.data ?? []}
          rowKey={(r: any) => r.id}
          emptyMessage="No action history yet."
        />
      </section>
    </main>
  );
}
