import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainProcurementCycleTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [posRes, bottlenecksRes, breakdownRes, slowRes, trendRes, chainRes, upcomingRes] = await Promise.all([
    supabase.rpc('list_pos_r2427'),
    supabase.rpc('list_bottlenecks_r2427'),
    supabase.rpc('bottleneck_breakdown_r2427'),
    supabase.rpc('top_slow_pos_r2427'),
    supabase.rpc('weekly_lead_trend_r2427'),
    supabase.rpc('chain_lead_summary_r2427'),
    supabase.rpc('upcoming_deliveries_r2427'),
  ]);

  const pos = (posRes.data ?? []) as any[];
  const bottlenecks = (bottlenecksRes.data ?? []) as any[];
  const breakdown = (breakdownRes.data ?? []) as any[];
  const slow = (slowRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const chains = (chainRes.data ?? []) as any[];
  const upcoming = (upcomingRes.data ?? []) as any[];

  const fmtDate = (v: any) => (v ? new Date(v).toLocaleDateString() : '—');
  const fmtDateTime = (v: any) => (v ? new Date(v).toLocaleString() : '—');
  const fmtINR = (n: any) => '₹' + Number(n ?? 0).toLocaleString('en-IN');

  const posCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'po_external_ref', header: 'PO Ref', render: (r: any) => r.po_external_ref },
    { key: 'raised_at', header: 'Raised', render: (r: any) => fmtDate(r.raised_at) },
    { key: 'approved_at', header: 'Approved', render: (r: any) => fmtDate(r.approved_at) },
    { key: 'delivered_at', header: 'Delivered', render: (r: any) => fmtDate(r.delivered_at) },
    { key: 'expected_delivery_at', header: 'Expected', render: (r: any) => fmtDate(r.expected_delivery_at) },
    { key: 'lead_days_total', header: 'Lead Days', render: (r: any) => r.lead_days_total ?? '—' },
    { key: 'bottleneck_stage', header: 'Bottleneck', render: (r: any) => r.bottleneck_stage },
    { key: 'value_rupees', header: 'Value', render: (r: any) => fmtINR(r.value_rupees) },
    { key: 'item_count', header: 'Items', render: (r: any) => r.item_count },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const bottleneckCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'week_start', header: 'Week', render: (r: any) => fmtDate(r.week_start) },
    { key: 'bottleneck_stage', header: 'Stage', render: (r: any) => r.bottleneck_stage },
    { key: 'po_count', header: 'POs', render: (r: any) => r.po_count },
    { key: 'avg_lead_days', header: 'Avg Lead Days', render: (r: any) => Number(r.avg_lead_days ?? 0).toFixed(2) },
    { key: 'worst_offender_po', header: 'Worst PO', render: (r: any) => r.worst_offender_po ?? '—' },
    { key: 'action_plan', header: 'Action Plan', render: (r: any) => r.action_plan ?? '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'closed_at', header: 'Closed', render: (r: any) => fmtDate(r.closed_at) },
  ];

  const breakdownCols: Column<any>[] = [
    { key: 'bottleneck_stage', header: 'Stage', render: (r: any) => r.bottleneck_stage },
    { key: 'po_count', header: 'PO Count', render: (r: any) => r.po_count },
    { key: 'avg_lead_days', header: 'Avg Lead Days', render: (r: any) => Number(r.avg_lead_days ?? 0).toFixed(2) },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtINR(r.total_value_rupees) },
  ];

  const slowCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'po_external_ref', header: 'PO Ref', render: (r: any) => r.po_external_ref },
    { key: 'bottleneck_stage', header: 'Bottleneck', render: (r: any) => r.bottleneck_stage },
    { key: 'lead_days_total', header: 'Lead Days', render: (r: any) => r.lead_days_total ?? '—' },
    { key: 'value_rupees', header: 'Value', render: (r: any) => fmtINR(r.value_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => fmtDate(r.week_start) },
    { key: 'po_count', header: 'PO Count', render: (r: any) => r.po_count },
    { key: 'avg_lead_days', header: 'Avg Lead Days', render: (r: any) => Number(r.avg_lead_days ?? 0).toFixed(2) },
  ];

  const chainCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'po_count', header: 'PO Count', render: (r: any) => r.po_count },
    { key: 'avg_lead_days', header: 'Avg Lead Days', render: (r: any) => Number(r.avg_lead_days ?? 0).toFixed(2) },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtINR(r.total_value_rupees) },
    { key: 'open_bottlenecks', header: 'Open Bottlenecks', render: (r: any) => r.open_bottlenecks },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'po_external_ref', header: 'PO Ref', render: (r: any) => r.po_external_ref },
    { key: 'expected_delivery_at', header: 'Expected', render: (r: any) => fmtDateTime(r.expected_delivery_at) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'bottleneck_stage', header: 'Bottleneck', render: (r: any) => r.bottleneck_stage },
    { key: 'value_rupees', header: 'Value', render: (r: any) => fmtINR(r.value_rupees) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  return (
    <div className="p-6 space-y-8">
      <div>
        <h1 className="text-2xl font-bold">Hospital Chain Procurement Cycle Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Chain > PO raised > approved > delivered cycle & bottleneck stage tracking.
        </p>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain Lead Summary</h2>
        <DataTable
          rows={chains}
          columns={chainCols}
          emptyMessage="No chain summary yet."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Bottleneck Breakdown</h2>
        <DataTable
          rows={breakdown}
          columns={breakdownCols}
          emptyMessage="No bottleneck breakdown."
          rowKey={(r: any, i: number) => String(r.bottleneck_stage ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Slow POs</h2>
        <DataTable
          rows={slow}
          columns={slowCols}
          emptyMessage="No slow POs."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upcoming Deliveries</h2>
        <DataTable
          rows={upcoming}
          columns={upcomingCols}
          emptyMessage="No upcoming deliveries."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly Lead Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Bottlenecks Log</h2>
        <DataTable
          rows={bottlenecks}
          columns={bottleneckCols}
          emptyMessage="No bottlenecks logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Purchase Orders</h2>
        <DataTable
          rows={pos}
          columns={posCols}
          emptyMessage="No POs."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
