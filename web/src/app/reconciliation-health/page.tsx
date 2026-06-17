import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Reconciliation health — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_at: string; runs: number; anomalies_total: number };

export default async function ReconciliationHealthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_reconciliation_health");
  if (error) throw new Error(`founder_reconciliation_health: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const monthsWithZeroRuns = rows.filter((r) => r.runs === 0).length;

  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_at}</span> },
    { key: "r", header: "Recon runs",
      render: (r) => {
        const tone = r.runs === 0 ? "text-[var(--color-danger)]"
          : r.runs < 25 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatNumber(r.runs)}</span>;
      }
    },
    { key: "a", header: "Anomalies", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.anomalies_total)}</span> },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Reconciliation health</h1>
        <span className="text-xs text-[var(--color-muted)]">Daily 3-way recon cron (r489) firing audit · last 12 months</span>
      </header>

      {monthsWithZeroRuns > 0 && (
        <section className="rounded border border-[var(--color-danger)] bg-[#fee] p-3 text-xs">
          <strong>⚠️ {monthsWithZeroRuns} month(s) with zero reconciliation runs.</strong>
          {" "}If this includes recent months, the cron is broken — likely a stale reference to a column that doesn&apos;t exist (see r856 fix). Investigate via Supabase function logs for <code>run_daily_reconciliation</code>.
        </section>
      )}

      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_at} emptyMessage="No reconciliation runs ever." />

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>Why this page.</strong> r856 fixed a latent reference to engineer_payouts.amount_rupees that may have silently broken the 3-way reconciliation cron since 2026-08-08. This page shows whether reconciliation_runs has actually been receiving rows, by month. Zero runs in recent months = bug was real; non-zero = cron worked (column was added via dashboard SQL outside migration history).
      </section>
    </div>
  );
}
