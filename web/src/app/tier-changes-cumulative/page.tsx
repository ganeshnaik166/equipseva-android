import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Tier changes cumulative — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; promotions: number; cum_promotions: number; demotions: number; cum_demotions: number };

export default async function TierChangesCumulativePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_tier_changes_cumulative");
  if (error) throw new Error(`founder_tier_changes_cumulative: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "p", header: "Promotions (m)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">+{formatNumber(r.promotions)}</span> },
    { key: "cp", header: "Cum promotions", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cum_promotions)}</span> },
    { key: "d", header: "Demotions (m)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">-{formatNumber(r.demotions)}</span> },
    { key: "cd", header: "Cum demotions", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cum_demotions)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Tier changes cumulative</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month cumulative promotions/demotions</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No tier events." />
    </div>
  );
}
