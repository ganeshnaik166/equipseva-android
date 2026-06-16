import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Code Red volume trend — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { day_ist: string; opened: number; accepted: number; resolved: number; timed_out: number };

export default async function CodeRedVolumeTrendPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_code_red_volume_trend");
  if (error) throw new Error(`founder_code_red_volume_trend: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const total = rows.reduce((s, r) => s + r.opened, 0);
  const totalTO = rows.reduce((s, r) => s + r.timed_out, 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Date (IST)", render: (r) => <span className="text-xs">{new Date(r.day_ist).toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short" })}</span> },
    { key: "o", header: "Opened", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.opened)}</span> },
    { key: "a", header: "Accepted", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.accepted)}</span> },
    { key: "r", header: "Resolved", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.resolved)}</span> },
    { key: "t", header: "Timed out",
      render: (r) => <span className={`text-xs tabular-nums ${r.timed_out > 0 ? "text-[var(--color-danger)]" : ""}`}>{formatNumber(r.timed_out)}</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Code Red volume trend</h1>
        <span className="text-xs text-[var(--color-muted)]">last 14 days · IST · grouped by opened-date</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="14d opened" value={formatNumber(total)} />
          <StatCard label="14d timed-out" value={formatNumber(totalTO)} tone={totalTO > 0 ? "danger" : "ok"} />
          <StatCard label="Daily avg opened" value={(total / 14).toFixed(1)} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No Code Red activity." />
    </div>
  );
}
