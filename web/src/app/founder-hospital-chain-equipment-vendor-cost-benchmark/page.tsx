import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [benchRes, actionsRes, focusRes, posRes, statusRes, trendRes, ownerRes] = await Promise.all([
    sb.rpc('list_benchmark_r2663'),
    sb.rpc('list_actions_r2663'),
    sb.rpc('top_above_market_focus_r2663'),
    sb.rpc('position_distribution_r2663'),
    sb.rpc('status_funnel_r2663'),
    sb.rpc('monthly_benchmark_trend_r2663'),
    sb.rpc('owner_load_r2663'),
  ]);

  const benchmarks: any[] = (benchRes.data as any[] | null) ?? [];
  const actions: any[] = (actionsRes.data as any[] | null) ?? [];
  const focus: any[] = (focusRes.data as any[] | null) ?? [];
  const positions: any[] = (posRes.data as any[] | null) ?? [];
  const statuses: any[] = (statusRes.data as any[] | null) ?? [];
  const trend: any[] = (trendRes.data as any[] | null) ?? [];
  const owners: any[] = (ownerRes.data as any[] | null) ?? [];

  const fmtRupees = (n: number | null | undefined) => {
    if (n === null || n === undefined) return '—';
    return '₹' + Number(n).toLocaleString('en-IN');
  };

  const benchCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_kind', header: 'Equipment', render: (r: any) => r.equipment_kind },
    { key: 'our_cost_rupees', header: 'Our Cost', render: (r: any) => fmtRupees(r.our_cost_rupees) },
    { key: 'market_median_rupees', header: 'Market Median', render: (r: any) => fmtRupees(r.market_median_rupees) },
    { key: 'top_quartile_rupees', header: 'Top Quartile', render: (r: any) => fmtRupees(r.top_quartile_rupees) },
    { key: 'position_kind', header: 'Position', render: (r: any) => r.position_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_kind', header: 'Equipment', render: (r: any) => r.equipment_kind },
    { key: 'action_at', header: 'When', render: (r: any) => r.action_at ? new Date(r.action_at).toLocaleString() : '—' },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const focusCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_kind', header: 'Equipment', render: (r: any) => r.equipment_kind },
    { key: 'our_cost_rupees', header: 'Our Cost', render: (r: any) => fmtRupees(r.our_cost_rupees) },
    { key: 'market_median_rupees', header: 'Market Median', render: (r: any) => fmtRupees(r.market_median_rupees) },
    { key: 'gap_rupees', header: 'Gap', render: (r: any) => fmtRupees(r.gap_rupees) },
    { key: 'position_kind', header: 'Position', render: (r: any) => r.position_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const posCols: Column<any>[] = [
    { key: 'position_kind', header: 'Position', render: (r: any) => r.position_kind },
    { key: 'benchmark_count', header: 'Count', render: (r: any) => r.benchmark_count },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'benchmark_count', header: 'Count', render: (r: any) => r.benchmark_count },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'benchmark_count', header: 'Benchmarks', render: (r: any) => r.benchmark_count },
    { key: 'avg_gap_rupees', header: 'Avg Gap', render: (r: any) => fmtRupees(r.avg_gap_rupees) },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'benchmark_count', header: 'Benchmarks', render: (r: any) => r.benchmark_count },
    { key: 'open_action_count', header: 'Open Actions', render: (r: any) => r.open_action_count },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Hospital Chain Equipment Vendor Cost Benchmark
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Track our equipment cost vs market median & top quartile across chains. Drive repricing & bundle actions where we sit above market.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Benchmarks</h2>
        <DataTable
          rows={benchmarks}
          columns={benchCols}
          emptyMessage="No benchmarks recorded"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Top Above-Market Focus</h2>
        <DataTable
          rows={focus}
          columns={focusCols}
          emptyMessage="No above-market benchmarks"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No actions logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '24px', marginBottom: '32px' }}>
        <div>
          <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Position Distribution</h2>
          <DataTable
            rows={positions}
            columns={posCols}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.position_kind ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Status Funnel</h2>
          <DataTable
            rows={statuses}
            columns={statusCols}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.status ?? i)}
          />
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Monthly Benchmark Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data yet"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Owner Load</h2>
        <DataTable
          rows={owners}
          columns={ownerCols}
          emptyMessage="No owners assigned"
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
