import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Repair jobs by status — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { status: string; job_count: number; share_pct: number; oldest_days: number };

export default async function RepairJobsStatusPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_repair_jobs_status");
  if (error) throw new Error(`founder_repair_jobs_status: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "Status",
      render: (r) => {
        const tone = r.status === "completed" ? "text-[var(--color-ok)]"
          : r.status === "cancelled" ? "text-[var(--color-danger)]"
          : r.status === "in_progress" ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs font-semibold ${tone}`}>{r.status}</span>;
      }
    },
    { key: "c", header: "Jobs", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.job_count)}</span> },
    { key: "p", header: "Share", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.share_pct}%</span> },
    { key: "o", header: "Oldest", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.oldest_days)}d</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Repair jobs by status</h1>
        <span className="text-xs text-[var(--color-muted)]">all-time job distribution by status</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.status} emptyMessage="No jobs." />
    </div>
  );
}
