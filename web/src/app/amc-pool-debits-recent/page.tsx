import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC pool debits recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { id: string; amc_contract_id: string; hospital_name: string; amount_rupees: number; balance_after: number; created_at: string };

export default async function AmcPoolDebitsRecentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_debits_recent");
  if (error) throw new Error(`founder_amc_pool_debits_recent: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "When", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.created_at).toLocaleString()}</span> },
    { key: "n", header: "Hospital", render: (r) => <span className="text-xs font-semibold">{r.hospital_name}</span> },
    { key: "a", header: "Debited (₹)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.amount_rupees)}</span> },
    { key: "b", header: "Balance after (₹)",
      render: (r) => {
        const tone = r.balance_after < 0 ? "text-[var(--color-danger)]"
          : r.balance_after < 1000 ? "text-[var(--color-warn)]" : "text-[var(--color-fg)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatNumber(r.balance_after)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool debits recent (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Last 100 pool debits · balance-after tone warns on low/negative</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.id} emptyMessage="No pool debits." />
    </div>
  );
}
