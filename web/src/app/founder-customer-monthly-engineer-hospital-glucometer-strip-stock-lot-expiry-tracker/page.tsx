import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  total_lots: number;
  in_stock_lots: number;
  low_lots: number;
  depleted_lots: number;
  expired_lots: number;
  quarantined_lots: number;
  total_remaining_strips: number;
  estimated_stock_value_rupees: number;
};

type ExpiringRow = {
  hospital_org_name: string;
  hospital_city: string;
  lot_number: string;
  brand: string;
  strip_count_remaining: number;
  lot_expiry_on: string;
  days_to_expiry: number;
};

type ReorderRow = {
  hospital_org_name: string;
  engineer_name: string;
  brand: string;
  strip_count_remaining: number;
  monthly_burn_rate: number | null;
  storage_status: string;
  reorder_triggered_at: string | null;
};

type EngineerRow = {
  engineer_name: string;
  lots_managed: number;
  hospitals_served: number;
  expired_lots: number;
  cold_chain_breaches: number;
  total_remaining: number;
};

type BrandRow = {
  brand: string;
  lots: number;
  total_remaining: number;
  avg_unit_cost: number;
};

type MonthlyRow = {
  delivery_month: string;
  hospitals: number;
  total_delivered: number;
  total_consumed: number;
  total_expired: number;
  total_quarantined: number;
  on_time_pct: number;
  total_invoice_rupees: number;
  avg_csat: number;
};

