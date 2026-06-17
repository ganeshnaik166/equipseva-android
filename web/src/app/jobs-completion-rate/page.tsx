import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs completion rate — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { week_start: string; posted: number; completed: number; cancelled: number; completion_pct: number };

export default async function JobsCompletionRatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_completion_rate");
  if (error) throw new Error(`founder_jobs_completion_rate: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Week posted", render: (r) => <span className="text-xs">{new Date(r.week_start).toLocaleDateString("en-IN", { day: "numeric", month: "short" })}</span> },
    { key: "p", header: "Posted", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.posted)}</span> },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.completed)}</span> },
    { key: "x", header: "Cancelled", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.cancelled)}</span> },
    { key: "r", header: "Completion %",
      render: (r) => {
        const tone = r.completion_pct < 50 ? "text-[var(--color-danger)]"
          : r.completion_pct < 75 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.completion_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs completion rate</h1>
        <span className="text-xs text-[var(--color-muted)]">posted-to-completed ratio per week · 13 weeks</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No jobs." />
    </div>
  );
}
