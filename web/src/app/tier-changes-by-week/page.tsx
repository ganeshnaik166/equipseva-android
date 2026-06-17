import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Tier changes by week — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { week_start: string; promotions: number; demotions: number; total_events: number };

export default async function TierChangesByWeekPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_tier_changes_by_week");
  if (error) throw new Error(`founder_tier_changes_by_week: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs">{new Date(r.week_start).toLocaleDateString("en-IN", { day: "numeric", month: "short" })}</span> },
    { key: "p", header: "Promotions", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">+{formatNumber(r.promotions)}</span> },
    { key: "d", header: "Demotions", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">-{formatNumber(r.demotions)}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.total_events)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Tier changes by week</h1>
        <span className="text-xs text-[var(--color-muted)]">last 13 weeks</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No tier events." />
    </div>
  );
}
