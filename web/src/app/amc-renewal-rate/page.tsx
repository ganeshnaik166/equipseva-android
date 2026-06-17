import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC renewal rate — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; attempted: number; succeeded: number; failed: number; abandoned: number; success_pct: number };

export default async function AmcRenewalRatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_renewal_rate");
  if (error) throw new Error(`founder_amc_renewal_rate: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "a", header: "Attempted", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.attempted)}</span> },
    { key: "s", header: "Succeeded", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.succeeded)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed)}</span> },
    { key: "ab", header: "Abandoned", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.abandoned)}</span> },
    { key: "p", header: "Success %",
      render: (r) => {
        const tone = r.success_pct < 70 ? "text-[var(--color-danger)]"
          : r.success_pct < 85 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.success_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC renewal rate</h1>
        <span className="text-xs text-[var(--color-muted)]">% of renewal attempts that succeeded · 30/90/365d</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No renewal attempts." />
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Drill <a href="/amc-renewal-failures" className="underline">/amc-renewal-failures</a> for the failed ones requiring intervention.
      </section>
    </div>
  );
}
