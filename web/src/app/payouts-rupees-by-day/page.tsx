import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payouts rupees by day — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { day_ist: string; processed_cnt: number; processed_rupees: number; failed_cnt: number; pending_cnt: number };

export default async function PayoutsRupeesByDayPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_rupees_by_day");
  if (error) throw new Error(`founder_payouts_rupees_by_day: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalRupees = rows.reduce((n, r) => n + (r.processed_rupees ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Day (IST)", render: (r) => <span className="text-xs tabular-nums">{r.day_ist}</span> },
    { key: "p", header: "Processed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.processed_cnt)}</span> },
    { key: "r", header: "Rupees", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.processed_rupees)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed_cnt)}</span> },
    { key: "x", header: "Pending", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.pending_cnt)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts rupees by day (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Total ₹{formatNumber(totalRupees)} processed in window</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No payouts." />
    </div>
  );
}
