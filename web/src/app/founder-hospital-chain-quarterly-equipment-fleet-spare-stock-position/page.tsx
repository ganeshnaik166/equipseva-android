import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_chains: number;
  total_skus: number;
  total_stock_value_rupees: number;
  critical_risk_count: number;
  reorder_now_count: number;
  avg_days_of_cover: number;
};

type StockRow = {
  id: string;
  quarter_label: string;
  chain_name: string;
  hospital_count: number;
  asset_family: string;
  asset_count: number;
  spare_sku: string;
  spare_sku_name: string;
  on_hand_units: number;
  reserved_units: number;
  available_units: number;
  quarterly_consumption_units: number;
  consumption_velocity_per_month: number;
  reorder_threshold_units: number;
  reorder_qty_units: number;
  unit_cost_rupees: number;
  stock_value_rupees: number;
  days_of_cover_estimate: number;
  stockout_risk: string;
  outcome_status: string;
};

type ChainRow = {
  chain_name: string;
  sku_count: number;
  total_on_hand: number;
  total_stock_value_rupees: number;
  critical_risk_count: number;
  avg_days_of_cover: number;
};

type AssetFamilyRow = {
  asset_family: string;
  sku_count: number;
  total_assets: number;
  total_consumption_units: number;
  total_stock_value_rupees: number;
};

type ReorderRow = {
  id: string;
  quarter_label: string;
  chain_name: string;
  spare_sku: string;
  reorder_event_at: string;
  qty_ordered: number;
  qty_delivered: number;
  lead_time_days: number;
  supplier_name: string;
  unit_cost_rupees: number;
  total_cost_rupees: number;
  outcome: string;
  downtime_hours_avoided: number;
  notes: string | null;
};

type OutcomeSummaryRow = {
  outcome: string;
  event_count: number;
  total_qty_ordered: number;
  total_qty_delivered: number;
  avg_lead_time_days: number;
  total_cost_rupees: number;
  total_downtime_hours_avoided: number;
};

type SupplierRow = {
  supplier_name: string;
  reorder_count: number;
  total_cost_rupees: number;
  avg_lead_time_days: number;
  on_time_count: number;
  late_count: number;
  total_downtime_hours_avoided: number;
};

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return 'Rs 0';
  return 'Rs ' + Number(n).toLocaleString('en-IN', { maximumFractionDigits: 0 });
}

