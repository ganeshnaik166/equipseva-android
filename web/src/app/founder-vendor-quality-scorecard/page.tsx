import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = {
  title: "Vendor quality scorecard · EquipSeva Founder",
  description:
    "Supplier quality scorecards aggregated from spare_part_orders and founder_vendor_contracts (r1369). 18 KPIs, 50-row scorecard, at-risk banner, 12-month trend.",
};
export const dynamic = "force-dynamic";

type Summary = {
  total_active_vendors: number | null;
  total_orders_lifetime: number | null;
  total_orders_90d: number | null;
  total_orders_30d: number | null;
  avg_on_time_pct: number | null;
  defect_rate_pct: number | null;
  avg_lead_time_days_90d: number | null;
  avg_unit_price_rupees: number | null;
  total_returned_orders: number | null;
  late_delivery_count_30d: number | null;
  top_vendor_by_volume_org_id: string | null;
  top_vendor_by_volume_name: string | null;
  top_vendor_orders_count: number | null;
  bottom_vendor_by_quality_org_id: string | null;
  bottom_vendor_by_quality_name: string | null;
  vendor_concentration_top3_pct: number | null;
  total_defect_flags_90d: number | null;
  generated_at: string | null;
};

type ScoreRow = {
  vendor_org_id: string | null;
  vendor_name: string | null;
  total_orders: number | null;
  total_amount_rupees: number | null;
  on_time_pct: number | null;
  defect_rate_pct: number | null;
  defect_flag_count_90d: number | null;
  avg_lead_time_days: number | null;
  last_order_at: string | null;
  quality_band: string | null;
};

type AtRiskRow = {
  vendor_org_id: string | null;
  vendor_name: string | null;
  total_orders: number | null;
  on_time_pct: number | null;
  defect_rate_pct: number | null;
  defect_flag_count: number | null;
  last_order_at: string | null;
  risk_reason: string | null;
};

type TrendRow = {
  month_start: string | null;
  month_label: string | null;
  orders_count: number | null;
  active_vendors: number | null;
  on_time_pct: number | null;
  defect_flag_count: number | null;
  defect_rate_pct: number | null;
  total_amount_rupees: number | null;
  avg_lead_time_days: number | null;
};

function fmt(n: number | null | undefined): string {
  if (n == null) return "0";
  return formatNumber(Math.round(Number(n)));
}

function fmtPct(n: number | null | undefined): string {
  if (n == null) return "0%";
  return `${Number(n).toFixed(1)}%`;
}

function bandTone(band: string | null | undefined): string {
  switch (band) {
    case "excellent":
      return "bg-[var(--color-ok)]/15 text-[var(--color-ok)]";
    case "good":
      return "bg-[var(--color-info)]/15 text-[var(--color-info)]";
    case "fair":
      return "bg-[var(--color-warn)]/15 text-[var(--color-warn)]";
    case "poor":
      return "bg-[var(--color-danger)]/15 text-[var(--color-danger)]";
    default:
      return "bg-[var(--color-surface-muted)] text-[var(--color-muted)]";
  }
}

export default async function FounderVendorQualityScorecardPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [sumRes, scoreRes, atRiskRes, trendRes] = await Promise.all([
    supabase.rpc("founder_vendor_quality_scorecard_summary"),
    supabase.rpc("founder_vendor_quality_scorecard_by_vendor", { p_limit: 50 }),
    supabase.rpc("founder_vendor_quality_at_risk_vendors"),
    supabase.rpc("founder_vendor_quality_monthly_trend", { p_months: 12 }),
  ]);

  const summary: Summary = (sumRes.data?.[0] ?? {}) as Summary;
  const scoreRows: ScoreRow[] = (scoreRes.data ?? []) as ScoreRow[];
  const atRisk: AtRiskRow[] = (atRiskRes.data ?? []) as AtRiskRow[];
  const trend: TrendRow[] = (trendRes.data ?? []) as TrendRow[];
  const errMsg =
    sumRes.error?.message ||
    scoreRes.error?.message ||
    atRiskRes.error?.message ||
    trendRes.error?.message ||
    null;

  const atRiskCount = atRisk.length;
  const generatedAt = summary.generated_at
    ? new Date(summary.generated_at).toISOString().slice(0, 19).replace("T", " ")
    : "—";

  return (
    <main className="mx-auto max-w-7xl px-4 py-8">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold">Vendor quality scorecard</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Supplier quality scorecards aggregated from public.spare_part_orders and
          public.founder_vendor_contracts (r1369). 18 KPIs · 50-row scorecard · at-risk
          banner · 12-month trend. Defect rate is placeholder until founder logs
          incidents via log_founder_vendor_quality_record_defect_flag.
        </p>
      </header>

      {errMsg ? (
        <div className="mb-6 rounded border border-[var(--color-danger)] bg-[var(--color-danger)]/10 p-3 text-sm text-[var(--color-danger)]">
          Failed to load scorecard: {errMsg}
        </div>
      ) : null}

      {atRiskCount > 0 ? (
        <div className="mb-6 rounded border border-[var(--color-danger)] bg-[var(--color-danger)]/10 p-3">
          <div className="text-sm font-medium text-[var(--color-danger)]">
            {fmt(atRiskCount)} vendor{atRiskCount === 1 ? "" : "s"} flagged at-risk
          </div>
          <div className="mt-0.5 text-xs text-[var(--color-muted)]">
            Bottom-decile quality band OR late-delivery rate {">"} 30% OR defect flags {">="} 3 in last 90 days.
          </div>
        </div>
      ) : null}

      {/* 18 KPI cards */}
      <section className="mb-8 grid grid-cols-2 gap-3 md:grid-cols-3 lg:grid-cols-6">
        <Card label="Active vendors (180d)" value={fmt(summary.total_active_vendors)} />
        <Card label="Orders lifetime" value={fmt(summary.total_orders_lifetime)} />
        <Card label="Orders 90d" value={fmt(summary.total_orders_90d)} />
        <Card label="Orders 30d" value={fmt(summary.total_orders_30d)} />
        <Card label="Avg on-time % (90d)" value={fmtPct(summary.avg_on_time_pct)} tone="info" />
        <Card label="Defect rate %" value={fmtPct(summary.defect_rate_pct)} tone="warn" />
        <Card label="Avg lead time (90d)" value={`${fmt(summary.avg_lead_time_days_90d)} d`} />
        <Card label="Avg unit price" value={`₹${fmt(summary.avg_unit_price_rupees)}`} />
        <Card label="Returned orders (90d)" value={fmt(summary.total_returned_orders)} tone="warn" />
        <Card label="Late delivery (30d)" value={fmt(summary.late_delivery_count_30d)} tone="danger" />
        <Card
          label="Top vendor by volume"
          value={summary.top_vendor_by_volume_name ?? "—"}
          sub={`${fmt(summary.top_vendor_orders_count)} orders`}
          tone="ok"
        />
        <Card
          label="Bottom vendor by quality"
          value={summary.bottom_vendor_by_quality_name ?? "—"}
          sub="most defect flags 90d"
          tone="danger"
        />
        <Card
          label="Top-3 vendor concentration"
          value={fmtPct(summary.vendor_concentration_top3_pct)}
          sub="share of orders 90d"
          tone="info"
        />
        <Card label="Defect flags (90d)" value={fmt(summary.total_defect_flags_90d)} tone="warn" />
        <Card label="At-risk vendors" value={fmt(atRiskCount)} tone="danger" />
        <Card label="Scorecard rows" value={fmt(scoreRows.length)} />
        <Card label="Trend months" value={fmt(trend.length)} />
        <Card label="Generated at" value={generatedAt} sub="UTC" />
      </section>

      {/* 50-row scorecard */}
      <section className="mb-4">
        <h2 className="text-lg font-medium">Top 50 vendors — scorecard</h2>
        <p className="mt-1 text-xs text-[var(--color-muted)]">
          Ranked by total orders (last 180 days). Quality band = excellent (on-time {">="} 90% AND 0 flags)
          {" / "}good {" / "}fair {" / "}poor (on-time {"<"} 50% OR {">="} 5 flags).
        </p>
      </section>

      <section className="mb-8 overflow-x-auto rounded border border-[var(--color-border)]">
        <table className="min-w-full text-sm">
          <thead className="bg-[var(--color-surface-muted)] text-left">
            <tr>
              <th className="px-3 py-2 font-medium">Vendor</th>
              <th className="px-3 py-2 font-medium">Band</th>
              <th className="px-3 py-2 text-right font-medium">Orders</th>
              <th className="px-3 py-2 text-right font-medium">Spend ₹</th>
              <th className="px-3 py-2 text-right font-medium">On-time %</th>
              <th className="px-3 py-2 text-right font-medium">Defect %</th>
              <th className="px-3 py-2 text-right font-medium">Flags 90d</th>
              <th className="px-3 py-2 text-right font-medium">Lead (d)</th>
              <th className="px-3 py-2 text-right font-medium">Last order</th>
            </tr>
          </thead>
          <tbody>
            {scoreRows.length === 0 ? (
              <tr>
                <td colSpan={9} className="px-3 py-6 text-center text-[var(--color-muted)]">
                  No vendor orders in last 180 days.
                </td>
              </tr>
            ) : (
              scoreRows.map((r, i) => (
                <tr key={`${r.vendor_org_id ?? "u"}-${i}`} className="border-t border-[var(--color-border)]">
                  <td className="px-3 py-2">{r.vendor_name ?? "Unknown vendor"}</td>
                  <td className="px-3 py-2">
                    <span className={`rounded px-2 py-0.5 text-xs uppercase tracking-wide ${bandTone(r.quality_band)}`}>
                      {r.quality_band ?? "—"}
                    </span>
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">{fmt(r.total_orders)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">₹{fmt(r.total_amount_rupees)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{fmtPct(r.on_time_pct)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{fmtPct(r.defect_rate_pct)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{fmt(r.defect_flag_count_90d)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{fmt(r.avg_lead_time_days)}</td>
                  <td className="px-3 py-2 text-right text-[var(--color-muted)]">
                    {r.last_order_at ? new Date(r.last_order_at).toISOString().slice(0, 10) : "—"}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </section>

      {/* At-risk vendors */}
      <section className="mb-4">
        <h2 className="text-lg font-medium">At-risk vendors</h2>
        <p className="mt-1 text-xs text-[var(--color-muted)]">
          Bottom-decile band OR on-time {"<"} 70% OR {">="} 3 defect flags in 90d.
        </p>
      </section>

      <section className="mb-8 overflow-x-auto rounded border border-[var(--color-border)]">
        <table className="min-w-full text-sm">
          <thead className="bg-[var(--color-surface-muted)] text-left">
            <tr>
              <th className="px-3 py-2 font-medium">Vendor</th>
              <th className="px-3 py-2 font-medium">Reason</th>
              <th className="px-3 py-2 text-right font-medium">Orders</th>
              <th className="px-3 py-2 text-right font-medium">On-time %</th>
              <th className="px-3 py-2 text-right font-medium">Defect %</th>
              <th className="px-3 py-2 text-right font-medium">Flags</th>
              <th className="px-3 py-2 text-right font-medium">Last order</th>
            </tr>
          </thead>
          <tbody>
            {atRisk.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-3 py-6 text-center text-[var(--color-muted)]">
                  No vendors currently at-risk.
                </td>
              </tr>
            ) : (
              atRisk.map((r, i) => (
                <tr key={`r-${r.vendor_org_id ?? "u"}-${i}`} className="border-t border-[var(--color-border)]">
                  <td className="px-3 py-2">{r.vendor_name ?? "Unknown vendor"}</td>
                  <td className="px-3 py-2">
                    <span className="rounded bg-[var(--color-danger)]/15 px-2 py-0.5 text-xs text-[var(--color-danger)]">
                      {r.risk_reason ?? "multi_factor"}
                    </span>
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">{fmt(r.total_orders)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{fmtPct(r.on_time_pct)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{fmtPct(r.defect_rate_pct)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{fmt(r.defect_flag_count)}</td>
                  <td className="px-3 py-2 text-right text-[var(--color-muted)]">
                    {r.last_order_at ? new Date(r.last_order_at).toISOString().slice(0, 10) : "—"}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </section>

      {/* 12-month trend */}
      <section className="mb-4">
        <h2 className="text-lg font-medium">12-month vendor quality trend</h2>
        <p className="mt-1 text-xs text-[var(--color-muted)]">
          Orders × active-vendors × on-time % × defect flags × spend, month by month.
        </p>
      </section>

      <section className="mb-8 overflow-x-auto rounded border border-[var(--color-border)]">
        <table className="min-w-full text-sm">
          <thead className="bg-[var(--color-surface-muted)] text-left">
            <tr>
              <th className="px-3 py-2 font-medium">Month</th>
              <th className="px-3 py-2 text-right font-medium">Orders</th>
              <th className="px-3 py-2 text-right font-medium">Vendors</th>
              <th className="px-3 py-2 text-right font-medium">On-time %</th>
              <th className="px-3 py-2 text-right font-medium">Flags</th>
              <th className="px-3 py-2 text-right font-medium">Defect %</th>
              <th className="px-3 py-2 text-right font-medium">Spend ₹</th>
              <th className="px-3 py-2 text-right font-medium">Lead (d)</th>
            </tr>
          </thead>
          <tbody>
            {trend.length === 0 ? (
              <tr>
                <td colSpan={8} className="px-3 py-6 text-center text-[var(--color-muted)]">
                  No trend data.
                </td>
              </tr>
            ) : (
              trend.map((r, i) => (
                <tr key={`t-${r.month_start ?? "u"}-${i}`} className="border-t border-[var(--color-border)]">
                  <td className="px-3 py-2">{r.month_label ?? "—"}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{fmt(r.orders_count)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{fmt(r.active_vendors)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{fmtPct(r.on_time_pct)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{fmt(r.defect_flag_count)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{fmtPct(r.defect_rate_pct)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">₹{fmt(r.total_amount_rupees)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{fmt(r.avg_lead_time_days)}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </section>

      <p className="text-xs text-[var(--color-muted)]">
        Source: public.spare_part_orders (180d window for scorecard, 90d window for active KPIs) joined to
        public.organizations on supplier_org_id. Quality band derived from on-time % and defect flag count.
        Defect flags written via public.log_founder_vendor_quality_record_defect_flag(uuid, text, text, text).
        Founder-only via is_founder() gate. NO new vendor master tables — pure aggregator.
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
      <div className={`mt-1 truncate text-lg font-semibold ${toneClass}`} title={value}>{value}</div>
      {sub ? <div className="mt-0.5 text-xs text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}
