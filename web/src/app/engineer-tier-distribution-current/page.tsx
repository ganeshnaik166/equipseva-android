import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Engineer tier distribution current — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  tier: string;
  engineer_cnt: number;
  verified_cnt: number;
  active_30d_cnt: number;
  verified_pct: number;
  active_30d_pct: number;
};

export default async function EngineerTierDistributionCurrentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_tier_distribution_current");
  if (error) throw new Error(`founder_engineer_tier_distribution_current: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-medium uppercase tracking-wide">{r.tier}</span> },
    { key: "e", header: "Engineers", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.engineer_cnt)}</span> },
    { key: "v", header: "Verified", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.verified_cnt)}</span> },
    { key: "vp", header: "Verified %", render: (r) => <span className="text-xs tabular-nums">{formatPct(Number(r.verified_pct) / 100)}</span> },
    { key: "a", header: "Active 30d", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.active_30d_cnt)}</span> },
    { key: "ap", header: "Active 30d %", render: (r) => <span className="text-xs tabular-nums">{formatPct(Number(r.active_30d_pct) / 100)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer tier distribution (current)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Per cached_highest_tier · engineers + verified + active-30d + percentages
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.tier} emptyMessage="No engineers." />
    </div>
  );
}
