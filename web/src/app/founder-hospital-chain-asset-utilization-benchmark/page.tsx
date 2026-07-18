import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainAssetUtilizationBenchmarkPage() {
  const supabase = await getSupabaseServerClient();

  const [utilizationRes, actionsRes, topOppsRes, summaryRes, gapDistRes, trendRes, funnelRes] = await Promise.all([
    supabase.rpc('list_utilization_r2503'),
    supabase.rpc('list_growth_actions_r2503'),
    supabase.rpc('top_growth_opportunities_r2503'),
    supabase.rpc('asset_class_summary_r2503'),
    supabase.rpc('gap_to_top_distribution_r2503'),
    supabase.rpc('monthly_growth_action_trend_r2503'),
    supabase.rpc('status_funnel_r2503'),
  ]);

  const utilization = (utilizationRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const topOpps = (topOppsRes.data ?? []) as any[];
  const summary = (summaryRes.data ?? []) as any[];
  const gapDist = (gapDistRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];

  const fmtRupees = (n: number | null | undefined) =>
    n == null ? '-' : '₹' + Number(n).toLocaleString('en-IN');

  const fmtPct = (n: number | null | undefined) =>
    n == null ? '-' : Number(n).toFixed(1) + '%';

  const utilColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '-' },
    { key: 'asset_class', header: 'Asset', render: (r: any) => r.asset_class ?? '-' },
    { key: 'our_utilization_pct', header: 'Ours', render: (r: any) => fmtPct(r.our_utilization_pct) },
    { key: 'market_benchmark_pct', header: 'Market', render: (r: any) => fmtPct(r.market_benchmark_pct) },
    { key: 'top_quartile_pct', header: 'Top Q', render: (r: any) => fmtPct(r.top_quartile_pct) },
    { key: 'gap_to_top_pct', header: 'Gap', render: (r: any) => fmtPct(r.gap_to_top_pct) },
    { key: 'growth_opportunity_rupees', header: 'Opportunity', render: (r: any) => fmtRupees(r.growth_opportunity_rupees) },
    { key: 'observed_period_end', header: 'Period End', render: (r: any) => r.observed_period_end ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '-' },
    { key: 'asset_class', header: 'Asset', render: (r: any) => r.asset_class ?? '-' },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'expected_revenue_rupees', header: 'Expected Revenue', render: (r: any) => fmtRupees(r.expected_revenue_rupees) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'action_at', header: 'When', render: (r: any) => (r.action_at ? new Date(r.action_at).toLocaleString() : '-') },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topOppColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '-' },
    { key: 'asset_class', header: 'Asset', render: (r: any) => r.asset_class ?? '-' },
    { key: 'gap_to_top_pct', header: 'Gap to Top', render: (r: any) => fmtPct(r.gap_to_top_pct) },
    { key: 'growth_opportunity_rupees', header: 'Opportunity', render: (r: any) => fmtRupees(r.growth_opportunity_rupees) },
  ];

  const summaryColumns: Column<any>[] = [
    { key: 'asset_class', header: 'Asset', render: (r: any) => r.asset_class ?? '-' },
    { key: 'rows_count', header: 'Rows', render: (r: any) => r.rows_count ?? 0 },
    { key: 'avg_our_pct', header: 'Avg Ours', render: (r: any) => fmtPct(r.avg_our_pct) },
    { key: 'avg_top_pct', header: 'Avg Top Q', render: (r: any) => fmtPct(r.avg_top_pct) },
    { key: 'avg_gap_pct', header: 'Avg Gap', render: (r: any) => fmtPct(r.avg_gap_pct) },
    { key: 'total_opportunity_rupees', header: 'Total Opportunity', render: (r: any) => fmtRupees(r.total_opportunity_rupees) },
  ];

  const gapColumns: Column<any>[] = [
    { key: 'bucket', header: 'Gap Bucket', render: (r: any) => r.bucket ?? '-' },
    { key: 'rows_count', header: 'Rows', render: (r: any) => r.rows_count ?? 0 },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label ?? '-' },
    { key: 'actions_count', header: 'Actions', render: (r: any) => r.actions_count ?? 0 },
    { key: 'expected_revenue_rupees', header: 'Expected Revenue', render: (r: any) => fmtRupees(r.expected_revenue_rupees) },
  ];

  const funnelColumns: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'actions_count', header: 'Actions', render: (r: any) => r.actions_count ?? 0 },
    { key: 'expected_revenue_rupees', header: 'Expected Revenue', render: (r: any) => fmtRupees(r.expected_revenue_rupees) },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Hospital Chain Asset Utilization Benchmark</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Chain & asset class vs market benchmark & top quartile =&gt; growth opportunity in ₹
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Utilization rows</h2>
        <DataTable
          rows={utilization}
          columns={utilColumns}
          emptyMessage="No utilization rows yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top growth opportunities</h2>
        <DataTable
          rows={topOpps}
          columns={topOppColumns}
          emptyMessage="No opportunities"
          rowKey={(r: any, i: number) => String(r.chain_name + '-' + r.asset_class + '-' + i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Asset class summary</h2>
        <DataTable
          rows={summary}
          columns={summaryColumns}
          emptyMessage="No summary data"
          rowKey={(r: any, i: number) => String(r.asset_class ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Gap-to-top distribution</h2>
        <DataTable
          rows={gapDist}
          columns={gapColumns}
          emptyMessage="No distribution data"
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Growth actions</h2>
        <DataTable
          rows={actions}
          columns={actionColumns}
          emptyMessage="No growth actions yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Status funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelColumns}
          emptyMessage="No actions"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly action trend</h2>
        <DataTable
          rows={trend}
          columns={trendColumns}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>
    </div>
  );
}
