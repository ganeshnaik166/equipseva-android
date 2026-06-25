import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_equipment: number;
  total_invested_rupees: number;
  total_revenue_rupees: number;
  weighted_roi_percent: number;
  avg_utilization_percent: number;
  underperformers: number;
};

type RoiRow = {
  id: string;
  customer_org_name: string;
  equipment_label: string;
  equipment_category: string;
  fiscal_quarter: string;
  purchase_cost_rupees: number;
  revenue_generated_rupees: number;
  roi_percent: number;
  utilization_percent: number;
  payback_months: number | null;
};

type CategoryRow = {
  equipment_category: string;
  units: number;
  invested_rupees: number;
  revenue_rupees: number;
  avg_roi_percent: number;
  avg_downtime_hours: number;
};

type UnderRow = {
  id: string;
  customer_org_name: string;
  equipment_label: string;
  roi_percent: number;
  utilization_percent: number;
  downtime_hours: number;
  payback_months: number | null;
};

type CustomerRow = {
  customer_org_name: string;
  units: number;
  total_invested_rupees: number;
  total_revenue_rupees: number;
  avg_roi_percent: number;
};

type DecisionRow = {
  id: string;
  customer_org_name: string;
  equipment_label: string;
  decision: string;
  decided_by_role: string;
  rationale: string;
  estimated_savings_rupees: number;
  approval_status: string;
  effective_from: string;
};

