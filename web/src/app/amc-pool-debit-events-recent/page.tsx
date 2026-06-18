import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatRupees, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "AMC pool debit events recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  created_at: string;
  amc_contract_id: string;
  hospital_name: string;
  tier: string;
  amount_rupees: number;
};

export default async function AmcPoolDebitEventsRecentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_debit_events_recent");
  if (error) throw new Error(`founder_amc_pool_debit_events_recent: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "When", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatRelativeTime(r.created_at)}</span> },
    { key: "h", header: "Hospital", render: (r) => <span className="text-xs font-medium">{r.hospital_name}</span> },
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-mono uppercase">{r.tier}</span> },
    { key: "a", header: "Amount", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">−{formatRupees(Number(r.amount_rupees))}</span> },
    { key: "i", header: "AMC ID", render: (r) => <span className="text-xs font-mono text-[var(--color-muted)]">{r.amc_contract_id.slice(0, 8)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool debit events (recent 100)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Visit/service consumption ledger · pair with /amc-pool-credit-events-recent (r1060)
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => `${r.amc_contract_id}-${r.created_at}`} emptyMessage="No debit events." />
    </div>
  );
}
