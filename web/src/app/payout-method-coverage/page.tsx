import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payout method coverage — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; earning_engineers: number; with_verified_vpa: number; coverage_pct: number };

export default async function PayoutMethodCoveragePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payout_method_coverage");
  if (error) throw new Error(`founder_payout_method_coverage: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const w30 = rows.find((r) => r.window_label === "30d");
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "e", header: "Earning engineers", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.earning_engineers)}</span> },
    { key: "v", header: "With verified VPA", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.with_verified_vpa)}</span> },
    { key: "p", header: "Coverage %",
      render: (r) => {
        const tone = r.coverage_pct < 70 ? "text-[var(--color-danger)]"
          : r.coverage_pct < 90 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.coverage_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payout method coverage</h1>
        <span className="text-xs text-[var(--color-muted)]">% of earning engineers with verified VPA · across 7/30/90d</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="30d earners" value={formatNumber(w30?.earning_engineers ?? 0)} />
          <StatCard label="30d verified" value={formatNumber(w30?.with_verified_vpa ?? 0)} tone="ok" />
          <StatCard label="30d coverage" value={`${w30?.coverage_pct ?? 0}%`} tone={(w30?.coverage_pct ?? 0) < 90 ? "warn" : "ok"} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No completed earners in window." />
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>Why this surface.</strong> Engineers who earn but lack verified VPA have payouts
        stuck in queue (see <a href="/engineers-missing-payout" className="underline">/engineers-missing-payout</a>).
        Coverage % is the platform-wide health signal. Below 90% means meaningful revenue is locked up.
      </section>
    </div>
  );
}
