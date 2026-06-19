import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "GST invoice snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  invoices_today: number;
  invoices_mtd: number;
  taxable_value_today_rupees: number;
  taxable_value_mtd_rupees: number;
  gst_collected_mtd_rupees: number;
  intra_state_share_pct_mtd: number;
  inter_state_share_pct_mtd: number;
  rcm_invoices_mtd: number;
  recipient_gstin_missing_mtd: number;
  cancelled_or_revised_mtd: number;
  dispatch_success_pct_30d: number;
  dispatch_failed_30d: number;
};

function Card({ title, val, sub, danger, ok }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${danger ? "text-[var(--color-danger)]" : ok ? "text-[var(--color-ok)]" : ""}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

function fmtRupees(n: number): string {
  return `Rs ${formatNumber(Math.round(Number(n) || 0))}`;
}

export default async function GstInvoiceSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_gst_invoice_snapshot_summary");
  if (error) throw new Error(`founder_gst_invoice_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">GST invoice snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">12-KPI tax-audit dashboard · today/MTD/30d · catches dispatch silent failures pre-GSTR-1</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Invoices today" val={formatNumber(r.invoices_today)} sub="IST day, status=issued" />
          <Card title="Invoices MTD" val={formatNumber(r.invoices_mtd)} sub="month-to-date" />
          <Card title="Taxable value today" val={fmtRupees(r.taxable_value_today_rupees)} />
          <Card title="Taxable value MTD" val={fmtRupees(r.taxable_value_mtd_rupees)} ok />
          <Card title="GST collected MTD" val={fmtRupees(r.gst_collected_mtd_rupees)} sub="CGST+SGST+IGST" />
          <Card title="Intra-state share MTD" val={`${Number(r.intra_state_share_pct_mtd).toFixed(1)}%`} sub="CGST+SGST 9+9" />
          <Card title="Inter-state share MTD" val={`${Number(r.inter_state_share_pct_mtd).toFixed(1)}%`} sub="IGST 18" />
          <Card title="RCM invoices MTD" val={formatNumber(r.rcm_invoices_mtd)} sub="reverse-charge flagged" />
          <Card
            title="Recipient GSTIN missing MTD"
            val={formatNumber(r.recipient_gstin_missing_mtd)}
            sub="ITC-claim risk"
            danger={r.recipient_gstin_missing_mtd > 0}
          />
          <Card title="Cancelled/revised MTD" val={formatNumber(r.cancelled_or_revised_mtd)} sub="credit notes + revisions" />
          <Card
            title="Dispatch success 30d"
            val={`${Number(r.dispatch_success_pct_30d).toFixed(1)}%`}
            sub="email delivery"
            ok={r.dispatch_success_pct_30d >= 95}
            danger={r.dispatch_success_pct_30d < 80 && r.dispatch_failed_30d > 0}
          />
          <Card
            title="Dispatch failed 30d"
            val={formatNumber(r.dispatch_failed_30d)}
            sub="resend_failed + no_email"
            danger={r.dispatch_failed_30d > 0}
          />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}