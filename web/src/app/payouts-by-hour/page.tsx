import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payouts by hour — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { hour_ist: number; paid: number; failed: number };

export default async function PayoutsByHourPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_by_hour");
  if (error) throw new Error(`founder_payouts_by_hour: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "h", header: "Hour (IST)", render: (r) => <span className="text-xs font-mono">{String(r.hour_ist).padStart(2, "0")}:00</span> },
    { key: "p", header: "Paid (90d)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.paid)}</span> },
    { key: "f", header: "Failed",
      render: (r) => <span className={`text-xs tabular-nums ${r.failed > 0 ? "text-[var(--color-danger)]" : "text-[var(--color-muted)]"}`}>{formatNumber(r.failed)}</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts by hour</h1>
        <span className="text-xs text-[var(--color-muted)]">90d queued_at hour distribution · IST</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => String(r.hour_ist)} emptyMessage="No payouts." />
    </div>
  );
}