type AtRiskRow = {
  hospital_org_name: string;
  csat: number | null;
  on_time_delivery: boolean;
  expired_units: number;
  quarantined_units: number;
  invoice_amount_rupees: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summary, expiring, reorder, engineer, brand, monthly, atRisk] = await Promise.all([
    supabase.rpc('founder_r3032_strip_inventory_summary'),
    supabase.rpc('founder_r3032_strip_expiring_lots'),
    supabase.rpc('founder_r3032_strip_reorder_queue'),
    supabase.rpc('founder_r3032_engineer_performance'),
    supabase.rpc('founder_r3032_brand_mix'),
    supabase.rpc('founder_r3032_monthly_delivery_rollup'),
    supabase.rpc('founder_r3032_at_risk_accounts'),
  ]);

  const s: SummaryRow | null = (summary.data?.[0] as SummaryRow) ?? null;
  const expiringRows: ExpiringRow[] = (expiring.data as ExpiringRow[]) ?? [];
  const reorderRows: ReorderRow[] = (reorder.data as ReorderRow[]) ?? [];
  const engineerRows: EngineerRow[] = (engineer.data as EngineerRow[]) ?? [];
  const brandRows: BrandRow[] = (brand.data as BrandRow[]) ?? [];
  const monthlyRows: MonthlyRow[] = (monthly.data as MonthlyRow[]) ?? [];
  const atRiskRows: AtRiskRow[] = (atRisk.data as AtRiskRow[]) ?? [];

  const expiringCols: Column<ExpiringRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_org_name },
    { header: 'City', accessor: (r) => r.hospital_city },
    { header: 'Lot', accessor: (r) => r.lot_number },
    { header: 'Brand', accessor: (r) => r.brand },
    { header: 'Remaining', accessor: (r) => r.strip_count_remaining },
    { header: 'Expires', accessor: (r) => r.lot_expiry_on },
    { header: 'Days', accessor: (r) => r.days_to_expiry },
  ];

  const reorderCols: Column<ReorderRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_org_name },
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Brand', accessor: (r) => r.brand },
    { header: 'Remaining', accessor: (r) => r.strip_count_remaining },
    { header: 'Monthly burn', accessor: (r) => r.monthly_burn_rate ?? '—' },
    { header: 'Status', accessor: (r) => r.storage_status },
    { header: 'Reorder at', accessor: (r) => r.reorder_triggered_at ?? '—' },
  ];

  const engineerCols: Column<EngineerRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Lots', accessor: (r) => r.lots_managed },
    { header: 'Hospitals', accessor: (r) => r.hospitals_served },
    { header: 'Expired', accessor: (r) => r.expired_lots },
    { header: 'Cold-chain breaches', accessor: (r) => r.cold_chain_breaches },
    { header: 'Total remaining', accessor: (r) => r.total_remaining },
  ];

  const brandCols: Column<BrandRow>[] = [
    { header: 'Brand', accessor: (r) => r.brand },
    { header: 'Lots', accessor: (r) => r.lots },
    { header: 'Total remaining', accessor: (r) => r.total_remaining },
    { header: 'Avg unit ₹', accessor: (r) => r.avg_unit_cost },
  ];

  const monthlyCols: Column<MonthlyRow>[] = [
    { header: 'Month', accessor: (r) => r.delivery_month },
    { header: 'Hospitals', accessor: (r) => r.hospitals },
    { header: 'Delivered', accessor: (r) => r.total_delivered },
    { header: 'Consumed', accessor: (r) => r.total_consumed },
    { header: 'Expired', accessor: (r) => r.total_expired },
    { header: 'Quarantined', accessor: (r) => r.total_quarantined },
    { header: 'On-time %', accessor: (r) => r.on_time_pct },
    { header: 'Invoice ₹', accessor: (r) => r.total_invoice_rupees },
    { header: 'CSAT', accessor: (r) => r.avg_csat },
  ];

  const atRiskCols: Column<AtRiskRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_org_name },
    { header: 'CSAT', accessor: (r) => r.csat ?? '—' },
    { header: 'On-time', accessor: (r) => (r.on_time_delivery ? 'yes' : 'no') },
    { header: 'Expired', accessor: (r) => r.expired_units },
    { header: 'Quarantined', accessor: (r) => r.quarantined_units },
    { header: 'Invoice ₹', accessor: (r) => r.invoice_amount_rupees },
    { header: 'Notes', accessor: (r) => r.notes ?? '—' },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">
          Customer · Monthly · Engineer · Hospital — Glucometer Strip-Stock & Lot Expiry Tracker
        </h1>
        <p className="text-sm text-neutral-500">
          Round r3032 — inventory health, expiry pressure, reorder queue, engineer + brand mix, monthly delivery,
          at-risk accounts.
        </p>
      </header>

      <section>
        <h2 className="mb-3 text-lg font-medium">Inventory summary</h2>
        {s ? (
          <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
            <Kpi label="Total lots" value={s.total_lots} />
            <Kpi label="In stock" value={s.in_stock_lots} />
            <Kpi label="Low" value={s.low_lots} />
            <Kpi label="Depleted" value={s.depleted_lots} />
            <Kpi label="Expired" value={s.expired_lots} />
            <Kpi label="Quarantined" value={s.quarantined_lots} />
            <Kpi label="Remaining strips" value={s.total_remaining_strips} />
            <Kpi label="Stock value ₹" value={s.estimated_stock_value_rupees} />
          </div>
        ) : (
          <p className="text-sm text-neutral-500">No summary.</p>
        )}
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Expiring within 60 days</h2>
        <DataTable
          rows={expiringRows}
          columns={expiringCols}
          emptyMessage="No lots expiring soon."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Reorder queue (low & depleted)</h2>
        <DataTable
          rows={reorderRows}
          columns={reorderCols}
          emptyMessage="Reorder queue empty."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Engineer performance</h2>
        <DataTable
          rows={engineerRows}
          columns={engineerCols}
          emptyMessage="No engineer data."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Brand mix</h2>
        <DataTable
          rows={brandRows}
          columns={brandCols}
          emptyMessage="No brand data."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Monthly delivery rollup</h2>
        <DataTable
          rows={monthlyRows}
          columns={monthlyCols}
          emptyMessage="No deliveries logged."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">At-risk customer accounts</h2>
        <DataTable
          rows={atRiskRows}
          columns={atRiskCols}
          emptyMessage="No at-risk accounts."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>
    </main>
  );
}

function Kpi({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-3 shadow-sm">
      <div className="text-xs text-neutral-500">{label}</div>
      <div className="text-lg font-semibold">{value}</div>
    </div>
  );
}
