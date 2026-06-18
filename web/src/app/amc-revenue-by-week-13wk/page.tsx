import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatRupees } from "@/lib/format";

export const metadata = { title: "AMC revenue by week 13wk — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  week_start: string;
  new_mrr_inr: number;
  expired_mrr_inr: number;
  net_mrr_change: number;
};

export default async function AmcRevenueByWeek13wkPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_revenue_by_week_13wk");
  if (error) throw new Error(`founder_amc_revenue_by_week_13wk: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "n", header: "New MRR", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">+{formatRupees(Number(r.new_mrr_inr))}</span> },
    { key: "e", header: "Expired MRR", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">−{formatRupees(Number(r.expired_mrr_inr))}</span> },
    { key: "x", header: "Net change", render: (r) => {
        const v = Number(r.net_mrr_change);
        const tone = v >= 0 ? "text-[var(--color-ok)] font-semibold" : "text-[var(--color-danger)] font-semibold";
        return <span className={`text-xs tabular-nums ${tone}`}>{v < 0 ? "−" : "+"}{formatRupees(Math.abs(v))}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC revenue by week (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Weekly new MRR − expired MRR = net MRR change · revenue health pulse
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No AMC activity in last 13 weeks." />
    </div>
  );
}
