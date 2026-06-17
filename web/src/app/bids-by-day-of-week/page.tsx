import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Bids by day of week — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { dow_num: number; dow_label: string; bids: number };

export default async function BidsByDayOfWeekPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_bids_by_day_of_week");
  if (error) throw new Error(`founder_bids_by_day_of_week: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const max = Math.max(1, ...rows.map((r) => r.bids));
  const cols: Column<Row>[] = [
    { key: "d", header: "Day", render: (r) => <span className="text-xs font-semibold">{r.dow_label}</span> },
    { key: "b", header: "Bids (90d)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.bids)}</span> },
    { key: "bar", header: "", render: (r) => (
        <div className="h-2 w-48 rounded bg-[var(--color-bg-subtle)]">
          <div className="h-2 rounded bg-[var(--color-fg)]" style={{ width: `${(r.bids / max) * 100}%` }} />
        </div>
      )
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Bids by day of week</h1>
        <span className="text-xs text-[var(--color-muted)]">90d distribution · IST</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.dow_label} emptyMessage="No bids." />
    </div>
  );
}
