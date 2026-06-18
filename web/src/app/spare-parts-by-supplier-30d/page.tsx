import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Spare parts by supplier 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  supplier_name: string;
  orders: number;
  paid_orders: number;
  total_gmv_inr: number;
  last_order_at: string | null;
};

export default async function SparePartsBySupplier30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spare_parts_by_supplier_30d");
  if (error) throw new Error(`founder_spare_parts_by_supplier_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalGmv = rows.reduce((a, r) => a + Number(r.total_gmv_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "s", header: "Supplier", render: (r) => <span className="text-xs font-medium">{r.supplier_name}</span> },
    { key: "o", header: "Orders", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.orders)}</span> },
    { key: "p", header: "Paid", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.paid_orders)}</span> },
    { key: "g", header: "GMV", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_gmv_inr))}</span> },
    { key: "l", header: "Last order", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.last_order_at ? formatRelativeTime(r.last_order_at) : "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spare parts by supplier (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Total paid GMV: <span className="font-mono tabular-nums">{formatRupees(totalGmv)}</span> · top 50 suppliers by 30d order count
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.supplier_name} emptyMessage="No spare part orders in last 30d." />
    </div>
  );
}
