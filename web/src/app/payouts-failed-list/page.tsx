import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payouts failed list — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  payout_id: string;
  engineer_user_id: string;
  display_name: string;
  amount_rupees: number;
  queued_at: string;
  processed_at: string | null;
  failure_reason: string | null;
};

export default async function PayoutsFailedListPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_failed_list");
  if (error) throw new Error(`founder_payouts_failed_list: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs font-semibold">{r.display_name}</span> },
    { key: "a", header: "Amount (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.amount_rupees)}</span> },
    { key: "q", header: "Queued at", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.queued_at).toLocaleString()}</span> },
    { key: "x", header: "Failure reason", render: (r) => <span className="text-xs text-[var(--color-danger)]">{r.failure_reason?.slice(0,60) ?? "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts failed list (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Last 100 failed payouts · queue + retry workflow</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.payout_id} emptyMessage="No failed payouts." />
    </div>
  );
}
