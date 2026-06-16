import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Bonded dispatch status — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { status: string; cnt: number; total_qty: number };

export default async function BondedDispatchStatusPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_bonded_dispatch_status");
  if (error) throw new Error(`founder_bonded_dispatch_status: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "Status",
      render: (r) => {
        const tone = r.status === "installed" ? "text-[var(--color-ok)]"
          : r.status === "lost" ? "text-[var(--color-danger)]"
          : r.status === "returned" ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs font-semibold ${tone}`}>{r.status}</span>;
      }
    },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "q", header: "Total qty", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total_qty)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Bonded dispatch status</h1>
        <span className="text-xs text-[var(--color-muted)]">all-time bonded dispatches by status</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.status} emptyMessage="No dispatches." />
    </div>
  );
}
