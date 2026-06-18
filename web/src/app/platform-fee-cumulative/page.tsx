import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatRupees } from "@/lib/format";

export const metadata = { title: "Platform fee cumulative — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  month_ist: string;
  monthly_fee_inr: number;
  cumulative_fee_inr: number;
};

export default async function PlatformFeeCumulativePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_platform_fee_cumulative");
  if (error) throw new Error(`founder_platform_fee_cumulative: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const grandCum = rows.length > 0 ? Number(rows[0].cumulative_fee_inr ?? 0) : 0;
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "f", header: "Monthly fee", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.monthly_fee_inr))}</span> },
    { key: "c", header: "Cumulative", render: (r) => <span className="text-xs tabular-nums font-semibold text-[var(--color-ok)]">{formatRupees(Number(r.cumulative_fee_inr))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Platform fee cumulative (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          12mo cumulative platform-fee revenue · grand total: <span className="font-mono tabular-nums text-[var(--color-ok)]">{formatRupees(grandCum)}</span>
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No platform-fee invoices yet." />
    </div>
  );
}
