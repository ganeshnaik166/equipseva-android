import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payouts cumulative — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; paid_count: number; paid_rupees: number; cum_count: number; cum_rupees: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function PayoutsCumulativePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_cumulative");
  if (error) throw new Error(`founder_payouts_cumulative: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "n", header: "Paid (month)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">+{formatNumber(r.paid_count)}</span> },
    { key: "r", header: "Rupees (month)", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.paid_rupees))}</span> },
    { key: "c", header: "Cum count", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cum_count)}</span> },
    { key: "cr", header: "Cum rupees", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.cum_rupees))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts cumulative</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month cumulative engineer payouts</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No payouts." />
    </div>
  );
}
