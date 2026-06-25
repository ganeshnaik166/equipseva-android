import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerShiftOverlapCoveragePage() {
  const supabase = await getSupabaseServerClient();

  const [
    overlapRes,
    gapActionsRes,
    topGapFocusRes,
    statusFunnelRes,
    monthlyTrendRes,
    zoneSummaryRes,
    ownerLoadRes,
  ] = await Promise.all([
    supabase.rpc('list_overlap_r2642'),
    supabase.rpc('list_gap_actions_r2642'),
    supabase.rpc('top_gap_focus_r2642'),
    supabase.rpc('status_funnel_r2642'),
    supabase.rpc('monthly_overlap_trend_r2642'),
    supabase.rpc('coverage_zone_summary_r2642'),
    supabase.rpc('owner_load_r2642'),
  ]);

  const overlaps = (overlapRes.data as any[]) ?? [];
  const gapActions = (gapActionsRes.data as any[]) ?? [];
  const topGapFocus = (topGapFocusRes.data as any[]) ?? [];
  const statusFunnel = (statusFunnelRes.data as any[]) ?? [];
  const monthlyTrend = (monthlyTrendRes.data as any[]) ?? [];
  const zoneSummary = (zoneSummaryRes.data as any[]) ?? [];
  const ownerLoad = (ownerLoadRes.data as any[]) ?? [];

  const overlapColumns: Column<any>[] = [
    { key: 'overlap_at', header: 'Overlap At', render: (r: any) => r.overlap_at ? new Date(r.overlap_at).toLocaleString() : '-' },
    { key: 'coverage_zone', header: 'Zone', render: (r: any) => r.coverage_zone ?? '-' },
    { key: 'overlap_minutes', header: 'Overlap Min', render: (r: any) => String(r.overlap_minutes ?? 0) },
    { key: 'gap_minutes', header: 'Gap Min', render: (r: any) => String(r.gap_minutes ?? 0) },
    { key: 'knowledge_transfer_ok', header: 'KT OK', render: (r: any) => r.knowledge_transfer_ok ? 'yes' : 'no' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const gapActionColumns: Column<any>[] = [
    { key: 'action_at', header: 'Action At', render: (r: any) => r.action_at ? new Date(r.action_at).toLocaleString() : '-' },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind ?? '-' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topGapFocusColumns: Column<any>[] = [
    { key: 'coverage_zone', header: 'Zone', render: (r: any) => r.coverage_zone ?? '-' },
    { key: 'total_gap_minutes', header: 'Total Gap Min', render: (r: any) => String(r.total_gap_minutes ?? 0) },
    { key: 'overlap_count', header: 'Overlaps', render: (r: any) => String(r.overlap_count ?? 0) },
    { key: 'avg_gap_minutes', header: 'Avg Gap Min', render: (r: any) => String(r.avg_gap_minutes ?? 0) },
  ];

  const statusFunnelColumns: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'overlap_count', header: 'Overlaps', render: (r: any) => String(r.overlap_count ?? 0) },
  ];

  const monthlyTrendColumns: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start ? String(r.month_start) : '-' },
    { key: 'overlap_count', header: 'Overlaps', render: (r: any) => String(r.overlap_count ?? 0) },
    { key: 'total_overlap_minutes', header: 'Total Overlap Min', render: (r: any) => String(r.total_overlap_minutes ?? 0) },
    { key: 'total_gap_minutes', header: 'Total Gap Min', render: (r: any) => String(r.total_gap_minutes ?? 0) },
  ];

  const zoneSummaryColumns: Column<any>[] = [
    { key: 'coverage_zone', header: 'Zone', render: (r: any) => r.coverage_zone ?? '-' },
    { key: 'overlap_count', header: 'Overlaps', render: (r: any) => String(r.overlap_count ?? 0) },
    { key: 'knowledge_transfer_ok_count', header: 'KT OK', render: (r: any) => String(r.knowledge_transfer_ok_count ?? 0) },
    { key: 'avg_overlap_minutes', header: 'Avg Overlap Min', render: (r: any) => String(r.avg_overlap_minutes ?? 0) },
  ];

  const ownerLoadColumns: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'overlap_count', header: 'Overlaps', render: (r: any) => String(r.overlap_count ?? 0) },
    { key: 'open_action_count', header: 'Open Actions', render: (r: any) => String(r.open_action_count ?? 0) },
    { key: 'total_gap_minutes', header: 'Total Gap Min', render: (r: any) => String(r.total_gap_minutes ?? 0) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Shift Overlap & Coverage</h1>
        <p className="text-sm text-gray-600">
          Track overlap windows between outgoing & incoming engineers; flag gaps > 0 and remediate.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Shift Overlap Windows</h2>
        <DataTable
          rows={overlaps}
          columns={overlapColumns}
          emptyMessage="No overlap windows recorded yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Gap Remediation Actions</h2>
        <DataTable
          rows={gapActions}
          columns={gapActionColumns}
          emptyMessage="No gap actions logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Gap Focus (by Zone)</h2>
        <DataTable
          rows={topGapFocus}
          columns={topGapFocusColumns}
          emptyMessage="No gap data"
          rowKey={(r: any, i: number) => String(r.coverage_zone ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status Funnel</h2>
        <DataTable
          rows={statusFunnel}
          columns={statusFunnelColumns}
          emptyMessage="No status data"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Overlap Trend</h2>
        <DataTable
          rows={monthlyTrend}
          columns={monthlyTrendColumns}
          emptyMessage="No monthly data"
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Coverage Zone Summary</h2>
        <DataTable
          rows={zoneSummary}
          columns={zoneSummaryColumns}
          emptyMessage="No zone data"
          rowKey={(r: any, i: number) => String(r.coverage_zone ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner Load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerLoadColumns}
          emptyMessage="No owner load data"
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
