import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Tier distribution trend — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { tier: string; current_cnt: number; promotions_30d: number; demotions_30d: number; net_30d: number };

export default async function TierDistributionTrendPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_tier_distribution_trend");
  if (error) throw new Error(`founder_tier_distribution_trend: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-semibold capitalize">{r.tier}</span> },
    { key: "c", header: "Current", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.current_cnt)}</span> },
    { key: "p", header: "Promotions 30d", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">+{formatNumber(r.promotions_30d)}</span> },
    { key: "d", header: "Demotions 30d", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">-{formatNumber(r.demotions_30d)}</span> },
    { key: "n", header: "Net 30d",
      render: (r) => {
        const tone = r.net_30d > 0 ? "text-[var(--color-ok)]" : r.net_30d < 0 ? "text-[var(--color-danger)]" : "";
        const sign = r.net_30d > 0 ? "+" : "";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{sign}{formatNumber(r.net_30d)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Tier distribution trend</h1>
        <span className="text-xs text-[var(--color-muted)]">current state + 30d net movement</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.tier} emptyMessage="No tier data." />
    </div>
  );
}
