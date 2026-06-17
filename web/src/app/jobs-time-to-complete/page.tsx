import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs time-to-complete — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; completed: number; avg_hours: number; p50_hours: number; p90_hours: number };

function fmt(h: number) {
  if (h < 24) return `${h.toFixed(1)}h`;
  return `${(h / 24).toFixed(1)}d`;
}

export default async function JobsTimeToCompletePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_time_to_complete");
  if (error) throw new Error(`founder_jobs_time_to_complete: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.completed)}</span> },
    { key: "a", header: "Avg", render: (r) => <span className="text-xs tabular-nums">{fmt(Number(r.avg_hours))}</span> },
    { key: "50", header: "p50", render: (r) => <span className="text-xs tabular-nums">{fmt(Number(r.p50_hours))}</span> },
    { key: "90", header: "p90",
      render: (r) => {
        const h = Number(r.p90_hours);
        const tone = h > 168 ? "text-[var(--color-danger)]" : h > 72 ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs tabular-nums ${tone}`}>{fmt(h)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs time-to-complete</h1>
        <span className="text-xs text-[var(--color-muted)]">accepted-bid → completed latency · 7/30/90d</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No completed jobs." />
    </div>
  );
}
