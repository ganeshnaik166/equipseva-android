import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Supervision funnel — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  window_label: string;
  requested: number;
  accepted: number;
  signed_off: number;
  successful: number;
  accept_rate_pct: number;
  success_rate_pct: number;
};

export default async function SupervisionFunnelPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_supervision_funnel");
  if (error) throw new Error(`founder_supervision_funnel: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const w30 = rows.find((r) => r.window_label === "30d");
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "rq", header: "Requested", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.requested)}</span> },
    { key: "a", header: "Accepted", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.accepted)}</span> },
    { key: "s", header: "Signed off", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.signed_off)}</span> },
    { key: "su", header: "Successful", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.successful)}</span> },
    {
      key: "ar", header: "Accept %",
      render: (r) => {
        const tone = r.accept_rate_pct >= 80 ? "text-[var(--color-ok)]"
          : r.accept_rate_pct >= 50 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs tabular-nums ${tone}`}>{r.accept_rate_pct}%</span>;
      }
    },
    {
      key: "sr", header: "Success %",
      render: (r) => {
        const tone = r.success_rate_pct >= 80 ? "text-[var(--color-ok)]"
          : r.success_rate_pct >= 50 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs tabular-nums ${tone}`}>{r.success_rate_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Supervision funnel</h1>
        <span className="text-xs text-[var(--color-muted)]">request → accept → sign-off → success</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="30d requested" value={formatNumber(w30?.requested ?? 0)} />
          <StatCard label="30d accept rate" value={`${w30?.accept_rate_pct ?? 0}%`} tone={(w30?.accept_rate_pct ?? 0) >= 80 ? "ok" : "warn"} />
          <StatCard label="30d signed off" value={formatNumber(w30?.signed_off ?? 0)} />
          <StatCard label="30d success rate" value={`${w30?.success_rate_pct ?? 0}%`} tone={(w30?.success_rate_pct ?? 0) >= 80 ? "ok" : "warn"} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No supervision activity in 90d." />
    </div>
  );
}
