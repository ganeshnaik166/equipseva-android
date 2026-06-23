import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Pipeline = {
  id: string;
  chain_name: string;
  hospital_user_id: string | null;
  quarter_label: string;
  refresh_kind: string;
  equipment_kind: string;
  pipeline_value_rupees: number;
  decision_kind: string;
  scheduled_at: string | null;
  owner_email: string | null;
  status: string;
  notes: string | null;
  created_at: string;
};

type Milestone = {
  id: string;
  pipeline_id: string;
  chain_name: string;
  equipment_kind: string;
  milestone_kind: string;
  planned_at: string | null;
  actual_at: string | null;
  owner_email: string | null;
  status: string;
  notes: string | null;
};

type TopValue = {
  chain_name: string;
  equipment_kind: string;
  refresh_kind: string;
  pipeline_value_rupees: number;
  status: string;
  scheduled_at: string | null;
};

type KindBreakdown = {
  refresh_kind: string;
  pipeline_count: number;
  total_value_rupees: number;
  approved_count: number;
};

type DecisionDist = {
  decision_kind: string;
  pipeline_count: number;
  total_value_rupees: number;
};

type ScheduledFocus = {
  chain_name: string;
  equipment_kind: string;
  refresh_kind: string;
  scheduled_at: string | null;
  pipeline_value_rupees: number;
  status: string;
  owner_email: string | null;
};

