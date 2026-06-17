import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Escrow cumulative — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; released_rupees: number; refunded_rupees: number; cum_released: number; cum_refunded: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function EscrowCumulativePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_escrow_cumulative");
  if (error) throw new Error(`founder_escrow_cumulative: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "r", header: "Released (m)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{inr(Number(r.released_rupees))}</span> },
    { key: "f", header: "Refunded (m)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{inr(Number(r.refunded_rupees))}</span> },
    { key: "cr", header: "Cum released", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.cum_released))}</span> },
    { key: "cf", header: "Cum refunded", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.cum_refunded))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Escrow cumulative</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month cumulative released vs refunded</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No escrow activity." />
    </div>
  );
}
