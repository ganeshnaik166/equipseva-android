import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ReassignRow = {
  id: string;
  engineer_user_id: string;
  engineer_name: string;
  from_region: string;
  to_region: string;
  move_reason: string;
  status: string;
  approval_state: string;
  initiated_on: string | null;
  effective_on: string | null;
  expected_duration_months: number;
  decision_owner: string;
  cost_entries: number;
  total_cost_rupees: number;
  total_gap_days: number;
};

type CostRow = {
  id: string;
  reassignment_id: string;
  engineer_name: string;
  from_region: string;
  to_region: string;
  cost_category: string;
  cost_rupees: number;
  incurred_on: string | null;
  gap_days: number;
  expected_monthly_value_rupees: number;
  actual_monthly_value_rupees: number;
  realized_review_state: string;
};

type NegativeRoiRow = {
  reassignment_id: string;
  engineer_name: string;
  from_region: string;
  to_region: string;
  status: string;
  total_cost_rupees: number;
  expected_monthly_value_rupees: number;
  actual_monthly_value_rupees: number;
  value_shortfall_rupees: number;
  effective_on: string | null;
};

type EngineerSummaryRow = {
  engineer_user_id: string;
  engineer_name: string;
  move_count: number;
  active_moves: number;
  reverted_moves: number;
  total_cost_rupees: number;
  total_gap_days: number;
  last_effective_on: string | null;
};

type RouteRow = {
  from_region: string;
  to_region: string;
  move_count: number;
  total_cost_rupees: number;
  avg_cost_rupees: number;
  total_gap_days: number;
  reverted_count: number;
};

type CategoryRow = {
  cost_category: string;
  entry_count: number;
  total_rupees: number;
  avg_rupees: number;
  total_gap_days: number;
};