type MonthlyTrend = {
  month_start: string;
  pipeline_count: number;
  total_value_rupees: number;
  approved_value_rupees: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [
    pipelineRes,
    milestonesRes,
    topValueRes,
    kindBreakdownRes,
    decisionDistRes,
    scheduledFocusRes,
    monthlyTrendRes,
  ] = await Promise.all([
    sb.rpc('list_pipeline_r2563'),
    sb.rpc('list_milestones_r2563'),
    sb.rpc('top_value_refreshes_r2563'),
    sb.rpc('refresh_kind_breakdown_r2563'),
    sb.rpc('decision_distribution_r2563'),
    sb.rpc('scheduled_focus_r2563'),
    sb.rpc('monthly_pipeline_trend_r2563'),
  ]);

  const pipeline: Pipeline[] = (pipelineRes.data ?? []) as Pipeline[];
  const milestones: Milestone[] = (milestonesRes.data ?? []) as Milestone[];
  const topValue: TopValue[] = (topValueRes.data ?? []) as TopValue[];
  const kindBreakdown: KindBreakdown[] = (kindBreakdownRes.data ?? []) as KindBreakdown[];
  const decisionDist: DecisionDist[] = (decisionDistRes.data ?? []) as DecisionDist[];
  const scheduledFocus: ScheduledFocus[] = (scheduledFocusRes.data ?? []) as ScheduledFocus[];
  const monthlyTrend: MonthlyTrend[] = (monthlyTrendRes.data ?? []) as MonthlyTrend[];

  const totalPipelineValue = pipeline.reduce((acc, p) => acc + (p.pipeline_value_rupees ?? 0), 0);
  const approvedValue = pipeline
    .filter((p) => p.decision_kind === 'approved')
    .reduce((acc, p) => acc + (p.pipeline_value_rupees ?? 0), 0);
  const scheduledCount = pipeline.filter((p) => p.status === 'scheduled').length;
  const installedCount = pipeline.filter((p) => p.status === 'installed').length;

  const pipelineCols: Column<Pipeline>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'kind', header: 'Refresh kind', render: (r: any) => r.refresh_kind },
    { key: 'equipment', header: 'Equipment', render: (r: any) => r.equipment_kind },
    { key: 'value', header: 'Value (Rs)', render: (r: any) => `Rs ${r.pipeline_value_rupees}` },
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'scheduled', header: 'Scheduled', render: (r: any) => (r.scheduled_at ? new Date(r.scheduled_at).toLocaleDateString() : '—') },
    { key: 'owner', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const milestoneCols: Column<Milestone>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment', header: 'Equipment', render: (r: any) => r.equipment_kind },
    { key: 'milestone', header: 'Milestone', render: (r: any) => r.milestone_kind },
    { key: 'planned', header: 'Planned', render: (r: any) => (r.planned_at ? new Date(r.planned_at).toLocaleDateString() : '—') },
    { key: 'actual', header: 'Actual', render: (r: any) => (r.actual_at ? new Date(r.actual_at).toLocaleDateString() : '—') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const topValueCols: Column<TopValue>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment', header: 'Equipment', render: (r: any) => r.equipment_kind },
    { key: 'kind', header: 'Kind', render: (r: any) => r.refresh_kind },
    { key: 'value', header: 'Value (Rs)', render: (r: any) => `Rs ${r.pipeline_value_rupees}` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'scheduled', header: 'Scheduled', render: (r: any) => (r.scheduled_at ? new Date(r.scheduled_at).toLocaleDateString() : '—') },
  ];

  const kindCols: Column<KindBreakdown>[] = [
    { key: 'kind', header: 'Refresh kind', render: (r: any) => r.refresh_kind },
    { key: 'count', header: 'Count', render: (r: any) => String(r.pipeline_count) },
    { key: 'value', header: 'Total value (Rs)', render: (r: any) => `Rs ${r.total_value_rupees}` },
    { key: 'approved', header: 'Approved', render: (r: any) => String(r.approved_count) },
  ];

  const decisionCols: Column<DecisionDist>[] = [
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision_kind },
    { key: 'count', header: 'Count', render: (r: any) => String(r.pipeline_count) },
    { key: 'value', header: 'Value (Rs)', render: (r: any) => `Rs ${r.total_value_rupees}` },
  ];

  const focusCols: Column<ScheduledFocus>[] = [
    { key: 'scheduled', header: 'Scheduled', render: (r: any) => (r.scheduled_at ? new Date(r.scheduled_at).toLocaleDateString() : '—') },
    { key: 'chain', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment', header: 'Equipment', render: (r: any) => r.equipment_kind },
    { key: 'kind', header: 'Kind', render: (r: any) => r.refresh_kind },
    { key: 'value', header: 'Value (Rs)', render: (r: any) => `Rs ${r.pipeline_value_rupees}` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const trendCols: Column<MonthlyTrend>[] = [
    { key: 'month', header: 'Month', render: (r: any) => new Date(r.month_start).toLocaleDateString(undefined, { year: 'numeric', month: 'short' }) },
    { key: 'count', header: 'Pipelines', render: (r: any) => String(r.pipeline_count) },
    { key: 'value', header: 'Total value (Rs)', render: (r: any) => `Rs ${r.total_value_rupees}` },
    { key: 'approved', header: 'Approved value (Rs)', render: (r: any) => `Rs ${r.approved_value_rupees}` },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Equipment Refresh Pipeline</h1>
        <p className="text-sm text-gray-500">r2563 · chain × refresh window × kind × pipeline value × decision × scheduled date</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Pipeline rows</div>
          <div className="text-2xl font-semibold">{pipeline.length}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total pipeline value</div>
          <div className="text-2xl font-semibold">Rs {totalPipelineValue}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Approved value</div>
          <div className="text-2xl font-semibold text-green-600">Rs {approvedValue}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Scheduled</div>
          <div className="text-2xl font-semibold text-blue-600">{scheduledCount}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Installed</div>
          <div className="text-2xl font-semibold">{installedCount}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Milestones tracked</div>
          <div className="text-2xl font-semibold">{milestones.length}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Refresh kinds</div>
          <div className="text-2xl font-semibold">{kindBreakdown.length}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Next-90d focus</div>
          <div className="text-2xl font-semibold">{scheduledFocus.length}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pipeline rows</h2>
        <DataTable rows={pipeline} columns={pipelineCols} emptyMessage="No pipeline rows yet" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top-value refreshes</h2>
        <DataTable rows={topValue} columns={topValueCols} emptyMessage="No high-value rows" rowKey={(r: any, i: number) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Refresh kind breakdown</h2>
        <DataTable rows={kindBreakdown} columns={kindCols} emptyMessage="No breakdown" rowKey={(r: any, i: number) => String(r.refresh_kind ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Decision distribution</h2>
        <DataTable rows={decisionDist} columns={decisionCols} emptyMessage="No decisions logged" rowKey={(r: any, i: number) => String(r.decision_kind ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Scheduled focus (next 90 days)</h2>
        <DataTable rows={scheduledFocus} columns={focusCols} emptyMessage="No scheduled refreshes in window" rowKey={(r: any, i: number) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly pipeline trend</h2>
        <DataTable rows={monthlyTrend} columns={trendCols} emptyMessage="No trend data" rowKey={(r: any, i: number) => String(r.month_start ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All milestones</h2>
        <DataTable rows={milestones} columns={milestoneCols} emptyMessage="No milestones logged" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
</page_tsx>
