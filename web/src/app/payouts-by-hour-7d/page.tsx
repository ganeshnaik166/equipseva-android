import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "Payouts by hour 7d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  hour_ist: number;
  queued: number;
  processed: number;
  failed: number;
  total_inr: number;
};

export default async function PayoutsByHour7dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_by_hour_7d");
  if (error) throw new Error(`founder_payouts_by_hour_7d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "h", header: "Hour IST", render: (r) => <span className="text-xs tabular-nums font-medium">{String(r.hour_ist).padStart(2, "0")}:00</span> },
    { key: "q", header: "Queued", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.queued)}</span> },
    { key: "p", header: "Processed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.processed)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed)}</span> },
    { key: "i", header: "Paid INR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_inr))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts by hour (7d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          24-hour IST distribution · payouts queued/processed/failed by queued-hour · 7d window
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => String(r.hour_ist)} emptyMessage="No payouts in last 7 days." />
    </div>
  );
}
