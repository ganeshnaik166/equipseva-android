import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC churn monthly — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; churned: number; active_atend: number; churn_pct: number };

export default async function AmcChurnMonthlyPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_churn_monthly");
  if (error) throw new Error(`founder_amc_churn_monthly: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "c", header: "Churned", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.churned)}</span> },
    { key: "a", header: "Active (end)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.active_atend)}</span> },
    { key: "p", header: "Churn %",
      render: (r) => {
        const tone = r.churn_pct > 5 ? "text-[var(--color-danger)]"
          : r.churn_pct > 2 ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.churn_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC churn monthly</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month churn % (proxy via updated_at)</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No churn data." />
    </div>
  );
}
