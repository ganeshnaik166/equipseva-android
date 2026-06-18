import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "State coverage — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  state: string;
  engineers_total: number;
  engineers_verified: number;
  hospitals_total: number;
  amcs_active: number;
  amcs_active_mrr_inr: number;
};

export default async function StateCoveragePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_state_coverage");
  if (error) throw new Error(`founder_state_coverage: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalMrr = rows.reduce((a, r) => a + Number(r.amcs_active_mrr_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "s", header: "State", render: (r) => <span className="text-xs font-medium">{r.state}</span> },
    { key: "et", header: "Engineers", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.engineers_total)}</span> },
    { key: "ev", header: "Verified", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.engineers_verified)}</span> },
    { key: "ht", header: "Hospitals", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.hospitals_total)}</span> },
    { key: "a", header: "AMCs active", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.amcs_active)}</span> },
    { key: "m", header: "Active MRR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.amcs_active_mrr_inr))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">State coverage</h1>
        <span className="text-xs text-[var(--color-muted)]">
          All states · grand active AMC MRR: <span className="font-mono tabular-nums">{formatRupees(totalMrr)}</span>
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.state} emptyMessage="No state data." />
    </div>
  );
}
