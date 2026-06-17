import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs cancellation rate — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; total_created: number; cancelled: number; completed: number; cancel_pct: number };

export default async function JobsCancellationRatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_cancellation_rate");
  if (error) throw new Error(`founder_jobs_cancellation_rate: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "t", header: "Created", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total_created)}</span> },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.completed)}</span> },
    { key: "x", header: "Cancelled", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.cancelled)}</span> },
    { key: "p", header: "Cancel %",
      render: (r) => {
        const tone = r.cancel_pct > 20 ? "text-[var(--color-danger)]"
          : r.cancel_pct > 10 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.cancel_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs cancellation rate</h1>
        <span className="text-xs text-[var(--color-muted)]">% of created jobs that ended in cancellation · 7/30/90d</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No jobs." />
    </div>
  );
}
