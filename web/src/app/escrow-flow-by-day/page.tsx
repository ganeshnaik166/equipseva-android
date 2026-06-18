import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Escrow flow by day — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { day_ist: string; inflow_rupees: number; release_rupees: number; refund_rupees: number; net_rupees: number };

export default async function EscrowFlowByDayPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_escrow_flow_by_day");
  if (error) throw new Error(`founder_escrow_flow_by_day: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalIn = rows.reduce((n, r) => n + (r.inflow_rupees ?? 0), 0);
  const totalOut = rows.reduce((n, r) => n + (r.release_rupees ?? 0) + (r.refund_rupees ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Day (IST)", render: (r) => <span className="text-xs tabular-nums">{r.day_ist}</span> },
    { key: "i", header: "Inflow (₹)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.inflow_rupees)}</span> },
    { key: "r", header: "Released (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.release_rupees)}</span> },
    { key: "f", header: "Refunded (₹)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.refund_rupees)}</span> },
    { key: "n", header: "Net (₹)",
      render: (r) => {
        const tone = r.net_rupees < 0 ? "text-[var(--color-danger)]" : "text-[var(--color-fg)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatNumber(r.net_rupees)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Escrow flow by day (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">In ₹{formatNumber(totalIn)} · Out ₹{formatNumber(totalOut)}</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No escrow activity." />
    </div>
  );
}
