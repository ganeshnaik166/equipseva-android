import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Reviews pending aging — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  bucket: string;
  bucket_order: number;
  cnt: number;
  oldest_completed_at: string | null;
};

export default async function ReviewsPendingAgingPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_reviews_pending_aging");
  if (error) throw new Error(`founder_reviews_pending_aging: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalCnt = rows.reduce((a, r) => a + (r.cnt ?? 0), 0);
  const stuckLong = rows.filter(r => r.bucket_order >= 4).reduce((a, r) => a + (r.cnt ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "b", header: "Age bucket", render: (r) => <span className={`text-xs font-medium ${r.bucket_order >= 4 ? "text-[var(--color-warn)]" : ""}`}>{r.bucket}</span> },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "o", header: "Oldest", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.oldest_completed_at ? formatRelativeTime(r.oldest_completed_at) : "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Reviews pending — aging</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Completed jobs without hospital rating: <span className="font-mono tabular-nums">{formatNumber(totalCnt)}</span> · {formatNumber(stuckLong)} idle &gt;14d · engagement gap
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No pending reviews." />
    </div>
  );
}
