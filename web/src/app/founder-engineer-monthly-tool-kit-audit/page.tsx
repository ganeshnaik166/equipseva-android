import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_items: number;
  engineers_audited: number;
  missing_items: number;
  overdue_calibration: number;
  damaged_items: number;
  total_replenish_cost_rupees: number;
};

type ByEngineer = {
  engineer_code: string;
  engineer_name: string;
  region: string;
  items_audited: number;
  missing_count: number;
  overdue_count: number;
  total_cost_rupees: number;
};

type CalRow = { calibration_status: string; item_count: number; estimated_cost_rupees: number };
type CondRow = { condition: string; item_count: number; pct_of_total: number };
type MissingRow = {
  engineer_code: string;
  engineer_name: string;
  kit_item: string;
  item_category: string;
  replenish_action: string;
  cost_estimate_rupees: number;
};
type QueueRow = {
  id: number;
  engineer_code: string;
  kit_item: string;
  order_status: string;
  vendor: string;
  expected_delivery_date: string | null;
  amount_rupees: number;
  priority: string;
};
type CatCost = { item_category: string; audit_count: number; total_cost_rupees: number };
type AuditRow = {
  id: number;
  engineer_code: string;
  engineer_name: string;
  region: string;
  kit_item: string;
  item_category: string;
  condition: string;
  calibration_status: string;
  missing_flag: boolean;
  replenish_action: string;
  cost_estimate_rupees: number;
};

