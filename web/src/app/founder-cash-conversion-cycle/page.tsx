import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = {
  title: "Cash conversion cycle · EquipSeva Founder",
  description:
    "DSO + DPO + inventory days → CCC. AR/AP aging buckets, net working capital, 12-week trend. Read-only aggregator across gst_invoices and spare_part_orders.",
};
export const dynamic = "force-dynamic";

type Summary = {
  dso_days_avg_90d: number | null;
  dpo_days_avg_90d: number | null;
  inventory_days_avg_90d: number | null;
  cash_conversion_cycle_days: number | null;
  total_outstanding_receivables_rupees: number | null;
  total_outstanding_payables_rupees: number | null;
  net_working_capital_rupees: number | null;
  ar_aging_0_30_rupees: number | null;
  ar_aging_31_60_rupees: number | null;
  ar_aging_61_90_rupees: number | null;
  ar_aging_over_90_rupees: number | null;
  ap_aging_0_30_rupees: number | null;
  ap_aging_31_60_rupees: number | null;
  ap_aging_61_90_rupees: number | null;
  ap_aging_over_90_rupees: number | null;
  generated_at: string | null;
};

type HistoryRow = {
  week_start: string | null;
  dso_days_avg: number | null;
  dpo_days_avg: number | null;
  cash_conversion_cycle_days: number | null;
  net_working_capital_rupees: number | null;
};

function fmtRup(n: number | null | undefined): string {
  if (n == null) return "0";
  return formatNumber(Math.round(Number(n)));
}

function fmtDays(n: number | null | undefined): string {
  if (n == null) return "0";
  const v = Number(n);
  return `${v.toFixed(1)} d`;
}

function fmtSignedRup(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  const sign = v < 0 ? "-" : "";
  return `${sign}₹${formatNumber(Math.abs(Math.round(v)))}`;
}

function cccTone(days: number | null | undefined): "ok" | "warn" | "danger" {
  const v = Number(days ?? 0);
  if (v <= 30) return "ok";
  if (v <= 60) return "warn";
  return "danger";
}

