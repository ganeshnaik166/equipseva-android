import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { spend_status: string; campaigns: number; pct: number };
type CategoryRow = {
  merchandise_category: string;
  campaigns: number;
  total_budget_rupees: number;
  total_actual_spend_rupees: number;
  over_budget_campaigns: number;
  total_units_ordered: number;
  total_units_distributed: number;
  total_units_remaining_inventory: number;
  avg_cost_per_unit_rupees: number | null;
};
type MatrixRow = {
  event_class: string;
  spend_status: string;
  campaigns: number;
  total_actual_spend_rupees: number;
  approval_missing: number;
};
type TrendRow = {
  period_month: string;
  campaigns: number;
  total_budget_rupees: number;
  total_actual_spend_rupees: number;
  variance_rupees: number;
  worsening_campaigns: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  overdue_flag: number;
  closed_flag: number;
};
type CauseRow = {
  root_cause: string | null;
  occurrences: number;
  pct: number;
};
type InventoryRow = {
  campaign_name: string;
  merchandise_category: string;
  period_month: string;
  units_ordered: number | null;
  units_distributed: number | null;
  units_remaining_inventory: number | null;
  spend_status: string;
  notes: string | null;
};
type RiskRow = {
  campaign_name: string;
  merchandise_category: string;
  event_class: string;
  period_month: string;
  spend_status: string;
  budget_rupees: number | null;
  actual_spend_rupees: number | null;
  approval_on_file: boolean;
  vendor_name: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    categoryRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    inventoryRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3743_spend_status_rollup'),
    supabase.rpc('founder_r3743_merchandise_category_scorecard'),
    supabase.rpc('founder_r3743_event_class_status_matrix'),
    supabase.rpc('founder_r3743_monthly_spend_trend'),
    supabase.rpc('founder_r3743_capa_status_board'),
    supabase.rpc('founder_r3743_root_cause_pareto'),
    supabase.rpc('founder_r3743_inventory_variance_digest'),
    supabase.rpc('founder_r3743_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const inventoryRows: InventoryRow[] = (inventoryRes.data as InventoryRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'spend_status', header: 'Spend Status' },
    { key: 'campaigns', header: 'Campaigns' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'merchandise_category', header: 'Merchandise Category' },
    { key: 'campaigns', header: 'Campaigns' },
    { key: 'total_budget_rupees', header: 'Budget (INR)' },
    { key: 'total_actual_spend_rupees', header: 'Actual Spend (INR)' },
    { key: 'over_budget_campaigns', header: 'Over Budget' },
    { key: 'total_units_ordered', header: 'Units Ordered' },
    { key: 'total_units_distributed', header: 'Units Distributed' },
    { key: 'total_units_remaining_inventory', header: 'Units Remaining' },
    { key: 'avg_cost_per_unit_rupees', header: 'Avg Cost/Unit (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'event_class', header: 'Event Class' },
    { key: 'spend_status', header: 'Spend Status' },
    { key: 'campaigns', header: 'Campaigns' },
    { key: 'total_actual_spend_rupees', header: 'Actual Spend (INR)' },
    { key: 'approval_missing', header: 'Approval Missing' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'campaigns', header: 'Campaigns' },
    { key: 'total_budget_rupees', header: 'Budget (INR)' },
    { key: 'total_actual_spend_rupees', header: 'Actual Spend (INR)' },
    { key: 'variance_rupees', header: 'Variance (INR)' },
    { key: 'worsening_campaigns', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'overdue_flag', header: 'Overdue' },
    { key: 'closed_flag', header: 'Closed' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const inventoryCols: Column<InventoryRow>[] = [
    { key: 'campaign_name', header: 'Campaign' },
    { key: 'merchandise_category', header: 'Category' },
    { key: 'period_month', header: 'Month' },
    { key: 'units_ordered', header: 'Ordered' },
    { key: 'units_distributed', header: 'Distributed' },
    { key: 'units_remaining_inventory', header: 'Remaining' },
    { key: 'spend_status', header: 'Spend Status' },
    { key: 'notes', header: 'Notes' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'campaign_name', header: 'Campaign' },
    { key: 'merchandise_category', header: 'Category' },
    { key: 'event_class', header: 'Event Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'spend_status', header: 'Spend Status' },
    { key: 'budget_rupees', header: 'Budget (INR)' },
    { key: 'actual_spend_rupees', header: 'Actual Spend (INR)' },
    { key: 'approval_on_file', header: 'Approval on File' },
    { key: 'vendor_name', header: 'Vendor' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Corporate Gifting / Promotional-Merchandise Spend Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per-campaign corporate gifting &amp; promotional-merchandise spend log — branded swag,
        conference giveaways &amp; client appreciation hampers &times; merchandise category
        &times; period month &times; budget vs actual spend &times; units ordered, distributed
        &amp; remaining inventory &times; approval-on-file &times; vendor &amp; cost per unit
        &times; event class &amp; CAPA closure. Distinct from HCP/official gift-declaration
        anti-bribery registers &mdash; this tracks marketing merchandise spend &amp; inventory
        reconciliation only. Founder-gated view: spend-status distribution, merchandise-category
        scorecards, inventory-variance digest, root-cause pareto, and a high-risk spend queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Spend-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No gifting/merchandise spend rows logged yet."
          rowKey={(r, i) => String(r.spend_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Merchandise category scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => String(r.merchandise_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Event class &times; spend status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No campaigns by event class."
          rowKey={(r, i) => `${r.event_class}-${r.spend_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly spend trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA actions."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Inventory variance digest</h2>
        <DataTable
          rows={inventoryRows}
          columns={inventoryCols}
          emptyMessage="No inventory variance flagged."
          rowKey={(r, i) => `${r.campaign_name}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk spend queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk campaigns."
          rowKey={(r, i) => `${r.campaign_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
