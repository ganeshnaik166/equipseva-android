import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Bid amount distribution — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { bucket: string; cnt: number };

export default async function BidAmountDistributionPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_bid_amount_distribution");
  if (error) throw new Error(`founder_bid_amount_distribution: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const total = rows.reduce((s, r) => s + r.cnt, 0);
  const cols: Column<Row>[] = [
    { key: "b", header: "Bucket", render: (r) => <span className="text-xs font-semibold">{r.bucket}</span> },
    { key: "c", header: "Bids", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "p", header: "Share",
      render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{total === 0 ? "—" : `${((r.cnt / total) * 100).toFixed(1)}%`}</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Bid amount distribution</h1>
        <span className="text-xs text-[var(--color-muted)]">90d bids · grouped by amount</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No bids." />
    </div>
  );
}
