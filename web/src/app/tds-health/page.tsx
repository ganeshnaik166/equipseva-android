import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "TDS health — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_at: string; tds_rows: number; processed_payouts: number; coverage_pct: number };

export default async function TdsHealthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_tds_health");
  if (error) throw new Error(`founder_tds_health: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const gapMonths = rows.filter((r) => r.processed_payouts > 0 && r.tds_rows === 0).length;

  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_at}</span> },
    { key: "t", header: "TDS rows", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.tds_rows)}</span> },
    { key: "p", header: "Processed payouts", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.processed_payouts)}</span> },
    { key: "c", header: "Coverage %",
      render: (r) => {
        const tone = r.coverage_pct < 90 && r.processed_payouts > 0 ? "text-[var(--color-danger)]"
          : r.coverage_pct < 99 && r.processed_payouts > 0 ? "text-[var(--color-warn)]"
          : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.coverage_pct}%</span>;
      }
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">TDS 194O health</h1>
        <span className="text-xs text-[var(--color-muted)]">tds_deductions row count vs processed payouts · last 12 months</span>
      </header>

      {gapMonths > 0 && (
        <section className="rounded border border-[var(--color-danger)] bg-[#fee] p-3 text-xs">
          <strong>⚠️ {gapMonths} month(s) with processed payouts but zero TDS rows.</strong>
          {" "}If recent, the r490 compute_tds_194o trigger is broken — likely the engineer_payouts.amount_rupees reference fixed by r856. Compliance risk: engineers received un-deducted payouts and EquipSeva owes TDS to govt for the gap.
        </section>
      )}

      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_at} emptyMessage="No payout/TDS rows." />
    </div>
  );
}
