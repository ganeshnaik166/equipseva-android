import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Repair jobs status snapshot — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { status: string; cnt: number; share_pct: number };

export default async function RepairJobsStatusSnapshotPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_repair_jobs_status_snapshot");
  if (error) throw new Error(`founder_repair_jobs_status_snapshot: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "Status", render: (r) => <span className="text-xs font-semibold">{r.status}</span> },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "p", header: "Share %", render: (r) => <span className="text-xs tabular-nums font-semibold">{r.share_pct}%</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Repair jobs status snapshot</h1>
        <span className="text-xs text-[var(--color-muted)]">All-time status distribution</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.status} emptyMessage="No jobs." />
    </div>
  );
}
