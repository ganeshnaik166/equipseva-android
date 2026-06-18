import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Jobs cancellation rate by week — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  week_start: string;
  posted: number;
  cancelled: number;
  cancellation_pct: number;
};

export default async function JobsCancellationRateByWeekPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_cancellation_rate_by_week");
  if (error) throw new Error(`founder_jobs_cancellation_rate_by_week: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "p", header: "Posted", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.posted)}</span> },
    { key: "c", header: "Cancelled", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.cancelled)}</span> },
    { key: "pct", header: "Cancellation %", render: (r) => {
        const v = Number(r.cancellation_pct);
        const tone = v <= 5 ? "text-[var(--color-ok)]" : v <= 15 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatPct(v / 100)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs cancellation rate by week (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          13wk · cancelled/posted %. Lower is better. &gt;15% = friction signal
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No jobs in last 13 weeks." />
    </div>
  );
}
