import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payouts by month × status — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; queued: number; processing: number; processed: number; failed: number; cancelled: number };

export default async function PayoutsByMonthByStatusPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_by_month_by_status");
  if (error) throw new Error(`founder_payouts_by_month_by_status: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "q", header: "Queued", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.queued)}</span> },
    { key: "i", header: "Processing", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.processing)}</span> },
    { key: "p", header: "Processed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.processed)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed)}</span> },
    { key: "c", header: "Cancelled", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.cancelled)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts by month × status (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">Cross-tab counts per status keyed by queued month</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No payouts." />
    </div>
  );
}
