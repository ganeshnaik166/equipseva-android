import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatRupees } from "@/lib/format";

export const metadata = { title: "AMC pool top balances — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  amc_contract_id: string;
  hospital_name: string;
  tier: string;
  monthly_fee: number;
  pool_balance: number;
  end_date: string | null;
};

export default async function AmcPoolTopBalancesPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_top_balances");
  if (error) throw new Error(`founder_amc_pool_top_balances: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "h", header: "Hospital", render: (r) => <span className="text-xs font-medium">{r.hospital_name}</span> },
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-mono uppercase">{r.tier}</span> },
    { key: "f", header: "Monthly fee", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.monthly_fee))}</span> },
    { key: "b", header: "Pool balance", render: (r) => <span className="text-xs tabular-nums font-semibold text-[var(--color-ok)]">{formatRupees(Number(r.pool_balance))}</span> },
    { key: "e", header: "End date", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.end_date ?? "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool top balances</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Top 50 active AMCs by current pool balance · upsell candidates (large unused float)
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.amc_contract_id} emptyMessage="No active AMCs." />
    </div>
  );
}
