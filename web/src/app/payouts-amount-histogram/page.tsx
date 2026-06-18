import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees, formatPct } from "@/lib/format";

export const metadata = { title: "Payouts amount histogram — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  bucket: string;
  bucket_order: number;
  cnt: number;
  total_inr: number;
  pct_of_total: number;
};

export default async function PayoutsAmountHistogramPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_amount_histogram");
  if (error) throw new Error(`founder_payouts_amount_histogram: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalCnt = rows.reduce((a, r) => a + (r.cnt ?? 0), 0);
  const totalInr = rows.reduce((a, r) => a + Number(r.total_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "b", header: "Amount bucket", render: (r) => <span className="text-xs font-medium">{r.bucket}</span> },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "t", header: "Total INR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_inr))}</span> },
    { key: "p", header: "% of total", render: (r) => <span className="text-xs tabular-nums">{formatPct(Number(r.pct_of_total) / 100)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts amount histogram (90d processed)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {formatNumber(totalCnt)} payouts · {formatRupees(totalInr)} total · 7 amount buckets
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No processed payouts in last 90d." />
    </div>
  );
}
