import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC renewal by month × status — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; succeeded: number; failed: number; abandoned: number };

export default async function AmcRenewalByMonthByStatusPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_renewal_by_month_by_status");
  if (error) throw new Error(`founder_amc_renewal_by_month_by_status: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "s", header: "Succeeded", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.succeeded)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed)}</span> },
    { key: "a", header: "Abandoned", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.abandoned)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC renewal by month × status (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">Succeeded vs failed vs abandoned attempts per month</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No renewal attempts." />
    </div>
  );
}
