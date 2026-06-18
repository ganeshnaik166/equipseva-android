import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Code Red by day 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  day_ist: string;
  total: number;
  resolved: number;
  timed_out: number;
  open_now: number;
  resolved_pct: number;
};

export default async function CodeRedByDay30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_code_red_by_day_30d");
  if (error) throw new Error(`founder_code_red_by_day_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const total = rows.reduce((a, r) => a + (r.total ?? 0), 0);
  const totalRes = rows.reduce((a, r) => a + (r.resolved ?? 0), 0);
  const totalTo = rows.reduce((a, r) => a + (r.timed_out ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Day", render: (r) => <span className="text-xs tabular-nums">{r.day_ist}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total)}</span> },
    { key: "r", header: "Resolved", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.resolved)}</span> },
    { key: "to", header: "Timed out", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.timed_out)}</span> },
    { key: "o", header: "Open now", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.open_now)}</span> },
    { key: "p", header: "Resolved %", render: (r) => {
        const v = Number(r.resolved_pct);
        const tone = v >= 80 ? "text-[var(--color-ok)]" : v >= 50 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs tabular-nums ${tone}`}>{formatPct(v / 100)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Code Red by day (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          30d total: <span className="font-mono tabular-nums">{formatNumber(total)}</span> · resolved: <span className="font-mono tabular-nums text-[var(--color-ok)]">{formatNumber(totalRes)}</span> · timed out: <span className="font-mono tabular-nums text-[var(--color-danger)]">{formatNumber(totalTo)}</span>
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No Code Red requests in last 30 days." />
    </div>
  );
}
