import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payouts by state — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { state: string; engineers: number; processed_90d: number; paid_rupees_90d: number };

export default async function PayoutsByStatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_by_state");
  if (error) throw new Error(`founder_payouts_by_state: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "State", render: (r) => <span className="text-xs">{r.state}</span> },
    { key: "e", header: "Engineers", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.engineers)}</span> },
    { key: "p", header: "Processed 90d", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.processed_90d)}</span> },
    { key: "r", header: "Paid (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.paid_rupees_90d)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts by state (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 40 states by engineer payout volume</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.state} emptyMessage="No payouts." />
    </div>
  );
}
