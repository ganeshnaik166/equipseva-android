import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatRupees } from "@/lib/format";

export const metadata = { title: "Platform fee revenue by month — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  month_ist: string;
  repair_job_fee: number;
  amc_visit_fee: number;
  spare_part_fee: number;
  amc_sub_fee: number;
  total_fee_inr: number;
};

export default async function PlatformFeeRevenueByMonthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_platform_fee_revenue_by_month");
  if (error) throw new Error(`founder_platform_fee_revenue_by_month: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const grandTotal = rows.reduce((a, r) => a + Number(r.total_fee_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "rj", header: "Repair job", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.repair_job_fee))}</span> },
    { key: "av", header: "AMC visit", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.amc_visit_fee))}</span> },
    { key: "sp", header: "Spare part", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.spare_part_fee))}</span> },
    { key: "as", header: "AMC sub", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatRupees(Number(r.amc_sub_fee))}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatRupees(Number(r.total_fee_inr))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Platform fee revenue by month</h1>
        <span className="text-xs text-[var(--color-muted)]">
          12mo · grand platform-fee revenue: <span className="font-mono tabular-nums">{formatRupees(grandTotal)}</span>
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No platform-fee invoices yet." />
    </div>
  );
}
