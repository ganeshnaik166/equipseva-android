import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Dispute resolution time distribution — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  bucket: string;
  bucket_order: number;
  cnt: number;
  pct_of_total: number;
};

export default async function DisputesResolutionTimeDistributionPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_disputes_resolution_time_distribution");
  if (error) throw new Error(`founder_disputes_resolution_time_distribution: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalCnt = rows.reduce((a, r) => a + (r.cnt ?? 0), 0);
  const slow = rows.filter(r => r.bucket_order >= 5).reduce((a, r) => a + (r.cnt ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "b", header: "Bucket", render: (r) => <span className={`text-xs font-medium ${r.bucket_order >= 5 ? "text-[var(--color-danger)]" : r.bucket_order >= 4 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]"}`}>{r.bucket}</span> },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "p", header: "%", render: (r) => <span className="text-xs tabular-nums">{formatPct(Number(r.pct_of_total) / 100)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Dispute resolution time distribution (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Total resolved: <span className="font-mono tabular-nums">{formatNumber(totalCnt)}</span> · <span className="text-[var(--color-danger)]">{formatNumber(slow)} took &gt;7d</span> · mediation velocity
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No resolved disputes in last 90d." />
    </div>
  );
}
