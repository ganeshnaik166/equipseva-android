import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payouts net of TDS — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; gross_rupees: number; tds_withheld: number; net_paid: number; effective_tds_pct: number };

export default async function PayoutsNetOfTdsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_net_of_tds");
  if (error) throw new Error(`founder_payouts_net_of_tds: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "g", header: "Gross (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.gross_rupees)}</span> },
    { key: "t", header: "TDS withheld (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.tds_withheld)}</span> },
    { key: "n", header: "Net paid (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.net_paid)}</span> },
    { key: "p", header: "Effective TDS %", render: (r) => <span className="text-xs tabular-nums">{r.effective_tds_pct}%</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts net of TDS</h1>
        <span className="text-xs text-[var(--color-muted)]">Gross vs TDS withheld vs net paid, 30/90/365d</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No payouts." />
    </div>
  );
}
