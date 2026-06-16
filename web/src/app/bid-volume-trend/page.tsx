import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Bid volume trend — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { day_ist: string; bids_placed: number; bids_accepted: number; distinct_engineers: number };

export default async function BidVolumeTrendPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_bid_volume_trend");
  if (error) throw new Error(`founder_bid_volume_trend: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const total14d = rows.reduce((s, r) => s + r.bids_placed, 0);
  const acc14d = rows.reduce((s, r) => s + r.bids_accepted, 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Date (IST)", render: (r) => <span className="text-xs">{new Date(r.day_ist).toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short" })}</span> },
    { key: "b", header: "Bids placed", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.bids_placed)}</span> },
    { key: "a", header: "Accepted", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.bids_accepted)}</span> },
    { key: "e", header: "Distinct engineers", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.distinct_engineers)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Bid volume trend</h1>
        <span className="text-xs text-[var(--color-muted)]">last 14 days · IST</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="14d bids" value={formatNumber(total14d)} />
          <StatCard label="14d accepted" value={formatNumber(acc14d)} subtext={total14d === 0 ? "—" : `${((acc14d / total14d) * 100).toFixed(1)}% accept rate`} tone="ok" />
          <StatCard label="Daily avg" value={(total14d / 14).toFixed(1)} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No bids." />
    </div>
  );
}
