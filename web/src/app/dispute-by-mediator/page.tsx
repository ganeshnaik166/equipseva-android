import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Dispute by mediator — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { mediator_user_id: string; mediator_name: string; decisions_90d: number; accepted: number; rejected: number };

export default async function DisputeByMediatorPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_dispute_by_mediator");
  if (error) throw new Error(`founder_dispute_by_mediator: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Mediator", render: (r) => <span className="text-xs font-semibold">{r.mediator_name}</span> },
    { key: "d", header: "Decisions (90d)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.decisions_90d)}</span> },
    { key: "a", header: "Accepted", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.accepted)}</span> },
    { key: "r", header: "Rejected", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.rejected)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Dispute by mediator (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 50 mediators by decision volume + accept/reject split</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.mediator_user_id} emptyMessage="No mediator decisions." />
    </div>
  );
}
