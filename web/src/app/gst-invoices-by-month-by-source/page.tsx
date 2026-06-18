import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "GST invoices by month × source — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  month_ist: string;
  total_cnt: number;
  repair_job_platform_fee_cnt: number;
  amc_visit_platform_fee_cnt: number;
  spare_part_platform_fee_cnt: number;
  engineer_service_cnt: number;
  refund_credit_note_cnt: number;
  amc_subscription_fee_cnt: number;
  total_taxable_inr: number;
  total_gst_inr: number;
  total_invoice_inr: number;
};

export default async function GstInvoicesByMonthBySourcePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_gst_invoices_by_month_by_source");
  if (error) throw new Error(`founder_gst_invoices_by_month_by_source: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const grandGst = rows.reduce((a, r) => a + Number(r.total_gst_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total_cnt)}</span> },
    { key: "rj", header: "Repair", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.repair_job_platform_fee_cnt)}</span> },
    { key: "av", header: "AMC visit", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.amc_visit_platform_fee_cnt)}</span> },
    { key: "sp", header: "Spare", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.spare_part_platform_fee_cnt)}</span> },
    { key: "es", header: "Eng→Hosp", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.engineer_service_cnt)}</span> },
    { key: "cn", header: "Credit", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.refund_credit_note_cnt)}</span> },
    { key: "as", header: "AMC sub", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.amc_subscription_fee_cnt)}</span> },
    { key: "tx", header: "Taxable", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_taxable_inr))}</span> },
    { key: "gst", header: "GST", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_gst_inr))}</span> },
    { key: "inv", header: "Invoice", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_invoice_inr))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">GST invoices by month × source</h1>
        <span className="text-xs text-[var(--color-muted)]">
          12mo · grand GST collected: <span className="font-mono tabular-nums">{formatRupees(grandGst)}</span> · tax compliance + revenue breakdown
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No invoices yet." />
    </div>
  );
}
