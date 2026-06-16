import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payout fail reasons — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { razorpayx_status: string; cnt: number; total_rupees: number; oldest_age_days: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function PayoutFailReasonsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payout_fail_reasons");
  if (error) throw new Error(`founder_payout_fail_reasons: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "RazorpayX status", render: (r) => <span className="text-xs font-mono">{r.razorpayx_status}</span> },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "t", header: "Total stuck", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.total_rupees))}</span> },
    { key: "o", header: "Oldest", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.oldest_age_days)}d</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payout fail reasons</h1>
        <span className="text-xs text-[var(--color-muted)]">RazorpayX status distribution for non-paid payouts</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.razorpayx_status} emptyMessage="No failed payouts." />
    </div>
  );
}
