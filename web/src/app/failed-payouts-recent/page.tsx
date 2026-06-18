import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Failed payouts recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  payout_id: string;
  engineer_name: string;
  amount_inr: number;
  failure_reason: string;
  queued_at: string;
  age_h: number;
};

export default async function FailedPayoutsRecentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_failed_payouts_recent");
  if (error) throw new Error(`founder_failed_payouts_recent: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalInr = rows.reduce((a, r) => a + (r.amount_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "w", header: "When", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatRelativeTime(r.queued_at)}</span> },
    { key: "e", header: "Engineer", render: (r) => <span className="text-xs font-medium">{r.engineer_name}</span> },
    { key: "a", header: "Amount", render: (r) => <span className="text-xs tabular-nums">{formatRupees(r.amount_inr)}</span> },
    { key: "r", header: "Failure reason", render: (r) => <span className="text-xs text-[var(--color-danger)]">{r.failure_reason}</span> },
    { key: "i", header: "ID", render: (r) => <span className="text-xs font-mono text-[var(--color-muted)]">{r.payout_id.slice(0, 8)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Failed payouts (recent 100)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          90d failed payouts: <span className="font-mono tabular-nums text-[var(--color-danger)]">{formatNumber(rows.length)}</span> · total: <span className="font-mono tabular-nums">{formatRupees(totalInr)}</span> · pair with /payouts-by-bank for root cause
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.payout_id} emptyMessage="No failed payouts in last 90d." />
    </div>
  );
}
