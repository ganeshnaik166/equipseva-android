import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  tracked_assets: number;
  total_lcc_rupees: number;
  avg_monthly_lcc_rupees: number;
  replace_or_retire: number;
  refurbish: number;
  healthy_keep: number;
  est_resale_pool_rupees: number;
};

type LedgerRow = {
  id: string;
  customer_org_name: string;
  equipment_name: string;
  equipment_category: string;
  install_date: string;
  expected_life_months: number;
  age_months: number;
  purchase_price_rupees: number;
  cumulative_ops_cost_rupees: number;
  cumulative_maintenance_cost_rupees: number;
  estimated_resale_rupees: number;
  total_lcc_rupees: number;
  monthly_lcc_rupees: number;
  decision_band: string;
};

type SnapshotRow = {
  id: string;
  equipment_name: string;
  customer_org_name: string;
  snapshot_month: string;
  ops_cost_rupees: number;
  maintenance_cost_rupees: number;
  downtime_hours: number;
  revenue_loss_rupees: number;
  resale_estimate_rupees: number;
  recommended_action: string;
  note: string | null;
};

type CategoryRow = {
  equipment_category: string;
  assets: number;
  total_lcc_rupees: number;
  avg_monthly_lcc_rupees: number;
  replace_or_retire: number;
};

type CandidateRow = {
  equipment_name: string;
  customer_org_name: string;
  age_months: number;
  expected_life_months: number;
  monthly_lcc_rupees: number;
  decision_band: string;
};

type AgeRow = {
  age_bucket: string;
  assets: number;
  avg_monthly_lcc_rupees: number;
};

type DowntimeRow = {
  equipment_name: string;
  customer_org_name: string;
  total_downtime_hours: number;
  total_revenue_loss_rupees: number;
};

function inr(value: number | null | undefined): string {
  const n = Number(value ?? 0);
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  }).format(n);
}

