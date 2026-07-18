import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [cyclesRes, snapsRes, slowRes, bottleRes, topDsoRes, trendRes, arRes] = await Promise.all([
    supabase.rpc('list_cycles_r2468'),
    supabase.rpc('list_dso_snapshots_r2468'),
    supabase.rpc('top_slow_cycles_r2468'),
    supabase.rpc('bottleneck_breakdown_r2468'),
    supabase.rpc('top_chains_by_dso_r2468'),
    supabase.rpc('monthly_dso_trend_r2468'),
    supabase.rpc('outstanding_ar_focus_r2468'),
  ]);

  const cycles = (cyclesRes.data ?? []) as any[];
  const snaps = (snapsRes.data ?? []) as any[];
  const slow = (slowRes.data ?? []) as any[];
  const bottle = (bottleRes.data ?? []) as any[];
  const topDso = (topDsoRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const ar = (arRes.data ?? []) as any[];

  const fmtRup = (n: number | null | undefined) =>
    n == null ? '—' : '₹' + Number(n).toLocaleString('en-IN');
  const fmtDate = (s: string | null | undefined) =>
    s ? new Date(s).toLocaleDateString() : '—';

  const cycleCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quote_external_ref', header: 'Quote Ref', render: (r: any) => r.quote_external_ref },
    { key: 'quoted_at', header: 'Quoted', render: (r: any) => fmtDate(r.quoted_at) },
    { key: 'cash_received_at', header: 'Cash In', render: (r: any) => fmtDate(r.cash_received_at) },
    { key: 'days_total', header: 'Total Days', render: (r: any) => r.days_total ?? '—' },
    { key: 'bottleneck_stage', header: 'Bottleneck', render: (r: any) => r.bottleneck_stage },
    { key: 'dso_impact_kind', header: 'DSO Impact', render: (r: any) => r.dso_impact_kind },
    { key: 'value_rupees', header: 'Value', render: (r: any) => fmtRup(r.value_rupees) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const snapCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'snapshot_date', header: 'Snapshot', render: (r: any) => fmtDate(r.snapshot_date) },
    { key: 'total_cycles', header: 'Cycles', render: (r: any) => r.total_cycles },
    { key: 'avg_days_total', header: 'Avg Days', render: (r: any) => Number(r.avg_days_total).toFixed(1) },
    { key: 'avg_dso_days', header: 'Avg DSO', render: (r: any) => Number(r.avg_dso_days).toFixed(1) },
    { key: 'top_bottleneck_stage', header: 'Top Bottleneck', render: (r: any) => r.top_bottleneck_stage ?? '—' },
    { key: 'total_outstanding_rupees', header: 'Outstanding', render: (r: any) => fmtRup(r.total_outstanding_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const slowCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quote_external_ref', header: 'Quote Ref', render: (r: any) => r.quote_external_ref },
    { key: 'days_total', header: 'Days', render: (r: any) => r.days_total ?? '—' },
    { key: 'bottleneck_stage', header: 'Bottleneck', render: (r: any) => r.bottleneck_stage },
    { key: 'value_rupees', header: 'Value', render: (r: any) => fmtRup(r.value_rupees) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const bottleCols: Column<any>[] = [
    { key: 'bottleneck_stage', header: 'Stage', render: (r: any) => r.bottleneck_stage },
    { key: 'cycles_count', header: 'Cycles', render: (r: any) => r.cycles_count },
    { key: 'avg_days', header: 'Avg Days', render: (r: any) => Number(r.avg_days).toFixed(1) },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtRup(r.total_value_rupees) },
  ];

  const topDsoCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'avg_dso_days', header: 'Avg DSO', render: (r: any) => Number(r.avg_dso_days).toFixed(1) },
    { key: 'total_outstanding_rupees', header: 'Outstanding', render: (r: any) => fmtRup(r.total_outstanding_rupees) },
    { key: 'ar_aging_90d_plus_rupees', header: '90d+ AR', render: (r: any) => fmtRup(r.ar_aging_90d_plus_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtDate(r.month_start) },
    { key: 'snapshot_count', header: 'Snapshots', render: (r: any) => r.snapshot_count },
    { key: 'avg_dso', header: 'Avg DSO', render: (r: any) => Number(r.avg_dso).toFixed(1) },
    { key: 'avg_outstanding', header: 'Avg Outstanding', render: (r: any) => fmtRup(Number(r.avg_outstanding)) },
  ];

  const arCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'total_outstanding_rupees', header: 'Outstanding', render: (r: any) => fmtRup(r.total_outstanding_rupees) },
    { key: 'ar_aging_30d_rupees', header: '30d', render: (r: any) => fmtRup(r.ar_aging_30d_rupees) },
    { key: 'ar_aging_60d_rupees', header: '60d', render: (r: any) => fmtRup(r.ar_aging_60d_rupees) },
    { key: 'ar_aging_90d_plus_rupees', header: '90d+', render: (r: any) => fmtRup(r.ar_aging_90d_plus_rupees) },
    { key: 'pct_90d_plus', header: '% 90d+', render: (r: any) => Number(r.pct_90d_plus).toFixed(1) + '%' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Hospital Chain Quote-to-Cash Cycle
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Chain &gt; quote &gt; PO &gt; invoice &gt; cash days & DSO impact tracker.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Quote-to-Cash Cycles</h2>
        <DataTable
          rows={cycles}
          columns={cycleCols}
          emptyMessage="No cycles recorded yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>DSO Snapshots</h2>
        <DataTable
          rows={snaps}
          columns={snapCols}
          emptyMessage="No DSO snapshots yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Slow Cycles</h2>
        <DataTable
          rows={slow}
          columns={slowCols}
          emptyMessage="No slow cycles."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Bottleneck Breakdown</h2>
        <DataTable
          rows={bottle}
          columns={bottleCols}
          emptyMessage="No bottleneck data."
          rowKey={(r: any, i: number) => String(r.bottleneck_stage ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Chains by DSO</h2>
        <DataTable
          rows={topDso}
          columns={topDsoCols}
          emptyMessage="No DSO leaderboard."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Monthly DSO Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Outstanding AR Focus</h2>
        <DataTable
          rows={ar}
          columns={arCols}
          emptyMessage="No outstanding AR."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>
    </main>
  );
}
