import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Undeposited TDS — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { fiscal_year: string; fy_quarter: string; rows: number; total_tds_rupees: number; oldest_days: number };

export default async function UndepositedTdsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_undeposited_tds");
  if (error) throw new Error(`founder_undeposited_tds: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const total = rows.reduce((n, r) => n + (r.total_tds_rupees ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "f", header: "Fiscal year", render: (r) => <span className="text-xs font-semibold">{r.fiscal_year}</span> },
    { key: "q", header: "Quarter", render: (r) => <span className="text-xs">{r.fy_quarter}</span> },
    { key: "r", header: "Rows", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.rows)}</span> },
    { key: "t", header: "TDS (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold text-[var(--color-danger)]">{formatNumber(r.total_tds_rupees)}</span> },
    { key: "d", header: "Oldest (days)",
      render: (r) => {
        const tone = r.oldest_days > 90 ? "text-[var(--color-danger)]"
          : r.oldest_days > 30 ? "text-[var(--color-warn)]" : "text-[var(--color-fg)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.oldest_days}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Undeposited TDS</h1>
        <span className="text-xs text-[var(--color-muted)]">Total ₹{formatNumber(total)} sitting in company account · owed to govt</span>
      </header>

      {total > 0 && (
        <section className="rounded border border-[var(--color-danger)] bg-[#fee] p-3 text-xs">
          <strong>⚠️ Compliance: ₹{formatNumber(total)} TDS deducted from engineer payouts but not yet deposited to govt.</strong> 194O TDS deposits are due quarterly (Q1 by 31-Jul, Q2 by 31-Oct, Q3 by 31-Jan, Q4 by 30-Apr). Penalty + interest accrue daily past due date. Reach out to CA / use TRACES portal to file.
        </section>
      )}

      <DataTable columns={cols} rows={rows} rowKey={(r) => `${r.fiscal_year}-${r.fy_quarter}`} emptyMessage="No undeposited TDS." />
    </div>
  );
}
