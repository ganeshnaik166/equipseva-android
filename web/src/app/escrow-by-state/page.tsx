import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Escrow by state — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { state: string; held_rupees: number; released_90d: number; refunded_90d: number };

export default async function EscrowByStatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_escrow_by_state");
  if (error) throw new Error(`founder_escrow_by_state: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "State", render: (r) => <span className="text-xs">{r.state}</span> },
    { key: "h", header: "Held (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.held_rupees)}</span> },
    { key: "rl", header: "Released 90d (₹)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.released_90d)}</span> },
    { key: "rf", header: "Refunded 90d (₹)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.refunded_90d)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Escrow by state</h1>
        <span className="text-xs text-[var(--color-muted)]">Held + released + refunded escrow per state · top 40</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.state} emptyMessage="No escrow." />
    </div>
  );
}
