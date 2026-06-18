import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "AMC pool burn rate × tier — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  tier: string;
  active_amcs: number;
  total_balance_inr: number;
  debits_last_30d_inr: number;
  avg_monthly_burn_per_amc: number;
  est_months_to_zero: number;
};

export default async function AmcPoolBurnRateByTierPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_burn_rate_by_tier");
  if (error) throw new Error(`founder_amc_pool_burn_rate_by_tier: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-medium uppercase tracking-wide">{r.tier}</span> },
    { key: "a", header: "Active", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.active_amcs)}</span> },
    { key: "b", header: "Total balance", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_balance_inr))}</span> },
    { key: "d", header: "30d debits", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatRupees(Number(r.debits_last_30d_inr))}</span> },
    { key: "avg", header: "Avg burn/AMC", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.avg_monthly_burn_per_amc))}</span> },
    { key: "m", header: "Months to zero", render: (r) => {
        const v = Number(r.est_months_to_zero);
        const tone = v === 0 ? "text-[var(--color-muted)]" : v < 2 ? "text-[var(--color-danger)] font-medium" : v < 4 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums ${tone}`}>{v === 0 ? "—" : `${v.toFixed(1)}mo`}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool burn rate × tier</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Predicts time-to-zero per tier · &lt;2mo = top-up campaign needed · pair with /amc-pool-zero-balance (r1011)
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.tier} emptyMessage="No active AMCs with pool activity." />
    </div>
  );
}
