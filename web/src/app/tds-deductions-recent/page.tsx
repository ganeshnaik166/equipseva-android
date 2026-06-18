import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "TDS deductions recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  id: string;
  engineer_name: string;
  fiscal_year: string;
  fy_quarter: string;
  gross_rupees: number;
  tds_rate_pct: number;
  tds_rupees: number;
  net_payable_rupees: number;
  deducted: boolean;
  deposited: boolean;
  created_at: string;
};

export default async function TdsDeductionsRecentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_tds_deductions_recent");
  if (error) throw new Error(`founder_tds_deductions_recent: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalTds = rows.reduce((n, r) => n + (r.tds_rupees ?? 0), 0);
  const undeposited = rows.filter((r) => r.deducted && !r.deposited).reduce((n, r) => n + (r.tds_rupees ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "t", header: "Created", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.created_at).toLocaleString()}</span> },
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs font-semibold">{r.engineer_name}</span> },
    { key: "fy", header: "FY", render: (r) => <span className="text-xs">{r.fiscal_year} {r.fy_quarter}</span> },
    { key: "g", header: "Gross", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.gross_rupees)}</span> },
    { key: "r", header: "Rate %", render: (r) => <span className="text-xs tabular-nums">{r.tds_rate_pct}%</span> },
    { key: "x", header: "TDS", render: (r) => <span className="text-xs tabular-nums font-semibold text-[var(--color-warn)]">{formatNumber(r.tds_rupees)}</span> },
    { key: "p", header: "Net", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.net_payable_rupees)}</span> },
    { key: "d", header: "Deposited",
      render: (r) => r.deposited
        ? <span className="text-xs text-[var(--color-ok)]">✓</span>
        : r.deducted ? <span className="text-xs text-[var(--color-warn)]">pending</span>
        : <span className="text-xs text-[var(--color-muted)]">below threshold</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">TDS deductions recent (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Total TDS ₹{formatNumber(totalTds)} · undeposited ₹{formatNumber(undeposited)}</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.id} emptyMessage="No TDS rows." />
    </div>
  );
}
