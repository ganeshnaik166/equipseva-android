import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Bids by hour — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { hour_ist: number; bids: number };

export default async function BidsByHourPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_bids_by_hour");
  if (error) throw new Error(`founder_bids_by_hour: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const max = Math.max(1, ...rows.map((r) => r.bids));
  const cols: Column<Row>[] = [
    { key: "h", header: "Hour (IST)", render: (r) => <span className="text-xs font-mono">{String(r.hour_ist).padStart(2, "0")}:00</span> },
    { key: "b", header: "Bids (90d)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.bids)}</span> },
    { key: "bar", header: "", render: (r) => (
        <div className="h-2 w-32 rounded bg-[var(--color-bg-subtle)]">
          <div className="h-2 rounded bg-[var(--color-fg)]" style={{ width: `${(r.bids / max) * 100}%` }} />
        </div>
      ),
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Bids by hour</h1>
        <span className="text-xs text-[var(--color-muted)]">90d distribution · IST</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => String(r.hour_ist)} emptyMessage="No bids." />
    </div>
  );
}
