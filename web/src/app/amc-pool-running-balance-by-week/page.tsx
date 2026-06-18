import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatRupees } from "@/lib/format";

export const metadata = { title: "AMC pool running balance by week — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  week_start: string;
  net_flow_inr: number;
  running_total_inr: number;
};

export default async function AmcPoolRunningBalanceByWeekPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_running_balance_by_week");
  if (error) throw new Error(`founder_amc_pool_running_balance_by_week: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "n", header: "Net flow", render: (r) => {
        const v = Number(r.net_flow_inr);
        const tone = v >= 0 ? "text-[var(--color-ok)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs tabular-nums ${tone}`}>{v < 0 ? "−" : ""}{formatRupees(Math.abs(v))}</span>;
      }
    },
    { key: "r", header: "Running total", render: (r) => {
        const v = Number(r.running_total_inr);
        const tone = v >= 0 ? "text-[var(--color-ok)] font-semibold" : "text-[var(--color-danger)] font-semibold";
        return <span className={`text-xs tabular-nums ${tone}`}>{v < 0 ? "−" : ""}{formatRupees(Math.abs(v))}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool running balance by week (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Weekly grain of /amc-pool-running-balance (r1066, monthly) · cumulative pool float trajectory
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No pool activity in last 13 weeks." />
    </div>
  );
}
