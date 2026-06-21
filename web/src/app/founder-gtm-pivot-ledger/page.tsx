import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function rupees(n: number | null | undefined): string {
  if (n == null) return "—";
  const v = Number(n) || 0;
  if (Math.abs(v) >= 10000000) return `₹${(v/10000000).toFixed(2)}Cr`;
  if (Math.abs(v) >= 100000) return `₹${(v/100000).toFixed(2)}L`;
  if (Math.abs(v) >= 1000) return `₹${(v/1000).toFixed(1)}K`;
  return `₹${v}`;
}

function num(n: number | null | undefined): string {
  if (n == null) return "—";
  return String(n);
}

function pct(n: number | null | undefined): string {
  if (n == null) return "—";
  return `${Number(n).toFixed(1)}%`;
}

export default async function FounderGtmPivotLedgerPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let recent: any[] = [];
  let byType: any[] = [];
  let winners: any[] = [];
  let losers: any[] = [];
  let checkpoints: any[] = [];
  let milestones: any[] = [];

  try {
    const r = await sb.rpc('founder_gtm_pivot_kpis');
    kpis = (r.data && r.data[0]) || {};
  } catch { kpis = {}; }

  try {
    const r = await sb.rpc('founder_gtm_pivot_recent', { p_limit: 50 });
    recent = r.data || [];
  } catch { recent = []; }

  try {
    const r = await sb.rpc('founder_gtm_pivot_by_type');
    byType = r.data || [];
  } catch { byType = []; }

  try {
    const r = await sb.rpc('founder_gtm_pivot_top_winners', { p_limit: 15 });
    winners = r.data || [];
  } catch { winners = []; }

  try {
    const r = await sb.rpc('founder_gtm_pivot_worst_losers', { p_limit: 15 });
    losers = r.data || [];
  } catch { losers = []; }

  try {
    const r = await sb.rpc('founder_gtm_pivot_checkpoint_due');
    checkpoints = r.data || [];
  } catch { checkpoints = []; }

  try {
    const r = await sb.rpc('founder_gtm_pivot_recent_milestones', { p_limit: 30 });
    milestones = r.data || [];
  } catch { milestones = []; }

  const kpiCards: Kpi[] = [
    { label: 'Total Pivots', value: num(kpis.total_pivots) },
    { label: 'Active', value: num(kpis.active_pivots) },
    { label: 'Completed', value: num(kpis.completed_pivots) },
    { label: 'Reversed', value: num(kpis.reversed_pivots) },
    { label: 'Abandoned', value: num(kpis.abandoned_pivots) },
    { label: 'Wins', value: num(kpis.win_count) },
    { label: 'Losses', value: num(kpis.loss_count) },
    { label: 'Mixed', value: num(kpis.mixed_count) },
    { label: 'Pending Verdict', value: num(kpis.pending_count) },
    { label: 'Expected Impact', value: rupees(kpis.total_expected_rupees) },
    { label: 'Actual 90d Outcome', value: rupees(kpis.total_outcome_90d_rupees) },
    { label: 'Pivot Cost', value: rupees(kpis.total_cost_rupees) },
    { label: 'Net ROI', value: rupees(kpis.net_roi_rupees) },
    { label: 'Avg Uplift %', value: pct(kpis.avg_uplift_pct) },
    { label: 'Last 30d', value: num(kpis.pivots_last_30d) },
    { label: 'Last 90d', value: num(kpis.pivots_last_90d) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'pivot_code', header: 'Code', render: (r: any) => r.pivot_code ?? "—" },
    { key: 'pivot_type', header: 'Type', render: (r: any) => r.pivot_type ?? "—" },
    { key: 'title', header: 'Title', render: (r: any) => r.title ?? "—" },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? "—" },
    { key: 'verdict', header: 'Verdict', render: (r: any) => r.verdict ?? "pending" },
    { key: 'decided_by_email', header: 'By', render: (r: any) => r.decided_by_email ?? "—" },
    { key: 'decided_at', header: 'Decided', render: (r: any) => r.decided_at ? new Date(r.decided_at).toLocaleDateString() : "—" },
    { key: 'expected_impact_rupees', header: 'Expected', render: (r: any) => rupees(r.expected_impact_rupees) },
    { key: 'outcome_90d_rupees', header: '90d Actual', render: (r: any) => rupees(r.outcome_90d_rupees) },
    { key: 'days_since_decision', header: 'Age (d)', render: (r: any) => num(r.days_since_decision) },
  ];

  const byTypeCols: Column<any>[] = [
    { key: 'pivot_type', header: 'Type', render: (r: any) => r.pivot_type ?? "—" },
    { key: 'pivot_count', header: 'Count', render: (r: any) => num(r.pivot_count) },
    { key: 'win_count', header: 'Wins', render: (r: any) => num(r.win_count) },
    { key: 'loss_count', header: 'Losses', render: (r: any) => num(r.loss_count) },
    { key: 'total_expected_rupees', header: 'Expected', render: (r: any) => rupees(r.total_expected_rupees) },
    { key: 'total_outcome_90d_rupees', header: '90d Actual', render: (r: any) => rupees(r.total_outcome_90d_rupees) },
    { key: 'total_cost_rupees', header: 'Cost', render: (r: any) => rupees(r.total_cost_rupees) },
    { key: 'net_roi_rupees', header: 'Net ROI', render: (r: any) => rupees(r.net_roi_rupees) },
    { key: 'avg_uplift_pct', header: 'Avg Uplift', render: (r: any) => pct(r.avg_uplift_pct) },
  ];

  const winnersCols: Column<any>[] = [
    { key: 'pivot_code', header: 'Code', render: (r: any) => r.pivot_code ?? "—" },
    { key: 'pivot_type', header: 'Type', render: (r: any) => r.pivot_type ?? "—" },
    { key: 'title', header: 'Title', render: (r: any) => r.title ?? "—" },
    { key: 'decided_at', header: 'Decided', render: (r: any) => r.decided_at ? new Date(r.decided_at).toLocaleDateString() : "—" },
    { key: 'expected_impact_rupees', header: 'Expected', render: (r: any) => rupees(r.expected_impact_rupees) },
    { key: 'outcome_90d_rupees', header: '90d Actual', render: (r: any) => rupees(r.outcome_90d_rupees) },
    { key: 'cost_to_pivot_rupees', header: 'Cost', render: (r: any) => rupees(r.cost_to_pivot_rupees) },
    { key: 'net_roi_rupees', header: 'Net ROI', render: (r: any) => rupees(r.net_roi_rupees) },
    { key: 'roi_multiple', header: 'ROI x', render: (r: any) => r.roi_multiple != null ? `${Number(r.roi_multiple).toFixed(2)}x` : "—" },
  ];

  const losersCols: Column<any>[] = [
    { key: 'pivot_code', header: 'Code', render: (r: any) => r.pivot_code ?? "—" },
    { key: 'pivot_type', header: 'Type', render: (r: any) => r.pivot_type ?? "—" },
    { key: 'title', header: 'Title', render: (r: any) => r.title ?? "—" },
    { key: 'decided_at', header: 'Decided', render: (r: any) => r.decided_at ? new Date(r.decided_at).toLocaleDateString() : "—" },
    { key: 'expected_impact_rupees', header: 'Expected', render: (r: any) => rupees(r.expected_impact_rupees) },
    { key: 'outcome_90d_rupees', header: '90d Actual', render: (r: any) => rupees(r.outcome_90d_rupees) },
    { key: 'cost_to_pivot_rupees', header: 'Cost', render: (r: any) => rupees(r.cost_to_pivot_rupees) },
    { key: 'net_roi_rupees', header: 'Net ROI', render: (r: any) => rupees(r.net_roi_rupees) },
    { key: 'variance_vs_expected', header: 'vs Expected', render: (r: any) => rupees(r.variance_vs_expected) },
  ];

  const checkpointCols: Column<any>[] = [
    { key: 'pivot_code', header: 'Code', render: (r: any) => r.pivot_code ?? "—" },
    { key: 'title', header: 'Title', render: (r: any) => r.title ?? "—" },
    { key: 'decided_at', header: 'Decided', render: (r: any) => r.decided_at ? new Date(r.decided_at).toLocaleDateString() : "—" },
    { key: 'days_since', header: 'Age (d)', render: (r: any) => num(r.days_since) },
    { key: 'next_checkpoint', header: 'Next', render: (r: any) => r.next_checkpoint ?? "—" },
    { key: 'next_checkpoint_due_in_days', header: 'Due In (d)', render: (r: any) => num(r.next_checkpoint_due_in_days) },
  ];

  const milestoneCols: Column<any>[] = [
    { key: 'observed_at', header: 'Observed', render: (r: any) => r.observed_at ? new Date(r.observed_at).toLocaleDateString() : "—" },
    { key: 'pivot_code', header: 'Pivot', render: (r: any) => r.pivot_code ?? "—" },
    { key: 'pivot_title', header: 'Title', render: (r: any) => r.pivot_title ?? "—" },
    { key: 'metric_name', header: 'Metric', render: (r: any) => r.metric_name ?? "—" },
    { key: 'metric_value_rupees', header: 'Value (₹)', render: (r: any) => rupees(r.metric_value_rupees) },
    { key: 'metric_value_count', header: 'Count', render: (r: any) => num(r.metric_value_count) },
    { key: 'recorded_by_email', header: 'By', render: (r: any) => r.recorded_by_email ?? "—" },
  ];

  return (
    <div className="p-6 space-y-8">
      <div>
        <h1 className="text-2xl font-bold">Founder · GTM Pivot Ledger</h1>
        <p className="text-sm text-gray-600 mt-1">
          Every channel switch, segment change, ICP refine. Reason, expected impact,
          actual 30/60/90d outcome, ROI per pivot. r1581.
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        {kpiCards.map((k) => (
          <div key={k.label} className="border rounded-lg p-3 bg-white">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold mt-1">{k.value}</div>
          </div>
        ))}
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Pivots</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Pivot Type</h2>
        <DataTable rows={byType} columns={byTypeCols} rowKey={(r: any) => r.pivot_type} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Winners (Net ROI)</h2>
        <DataTable rows={winners} columns={winnersCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Worst Losers</h2>
        <DataTable rows={losers} columns={losersCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Checkpoint Due (30/60/90d)</h2>
        <DataTable rows={checkpoints} columns={checkpointCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Milestones</h2>
        <DataTable rows={milestones} columns={milestoneCols} rowKey={(r: any) => r.milestone_id} />
      </section>
    </div>
  );
}
