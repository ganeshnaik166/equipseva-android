import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "AMC churn rate by month — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  month_ist: string;
  active_start_of_month: number;
  expired_in_month: number;
  newly_paused_in_month: number;
  churn_pct: number;
};

export default async function AmcChurnRateByMonthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_churn_rate_by_month");
  if (error) throw new Error(`founder_amc_churn_rate_by_month: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "a", header: "Active SOM", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.active_start_of_month)}</span> },
    { key: "e", header: "Expired", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.expired_in_month)}</span> },
    { key: "p", header: "Newly paused", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.newly_paused_in_month)}</span> },
    { key: "pct", header: "Churn %", render: (r) => {
        const v = Number(r.churn_pct);
        const tone = v <= 3 ? "text-[var(--color-ok)]" : v <= 8 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatPct(v / 100)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC churn rate by month (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          (Expired + newly paused) / Active SOM × 100 · churn signal · target ≤3%
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No churn data." />
    </div>
  );
}
