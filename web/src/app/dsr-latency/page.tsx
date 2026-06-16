import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "DSR sign-off latency — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  window_label: string;
  signed_count: number;
  avg_hours: number;
  p50_hours: number;
  p90_hours: number;
  unsigned_count: number;
};

function fmt(h: number | null) {
  if (h == null) return "—";
  if (h < 24) return `${h.toFixed(1)}h`;
  return `${(h / 24).toFixed(1)}d`;
}

export default async function DsrLatencyPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_dsr_signoff_latency");
  if (error) throw new Error(`founder_dsr_signoff_latency: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const w7 = rows.find((r) => r.window_label === "7d");
  const w30 = rows.find((r) => r.window_label === "30d");
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "s", header: "Signed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.signed_count)}</span> },
    { key: "u", header: "Unsigned", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.unsigned_count)}</span> },
    { key: "a", header: "Avg", render: (r) => <span className="text-xs tabular-nums">{fmt(r.avg_hours)}</span> },
    { key: "50", header: "p50", render: (r) => <span className="text-xs tabular-nums">{fmt(r.p50_hours)}</span> },
    {
      key: "90", header: "p90",
      render: (r) => {
        const tone = r.p90_hours > 48 ? "text-[var(--color-danger)]"
          : r.p90_hours > 24 ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs tabular-nums ${tone}`}>{fmt(r.p90_hours)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">DSR sign-off latency</h1>
        <span className="text-xs text-[var(--color-muted)]">Hospital sign-off lag</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="7d avg" value={fmt(w7?.avg_hours ?? null)} />
          <StatCard label="7d p90" value={fmt(w7?.p90_hours ?? null)} tone={(w7?.p90_hours ?? 0) > 24 ? "warn" : "ok"} />
          <StatCard label="Unsigned 7d" value={formatNumber(w7?.unsigned_count ?? 0)} tone={(w7?.unsigned_count ?? 0) > 0 ? "warn" : "ok"} />
          <StatCard label="30d avg" value={fmt(w30?.avg_hours ?? null)} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No DSR sign-offs." />
    </div>
  );
}
