import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [milestones, snapshots, atRisk, topChains, kindSummary, weekly, upcoming] = await Promise.all([
    sb.rpc('list_milestones_r2459'),
    sb.rpc('list_burndown_snapshots_r2459'),
    sb.rpc('at_risk_focus_r2459'),
    sb.rpc('top_chains_by_completion_r2459'),
    sb.rpc('milestone_kind_summary_r2459'),
    sb.rpc('weekly_burndown_trend_r2459'),
    sb.rpc('upcoming_milestones_r2459'),
  ]);

  const milestoneCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'milestone_kind', header: 'Milestone', render: (r: any) => r.milestone_kind },
    { key: 'planned_at', header: 'Planned', render: (r: any) => r.planned_at ? new Date(r.planned_at).toLocaleDateString() : '-' },
    { key: 'actual_at', header: 'Actual', render: (r: any) => r.actual_at ? new Date(r.actual_at).toLocaleDateString() : '-' },
    { key: 'days_delta', header: 'Delta (d)', render: (r: any) => r.days_delta ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'at_risk', header: 'At Risk', render: (r: any) => r.at_risk ? 'yes' : 'no' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const snapshotCols: Column<any>[] = [
    { key: 'snapshot_date', header: 'Snapshot', render: (r: any) => r.snapshot_date },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'total_milestones', header: 'Total', render: (r: any) => r.total_milestones },
    { key: 'completed_milestones', header: 'Done', render: (r: any) => r.completed_milestones },
    { key: 'completion_pct', header: 'Completion %', render: (r: any) => r.completion_pct ?? '-' },
    { key: 'at_risk_count', header: 'At Risk', render: (r: any) => r.at_risk_count },
    { key: 'days_to_go_live', header: 'Days to Go-Live', render: (r: any) => r.days_to_go_live ?? '-' },
    { key: 'status', header: 'RAG', render: (r: any) => r.status },
    { key: 'top_blocker', header: 'Top Blocker', render: (r: any) => r.top_blocker ?? '-' },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'milestone_kind', header: 'Milestone', render: (r: any) => r.milestone_kind },
    { key: 'planned_at', header: 'Planned', render: (r: any) => r.planned_at ? new Date(r.planned_at).toLocaleDateString() : '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'blocker_notes', header: 'Blocker', render: (r: any) => r.blocker_notes ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const topCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'total_milestones', header: 'Total', render: (r: any) => r.total_milestones },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
    { key: 'completion_pct', header: 'Completion %', render: (r: any) => r.completion_pct ?? '-' },
  ];

  const kindCols: Column<any>[] = [
    { key: 'milestone_kind', header: 'Kind', render: (r: any) => r.milestone_kind },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
    { key: 'done', header: 'Done', render: (r: any) => r.done },
    { key: 'blocked', header: 'Blocked', render: (r: any) => r.blocked },
    { key: 'at_risk', header: 'At Risk', render: (r: any) => r.at_risk },
    { key: 'avg_delta', header: 'Avg Delta (d)', render: (r: any) => r.avg_delta ?? '-' },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'week_bucket', header: 'Week', render: (r: any) => r.week_bucket },
    { key: 'avg_completion_pct', header: 'Avg Completion %', render: (r: any) => r.avg_completion_pct ?? '-' },
    { key: 'avg_at_risk', header: 'Avg At-Risk', render: (r: any) => r.avg_at_risk ?? '-' },
    { key: 'snapshot_count', header: 'Snapshots', render: (r: any) => r.snapshot_count },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'milestone_kind', header: 'Milestone', render: (r: any) => r.milestone_kind },
    { key: 'planned_at', header: 'Planned', render: (r: any) => r.planned_at ? new Date(r.planned_at).toLocaleDateString() : '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'days_out', header: 'Days Out', render: (r: any) => r.days_out ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Hospital Chain Implementation Burndown</h1>
        <p className="text-sm text-gray-500">Chain & milestones > planned vs actual > burndown & at-risk slips.</p>
      </div>

      <section>
        <h2 className="text-lg font-medium mb-2">All Milestones</h2>
        <DataTable
          columns={milestoneCols}
          rows={milestones.data ?? []}
          emptyMessage="No milestones tracked."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Burndown Snapshots</h2>
        <DataTable
          columns={snapshotCols}
          rows={snapshots.data ?? []}
          emptyMessage="No snapshots captured."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">At-Risk Focus</h2>
        <DataTable
          columns={atRiskCols}
          rows={atRisk.data ?? []}
          emptyMessage="No at-risk milestones."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Top Chains by Completion</h2>
        <DataTable
          columns={topCols}
          rows={topChains.data ?? []}
          emptyMessage="No chain data."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Milestone Kind Summary</h2>
        <DataTable
          columns={kindCols}
          rows={kindSummary.data ?? []}
          emptyMessage="No kinds tracked."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Weekly Burndown Trend</h2>
        <DataTable
          columns={weeklyCols}
          rows={weekly.data ?? []}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Upcoming Milestones</h2>
        <DataTable
          columns={upcomingCols}
          rows={upcoming.data ?? []}
          emptyMessage="No upcoming milestones."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
