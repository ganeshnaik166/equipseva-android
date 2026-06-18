import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC pool credits by month × tier — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; tier: string; credits: number; rupees: number };

export default async function AmcPoolCreditsByMonthByTierPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_credits_by_month_by_tier");
  if (error) throw new Error(`founder_amc_pool_credits_by_month_by_tier: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-semibold">{r.tier}</span> },
    { key: "c", header: "Credits", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.credits)}</span> },
    { key: "r", header: "Rupees (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold text-[var(--color-ok)]">{formatNumber(r.rupees)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool credits by month × tier (6mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">Per-tier pool top-up cadence — pair with r983 debits</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => `${r.month_ist}-${r.tier}`} emptyMessage="No pool credits." />
    </div>
  );
}
