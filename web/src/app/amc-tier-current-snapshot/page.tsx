import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "AMC tier current snapshot — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  tier: string;
  active_cnt: number;
  paused_cnt: number;
  expired_cnt: number;
  avg_amount_inr: number;
  total_mrr_inr: number;
  avg_pool_inr: number;
  avg_days_to_end: number;
};

export default async function AmcTierCurrentSnapshotPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_tier_current_snapshot");
  if (error) throw new Error(`founder_amc_tier_current_snapshot: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalMrr = rows.reduce((a, r) => a + Number(r.total_mrr_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-medium uppercase tracking-wide">{r.tier}</span> },
    { key: "a", header: "Active", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.active_cnt)}</span> },
    { key: "p", header: "Paused", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.paused_cnt)}</span> },
    { key: "e", header: "Expired", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.expired_cnt)}</span> },
    { key: "av", header: "Avg INR/AMC", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.avg_amount_inr))}</span> },
    { key: "m", header: "Total MRR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_mrr_inr))}</span> },
    { key: "ap", header: "Avg pool", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.avg_pool_inr))}</span> },
    { key: "d", header: "Avg days→end", render: (r) => <span className="text-xs tabular-nums">{Number(r.avg_days_to_end ?? 0).toFixed(0)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC tier current snapshot</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Grand active MRR: <span className="font-mono tabular-nums">{formatRupees(totalMrr)}</span> · per-tier health view
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.tier} emptyMessage="No AMC contracts." />
    </div>
  );
}
