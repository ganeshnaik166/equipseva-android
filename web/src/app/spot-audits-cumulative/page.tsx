import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spot audits cumulative — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; invitations: number; cum_inv: number; responses: number; cum_resp: number };

export default async function SpotAuditsCumulativePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spot_audits_cumulative");
  if (error) throw new Error(`founder_spot_audits_cumulative: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "i", header: "Invitations (m)", render: (r) => <span className="text-xs tabular-nums">+{formatNumber(r.invitations)}</span> },
    { key: "ci", header: "Cum invitations", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cum_inv)}</span> },
    { key: "r", header: "Responses (m)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">+{formatNumber(r.responses)}</span> },
    { key: "cr", header: "Cum responses", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cum_resp)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spot audits cumulative</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month cumulative spot audits</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No spot audits." />
    </div>
  );
}
