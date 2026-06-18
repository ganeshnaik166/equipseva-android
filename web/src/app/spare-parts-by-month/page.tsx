import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spare parts by month — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; orders: number; rupees: number };

export default async function SparePartsByMonthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spare_parts_by_month");
  if (error) throw new Error(`founder_spare_parts_by_month: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalRevenue = rows.reduce((n, r) => n + (r.rupees ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "o", header: "Orders", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.orders)}</span> },
    { key: "r", header: "Rupees", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.rupees)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spare parts by month (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">Total 12mo ₹{formatNumber(totalRevenue)}</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No spare part orders." />
    </div>
  );
}
