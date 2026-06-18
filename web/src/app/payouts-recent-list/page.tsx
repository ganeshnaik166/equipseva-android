import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payouts recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  payout_id: string;
  engineer_name: string;
  amount_rupees: number;
  status: string;
  mode: string;
  utr: string | null;
  queued_at: string;
  processed_at: string | null;
};

export default async function PayoutsRecentListPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_recent_list");
  if (error) throw new Error(`founder_payouts_recent_list: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "q", header: "Queued", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.queued_at).toLocaleString()}</span> },
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs font-semibold">{r.engineer_name}</span> },
    { key: "a", header: "Amount (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.amount_rupees)}</span> },
    { key: "m", header: "Mode", render: (r) => <span className="text-xs">{r.mode}</span> },
    { key: "s", header: "Status",
      render: (r) => {
        const tone = r.status === "processed" ? "text-[var(--color-ok)]"
          : r.status === "failed" || r.status === "cancelled" ? "text-[var(--color-danger)]"
          : "text-[var(--color-warn)]";
        return <span className={`text-xs font-semibold ${tone}`}>{r.status}</span>;
      }
    },
    { key: "u", header: "UTR", render: (r) => <span className="text-xs font-mono">{r.utr ?? "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts recent (7d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Last 100 engineer payouts with mode + UTR + status</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.payout_id} emptyMessage="No payouts." />
    </div>
  );
}
