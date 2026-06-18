import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Tier promotion rate by month — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  month_ist: string;
  promotions: number;
  demotions: number;
  active_engineers: number;
  promotion_pct: number;
};

export default async function TierPromotionRateByMonthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_tier_promotion_rate_by_month");
  if (error) throw new Error(`founder_tier_promotion_rate_by_month: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "p", header: "Promotions", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.promotions)}</span> },
    { key: "d", header: "Demotions", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.demotions)}</span> },
    { key: "a", header: "Active engineers", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.active_engineers)}</span> },
    { key: "pct", header: "Promotion %", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatPct(Number(r.promotion_pct) / 100)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Tier promotion rate by month (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Promotions/active-engineers % per month · engineer quality trend
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No tier changes in last 12 months." />
    </div>
  );
}
