import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC pool utilization — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { bucket: string; cnt: number; share_pct: number };

export default async function AmcPoolUtilizationPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_utilization");
  if (error) throw new Error(`founder_amc_pool_utilization: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "b", header: "Utilization", render: (r) => <span className="text-xs font-semibold">{r.bucket}</span> },
    { key: "c", header: "Contracts", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "s", header: "Share %", render: (r) => <span className="text-xs tabular-nums font-semibold">{r.share_pct}%</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool utilization</h1>
        <span className="text-xs text-[var(--color-muted)]">debits / credits per active contract · buckets</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No active contracts." />
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        High %-used buckets = hospital using AMC heavily (high value). Low %-used = hospital paying for unused service (churn risk).
      </section>
    </div>
  );
}
