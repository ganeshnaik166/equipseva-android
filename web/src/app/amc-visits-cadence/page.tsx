import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC visits cadence — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { visit_frequency: string; active_cnt: number; visits_done: number; visits_sched: number; completion_pct: number };

export default async function AmcVisitsCadencePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_visits_cadence");
  if (error) throw new Error(`founder_amc_visits_cadence: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "f", header: "Frequency", render: (r) => <span className="text-xs font-semibold capitalize">{r.visit_frequency}</span> },
    { key: "a", header: "Active AMCs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.active_cnt)}</span> },
    { key: "d", header: "Visits done", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.visits_done)}</span> },
    { key: "s", header: "Scheduled", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.visits_sched)}</span> },
    { key: "p", header: "Completion",
      render: (r) => {
        const tone = r.completion_pct < 50 ? "text-[var(--color-danger)]"
          : r.completion_pct < 80 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.completion_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC visits cadence</h1>
        <span className="text-xs text-[var(--color-muted)]">visits completed vs scheduled · per frequency</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.visit_frequency} emptyMessage="No active AMCs." />
    </div>
  );
}
