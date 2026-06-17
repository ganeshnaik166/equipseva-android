import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payouts pending list — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  payout_id: string;
  engineer_user_id: string;
  display_name: string;
  amount_rupees: number;
  queued_at: string;
  hours_old: number;
  has_method: boolean;
};

export default async function PayoutsPendingListPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_pending_list");
  if (error) throw new Error(`founder_payouts_pending_list: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs font-semibold">{r.display_name}</span> },
    { key: "a", header: "Amount (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.amount_rupees)}</span> },
    { key: "h", header: "Hours old",
      render: (r) => {
        const tone = r.hours_old > 72 ? "text-[var(--color-danger)]"
          : r.hours_old > 24 ? "text-[var(--color-warn)]" : "text-[var(--color-fg)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.hours_old}</span>;
      }
    },
    { key: "m", header: "Payout method",
      render: (r) => r.has_method
        ? <span className="text-xs text-[var(--color-ok)]">✓</span>
        : <span className="text-xs text-[var(--color-danger)]">missing</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts pending list</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 100 pending payouts oldest-first</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.payout_id} emptyMessage="No pending payouts." />
    </div>
  );
}
