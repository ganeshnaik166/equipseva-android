import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Escrow by month — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; released_count: number; released_rupees: number; refunded_count: number; refunded_rupees: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function EscrowByMonthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_escrow_by_month");
  if (error) throw new Error(`founder_escrow_by_month: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "rc", header: "Released", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.released_count)}</span> },
    { key: "rr", header: "Released rupees", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.released_rupees))}</span> },
    { key: "fc", header: "Refunded", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.refunded_count)}</span> },
    { key: "fr", header: "Refunded rupees", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.refunded_rupees))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Escrow by month</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month released vs refunded</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No escrow activity." />
    </div>
  );
}
