import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees, formatPct } from "@/lib/format";

export const metadata = { title: "Engineer earnings distribution — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  bucket: string;
  bucket_order: number;
  engineer_cnt: number;
  total_inr: number;
  pct_of_total: number;
};

export default async function EngineerEarningsDistributionPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_earnings_distribution");
  if (error) throw new Error(`founder_engineer_earnings_distribution: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalEng = rows.reduce((a, r) => a + (r.engineer_cnt ?? 0), 0);
  const totalInr = rows.reduce((a, r) => a + Number(r.total_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "b", header: "90d earnings bucket", render: (r) => <span className="text-xs font-medium">{r.bucket}</span> },
    { key: "c", header: "Engineers", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.engineer_cnt)}</span> },
    { key: "t", header: "Total INR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_inr))}</span> },
    { key: "p", header: "%", render: (r) => <span className="text-xs tabular-nums">{formatPct(Number(r.pct_of_total) / 100)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer earnings distribution (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {formatNumber(totalEng)} earning engineers · grand 90d payout: <span className="font-mono tabular-nums">{formatRupees(totalInr)}</span> · pricing-fairness signal
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No engineer earnings in last 90d." />
    </div>
  );
}