type TrendRow = {
  month_start: string;
  move_count: number;
  total_cost_rupees: number;
  total_gap_days: number;
  reverted_count: number;
  positive_roi_count: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [reassignRes, costRes, negRes, engSumRes, routeRes, catRes, trendRes] = await Promise.all([
    sb.rpc('list_reassignments_r2314'),
    sb.rpc('list_reassignment_costs_r2314'),
    sb.rpc('negative_roi_moves_r2314'),
    sb.rpc('engineer_move_summary_r2314'),
    sb.rpc('route_breakdown_r2314'),
    sb.rpc('cost_category_mix_r2314'),
    sb.rpc('monthly_reassignment_trend_r2314'),
  ]);

  const reassigns: ReassignRow[] = (reassignRes.data as ReassignRow[] | null) ?? [];
  const costs: CostRow[] = (costRes.data as CostRow[] | null) ?? [];
  const negativeRoi: NegativeRoiRow[] = (negRes.data as NegativeRoiRow[] | null) ?? [];
  const engineerSummary: EngineerSummaryRow[] = (engSumRes.data as EngineerSummaryRow[] | null) ?? [];
  const routes: RouteRow[] = (routeRes.data as RouteRow[] | null) ?? [];
  const categories: CategoryRow[] = (catRes.data as CategoryRow[] | null) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[] | null) ?? [];

  const reassignCols: Column<ReassignRow>[] = [
    { key: 'effective_on', header: 'Effective', render: (r: any) => r.effective_on ?? '—' },
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
    { key: 'from_region', header: 'From', render: (r: any) => r.from_region },
    { key: 'to_region', header: 'To', render: (r: any) => r.to_region },
    { key: 'move_reason', header: 'Reason', render: (r: any) => r.move_reason },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'approval_state', header: 'Approval', render: (r: any) => r.approval_state },
    { key: 'expected_duration_months', header: 'Months', render: (r: any) => r.expected_duration_months },
    { key: 'cost_entries', header: 'Cost rows', render: (r: any) => r.cost_entries },
    { key: 'total_cost_rupees', header: 'Total cost', render: (r: any) => r.total_cost_rupees },
    { key: 'total_gap_days', header: 'Gap days', render: (r: any) => r.total_gap_days },
    { key: 'decision_owner', header: 'Owner', render: (r: any) => r.decision_owner || '—' },
  ];

  const costCols: Column<CostRow>[] = [
    { key: 'incurred_on', header: 'Date', render: (r: any) => r.incurred_on ?? '—' },
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
    { key: 'from_region', header: 'From', render: (r: any) => r.from_region },
    { key: 'to_region', header: 'To', render: (r: any) => r.to_region },
    { key: 'cost_category', header: 'Category', render: (r: any) => r.cost_category },
    { key: 'cost_rupees', header: 'Cost', render: (r: any) => r.cost_rupees },
    { key: 'gap_days', header: 'Gap', render: (r: any) => r.gap_days },
    { key: 'expected_monthly_value_rupees', header: 'Exp value', render: (r: any) => r.expected_monthly_value_rupees },
    { key: 'actual_monthly_value_rupees', header: 'Actual value', render: (r: any) => r.actual_monthly_value_rupees },
    { key: 'realized_review_state', header: 'Review', render: (r: any) => r.realized_review_state },
  ];

  const negCols: Column<NegativeRoiRow>[] = [
    { key: 'value_shortfall_rupees', header: 'Shortfall', render: (r: any) => r.value_shortfall_rupees },
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
    { key: 'from_region', header: 'From', render: (r: any) => r.from_region },
    { key: 'to_region', header: 'To', render: (r: any) => r.to_region },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'total_cost_rupees', header: 'Total cost', render: (r: any) => r.total_cost_rupees },
    { key: 'expected_monthly_value_rupees', header: 'Exp value', render: (r: any) => r.expected_monthly_value_rupees },
    { key: 'actual_monthly_value_rupees', header: 'Actual value', render: (r: any) => r.actual_monthly_value_rupees },
    { key: 'effective_on', header: 'Effective', render: (r: any) => r.effective_on ?? '—' },
  ];

  const engSumCols: Column<EngineerSummaryRow>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
    { key: 'move_count', header: 'Moves', render: (r: any) => r.move_count },
    { key: 'active_moves', header: 'Active', render: (r: any) => r.active_moves },
    { key: 'reverted_moves', header: 'Reverted', render: (r: any) => r.reverted_moves },
    { key: 'total_cost_rupees', header: 'Total cost', render: (r: any) => r.total_cost_rupees },
    { key: 'total_gap_days', header: 'Gap days', render: (r: any) => r.total_gap_days },
    { key: 'last_effective_on', header: 'Last move', render: (r: any) => r.last_effective_on ?? '—' },
  ];

  const routeCols: Column<RouteRow>[] = [
    { key: 'from_region', header: 'From', render: (r: any) => r.from_region },
    { key: 'to_region', header: 'To', render: (r: any) => r.to_region },
    { key: 'move_count', header: 'Moves', render: (r: any) => r.move_count },
    { key: 'total_cost_rupees', header: 'Total cost', render: (r: any) => r.total_cost_rupees },
    { key: 'avg_cost_rupees', header: 'Avg cost', render: (r: any) => r.avg_cost_rupees },
    { key: 'total_gap_days', header: 'Gap days', render: (r: any) => r.total_gap_days },
    { key: 'reverted_count', header: 'Reverted', render: (r: any) => r.reverted_count },
  ];

  const catCols: Column<CategoryRow>[] = [
    { key: 'cost_category', header: 'Category', render: (r: any) => r.cost_category },
    { key: 'entry_count', header: 'Entries', render: (r: any) => r.entry_count },
    { key: 'total_rupees', header: 'Total', render: (r: any) => r.total_rupees },
    { key: 'avg_rupees', header: 'Avg', render: (r: any) => r.avg_rupees },
    { key: 'total_gap_days', header: 'Gap days', render: (r: any) => r.total_gap_days },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start },
    { key: 'move_count', header: 'Moves', render: (r: any) => r.move_count },
    { key: 'total_cost_rupees', header: 'Total cost', render: (r: any) => r.total_cost_rupees },
    { key: 'total_gap_days', header: 'Gap days', render: (r: any) => r.total_gap_days },
    { key: 'reverted_count', header: 'Reverted', render: (r: any) => r.reverted_count },
    { key: 'positive_roi_count', header: 'Positive ROI', render: (r: any) => r.positive_roi_count },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Regional Reassignment Cost Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track engineers moved across regions. Capture travel, relocation, gap-days and ramp costs =&gt; compare against expected and actual monthly value. Flag negative-ROI moves before they compound.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Reassignments ({reassigns.length})</h2>
        <DataTable
          rows={reassigns}
          columns={reassignCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No reassignments logged."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Cost entries ({costs.length})</h2>
        <DataTable
          rows={costs}
          columns={costCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No cost rows."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Negative-ROI watchlist ({negativeRoi.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Moves where review state is negative or break-even, or where actual monthly value &lt; expected after 60+ days effective. Decide: revert, double-down, or write-off.
        </p>
        <DataTable
          rows={negativeRoi}
          columns={negCols}
          rowKey={(r: any, i: number) => String(r.reassignment_id ?? i)}
          emptyMessage="No negative-ROI moves."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Per-engineer summary ({engineerSummary.length})</h2>
        <DataTable
          rows={engineerSummary}
          columns={engSumCols}
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
          emptyMessage="No engineer summary."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Route breakdown ({routes.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          From-region =&gt; To-region cost and frequency. Spot expensive lanes and high-revert routes.
        </p>
        <DataTable
          rows={routes}
          columns={routeCols}
          rowKey={(r: any, i: number) => String(r.from_region ? `${r.from_region}_${r.to_region}` : i)}
          emptyMessage="No route data."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Cost category mix ({categories.length})</h2>
        <DataTable
          rows={categories}
          columns={catCols}
          rowKey={(r: any, i: number) => String(r.cost_category ?? i)}
          emptyMessage="No category data."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly trend ({trend.length})</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
          emptyMessage="No trend data."
        />
      </section>
    </div>
  );
}
