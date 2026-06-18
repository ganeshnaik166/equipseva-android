import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Repair jobs by source — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { source: string; jobs_90d: number; gross_90d: number; share_pct: number };

export default async function RepairJobsBySourcePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_repair_jobs_by_source");
  if (error) throw new Error(`founder_repair_jobs_by_source: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "Source", render: (r) => <span className="text-xs font-semibold">{r.source}</span> },
    { key: "j", header: "Jobs (90d)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_90d)}</span> },
    { key: "g", header: "Gross (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.gross_90d)}</span> },
    { key: "p", header: "Share %", render: (r) => <span className="text-xs tabular-nums">{r.share_pct}%</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Repair jobs by source (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">amc_visit · code_red · direct</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.source} emptyMessage="No jobs." />
    </div>
  );
}
