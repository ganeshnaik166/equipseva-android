import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Code Red SLA — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  window_label: string;
  total_requests: number;
  accepted: number;
  resolved: number;
  timed_out: number;
  accept_rate_pct: number;
  avg_accept_minutes: number | null;
};

export default async function CodeRedSlaPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_code_red_sla");
  if (error) throw new Error(`founder_code_red_sla: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const w7 = rows.find((r) => r.window_label === "7d");
  const w30 = rows.find((r) => r.window_label === "30d");
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total_requests)}</span> },
    { key: "a", header: "Accepted", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.accepted)}</span> },
    { key: "r", header: "Resolved", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.resolved)}</span> },
    { key: "to", header: "Timed out", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.timed_out)}</span> },
    {
      key: "p", header: "Accept rate",
      render: (r) => {
        const tone = r.accept_rate_pct >= 90 ? "text-[var(--color-ok)]"
          : r.accept_rate_pct >= 70 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.accept_rate_pct}%</span>;
      }
    },
    { key: "m", header: "Avg accept", render: (r) => <span className="text-xs tabular-nums">{r.avg_accept_minutes != null ? `${r.avg_accept_minutes}m` : "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Code Red SLA</h1>
        <span className="text-xs text-[var(--color-muted)]">emergency request performance</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="7d total" value={formatNumber(w7?.total_requests ?? 0)} />
          <StatCard label="7d accept rate" value={`${w7?.accept_rate_pct ?? 0}%`} tone={(w7?.accept_rate_pct ?? 100) >= 90 ? "ok" : (w7?.accept_rate_pct ?? 0) >= 70 ? "warn" : "danger"} />
          <StatCard label="7d avg accept" value={w7?.avg_accept_minutes != null ? `${w7.avg_accept_minutes}m` : "—"} />
          <StatCard label="30d timed out" value={formatNumber(w30?.timed_out ?? 0)} tone={(w30?.timed_out ?? 0) > 0 ? "warn" : "ok"} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No Code Red requests in 90d." />
    </div>
  );
}
