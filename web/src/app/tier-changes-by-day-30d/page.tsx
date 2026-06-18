import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Tier changes by day 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  day_ist: string;
  promotions: number;
  demotions: number;
  total: number;
};

export default async function TierChangesByDay30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_tier_changes_by_day_30d");
  if (error) throw new Error(`founder_tier_changes_by_day_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const tProm = rows.reduce((a, r) => a + (r.promotions ?? 0), 0);
  const tDem = rows.reduce((a, r) => a + (r.demotions ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Day", render: (r) => <span className="text-xs tabular-nums">{r.day_ist}</span> },
    { key: "p", header: "Promotions", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.promotions)}</span> },
    { key: "x", header: "Demotions", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.demotions)}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Tier changes by day (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          30d promotions: <span className="font-mono tabular-nums text-[var(--color-ok)]">{formatNumber(tProm)}</span> · demotions: <span className="font-mono tabular-nums text-[var(--color-danger)]">{formatNumber(tDem)}</span> · supply quality pulse
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No tier changes in last 30 days." />
    </div>
  );
}
