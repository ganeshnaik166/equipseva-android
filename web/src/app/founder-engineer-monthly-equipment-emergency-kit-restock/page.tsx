import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_engineers: number;
  critical_kits: number;
  depleted_kits: number;
  watch_kits: number;
  healthy_kits: number;
  avg_fill_pct: number;
  total_stockouts: number;
  total_restock_budget_rupees: number;
};

type Engineer = {
  id: string;
  engineer_code: string;
  engineer_name: string;
  city: string;
  kit_tier: string;
  kit_capacity_items: number;
  current_fill_pct: number;
  monthly_restock_budget_rupees: number;
  restock_cadence_days: number;
  jobs_handled_last_30d: number;
  stockout_incidents_last_30d: number;
  verdict: string;
  next_audit_due: string;
  notes: string | null;
};

type Stockout = {
  engineer_code: string;
  engineer_name: string;
  city: string;
  stockout_items: number;
  total_consumed: number;
  worst_item: string | null;
  verdict: string;
};

type Item = {
  id: string;
  engineer_code: string;
  item_sku: string;
  item_name: string;
  item_category: string;
  par_qty: number;
  on_hand_qty: number;
  consumed_last_30d: number;
  unit_cost_rupees: number;
  restock_qty_due: number;
  stockout_flag: boolean;
  consumption_verdict: string;
};

type CategoryCost = {
  item_category: string;
  items_tracked: number;
  total_restock_qty: number;
  total_restock_cost_rupees: number;
  stockout_count: number;
};

type Cadence = {
  engineer_code: string;
  engineer_name: string;
  city: string;
  last_audit_date: string;
  next_audit_due: string;
  days_until_due: number;
  cadence_status: string;
};

type Spike = {
  engineer_code: string;
  item_sku: string;
  item_name: string;
  par_qty: number;
  on_hand_qty: number;
  consumed_last_30d: number;
  burn_rate_pct: number;
  unit_cost_rupees: number;
  consumption_verdict: string;
};

