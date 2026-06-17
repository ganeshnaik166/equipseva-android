import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Code Red by day of week — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { dow_num: number; dow_label: string; opened: number; timed_out: number };

export default async function CodeRedByDayOfWeekPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_code_red_by_day_of_week");
  if (error) throw new Error(`founder_code_red_by_day_of_week: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "d", header: "Day", render: (r) => <span className="text-xs font-semibold">{r.dow_label}</span> },
    { key: "o", header: "Opened (90d)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.opened)}</span> },
    { key: "t", header: "Timed-out",
      render: (r) => <span className={`text-xs tabular-nums ${r.timed_out > 0 ? "text-[var(--color-danger)]" : "text-[var(--color-muted)]"}`}>{formatNumber(r.timed_out)}</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Code Red by day of week</h1>
        <span className="text-xs text-[var(--color-muted)]">90d distribution</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.dow_label} emptyMessage="No Code Red activity." />
    </div>
  );
}
