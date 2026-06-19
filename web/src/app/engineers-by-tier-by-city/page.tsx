import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineers by tier by city — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  city: string;
  total: number;
  gold_cnt: number;
  silver_cnt: number;
  bronze_cnt: number;
  none_cnt: number;
  verified_cnt: number;
};

export default async function EngineersByTierByCityPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineers_by_tier_by_city");
  if (error) throw new Error(`founder_engineers_by_tier_by_city: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "c", header: "City", render: (r) => <span className="text-xs font-medium">{r.city}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total)}</span> },
    { key: "g", header: "Gold", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.gold_cnt)}</span> },
    { key: "s", header: "Silver", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.silver_cnt)}</span> },
    { key: "b", header: "Bronze", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.bronze_cnt)}</span> },
    { key: "n", header: "None", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.none_cnt)}</span> },
    { key: "v", header: "Verified", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.verified_cnt)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineers by tier by city</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Top 50 cities · cross-tab of cached_highest_tier × city
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.city} emptyMessage="No engineers." />
    </div>
  );
}
