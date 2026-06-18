import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Jobs completion rate by week — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  week_start: string;
  posted: number;
  completed_within: number;
  completion_pct: number;
};

export default async function JobsCompletionRateByWeekPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_completion_rate_by_week");
  if (error) throw new Error(`founder_jobs_completion_rate_by_week: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "p", header: "Posted", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.posted)}</span> },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.completed_within)}</span> },
    { key: "pct", header: "Completion %", render: (r) => {
        const v = Number(r.completion_pct);
        const tone = v >= 70 ? "text-[var(--color-ok)]" : v >= 40 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatPct(v / 100)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs completion rate by week (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          For jobs posted in week X · % completed (any time after) · marketplace health
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No jobs in last 13 weeks." />
    </div>
  );
}
