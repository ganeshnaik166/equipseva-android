import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC pool balance by hospital — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { hospital_user_id: string; display_name: string; city: string; contracts: number; total_balance: number; monthly_fee_sum: number; buffer_months: number };

export default async function AmcPoolBalanceByHospitalPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_balance_by_hospital");
  if (error) throw new Error(`founder_amc_pool_balance_by_hospital: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Hospital", render: (r) => <span className="text-xs font-semibold">{r.display_name}</span> },
    { key: "c", header: "City", render: (r) => <span className="text-xs text-[var(--color-muted)]">{r.city}</span> },
    { key: "k", header: "Contracts", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.contracts)}</span> },
    { key: "b", header: "Balance (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total_balance)}</span> },
    { key: "m", header: "MRR (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.monthly_fee_sum)}</span> },
    { key: "x", header: "Buffer (mo)",
      render: (r) => {
        const tone = r.buffer_months < 1 ? "text-[var(--color-danger)]"
          : r.buffer_months < 2 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.buffer_months}×</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool balance by hospital</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 50 hospitals by total active-contract pool balance</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.hospital_user_id} emptyMessage="No active contracts." />
    </div>
  );
}