export default async function FounderCashConversionCyclePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, historyRes] = await Promise.all([
    supabase.rpc("founder_cash_conversion_cycle_summary"),
    supabase.rpc("founder_cash_conversion_history", { p_weeks: 12 }),
  ]);

  const summary: Summary = (summaryRes.data?.[0] ?? {}) as Summary;
  const history: HistoryRow[] = (historyRes.data ?? []) as HistoryRow[];
  const errMsg = summaryRes.error?.message ?? historyRes.error?.message ?? null;

  const ccc = Number(summary.cash_conversion_cycle_days ?? 0);
  const tone = cccTone(ccc);
  const heroToneClass =
    tone === "ok"
      ? "text-[var(--color-ok)]"
      : tone === "warn"
      ? "text-[var(--color-warn)]"
      : "text-[var(--color-danger)]";
  const heroBorderClass =
    tone === "ok"
      ? "border-[var(--color-ok)]"
      : tone === "warn"
      ? "border-[var(--color-warn)]"
      : "border-[var(--color-danger)]";

  return (
    <main className="mx-auto max-w-7xl px-4 py-8">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold">Cash conversion cycle</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          DSO (days sales outstanding) - DPO (days payable outstanding) + inventory days = CCC.
          Lower is better. Pure aggregator across gst_invoices (AR) and spare_part_orders (AP).
          90-day rolling window for averages.
        </p>
      </header>

      {errMsg ? (
        <div className="mb-6 rounded border border-[var(--color-danger)] bg-[var(--color-danger)]/10 p-3 text-sm text-[var(--color-danger)]">
          Failed to load CCC: {errMsg}
        </div>
      ) : null}

      <section className={`mb-8 rounded-lg border-2 ${heroBorderClass} bg-[var(--color-surface)] p-8 text-center`}>
        <div className="text-sm uppercase tracking-wide text-[var(--color-muted)]">
          Cash conversion cycle
        </div>
        <div className={`mt-2 text-7xl font-bold ${heroToneClass}`}>
          {Number(ccc).toFixed(1)}
        </div>
        <div className="mt-2 text-lg text-[var(--color-muted)]">days</div>
        <div className="mt-3 text-xs text-[var(--color-muted)]">
          band: ≤30 d ok · ≤60 d warn · {">"} 60 d danger
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-medium">Working capital cycle drivers</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Card label="DSO (90d avg)" value={fmtDays(summary.dso_days_avg_90d)} sub="invoice issue → paid" tone="info" />
          <Card label="DPO (90d avg)" value={fmtDays(summary.dpo_days_avg_90d)} sub="vendor order → paid" tone="info" />
          <Card label="Inventory days (90d)" value={fmtDays(summary.inventory_days_avg_90d)} sub="spare parts hold time" tone="info" />
          <Card
            label="Net working capital"
            value={fmtSignedRup(summary.net_working_capital_rupees)}
            sub="AR - AP"
            tone={Number(summary.net_working_capital_rupees ?? 0) >= 0 ? "ok" : "danger"}
          />
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-medium">Outstanding balances</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <Card label="Total receivables (AR)" value={`₹${fmtRup(summary.total_outstanding_receivables_rupees)}`} sub="gst_invoices status='issued'" tone="info" />
          <Card label="Total payables (AP)" value={`₹${fmtRup(summary.total_outstanding_payables_rupees)}`} sub="spare_part_orders unpaid" tone="warn" />
          <Card label="Net position" value={fmtSignedRup(summary.net_working_capital_rupees)} sub="working capital balance" tone={Number(summary.net_working_capital_rupees ?? 0) >= 0 ? "ok" : "danger"} />
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-medium">Accounts receivable aging</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Card label="AR 0–30 days" value={`₹${fmtRup(summary.ar_aging_0_30_rupees)}`} tone="ok" />
          <Card label="AR 31–60 days" value={`₹${fmtRup(summary.ar_aging_31_60_rupees)}`} tone="info" />
          <Card label="AR 61–90 days" value={`₹${fmtRup(summary.ar_aging_61_90_rupees)}`} tone="warn" />
          <Card label="AR ≥ 90 days" value={`₹${fmtRup(summary.ar_aging_over_90_rupees)}`} sub="collections risk" tone="danger" />
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-medium">Accounts payable aging</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Card label="AP 0–30 days" value={`₹${fmtRup(summary.ap_aging_0_30_rupees)}`} tone="ok" />
          <Card label="AP 31–60 days" value={`₹${fmtRup(summary.ap_aging_31_60_rupees)}`} tone="info" />
          <Card label="AP 61–90 days" value={`₹${fmtRup(summary.ap_aging_61_90_rupees)}`} tone="warn" />
          <Card label="AP ≥ 90 days" value={`₹${fmtRup(summary.ap_aging_over_90_rupees)}`} sub="supplier-trust risk" tone="danger" />
        </div>
      </section>

      <section className="mb-4">
        <h2 className="text-lg font-medium">12-week trend</h2>
        <p className="mt-1 text-xs text-[var(--color-muted)]">
          Weekly DSO, DPO, CCC (DSO - DPO), and NWC (AR - AP) snapshots. Older weeks at the bottom.
        </p>
      </section>

      <section className="overflow-x-auto rounded border border-[var(--color-border)]">
        <table className="min-w-full text-sm">
          <thead className="bg-[var(--color-surface-muted)] text-left">
            <tr>
              <th className="px-3 py-2 font-medium">Week start</th>
              <th className="px-3 py-2 text-right font-medium">DSO (days)</th>
              <th className="px-3 py-2 text-right font-medium">DPO (days)</th>
              <th className="px-3 py-2 text-right font-medium">CCC (days)</th>
              <th className="px-3 py-2 text-right font-medium">NWC (₹)</th>
            </tr>
          </thead>
          <tbody>
            {history.length === 0 ? (
              <tr>
                <td colSpan={5} className="px-3 py-6 text-center text-[var(--color-muted)]">
                  No history yet. Once invoices and orders accrue, weekly buckets fill in.
                </td>
              </tr>
            ) : (
              history.map((r, i) => {
                const cccDays = Number(r.cash_conversion_cycle_days ?? 0);
                const rowTone = cccTone(cccDays);
                const cccClass =
                  rowTone === "ok"
                    ? "text-[var(--color-ok)]"
                    : rowTone === "warn"
                    ? "text-[var(--color-warn)]"
                    : "text-[var(--color-danger)]";
                const nwc = Number(r.net_working_capital_rupees ?? 0);
                const nwcClass = nwc >= 0 ? "text-[var(--color-ok)]" : "text-[var(--color-danger)]";
                return (
                  <tr key={`${r.week_start ?? "w"}-${i}`} className="border-t border-[var(--color-border)]">
                    <td className="px-3 py-2 font-mono text-xs">
                      {r.week_start ? new Date(r.week_start).toISOString().slice(0, 10) : "—"}
                    </td>
                    <td className="px-3 py-2 text-right">{fmtDays(r.dso_days_avg)}</td>
                    <td className="px-3 py-2 text-right">{fmtDays(r.dpo_days_avg)}</td>
                    <td className={`px-3 py-2 text-right font-semibold ${cccClass}`}>
                      {fmtDays(r.cash_conversion_cycle_days)}
                    </td>
                    <td className={`px-3 py-2 text-right ${nwcClass}`}>
                      {fmtSignedRup(r.net_working_capital_rupees)}
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </section>

      <p className="mt-6 text-xs text-[var(--color-muted)]">
        Source: public.gst_invoices (AR — status='issued' is outstanding; non-issued is paid proxy) +
        public.spare_part_orders (AP — payment_status='paid' is paid; otherwise outstanding unless
        cancelled/refunded). DSO and DPO use updated_at minus origination as days-to-pay over a 90d
        rolling window. CCC = DSO - DPO + inventory days. NWC = total AR - total AP. Refresh on page
        load via founder_cash_conversion_cycle_summary().
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
