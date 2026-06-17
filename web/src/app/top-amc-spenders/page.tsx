import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Top AMC spenders — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { hospital_user_id: string; display_name: string; city: string; credit_rupees_90d: number; active_contracts: number };

export default async function TopAmcSpendersPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_top_amc_spenders");
  if (error) throw new Error(`founder_top_amc_spenders: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Hospital", render: (r) => <span className="text-xs font-semibold">{r.display_name}</span> },
    { key: "c", header: "City", render: (r) => <span className="text-xs text-[var(--color-muted)]">{r.city}</span> },
    { key: "r", header: "Credited 90d (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.credit_rupees_90d)}</span> },
    { key: "a", header: "Active AMCs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.active_contracts)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Top AMC spenders (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 50 hospitals by 90d pool credits</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.hospital_user_id} emptyMessage="No pool credits." />
    </div>
  );
}
