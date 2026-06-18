import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Payouts pending by engineer — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  engineer_name: string;
  pending_cnt: number;
  pending_inr: number;
  oldest_queued_at: string | null;
  failed_cnt_90d: number;
};

export default async function PayoutsPendingByEngineerPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_pending_by_engineer");
  if (error) throw new Error(`founder_payouts_pending_by_engineer: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalInr = rows.reduce((a, r) => a + Number(r.pending_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs font-medium">{r.engineer_name}</span> },
    { key: "c", header: "Pending", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.pending_cnt)}</span> },
    { key: "i", header: "Pending INR", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatRupees(Number(r.pending_inr))}</span> },
    { key: "o", header: "Oldest queued", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.oldest_queued_at ? formatRelativeTime(r.oldest_queued_at) : "—"}</span> },
    { key: "f", header: "Fails 90d", render: (r) => <span className={`text-xs tabular-nums ${r.failed_cnt_90d > 0 ? "text-[var(--color-danger)]" : ""}`}>{formatNumber(r.failed_cnt_90d)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts pending by engineer (top 50)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Top 50 engineers by total pending INR · grand pending: <span className="font-mono tabular-nums">{formatRupees(totalInr)}</span> · founder unblock queue
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.engineer_name} emptyMessage="No pending payouts." />
    </div>
  );
}
