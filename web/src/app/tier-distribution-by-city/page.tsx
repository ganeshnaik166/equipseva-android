import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Tier distribution by city — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { city: string; none_cnt: number; bronze_cnt: number; silver_cnt: number; gold_cnt: number; total_cnt: number };

export default async function TierDistributionByCityPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_tier_distribution_by_city");
  if (error) throw new Error(`founder_tier_distribution_by_city: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "c", header: "City", render: (r) => <span className="text-xs">{r.city}</span> },
    { key: "n", header: "none", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.none_cnt)}</span> },
    { key: "b", header: "bronze", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.bronze_cnt)}</span> },
    { key: "s", header: "silver", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.silver_cnt)}</span> },
    { key: "g", header: "gold", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.gold_cnt)}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total_cnt)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Tier distribution by city</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 50 cities · engineer cert tier mix</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.city} emptyMessage="No engineers." />
    </div>
  );
}
