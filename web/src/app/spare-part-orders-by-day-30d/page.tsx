import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "Spare part orders by day 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  day_ist: string;
  orders: number;
  paid: number;
  shipped: number;
  delivered: number;
  gmv_inr: number;
};

export default async function SparePartOrdersByDay30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spare_part_orders_by_day_30d");
  if (error) throw new Error(`founder_spare_part_orders_by_day_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalGmv = rows.reduce((a, r) => a + Number(r.gmv_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Day", render: (r) => <span className="text-xs tabular-nums">{r.day_ist}</span> },
    { key: "o", header: "Orders", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.orders)}</span> },
    { key: "p", header: "Paid", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.paid)}</span> },
    { key: "s", header: "Shipped", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.shipped)}</span> },
    { key: "dl", header: "Delivered", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.delivered)}</span> },
    { key: "g", header: "Paid GMV", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.gmv_inr))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spare part orders by day (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          30d cumulative paid GMV: <span className="font-mono tabular-nums">{formatRupees(totalGmv)}</span>
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No spare part orders in last 30 days." />
    </div>
  );
}
