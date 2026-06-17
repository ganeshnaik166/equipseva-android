import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payouts success rate — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; processed: number; failed: number; success_pct: number };

export default async function PayoutsSuccessRatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_success_rate");
  if (error) throw new Error(`founder_payouts_success_rate: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "p", header: "Processed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.processed)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed)}</span> },
    { key: "s", header: "Success %",
      render: (r) => {
        const tone = r.success_pct < 90 ? "text-[var(--color-danger)]"
          : r.success_pct < 98 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.success_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts success rate</h1>
        <span className="text-xs text-[var(--color-muted)]">% engineer payouts processed vs failed · 7/30/90d</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No payouts." />
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Drill failures via <a href="/payout-fail-reasons" className="underline">/payout-fail-reasons</a>.
      </section>
    </div>
  );
}