function num(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0';
  return Number(n).toLocaleString('en-IN', { maximumFractionDigits: 2 });
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, stockRes, chainsRes, familiesRes, risksRes, reordersRes, summaryRes, suppliersRes] =
    await Promise.all([
      supabase.rpc('founder_chain_fleet_spare_stock_kpis_r2863'),
      supabase.rpc('founder_chain_fleet_spare_stock_list_r2863'),
      supabase.rpc('founder_chain_fleet_spare_by_chain_r2863'),
      supabase.rpc('founder_chain_fleet_spare_by_asset_family_r2863'),
      supabase.rpc('founder_chain_fleet_spare_stockout_risks_r2863'),
      supabase.rpc('founder_chain_fleet_spare_reorder_outcomes_r2863'),
      supabase.rpc('founder_chain_fleet_spare_reorder_outcome_summary_r2863'),
      supabase.rpc('founder_chain_fleet_spare_supplier_performance_r2863'),
    ]);

  const kpis: Kpis = (kpisRes.data?.[0] as Kpis) ?? {
    total_chains: 0,
    total_skus: 0,
    total_stock_value_rupees: 0,
    critical_risk_count: 0,
    reorder_now_count: 0,
    avg_days_of_cover: 0,
  };
  const stock: StockRow[] = (stockRes.data as StockRow[]) ?? [];
  const chains: ChainRow[] = (chainsRes.data as ChainRow[]) ?? [];
  const families: AssetFamilyRow[] = (familiesRes.data as AssetFamilyRow[]) ?? [];
  const risks: StockRow[] = (risksRes.data as StockRow[]) ?? [];
  const reorders: ReorderRow[] = (reordersRes.data as ReorderRow[]) ?? [];
  const summary: OutcomeSummaryRow[] = (summaryRes.data as OutcomeSummaryRow[]) ?? [];
  const suppliers: SupplierRow[] = (suppliersRes.data as SupplierRow[]) ?? [];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-3xl font-bold tracking-tight">
          Hospital Chain Quarterly Equipment Fleet Spare Stock Position
        </h1>
        <p className="text-sm text-muted-foreground">
          Chain × asset × spare SKU × on-hand × consumption × reorder × outcome
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-6">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-muted-foreground">Total Chains</div>
          <div className="mt-1 text-2xl font-semibold">{kpis.total_chains}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-muted-foreground">Total SKUs</div>
          <div className="mt-1 text-2xl font-semibold">{kpis.total_skus}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-muted-foreground">Stock Value</div>
          <div className="mt-1 text-2xl font-semibold">{rupees(kpis.total_stock_value_rupees)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-muted-foreground">Critical Risk</div>
          <div className="mt-1 text-2xl font-semibold text-red-600">{kpis.critical_risk_count}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-muted-foreground">Reorder Now</div>
          <div className="mt-1 text-2xl font-semibold text-amber-600">{kpis.reorder_now_count}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-muted-foreground">Avg Days Cover</div>
          <div className="mt-1 text-2xl font-semibold">{num(kpis.avg_days_of_cover)}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">By Chain</h2>
        <DataTable
          rows={chains}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ChainRow) => r.chain_name },
            { key: 'sku_count', header: 'SKUs', render: (r: ChainRow) => r.sku_count },
            { key: 'total_on_hand', header: 'On Hand', render: (r: ChainRow) => num(r.total_on_hand) },
            {
              key: 'total_stock_value_rupees',
              header: 'Stock Value',
              render: (r: ChainRow) => rupees(r.total_stock_value_rupees),
            },
            {
              key: 'critical_risk_count',
              header: 'Critical',
              render: (r: ChainRow) => r.critical_risk_count,
            },
            {
              key: 'avg_days_of_cover',
              header: 'Avg Days Cover',
              render: (r: ChainRow) => num(r.avg_days_of_cover),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: ChainRow, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">By Asset Family</h2>
        <DataTable
          rows={families}
          columns={[
            { key: 'asset_family', header: 'Asset Family', render: (r: AssetFamilyRow) => r.asset_family },
            { key: 'sku_count', header: 'SKUs', render: (r: AssetFamilyRow) => r.sku_count },
            {
              key: 'total_assets',
              header: 'Assets',
              render: (r: AssetFamilyRow) => num(r.total_assets),
            },
            {
              key: 'total_consumption_units',
              header: 'Qtrly Consumption',
              render: (r: AssetFamilyRow) => num(r.total_consumption_units),
            },
            {
              key: 'total_stock_value_rupees',
              header: 'Stock Value',
              render: (r: AssetFamilyRow) => rupees(r.total_stock_value_rupees),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: AssetFamilyRow, i: number) => String(r.asset_family ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Stockout Risks (high & critical)</h2>
        <DataTable
          rows={risks}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: StockRow) => r.chain_name },
            { key: 'asset_family', header: 'Asset', render: (r: StockRow) => r.asset_family },
            { key: 'spare_sku_name', header: 'SKU', render: (r: StockRow) => r.spare_sku_name },
            {
              key: 'available_units',
              header: 'Available',
              render: (r: StockRow) => r.available_units,
            },
            {
              key: 'days_of_cover_estimate',
              header: 'Days Cover',
              render: (r: StockRow) => r.days_of_cover_estimate,
            },
            { key: 'stockout_risk', header: 'Risk', render: (r: StockRow) => r.stockout_risk },
            { key: 'outcome_status', header: 'Outcome', render: (r: StockRow) => r.outcome_status },
          ]}
          emptyMessage="No data"
          rowKey={(r: StockRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Full Stock Position</h2>
        <DataTable
          rows={stock}
          columns={[
            { key: 'quarter_label', header: 'Quarter', render: (r: StockRow) => r.quarter_label },
            { key: 'chain_name', header: 'Chain', render: (r: StockRow) => r.chain_name },
            { key: 'asset_family', header: 'Asset', render: (r: StockRow) => r.asset_family },
            { key: 'spare_sku_name', header: 'SKU', render: (r: StockRow) => r.spare_sku_name },
            {
              key: 'on_hand_units',
              header: 'On Hand',
              render: (r: StockRow) => r.on_hand_units,
            },
            {
              key: 'quarterly_consumption_units',
              header: 'Q Consumption',
              render: (r: StockRow) => r.quarterly_consumption_units,
            },
            {
              key: 'reorder_threshold_units',
              header: 'Reorder At',
              render: (r: StockRow) => r.reorder_threshold_units,
            },
            {
              key: 'stock_value_rupees',
              header: 'Value',
              render: (r: StockRow) => rupees(r.stock_value_rupees),
            },
            { key: 'stockout_risk', header: 'Risk', render: (r: StockRow) => r.stockout_risk },
            { key: 'outcome_status', header: 'Status', render: (r: StockRow) => r.outcome_status },
          ]}
          emptyMessage="No data"
          rowKey={(r: StockRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Reorder Outcomes</h2>
        <DataTable
          rows={reorders}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ReorderRow) => r.chain_name },
            { key: 'spare_sku', header: 'SKU', render: (r: ReorderRow) => r.spare_sku },
            { key: 'supplier_name', header: 'Supplier', render: (r: ReorderRow) => r.supplier_name },
            {
              key: 'qty_ordered',
              header: 'Qty Ordered',
              render: (r: ReorderRow) => r.qty_ordered,
            },
            {
              key: 'qty_delivered',
              header: 'Qty Delivered',
              render: (r: ReorderRow) => r.qty_delivered,
            },
            {
              key: 'lead_time_days',
              header: 'Lead (days)',
              render: (r: ReorderRow) => r.lead_time_days,
            },
            {
              key: 'total_cost_rupees',
              header: 'Cost',
              render: (r: ReorderRow) => rupees(r.total_cost_rupees),
            },
            { key: 'outcome', header: 'Outcome', render: (r: ReorderRow) => r.outcome },
            {
              key: 'downtime_hours_avoided',
              header: 'Downtime Avoided (h)',
              render: (r: ReorderRow) => r.downtime_hours_avoided,
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: ReorderRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Outcome Summary</h2>
        <DataTable
          rows={summary}
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r: OutcomeSummaryRow) => r.outcome },
            {
              key: 'event_count',
              header: 'Events',
              render: (r: OutcomeSummaryRow) => r.event_count,
            },
            {
              key: 'total_qty_ordered',
              header: 'Qty Ordered',
              render: (r: OutcomeSummaryRow) => num(r.total_qty_ordered),
            },
            {
              key: 'total_qty_delivered',
              header: 'Qty Delivered',
              render: (r: OutcomeSummaryRow) => num(r.total_qty_delivered),
            },
            {
              key: 'avg_lead_time_days',
              header: 'Avg Lead (d)',
              render: (r: OutcomeSummaryRow) => num(r.avg_lead_time_days),
            },
            {
              key: 'total_cost_rupees',
              header: 'Total Cost',
              render: (r: OutcomeSummaryRow) => rupees(r.total_cost_rupees),
            },
            {
              key: 'total_downtime_hours_avoided',
              header: 'Downtime Avoided',
              render: (r: OutcomeSummaryRow) => r.total_downtime_hours_avoided,
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeSummaryRow, i: number) => String(r.outcome ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Supplier Performance</h2>
        <DataTable
          rows={suppliers}
          columns={[
            { key: 'supplier_name', header: 'Supplier', render: (r: SupplierRow) => r.supplier_name },
            {
              key: 'reorder_count',
              header: 'Orders',
              render: (r: SupplierRow) => r.reorder_count,
            },
            {
              key: 'total_cost_rupees',
              header: 'Total Cost',
              render: (r: SupplierRow) => rupees(r.total_cost_rupees),
            },
            {
              key: 'avg_lead_time_days',
              header: 'Avg Lead (d)',
              render: (r: SupplierRow) => num(r.avg_lead_time_days),
            },
            {
              key: 'on_time_count',
              header: 'On Time',
              render: (r: SupplierRow) => r.on_time_count,
            },
            { key: 'late_count', header: 'Late', render: (r: SupplierRow) => r.late_count },
            {
              key: 'total_downtime_hours_avoided',
              header: 'Downtime Avoided (h)',
              render: (r: SupplierRow) => r.total_downtime_hours_avoided,
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: SupplierRow, i: number) => String(r.supplier_name ?? i)}
        />
      </section>
    </main>
  );
}
