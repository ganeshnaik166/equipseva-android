import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Payouts stuck — aging buckets — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  bucket: string;
  bucket_order: number;
  cnt: number;
  amount_inr: number;
  oldest_queued_at: string | null;
};

export default async function PayoutsStuckAgingPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_stuck_aging");
  if (error) throw new Error(`founder_payouts_stuck_aging: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalCnt = rows.reduce((a, r) => a + (r.cnt ?? 0), 0);
  const totalInr = rows.reduce((a, r) => a + (r.amount_inr ?? 0), 0);
  const stuckLong = rows.filter(r => r.bucket_order >= 4).reduce((a, r) => a + (r.cnt ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "b", header: "Age bucket", render: (r) => <span className={`text-xs font-medium ${r.bucket_order >= 4 ? "text-[var(--color-danger)]" : r.bucket_order >= 3 ? "text-[var(--color-warn)]" : ""}`}>{r.bucket}</span> },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "a", header: "Total INR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(r.amount_inr)}</span> },
    { key: "o", header: "Oldest queued", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.oldest_queued_at ? formatRelativeTime(r.oldest_queued_at) : "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts stuck — aging buckets</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Total queued/processing: <span className="font-mono tabular-nums">{formatNumber(totalCnt)}</span> · {formatRupees(totalInr)} · <span className="text-[var(--color-danger)]">{formatNumber(stuckLong)} stuck &gt;7d</span>
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No queued payouts." />
    </div>
  );
}