function rupees(n: number) {
  return '₹' + (n ?? 0).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [ov, byEng, cal, cond, missing, queue, catCost, fullList] = await Promise.all([
    supabase.rpc('founder_r2686_kit_overview'),
    supabase.rpc('founder_r2686_kit_by_engineer'),
    supabase.rpc('founder_r2686_kit_calibration_status'),
    supabase.rpc('founder_r2686_kit_condition_breakdown'),
    supabase.rpc('founder_r2686_kit_missing_items'),
    supabase.rpc('founder_r2686_kit_replenish_queue'),
    supabase.rpc('founder_r2686_kit_category_costs'),
    supabase.rpc('founder_r2686_kit_full_audit_list'),
  ]);

  const overview: Overview = (ov.data?.[0] as Overview) ?? {
    total_items: 0,
    engineers_audited: 0,
    missing_items: 0,
    overdue_calibration: 0,
    damaged_items: 0,
    total_replenish_cost_rupees: 0,
  };
  const byEngineer: ByEngineer[] = (byEng.data as ByEngineer[]) ?? [];
  const calRows: CalRow[] = (cal.data as CalRow[]) ?? [];
  const condRows: CondRow[] = (cond.data as CondRow[]) ?? [];
  const missingRows: MissingRow[] = (missing.data as MissingRow[]) ?? [];
  const queueRows: QueueRow[] = (queue.data as QueueRow[]) ?? [];
  const catRows: CatCost[] = (catCost.data as CatCost[]) ?? [];
  const auditRows: AuditRow[] = (fullList.data as AuditRow[]) ?? [];

  return (
    <main className="mx-auto max-w-7xl px-6 py-8 space-y-8">
      <header className="space-y-2">
        <p className="text-xs uppercase tracking-wider text-slate-500">Round 2686 · Field Ops</p>
        <h1 className="text-3xl font-bold tracking-tight">Engineer Monthly Tool Kit Audit</h1>
        <p className="text-slate-600 max-w-2xl">
          Track every engineer's kit: condition, calibration status, missing items, and replenishment
          actions for the rolling month.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <Kpi label="Items audited" value={overview.total_items} />
        <Kpi label="Engineers" value={overview.engineers_audited} />
        <Kpi label="Missing" value={overview.missing_items} tone="warn" />
        <Kpi label="Overdue calibration" value={overview.overdue_calibration} tone="warn" />
        <Kpi label="Damaged" value={overview.damaged_items} tone="warn" />
        <Kpi label="Replenish cost" value={rupees(overview.total_replenish_cost_rupees)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">By engineer</h2>
        <DataTable<ByEngineer>
          rows={byEngineer}
          rowKey={(r, i) => String(r.engineer_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'region', header: 'Region', render: (r) => r.region },
            { key: 'items_audited', header: 'Items', render: (r) => r.items_audited },
            { key: 'missing_count', header: 'Missing', render: (r) => r.missing_count },
            { key: 'overdue_count', header: 'Overdue', render: (r) => r.overdue_count },
            { key: 'total_cost_rupees', header: 'Cost', render: (r) => rupees(r.total_cost_rupees) },
          ]}
        />
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div className="space-y-3">
          <h2 className="text-xl font-semibold">Calibration status</h2>
          <DataTable<CalRow>
            rows={calRows}
            rowKey={(r, i) => String(r.calibration_status ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'calibration_status', header: 'Status', render: (r) => r.calibration_status },
              { key: 'item_count', header: 'Items', render: (r) => r.item_count },
              { key: 'estimated_cost_rupees', header: 'Est. cost', render: (r) => rupees(r.estimated_cost_rupees) },
            ]}
          />
        </div>
        <div className="space-y-3">
          <h2 className="text-xl font-semibold">Condition mix</h2>
          <DataTable<CondRow>
            rows={condRows}
            rowKey={(r, i) => String(r.condition ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'condition', header: 'Condition', render: (r) => r.condition },
              { key: 'item_count', header: 'Count', render: (r) => r.item_count },
              { key: 'pct_of_total', header: 'Share %', render: (r) => `${r.pct_of_total}%` },
            ]}
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Missing / damaged items</h2>
        <DataTable<MissingRow>
          rows={missingRows}
          rowKey={(r, i) => String(`${r.engineer_code}-${r.kit_item}-${i}`)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'kit_item', header: 'Kit item', render: (r) => r.kit_item },
            { key: 'item_category', header: 'Category', render: (r) => r.item_category },
            { key: 'replenish_action', header: 'Action', render: (r) => r.replenish_action },
            { key: 'cost_estimate_rupees', header: 'Cost', render: (r) => rupees(r.cost_estimate_rupees) },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Replenish order queue</h2>
        <DataTable<QueueRow>
          rows={queueRows}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r) => r.engineer_code },
            { key: 'kit_item', header: 'Kit item', render: (r) => r.kit_item },
            { key: 'order_status', header: 'Status', render: (r) => r.order_status },
            { key: 'vendor', header: 'Vendor', render: (r) => r.vendor },
            { key: 'expected_delivery_date', header: 'ETA', render: (r) => r.expected_delivery_date ?? '-' },
            { key: 'amount_rupees', header: 'Amount', render: (r) => rupees(r.amount_rupees) },
            { key: 'priority', header: 'Priority', render: (r) => r.priority },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Category cost rollup</h2>
        <DataTable<CatCost>
          rows={catRows}
          rowKey={(r, i) => String(r.item_category ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'item_category', header: 'Category', render: (r) => r.item_category },
            { key: 'audit_count', header: 'Audits', render: (r) => r.audit_count },
            { key: 'total_cost_rupees', header: 'Total cost', render: (r) => rupees(r.total_cost_rupees) },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Full audit list</h2>
        <DataTable<AuditRow>
          rows={auditRows}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'region', header: 'Region', render: (r) => r.region },
            { key: 'kit_item', header: 'Item', render: (r) => r.kit_item },
            { key: 'item_category', header: 'Category', render: (r) => r.item_category },
            { key: 'condition', header: 'Condition', render: (r) => r.condition },
            { key: 'calibration_status', header: 'Calibration', render: (r) => r.calibration_status },
            { key: 'missing_flag', header: 'Missing?', render: (r) => (r.missing_flag ? 'yes' : 'no') },
            { key: 'replenish_action', header: 'Action', render: (r) => r.replenish_action },
            { key: 'cost_estimate_rupees', header: 'Cost', render: (r) => rupees(r.cost_estimate_rupees) },
          ]}
        />
      </section>
    </main>
  );
}

function Kpi({ label, value, tone }: { label: string; value: number | string; tone?: 'warn' }) {
  const toneClass = tone === 'warn' ? 'text-amber-700' : 'text-slate-900';
  return (
    <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
      <p className="text-xs uppercase tracking-wider text-slate-500">{label}</p>
      <p className={`mt-1 text-2xl font-semibold ${toneClass}`}>{value}</p>
    </div>
  );
}
