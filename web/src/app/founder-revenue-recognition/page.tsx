import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = {
  title: "Revenue recognition · EquipSeva Founder",
  description:
    "Three definitions of revenue side-by-side: accrued (earned), invoiced (billed), cash (collected). 14 KPIs + 12-month trend. Read-only aggregator across amc_contracts, gst_invoices, payments.",
};
export const dynamic = "force-dynamic";

type Summary = {
  this_month_accrued_revenue_rupees: number | null;
  this_month_invoiced_rupees: number | null;
  this_month_cash_collected_rupees: number | null;
  last_month_accrued_rupees: number | null;
  last_month_invoiced_rupees: number | null;
  last_month_cash_collected_rupees: number | null;
  ytd_accrued_rupees: number | null;
  ytd_invoiced_rupees: number | null;
  ytd_cash_collected_rupees: number | null;
  mom_accrued_delta_pct: number | null;
  mom_cash_delta_pct: number | null;
  deferred_revenue_estimate_rupees: number | null;
  bad_debt_estimate_rupees: number | null;
  generated_at: string | null;
};

type HistoryRow = {
  month_start: string | null;
  accrued_rupees: number | null;
  invoiced_rupees: number | null;
  cash_collected_rupees: number | null;
  gst_remitted_rupees: number | null;
  net_recognized_rupees: number | null;
};

function fmtRup(n: number | null | undefined): string {
  if (n == null) return "0";
  return formatNumber(Math.round(Number(n)));
}

function fmtPct(n: number | null | undefined): string {
  if (n == null) return "0.00%";
  const v = Number(n);
  const sign = v > 0 ? "+" : "";
  return `${sign}${v.toFixed(2)}%`;
}

function pctTone(n: number | null | undefined): "ok" | "warn" | "danger" | "info" {
  const v = Number(n ?? 0);
  if (v >= 5) return "ok";
  if (v >= -5) return "info";
  if (v >= -15) return "warn";
  return "danger";
}

function fmtMonth(d: string | null | undefined): string {
  if (!d) return "—";
  return new Date(d).toISOString().slice(0, 7);
}

export default async function FounderRevenueRecognitionPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, historyRes] = await Promise.all([
    supabase.rpc("founder_revenue_recognition_summary"),
    supabase.rpc("founder_revenue_recognition_history", { p_months: 12 }),
  ]);

  const summary: Summary = (summaryRes.data?.[0] ?? {}) as Summary;
  const history: HistoryRow[] = (historyRes.data ?? []) as HistoryRow[];
  const errMsg = summaryRes.error?.message ?? historyRes.error?.message ?? null;

  return (
    <main className="mx-auto max-w-7xl px-4 py-8">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold">Revenue recognition</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Three lenses on the same business. Accrued = earned (AMC contracts × monthly fee).
          Invoiced = billed (gst_invoices issued, taxes included). Cash = bank-credited
          (payments captured). The gaps tell the working-capital story.
        </p>
      </header>

      {errMsg ? (
        <div className="mb-6 rounded border border-[var(--color-danger)] bg-[var(--color-danger)]/10 p-3 text-sm text-[var(--color-danger)]">
          Failed to load revenue recognition: {errMsg}
        </div>
      ) : null}

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-medium">Accrual basis (earned)</h2>
        <p className="mb-3 text-xs text-[var(--color-muted)]">
          Sum of monthly_fee_rupees across active AMC contracts overlapping the window.
          GAAP / Ind-AS view: revenue is recognized when service is provided, not when billed or paid.
        </p>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Card label="This month accrued" value={`₹${fmtRup(summary.this_month_accrued_revenue_rupees)}`} sub="active contracts · monthly fee" tone="ok" />
          <Card label="Last month accrued" value={`₹${fmtRup(summary.last_month_accrued_rupees)}`} sub="prior month baseline" tone="info" />
          <Card label="YTD accrued" value={`₹${fmtRup(summary.ytd_accrued_rupees)}`} sub="jan 1 → today" tone="info" />
          <Card label="MoM accrued delta" value={fmtPct(summary.mom_accrued_delta_pct)} sub="this vs last month" tone={pctTone(summary.mom_accrued_delta_pct)} />
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-medium">Invoiced basis (billed)</h2>
        <p className="mb-3 text-xs text-[var(--color-muted)]">
          Sum of gst_invoices issued in the window (taxable + CGST + SGST + IGST), excluding cancelled.
          Tax-authority view: what we declared to the GSTN.
        </p>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Card label="This month invoiced" value={`₹${fmtRup(summary.this_month_invoiced_rupees)}`} sub="gst_invoices issued · incl. tax" tone="info" />
          <Card label="Last month invoiced" value={`₹${fmtRup(summary.last_month_invoiced_rupees)}`} sub="prior month baseline" tone="info" />
          <Card label="YTD invoiced" value={`₹${fmtRup(summary.ytd_invoiced_rupees)}`} sub="jan 1 → today" tone="info" />
          <Card label="Deferred revenue" value={`₹${fmtRup(summary.deferred_revenue_estimate_rupees)}`} sub="invoiced − cash (all-time)" tone="warn" />
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-medium">Cash basis (collected)</h2>
        <p className="mb-3 text-xs text-[var(--color-muted)]">
          Sum of payments where status = {"'"}captured{"'"}. Treasury view: rupees actually in the bank.
          This is what funds payroll on the 1st.
        </p>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Card label="This month cash" value={`₹${fmtRup(summary.this_month_cash_collected_rupees)}`} sub="payments captured" tone="ok" />
          <Card label="Last month cash" value={`₹${fmtRup(summary.last_month_cash_collected_rupees)}`} sub="prior month baseline" tone="info" />
          <Card label="YTD cash" value={`₹${fmtRup(summary.ytd_cash_collected_rupees)}`} sub="jan 1 → today" tone="info" />
          <Card label="MoM cash delta" value={fmtPct(summary.mom_cash_delta_pct)} sub="this vs last month" tone={pctTone(summary.mom_cash_delta_pct)} />
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-medium">Recognition quality</h2>
        <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
          <Card label="Deferred revenue estimate" value={`₹${fmtRup(summary.deferred_revenue_estimate_rupees)}`} sub="invoices issued but cash not yet received · funds customers' float" tone="warn" />
          <Card label="Bad-debt estimate" value={`₹${fmtRup(summary.bad_debt_estimate_rupees)}`} sub="invoices issued ≥ 90 days ago still in status='issued'" tone="danger" />
        </div>
      </section>

      <section className="mb-4">
        <h2 className="text-lg font-medium">12-month trend</h2>
        <p className="mt-1 text-xs text-[var(--color-muted)]">
          Monthly accrued vs invoiced vs cash. GST remitted = CGST + SGST + IGST (the chunk that
          isn{"'"}t ours). Net recognized = invoiced − GST remitted (revenue net of statutory pass-through).
        </p>
      </section>

      <section className="overflow-x-auto rounded border border-[var(--color-border)]">
        <table className="min-w-full text-sm">
          <thead className="bg-[var(--color-surface-muted)] text-left">
            <tr>
              <th className="px-3 py-2 font-medium">Month</th>
              <th className="px-3 py-2 text-right font-medium">Accrued (₹)</th>
              <th className="px-3 py-2 text-right font-medium">Invoiced (₹)</th>
              <th className="px-3 py-2 text-right font-medium">Cash (₹)</th>
              <th className="px-3 py-2 text-right font-medium">GST remitted (₹)</th>
              <th className="px-3 py-2 text-right font-medium">Net recognized (₹)</th>
            </tr>
          </thead>
          <tbody>
            {history.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-3 py-6 text-center text-[var(--color-muted)]">
                  No history yet. Once contracts, invoices, and payments accrue, monthly buckets fill in.
                </td>
              </tr>
            ) : (
              history.map((r, i) => {
                const accr = Number(r.accrued_rupees ?? 0);
                const cash = Number(r.cash_collected_rupees ?? 0);
                const gap = accr - cash;
                const gapClass = gap > 0
                  ? "text-[var(--color-warn)]"
                  : "text-[var(--color-ok)]";
                return (
                  <tr key={`${r.month_start ?? "m"}-${i}`} className="border-t border-[var(--color-border)]">
                    <td className="px-3 py-2 font-mono text-xs">{fmtMonth(r.month_start)}</td>
                    <td className="px-3 py-2 text-right">₹{fmtRup(r.accrued_rupees)}</td>
                    <td className="px-3 py-2 text-right">₹{fmtRup(r.invoiced_rupees)}</td>
                    <td className={`px-3 py-2 text-right font-semibold ${gapClass}`}>₹{fmtRup(r.cash_collected_rupees)}</td>
                    <td className="px-3 py-2 text-right text-[var(--color-muted)]">₹{fmtRup(r.gst_remitted_rupees)}</td>
                    <td className="px-3 py-2 text-right">₹{fmtRup(r.net_recognized_rupees)}</td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </section>

      <section className="mt-6 rounded border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)]">
        <h3 className="mb-2 text-sm font-medium text-[var(--color-fg)]">Revenue-recognition policy</h3>
        <ul className="ml-4 list-disc space-y-1">
          <li>
            <span className="font-medium text-[var(--color-fg)]">Accrual basis:</span> AMC monthly fees
            are EARNED daily (1/30th per day) but recognized in monthly buckets here for readability.
            Active contracts contribute their full monthly_fee for any month their span overlaps.
          </li>
          <li>
            <span className="font-medium text-[var(--color-fg)]">Invoiced basis:</span> Invoices are
            issued monthly (gst_invoices.status = {"'"}issued{"'"}). Cancelled invoices are excluded;
            revised invoices count their net amount (taxable + all tax components).
          </li>
          <li>
            <span className="font-medium text-[var(--color-fg)]">Cash basis:</span> Cash is recognized
            when payments.status = {"'"}captured{"'"} — gateway confirmed, settlement may still take
            T+2. Excludes refunds and disputes.
          </li>
          <li>
            <span className="font-medium text-[var(--color-fg)]">Deferred revenue:</span> Invoices
            issued but not yet collected. The bigger this gets the more we{"'"}re financing customers.
          </li>
          <li>
            <span className="font-medium text-[var(--color-fg)]">Bad-debt estimate:</span> Conservative
            proxy: invoices still status={"'"}issued{"'"} after 90 days. Real bad-debt requires
            individual write-off review.
          </li>
          <li>
            <span className="font-medium text-[var(--color-fg)]">GST remitted:</span> CGST + SGST + IGST.
            Statutory pass-through, not ours. Net recognized = invoiced − tax.
          </li>
        </ul>
      </section>

      <p className="mt-6 text-xs text-[var(--color-muted)]">
        Source: public.amc_contracts (accrual base · status={"'"}active{"'"}) + public.gst_invoices
        (issued ledger · status {"<>"} {"'"}cancelled{"'"}) + public.payments (cash captured ·
        status={"'"}captured{"'"}). Aggregator only; no writes. Refresh on page load via
        founder_revenue_recognition_summary() and founder_revenue_recognition_history(12).
      </p>
    </main>
  );
}

function Card({
  label,
  value,
  sub,
  tone,
}: {
  label: string;
  value: string;
  sub?: string;
  tone?: "info" | "warn" | "danger" | "ok" | "accent";
}) {
  const toneClass =
    tone === "danger"
      ? "text-[var(--color-danger)]"
      : tone === "warn"
      ? "text-[var(--color-warn)]"
      : tone === "ok"
      ? "text-[var(--color-ok)]"
      : tone === "info"
      ? "text-[var(--color-info)]"
      : tone === "accent"
      ? "text-[var(--color-accent)]"
      : "";
  return (
    <div className="rounded border border-[var(--color-border)] bg-[var(--color-surface)] p-3">
      <div className="text-xs text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-lg font-semibold ${toneClass}`}>{value}</div>
      {sub ? <div className="mt-0.5 text-xs text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}