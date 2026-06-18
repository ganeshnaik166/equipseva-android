import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees, formatPct } from "@/lib/format";

export const metadata = { title: "AMC pool balance distribution — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  bucket: string;
  bucket_order: number;
  cnt: number;
  total_inr: number;
  pct_of_total: number;
};

export default async function AmcPoolBalanceDistributionPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_balance_distribution");
  if (error) throw new Error(`founder_amc_pool_balance_distribution: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalCnt = rows.reduce((a, r) => a + (r.cnt ?? 0), 0);
  const totalInr = rows.reduce((a, r) => a + Number(r.total_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "b", header: "Balance bucket", render: (r) => <span className={`text-xs font-medium ${r.bucket_order === 1 ? "text-[var(--color-danger)]" : r.bucket_order === 2 ? "text-[var(--color-warn)]" : ""}`}>{r.bucket}</span> },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "t", header: "Total INR in bucket", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_inr))}</span> },
    { key: "p", header: "% of active", render: (r) => <span className="text-xs tabular-nums">{formatPct(Number(r.pct_of_total) / 100)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool balance distribution</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {formatNumber(totalCnt)} active AMCs · grand float: <span className="font-mono tabular-nums">{formatRupees(totalInr)}</span> · 7 balance buckets
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No active AMCs." />
    </div>
  );
}
