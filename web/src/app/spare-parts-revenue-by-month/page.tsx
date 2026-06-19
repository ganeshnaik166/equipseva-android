import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "Spare parts revenue by month — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  month_ist: string;
  paid_orders: number;
  gmv_inr: number;
  avg_inr: number;
};

export default async function SparePartsRevenueByMonthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spare_parts_revenue_by_month");
  if (error) throw new Error(`founder_spare_parts_revenue_by_month: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const grandGmv = rows.reduce((a, r) => a + Number(r.gmv_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "p", header: "Paid orders", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.paid_orders)}</span> },
    { key: "g", header: "GMV", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.gmv_inr))}</span> },
    { key: "a", header: "Avg/order", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.avg_inr))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spare parts revenue by month (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          12mo cumulative GMV: <span className="font-mono tabular-nums">{formatRupees(grandGmv)}</span>
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No paid orders in last 12 months." />
    </div>
  );
}
