import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Escrow by week — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { week_start: string; released_count: number; released_rupees: number; refunded_count: number; refunded_rupees: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function EscrowByWeekPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_escrow_by_week");
  if (error) throw new Error(`founder_escrow_by_week: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs">{new Date(r.week_start).toLocaleDateString("en-IN", { day: "numeric", month: "short" })}</span> },
    { key: "rc", header: "Released", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.released_count)}</span> },
    { key: "rr", header: "Released ₹", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.released_rupees))}</span> },
    { key: "fc", header: "Refunded", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.refunded_count)}</span> },
    { key: "fr", header: "Refunded ₹", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.refunded_rupees))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Escrow by week</h1>
        <span className="text-xs text-[var(--color-muted)]">last 13 weeks</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No escrow activity." />
    </div>
  );
}
