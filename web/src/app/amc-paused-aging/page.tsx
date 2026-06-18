import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "AMC paused aging — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  bucket: string;
  bucket_order: number;
  cnt: number;
  frozen_mrr_inr: number;
  oldest_paused_at: string | null;
};

export default async function AmcPausedAgingPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_paused_aging");
  if (error) throw new Error(`founder_amc_paused_aging: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalCnt = rows.reduce((a, r) => a + (r.cnt ?? 0), 0);
  const totalMrr = rows.reduce((a, r) => a + Number(r.frozen_mrr_inr ?? 0), 0);
  const long = rows.filter(r => r.bucket_order >= 4).reduce((a, r) => a + (r.cnt ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "b", header: "Age bucket", render: (r) => <span className={`text-xs font-medium ${r.bucket_order >= 4 ? "text-[var(--color-danger)]" : r.bucket_order >= 3 ? "text-[var(--color-warn)]" : ""}`}>{r.bucket}</span> },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "m", header: "Frozen MRR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.frozen_mrr_inr))}</span> },
    { key: "o", header: "Oldest paused", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.oldest_paused_at ? formatRelativeTime(r.oldest_paused_at) : "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC paused aging</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Paused AMCs: <span className="font-mono tabular-nums">{formatNumber(totalCnt)}</span> · frozen MRR: <span className="font-mono tabular-nums">{formatRupees(totalMrr)}</span> · <span className="text-[var(--color-danger)]">{formatNumber(long)} paused &gt;30d</span> (likely churned)
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No paused AMCs." />
    </div>
  );
}
