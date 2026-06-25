import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainEquipmentFleetRenewalRoadmapPage() {
  const supabase = await getSupabaseServerClient();

  const [roadmapsRes, milestonesRes, topValueRes, kindDistRes, statusFunnelRes, trendRes, summaryRes] = await Promise.all([
    supabase.rpc('list_roadmaps_r2623'),
    supabase.rpc('list_milestones_r2623'),
    supabase.rpc('top_total_value_focus_r2623'),
    supabase.rpc('equipment_kind_distribution_r2623'),
    supabase.rpc('status_funnel_r2623'),
    supabase.rpc('monthly_milestone_trend_r2623'),
    supabase.rpc('refresh_in_12mo_summary_r2623'),
  ]);

  const roadmaps = (roadmapsRes.data ?? []) as any[];
  const milestones = (milestonesRes.data ?? []) as any[];
  const topValue = (topValueRes.data ?? []) as any[];
  const kindDist = (kindDistRes.data ?? []) as any[];
  const statusFunnel = (statusFunnelRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const summary = (summaryRes.data ?? [])[0] as any | undefined;

  const fmtCr = (n: number | null | undefined) => {
    const v = Number(n ?? 0);
    return `₹${(v / 10000000).toFixed(2)} Cr`;
  };
  const fmtDate = (s: string | null | undefined) => (s ? new Date(s).toLocaleDateString() : '-');
  const fmtMonth = (s: string | null | undefined) => (s ? new Date(s).toLocaleString(undefined, { month: 'short', year: 'numeric' }) : '-');

  const roadmapCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_kind', header: 'Equipment', render: (r: any) => r.equipment_kind },
    { key: 'current_count', header: 'Current', render: (r: any) => r.current_count },
    { key: 'refresh_in_12mo_count', header: '12mo', render: (r: any) => r.refresh_in_12mo_count },
    { key: 'refresh_in_24mo_count', header: '24mo', render: (r: any) => r.refresh_in_24mo_count },
    { key: 'refresh_in_36mo_count', header: '36mo', render: (r: any) => r.refresh_in_36mo_count },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtCr(r.total_value_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const milestoneCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '-' },
    { key: 'milestone_kind', header: 'Kind', render: (r: any) => r.milestone_kind },
    { key: 'milestone_at', header: 'When', render: (r: any) => fmtDate(r.milestone_at) },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topValueCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_kind', header: 'Equipment', render: (r: any) => r.equipment_kind },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtCr(r.total_value_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const kindDistCols: Column<any>[] = [
    { key: 'equipment_kind', header: 'Equipment', render: (r: any) => r.equipment_kind },
    { key: 'roadmap_count', header: 'Roadmaps', render: (r: any) => r.roadmap_count },
    { key: 'total_value_rupees', header: 'Value', render: (r: any) => fmtCr(r.total_value_rupees) },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'roadmap_count', header: 'Roadmaps', render: (r: any) => r.roadmap_count },
    { key: 'total_value_rupees', header: 'Value', render: (r: any) => fmtCr(r.total_value_rupees) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtMonth(r.month_start) },
    { key: 'milestone_count', header: 'Milestones', render: (r: any) => r.milestone_count },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
  ];

  return (
    <main className="p-6 space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital Chain Equipment Fleet Renewal Roadmap</h1>
        <p className="text-sm text-gray-600">
          Multi-year refresh pipeline across chains & equipment kinds — founder-only view.
        </p>
      </header>

      {summary && (
        <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Chains</div>
            <div className="text-xl font-semibold">{summary.chain_count ?? 0}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Units 12mo</div>
            <div className="text-xl font-semibold">{summary.total_units_12mo ?? 0}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Units 24mo</div>
            <div className="text-xl font-semibold">{summary.total_units_24mo ?? 0}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Units 36mo</div>
            <div className="text-xl font-semibold">{summary.total_units_36mo ?? 0}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Pipeline Value</div>
            <div className="text-xl font-semibold">{fmtCr(summary.total_value_rupees)}</div>
          </div>
        </section>
      )}

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Top Value Focus</h2>
        <DataTable
          rows={topValue}
          columns={topValueCols}
          emptyMessage="No roadmaps yet."
          rowKey={(r: any, i: number) => String(r.id ?? `${r.chain_name}-${i}`)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Equipment Kind Distribution</h2>
        <DataTable
          rows={kindDist}
          columns={kindDistCols}
          emptyMessage="No data."
          rowKey={(r: any, i: number) => String(r.equipment_kind ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Status Funnel</h2>
        <DataTable
          rows={statusFunnel}
          columns={statusCols}
          emptyMessage="No data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Monthly Milestone Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No milestone activity in last 12 months."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Roadmaps</h2>
        <DataTable
          rows={roadmaps}
          columns={roadmapCols}
          emptyMessage="No roadmaps yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Milestones</h2>
        <DataTable
          rows={milestones}
          columns={milestoneCols}
          emptyMessage="No milestones logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