type DecisionMixRow = {
  decision: string;
  units: number;
  estimated_savings_rupees: number;
};

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return '₹' + (n / 100000).toFixed(1) + 'L';
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return n.toFixed(1) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, listRes, catRes, underRes, custRes, decRes, mixRes] = await Promise.all([
    supabase.rpc('roi_r2676_portfolio_kpis'),
    supabase.rpc('roi_r2676_list_by_roi'),
    supabase.rpc('roi_r2676_category_rollup'),
    supabase.rpc('roi_r2676_underperformers'),
    supabase.rpc('roi_r2676_customer_summary'),
    supabase.rpc('roi_r2676_decisions_list'),
    supabase.rpc('roi_r2676_decision_mix'),
  ]);

  const kpis: Kpis | null = (kpisRes.data?.[0] as Kpis) ?? null;
  const rows: RoiRow[] = (listRes.data as RoiRow[]) ?? [];
  const cats: CategoryRow[] = (catRes.data as CategoryRow[]) ?? [];
  const under: UnderRow[] = (underRes.data as UnderRow[]) ?? [];
  const customers: CustomerRow[] = (custRes.data as CustomerRow[]) ?? [];
  const decisions: DecisionRow[] = (decRes.data as DecisionRow[]) ?? [];
  const mix: DecisionMixRow[] = (mixRes.data as DecisionMixRow[]) ?? [];

  return (
    <main className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-semibold">Customer Quarterly Equipment ROI Justification</h1>
        <p className="text-sm text-gray-600 mt-1">
          Equipment × cost × utilization × revenue × ROI — keep / replace / divest decisions
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        <KpiCard label="Equipment units" value={String(kpis?.total_equipment ?? 0)} />
        <KpiCard label="Total invested" value={fmtRupees(kpis?.total_invested_rupees ?? 0)} />
        <KpiCard label="Revenue generated" value={fmtRupees(kpis?.total_revenue_rupees ?? 0)} />
        <KpiCard label="Avg ROI" value={fmtPct(kpis?.weighted_roi_percent)} />
        <KpiCard label="Avg utilization" value={fmtPct(kpis?.avg_utilization_percent)} />
        <KpiCard label="Underperformers (ROI < 40%)" value={String(kpis?.underperformers ?? 0)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Equipment ROI ranking</h2>
        <DataTable
          rows={rows}
          rowKey={(r, i) => String((r as RoiRow).id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: RoiRow) => r.customer_org_name },
            { key: 'equipment_label', header: 'Equipment', render: (r: RoiRow) => r.equipment_label },
            { key: 'equipment_category', header: 'Category', render: (r: RoiRow) => r.equipment_category },
            { key: 'fiscal_quarter', header: 'Quarter', render: (r: RoiRow) => r.fiscal_quarter },
            { key: 'purchase_cost_rupees', header: 'Invested', render: (r: RoiRow) => fmtRupees(r.purchase_cost_rupees) },
            { key: 'revenue_generated_rupees', header: 'Revenue', render: (r: RoiRow) => fmtRupees(r.revenue_generated_rupees) },
            { key: 'roi_percent', header: 'ROI', render: (r: RoiRow) => fmtPct(r.roi_percent) },
            { key: 'utilization_percent', header: 'Utilization', render: (r: RoiRow) => fmtPct(r.utilization_percent) },
            { key: 'payback_months', header: 'Payback (mo)', render: (r: RoiRow) => r.payback_months !== null ? r.payback_months.toFixed(1) : '-' },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Category rollup</h2>
        <DataTable
          rows={cats}
          rowKey={(r, i) => String((r as CategoryRow).equipment_category ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'equipment_category', header: 'Category', render: (r: CategoryRow) => r.equipment_category },
            { key: 'units', header: 'Units', render: (r: CategoryRow) => String(r.units) },
            { key: 'invested_rupees', header: 'Invested', render: (r: CategoryRow) => fmtRupees(r.invested_rupees) },
            { key: 'revenue_rupees', header: 'Revenue', render: (r: CategoryRow) => fmtRupees(r.revenue_rupees) },
            { key: 'avg_roi_percent', header: 'Avg ROI', render: (r: CategoryRow) => fmtPct(r.avg_roi_percent) },
            { key: 'avg_downtime_hours', header: 'Avg downtime hrs', render: (r: CategoryRow) => r.avg_downtime_hours.toFixed(1) },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Underperformers (ROI &lt; 40%)</h2>
        <DataTable
          rows={under}
          rowKey={(r, i) => String((r as UnderRow).id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: UnderRow) => r.customer_org_name },
            { key: 'equipment_label', header: 'Equipment', render: (r: UnderRow) => r.equipment_label },
            { key: 'roi_percent', header: 'ROI', render: (r: UnderRow) => fmtPct(r.roi_percent) },
            { key: 'utilization_percent', header: 'Utilization', render: (r: UnderRow) => fmtPct(r.utilization_percent) },
            { key: 'downtime_hours', header: 'Downtime hrs', render: (r: UnderRow) => String(r.downtime_hours) },
            { key: 'payback_months', header: 'Payback (mo)', render: (r: UnderRow) => r.payback_months !== null ? r.payback_months.toFixed(1) : '-' },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Customer summary</h2>
        <DataTable
          rows={customers}
          rowKey={(r, i) => String((r as CustomerRow).customer_org_name ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: CustomerRow) => r.customer_org_name },
            { key: 'units', header: 'Units', render: (r: CustomerRow) => String(r.units) },
            { key: 'total_invested_rupees', header: 'Invested', render: (r: CustomerRow) => fmtRupees(r.total_invested_rupees) },
            { key: 'total_revenue_rupees', header: 'Revenue', render: (r: CustomerRow) => fmtRupees(r.total_revenue_rupees) },
            { key: 'avg_roi_percent', header: 'Avg ROI', render: (r: CustomerRow) => fmtPct(r.avg_roi_percent) },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Decision mix</h2>
        <DataTable
          rows={mix}
          rowKey={(r, i) => String((r as DecisionMixRow).decision ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'decision', header: 'Decision', render: (r: DecisionMixRow) => r.decision },
            { key: 'units', header: 'Units', render: (r: DecisionMixRow) => String(r.units) },
            { key: 'estimated_savings_rupees', header: 'Est. savings', render: (r: DecisionMixRow) => fmtRupees(r.estimated_savings_rupees) },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Keep / replace / divest decisions</h2>
        <DataTable
          rows={decisions}
          rowKey={(r, i) => String((r as DecisionRow).id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: DecisionRow) => r.customer_org_name },
            { key: 'equipment_label', header: 'Equipment', render: (r: DecisionRow) => r.equipment_label },
            { key: 'decision', header: 'Decision', render: (r: DecisionRow) => r.decision },
            { key: 'decided_by_role', header: 'By', render: (r: DecisionRow) => r.decided_by_role },
            { key: 'rationale', header: 'Rationale', render: (r: DecisionRow) => r.rationale },
            { key: 'estimated_savings_rupees', header: 'Est. savings', render: (r: DecisionRow) => fmtRupees(r.estimated_savings_rupees) },
            { key: 'approval_status', header: 'Status', render: (r: DecisionRow) => r.approval_status },
            { key: 'effective_from', header: 'Effective', render: (r: DecisionRow) => r.effective_from },
          ]}
        />
      </section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="border rounded-lg p-3 bg-white shadow-sm">
      <div className="text-xs text-gray-500">{label}</div>
      <div className="text-lg font-semibold mt-1">{value}</div>
    </div>
  );
}
