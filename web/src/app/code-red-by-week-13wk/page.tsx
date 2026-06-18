import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Code Red by week 13wk — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  week_start: string;
  total: number;
  resolved: number;
  timed_out: number;
  resolved_pct: number;
};

export default async function CodeRedByWeek13wkPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_code_red_by_week_13wk");
  if (error) throw new Error(`founder_code_red_by_week_13wk: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const tTot = rows.reduce((a, r) => a + (r.total ?? 0), 0);
  const tRes = rows.reduce((a, r) => a + (r.resolved ?? 0), 0);
  const tTo = rows.reduce((a, r) => a + (r.timed_out ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total)}</span> },
    { key: "r", header: "Resolved", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.resolved)}</span> },
    { key: "x", header: "Timed out", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.timed_out)}</span> },
    { key: "p", header: "Resolved %", render: (r) => {
        const v = Number(r.resolved_pct);
        const tone = v >= 80 ? "text-[var(--color-ok)]" : v >= 50 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatPct(v / 100)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Code Red by week (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          13wk: <span className="font-mono tabular-nums">{formatNumber(tTot)}</span> total · <span className="font-mono tabular-nums text-[var(--color-ok)]">{formatNumber(tRes)}</span> resolved · <span className="font-mono tabular-nums text-[var(--color-danger)]">{formatNumber(tTo)}</span> timed_out
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No Code Red requests in last 13 weeks." />
    </div>
  );
}
