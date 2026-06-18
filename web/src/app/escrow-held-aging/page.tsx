import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Escrow held aging — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  bucket: string;
  bucket_order: number;
  cnt: number;
  amount_inr: number;
  oldest_created_at: string | null;
};

export default async function EscrowHeldAgingPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_escrow_held_aging");
  if (error) throw new Error(`founder_escrow_held_aging: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalCnt = rows.reduce((a, r) => a + (r.cnt ?? 0), 0);
  const totalInr = rows.reduce((a, r) => a + Number(r.amount_inr ?? 0), 0);
  const stuckLong = rows.filter(r => r.bucket_order >= 4).reduce((a, r) => a + (r.cnt ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "b", header: "Age bucket", render: (r) => <span className={`text-xs font-medium ${r.bucket_order >= 4 ? "text-[var(--color-danger)]" : r.bucket_order >= 3 ? "text-[var(--color-warn)]" : ""}`}>{r.bucket}</span> },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "a", header: "Total INR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.amount_inr))}</span> },
    { key: "o", header: "Oldest", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.oldest_created_at ? formatRelativeTime(r.oldest_created_at) : "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Escrow held — aging</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Held escrow rows: <span className="font-mono tabular-nums">{formatNumber(totalCnt)}</span> · {formatRupees(totalInr)} · <span className="text-[var(--color-danger)]">{formatNumber(stuckLong)} stuck &gt;14d</span> · capital tied up
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No held escrow rows." />
    </div>
  );
}
