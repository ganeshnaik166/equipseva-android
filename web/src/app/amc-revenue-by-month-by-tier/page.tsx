import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC revenue by month × tier — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; tier: string; orders: number; rupees: number };

export default async function AmcRevenueByMonthByTierPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_revenue_by_month_by_tier");
  if (error) throw new Error(`founder_amc_revenue_by_month_by_tier: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-semibold">{r.tier}</span> },
    { key: "o", header: "Orders", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.orders)}</span> },
    { key: "r", header: "Rupees (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.rupees)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC revenue by month × tier (6mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">Cross-tab of AMC paid orders</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => `${r.month_ist}-${r.tier}`} emptyMessage="No paid orders." />
    </div>
  );
}
