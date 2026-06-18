import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Supervised by day 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  day_ist: string;
  requested: number;
  active: number;
  successful: number;
  failed: number;
  declined: number;
};

export default async function SupervisedByDay30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_supervised_by_day_30d");
  if (error) throw new Error(`founder_supervised_by_day_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalSucc = rows.reduce((a, r) => a + (r.successful ?? 0), 0);
  const totalReq = rows.reduce((a, r) => a + (r.requested ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Day", render: (r) => <span className="text-xs tabular-nums">{r.day_ist}</span> },
    { key: "r", header: "Requested", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.requested)}</span> },
    { key: "a", header: "Active", render: (r) => <span className="text-xs tabular-nums text-[var(--color-info)]">{formatNumber(r.active)}</span> },
    { key: "s", header: "Successful", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.successful)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed)}</span> },
    { key: "dc", header: "Declined", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.declined)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Supervised by day (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          30d requested: <span className="font-mono tabular-nums">{formatNumber(totalReq)}</span> · successful: <span className="font-mono tabular-nums text-[var(--color-ok)]">{formatNumber(totalSucc)}</span> · supervised training pulse
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No supervised assignments in last 30 days." />
    </div>
  );
}