function num(value: number | null | undefined): string {
  return new Intl.NumberFormat('en-IN').format(Number(value ?? 0));
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, ledgerRes, snapshotsRes, byCatRes, candidatesRes, ageRes, downtimeRes] =
    await Promise.all([
      supabase.rpc('founder_r2780_lcc_kpis'),
      supabase.rpc('founder_r2780_list_ledger'),
      supabase.rpc('founder_r2780_list_snapshots'),
      supabase.rpc('founder_r2780_by_category'),
      supabase.rpc('founder_r2780_top_replace_candidates'),
      supabase.rpc('founder_r2780_age_distribution'),
      supabase.rpc('founder_r2780_downtime_leaders'),
    ]);

  const kpis: Kpis = (kpisRes.data?.[0] ?? {
    tracked_assets: 0,
    total_lcc_rupees: 0,
    avg_monthly_lcc_rupees: 0,
    replace_or_retire: 0,
    refurbish: 0,
    healthy_keep: 0,
    est_resale_pool_rupees: 0,
  }) as Kpis;

  const ledger: LedgerRow[] = (ledgerRes.data ?? []) as LedgerRow[];
  const snapshots: SnapshotRow[] = (snapshotsRes.data ?? []) as SnapshotRow[];
  const byCat: CategoryRow[] = (byCatRes.data ?? []) as CategoryRow[];
  const candidates: CandidateRow[] = (candidatesRes.data ?? []) as CandidateRow[];
  const ages: AgeRow[] = (ageRes.data ?? []) as AgeRow[];
  const downtime: DowntimeRow[] = (downtimeRes.data ?? []) as DowntimeRow[];

  const ledgerCols = [
    { key: 'equipment_name', header: 'Equipment', render: (r: LedgerRow) => r.equipment_name },
    { key: 'customer_org_name', header: 'Customer', render: (r: LedgerRow) => r.customer_org_name },
    { key: 'equipment_category', header: 'Category', render: (r: LedgerRow) => r.equipment_category },
    { key: 'age', header: 'Age / Life (mo)', render: (r: LedgerRow) => `${r.age_months} / ${r.expected_life_months}` },
    { key: 'purchase_price_rupees', header: 'Purchase', render: (r: LedgerRow) => inr(r.purchase_price_rupees) },
    { key: 'cumulative_ops_cost_rupees', header: 'Ops', render: (r: LedgerRow) => inr(r.cumulative_ops_cost_rupees) },
    { key: 'cumulative_maintenance_cost_rupees', header: 'Maint', render: (r: LedgerRow) => inr(r.cumulative_maintenance_cost_rupees) },
    { key: 'estimated_resale_rupees', header: 'Resale', render: (r: LedgerRow) => inr(r.estimated_resale_rupees) },
    { key: 'total_lcc_rupees', header: 'Total LCC', render: (r: LedgerRow) => inr(r.total_lcc_rupees) },
    { key: 'monthly_lcc_rupees', header: 'Monthly LCC', render: (r: LedgerRow) => inr(r.monthly_lcc_rupees) },
    { key: 'decision_band', header: 'Decision', render: (r: LedgerRow) => r.decision_band },
  ];

  const snapshotCols = [
    { key: 'snapshot_month', header: 'Month', render: (r: SnapshotRow) => r.snapshot_month },
    { key: 'equipment_name', header: 'Equipment', render: (r: SnapshotRow) => r.equipment_name },
    { key: 'customer_org_name', header: 'Customer', render: (r: SnapshotRow) => r.customer_org_name },
    { key: 'ops_cost_rupees', header: 'Ops', render: (r: SnapshotRow) => inr(r.ops_cost_rupees) },
    { key: 'maintenance_cost_rupees', header: 'Maint', render: (r: SnapshotRow) => inr(r.maintenance_cost_rupees) },
    { key: 'downtime_hours', header: 'Downtime (h)', render: (r: SnapshotRow) => num(r.downtime_hours) },
    { key: 'revenue_loss_rupees', header: 'Rev Loss', render: (r: SnapshotRow) => inr(r.revenue_loss_rupees) },
    { key: 'resale_estimate_rupees', header: 'Resale Est', render: (r: SnapshotRow) => inr(r.resale_estimate_rupees) },
    { key: 'recommended_action', header: 'Action', render: (r: SnapshotRow) => r.recommended_action },
    { key: 'note', header: 'Note', render: (r: SnapshotRow) => r.note ?? '' },
  ];

  const catCols = [
    { key: 'equipment_category', header: 'Category', render: (r: CategoryRow) => r.equipment_category },
    { key: 'assets', header: 'Assets', render: (r: CategoryRow) => num(r.assets) },
    { key: 'total_lcc_rupees', header: 'Total LCC', render: (r: CategoryRow) => inr(r.total_lcc_rupees) },
    { key: 'avg_monthly_lcc_rupees', header: 'Avg Monthly LCC', render: (r: CategoryRow) => inr(r.avg_monthly_lcc_rupees) },
    { key: 'replace_or_retire', header: 'Replace/Retire', render: (r: CategoryRow) => num(r.replace_or_retire) },
  ];

  const candidateCols = [
    { key: 'equipment_name', header: 'Equipment', render: (r: CandidateRow) => r.equipment_name },
    { key: 'customer_org_name', header: 'Customer', render: (r: CandidateRow) => r.customer_org_name },
    { key: 'age', header: 'Age / Life (mo)', render: (r: CandidateRow) => `${r.age_months} / ${r.expected_life_months}` },
    { key: 'monthly_lcc_rupees', header: 'Monthly LCC', render: (r: CandidateRow) => inr(r.monthly_lcc_rupees) },
    { key: 'decision_band', header: 'Decision', render: (r: CandidateRow) => r.decision_band },
  ];

  const ageCols = [
    { key: 'age_bucket', header: 'Age Bucket', render: (r: AgeRow) => r.age_bucket },
    { key: 'assets', header: 'Assets', render: (r: AgeRow) => num(r.assets) },
    { key: 'avg_monthly_lcc_rupees', header: 'Avg Monthly LCC', render: (r: AgeRow) => inr(r.avg_monthly_lcc_rupees) },
  ];

  const downtimeCols = [
    { key: 'equipment_name', header: 'Equipment', render: (r: DowntimeRow) => r.equipment_name },
    { key: 'customer_org_name', header: 'Customer', render: (r: DowntimeRow) => r.customer_org_name },
    { key: 'total_downtime_hours', header: 'Downtime (h)', render: (r: DowntimeRow) => num(r.total_downtime_hours) },
    { key: 'total_revenue_loss_rupees', header: 'Revenue Loss', render: (r: DowntimeRow) => inr(r.total_revenue_loss_rupees) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Customer Monthly Equipment Life-Cycle Cost Tracking</h1>
        <p className="text-sm text-gray-600">
          Track purchase, ops, maintenance & resale to derive total LCC and keep / refurbish / replace / retire decisions per asset.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Tracked Assets</div>
          <div className="text-xl font-semibold">{num(kpis.tracked_assets)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Total LCC</div>
          <div className="text-xl font-semibold">{inr(kpis.total_lcc_rupees)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Avg Monthly LCC</div>
          <div className="text-xl font-semibold">{inr(kpis.avg_monthly_lcc_rupees)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Replace / Retire</div>
          <div className="text-xl font-semibold">{num(kpis.replace_or_retire)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Refurbish</div>
          <div className="text-xl font-semibold">{num(kpis.refurbish)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Healthy (Keep + Monitor)</div>
          <div className="text-xl font-semibold">{num(kpis.healthy_keep)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Estimated Resale Pool</div>
          <div className="text-xl font-semibold">{inr(kpis.est_resale_pool_rupees)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Decision Rule</div>
          <div className="text-xs">
            Age &gt;= life =&gt; retire; monthly LCC &gt; 1.5x straight-line =&gt; replace; age &gt;= 75% life =&gt; refurbish.
          </div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Equipment LCC Ledger</h2>
        <DataTable
          rows={ledger}
          columns={ledgerCols}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Monthly Snapshots</h2>
        <DataTable
          rows={snapshots}
          columns={snapshotCols}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">By Category</h2>
        <DataTable
          rows={byCat}
          columns={catCols}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.equipment_category ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top Replace / Retire Candidates</h2>
        <DataTable
          rows={candidates}
          columns={candidateCols}
          emptyMessage="No data"
          rowKey={(r, i) => String(`${r.equipment_name}-${i}`)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Age Distribution</h2>
        <DataTable
          rows={ages}
          columns={ageCols}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.age_bucket ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Downtime Leaders</h2>
        <DataTable
          rows={downtime}
          columns={downtimeCols}
          emptyMessage="No data"
          rowKey={(r, i) => String(`${r.equipment_name}-${i}`)}
        />
      </section>
    </div>
  );
}
