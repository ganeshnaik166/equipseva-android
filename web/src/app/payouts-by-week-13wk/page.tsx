import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "Payouts by week 13wk — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  week_start: string;
  queued: number;
  processed: number;
  failed: number;
  total_inr: number;
};

export default async function PayoutsByWeek13wkPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_by_week_13wk");
  if (error) throw new Error(`founder_payouts_by_week_13wk: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalInr = rows.reduce((a, r) => a + Number(r.total_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "q", header: "Queued", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.queued)}</span> },
    { key: "p", header: "Processed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.processed)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed)}</span> },
    { key: "i", header: "Paid INR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_inr))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts by week (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          13wk cumulative paid: <span className="font-mono tabular-nums">{formatRupees(totalInr)}</span>
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No payouts in last 13 weeks." />
    </div>
  );
}
