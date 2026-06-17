import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC pool coverage — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { bucket: string; cnt: number; share_pct: number; ord: number };

export default async function AmcPoolCoveragePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_coverage");
  if (error) throw new Error(`founder_amc_pool_coverage: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const healthy = rows.find((r) => r.bucket.startsWith("Healthy"));
  const negative = rows.find((r) => r.bucket.startsWith("Negative"));
  const cols: Column<Row>[] = [
    { key: "b", header: "Bucket",
      render: (r) => {
        const tone = r.bucket.startsWith("Healthy") ? "text-[var(--color-ok)]"
          : r.bucket.startsWith("Caution") ? ""
          : r.bucket.startsWith("Low") ? "text-[var(--color-warn)]"
          : "text-[var(--color-danger)]";
        return <span className={`text-xs font-semibold ${tone}`}>{r.bucket}</span>;
      }
    },
    { key: "c", header: "Active AMCs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "p", header: "Share", render: (r) => <span className="text-xs tabular-nums">{r.share_pct}%</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool coverage</h1>
        <span className="text-xs text-[var(--color-muted)]">distribution of active AMCs by pool-vs-fee buffer</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="Healthy share" value={`${healthy?.share_pct ?? 0}%`} tone={(healthy?.share_pct ?? 0) >= 80 ? "ok" : "warn"} />
          <StatCard label="Negative count" value={formatNumber(negative?.cnt ?? 0)} tone={(negative?.cnt ?? 0) > 0 ? "danger" : "ok"} />
          <StatCard label="Active total" value={formatNumber(rows.reduce((s, r) => s + r.cnt, 0))} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No active AMCs." />
    </div>
  );
}
