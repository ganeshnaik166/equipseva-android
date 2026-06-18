import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatRupees } from "@/lib/format";

export const metadata = { title: "AMC pool net flow by week 13wk — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  week_start: string;
  credits_inr: number;
  debits_inr: number;
  refunds_inr: number;
  net_flow_inr: number;
};

export default async function AmcPoolNetFlowByWeek13wkPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_net_flow_by_week_13wk");
  if (error) throw new Error(`founder_amc_pool_net_flow_by_week_13wk: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "c", header: "Credits", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatRupees(Number(r.credits_inr))}</span> },
    { key: "d", header: "Debits", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">−{formatRupees(Number(r.debits_inr))}</span> },
    { key: "r", header: "Refunds", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">−{formatRupees(Number(r.refunds_inr))}</span> },
    { key: "n", header: "Net flow", render: (r) => {
        const v = Number(r.net_flow_inr);
        const tone = v >= 0 ? "text-[var(--color-ok)] font-semibold" : "text-[var(--color-danger)] font-semibold";
        return <span className={`text-xs tabular-nums ${tone}`}>{v < 0 ? "−" : ""}{formatRupees(Math.abs(v))}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool net flow by week (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Credits − (debits + refunds) per week · weekly grain of /amc-pool-net-flow-by-month (r1065)
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No pool activity in last 13 weeks." />
    </div>
  );
}