type VerdictMix = {
  verdict: string;
  engineer_count: number;
  avg_fill_pct: number;
  total_budget_rupees: number;
  total_jobs: number;
};

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '₹0';
  return '₹' + n.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, rosterRes, stockoutRes, itemsRes, categoryRes, cadenceRes, spikeRes, mixRes] = await Promise.all([
    supabase.rpc('founder_r2774_kit_kpi'),
    supabase.rpc('founder_r2774_engineer_roster'),
    supabase.rpc('founder_r2774_stockout_offenders'),
    supabase.rpc('founder_r2774_item_ledger'),
    supabase.rpc('founder_r2774_restock_cost_by_category'),
    supabase.rpc('founder_r2774_cadence_audit'),
    supabase.rpc('founder_r2774_spike_items'),
    supabase.rpc('founder_r2774_verdict_mix'),
  ]);

  const kpi: Kpi | null = (kpiRes.data?.[0] as Kpi) ?? null;
  const roster: Engineer[] = (rosterRes.data as Engineer[]) ?? [];
  const stockouts: Stockout[] = (stockoutRes.data as Stockout[]) ?? [];
  const items: Item[] = (itemsRes.data as Item[]) ?? [];
  const categories: CategoryCost[] = (categoryRes.data as CategoryCost[]) ?? [];
  const cadence: Cadence[] = (cadenceRes.data as Cadence[]) ?? [];
  const spikes: Spike[] = (spikeRes.data as Spike[]) ?? [];
  const mix: VerdictMix[] = (mixRes.data as VerdictMix[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Equipment Emergency Kit Restock</h1>
        <p className="text-sm text-gray-600">
          Kit × item × consumption × restock × cost × cadence × verdict
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Engineers</div>
          <div className="text-2xl font-bold">{kpi?.total_engineers ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Critical Kits</div>
          <div className="text-2xl font-bold text-red-700">{kpi?.critical_kits ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Depleted</div>
          <div className="text-2xl font-bold text-orange-700">{kpi?.depleted_kits ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Watch</div>
          <div className="text-2xl font-bold text-amber-600">{kpi?.watch_kits ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Healthy</div>
          <div className="text-2xl font-bold text-emerald-700">{kpi?.healthy_kits ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Avg Fill %</div>
          <div className="text-2xl font-bold">{kpi?.avg_fill_pct ?? 0}%</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Stockouts 30d</div>
          <div className="text-2xl font-bold">{kpi?.total_stockouts ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Monthly Budget</div>
          <div className="text-2xl font-bold">{rupees(kpi?.total_restock_budget_rupees ?? 0)}</div>
        </div>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Engineer Kit Roster</h2>
        <DataTable<Engineer>
          rows={roster}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No engineers"
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'city', header: 'City', render: (r) => r.city },
            { key: 'kit_tier', header: 'Tier', render: (r) => r.kit_tier },
            { key: 'kit_capacity_items', header: 'Capacity', render: (r) => r.kit_capacity_items },
            { key: 'current_fill_pct', header: 'Fill %', render: (r) => r.current_fill_pct + '%' },
            { key: 'jobs_handled_last_30d', header: 'Jobs 30d', render: (r) => r.jobs_handled_last_30d },
            { key: 'stockout_incidents_last_30d', header: 'Stockouts', render: (r) => r.stockout_incidents_last_30d },
            { key: 'monthly_restock_budget_rupees', header: 'Budget', render: (r) => rupees(r.monthly_restock_budget_rupees) },
            { key: 'next_audit_due', header: 'Next Audit', render: (r) => r.next_audit_due },
            { key: 'verdict', header: 'Verdict', render: (r) => r.verdict },
          ]}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Stockout Offenders</h2>
        <DataTable<Stockout>
          rows={stockouts}
          rowKey={(r, i) => String(r.engineer_code ?? i)}
          emptyMessage="No stockout offenders"
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'city', header: 'City', render: (r) => r.city },
            { key: 'stockout_items', header: 'Stockout Items', render: (r) => r.stockout_items },
            { key: 'total_consumed', header: 'Total Consumed', render: (r) => r.total_consumed },
            { key: 'worst_item', header: 'Worst Item', render: (r) => r.worst_item ?? '-' },
            { key: 'verdict', header: 'Verdict', render: (r) => r.verdict },
          ]}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Item Consumption Ledger</h2>
        <DataTable<Item>
          rows={items}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No items"
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
            { key: 'item_sku', header: 'SKU', render: (r) => r.item_sku },
            { key: 'item_name', header: 'Item', render: (r) => r.item_name },
            { key: 'item_category', header: 'Category', render: (r) => r.item_category },
            { key: 'par_qty', header: 'Par', render: (r) => r.par_qty },
            { key: 'on_hand_qty', header: 'On Hand', render: (r) => r.on_hand_qty },
            { key: 'consumed_last_30d', header: 'Used 30d', render: (r) => r.consumed_last_30d },
            { key: 'restock_qty_due', header: 'Restock Due', render: (r) => r.restock_qty_due },
            { key: 'unit_cost_rupees', header: 'Unit Cost', render: (r) => rupees(r.unit_cost_rupees) },
            { key: 'stockout_flag', header: 'Stockout?', render: (r) => (r.stockout_flag ? 'YES' : 'no') },
            { key: 'consumption_verdict', header: 'Verdict', render: (r) => r.consumption_verdict },
          ]}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Restock Cost by Category</h2>
        <DataTable<CategoryCost>
          rows={categories}
          rowKey={(r, i) => String(r.item_category ?? i)}
          emptyMessage="No categories"
          columns={[
            { key: 'item_category', header: 'Category', render: (r) => r.item_category },
            { key: 'items_tracked', header: 'Items', render: (r) => r.items_tracked },
            { key: 'total_restock_qty', header: 'Restock Qty', render: (r) => r.total_restock_qty },
            { key: 'total_restock_cost_rupees', header: 'Restock Cost', render: (r) => rupees(r.total_restock_cost_rupees) },
            { key: 'stockout_count', header: 'Stockouts', render: (r) => r.stockout_count },
          ]}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Cadence Audit</h2>
        <DataTable<Cadence>
          rows={cadence}
          rowKey={(r, i) => String(r.engineer_code ?? i)}
          emptyMessage="No cadence rows"
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'city', header: 'City', render: (r) => r.city },
            { key: 'last_audit_date', header: 'Last Audit', render: (r) => r.last_audit_date },
            { key: 'next_audit_due', header: 'Next Audit', render: (r) => r.next_audit_due },
            { key: 'days_until_due', header: 'Days Until', render: (r) => r.days_until_due },
            { key: 'cadence_status', header: 'Status', render: (r) => r.cadence_status },
          ]}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Spike / Elevated Items</h2>
        <DataTable<Spike>
          rows={spikes}
          rowKey={(r, i) => String((r.engineer_code ?? '') + (r.item_sku ?? '') + i)}
          emptyMessage="No spike items"
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
            { key: 'item_sku', header: 'SKU', render: (r) => r.item_sku },
            { key: 'item_name', header: 'Item', render: (r) => r.item_name },
            { key: 'par_qty', header: 'Par', render: (r) => r.par_qty },
            { key: 'on_hand_qty', header: 'On Hand', render: (r) => r.on_hand_qty },
            { key: 'consumed_last_30d', header: 'Used 30d', render: (r) => r.consumed_last_30d },
            { key: 'burn_rate_pct', header: 'Burn %', render: (r) => r.burn_rate_pct + '%' },
            { key: 'unit_cost_rupees', header: 'Unit Cost', render: (r) => rupees(r.unit_cost_rupees) },
            { key: 'consumption_verdict', header: 'Verdict', render: (r) => r.consumption_verdict },
          ]}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Verdict Mix</h2>
        <DataTable<VerdictMix>
          rows={mix}
          rowKey={(r, i) => String(r.verdict ?? i)}
          emptyMessage="No verdict rollup"
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r) => r.verdict },
            { key: 'engineer_count', header: 'Engineers', render: (r) => r.engineer_count },
            { key: 'avg_fill_pct', header: 'Avg Fill %', render: (r) => r.avg_fill_pct + '%' },
            { key: 'total_budget_rupees', header: 'Budget', render: (r) => rupees(r.total_budget_rupees) },
            { key: 'total_jobs', header: 'Jobs 30d', render: (r) => r.total_jobs },
          ]}
        />
      </section>
    </div>
  );
}