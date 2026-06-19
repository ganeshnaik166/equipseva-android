import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = {
  title: "Vendor payables · EquipSeva Founder",
  description:
    "Supplier ledger — pending orders, overdue 30d, bonded vs unbonded split, top suppliers by pending amount.",
};
export const dynamic = "force-dynamic";

type Summary = {
  total_active_suppliers: number | null;
  total_pending_orders: number | null;
  total_pending_amount_rupees: number | null;
  total_overdue_orders_30d: number | null;
  total_overdue_amount_rupees: number | null;
  largest_pending_amount_rupees: number | null;
  top_supplier_by_pending_org_id: string | null;
  top_supplier_by_pending_name: string | null;
  top_supplier_by_pending_amount_rupees: number | null;
  bonded_pending_amount_rupees: number | null;
  unbonded_pending_amount_rupees: number | null;
  avg_days_to_pay: number | null;
};

type Row = {
  supplier_org_id: string | null;
  supplier_name: string | null;
  is_bonded: boolean | null;
  pending_orders: number | null;
  pending_amount_rupees: number | null;
  overdue_orders_30d: number | null;
  overdue_amount_rupees: number | null;
  oldest_pending_days: number | null;
  last_order_at: string | null;
};

function fmtRup(n: number | null | undefined): string {
  if (n == null) return "0";
  return formatNumber(Math.round(Number(n)));
}

function pct(part: number | null | undefined, whole: number | null | undefined): string {
  const p = Number(part ?? 0);
  const w = Number(whole ?? 0);
  if (w <= 0) return "0%";
  return `${Math.round((p / w) * 1000) / 10}%`;
}

export default async function FounderVendorPayablesPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, suppliersRes] = await Promise.all([
    supabase.rpc("founder_vendor_payables_summary"),
    supabase.rpc("founder_vendor_payables_by_supplier", { p_limit: 30 }),
  ]);

  const summary: Summary = (summaryRes.data?.[0] ?? {}) as Summary;
  const suppliers: Row[] = (suppliersRes.data ?? []) as Row[];
  const errMsg = summaryRes.error?.message ?? suppliersRes.error?.message ?? null;

  const bondedShare = pct(summary.bonded_pending_amount_rupees, summary.total_pending_amount_rupees);
  const unbondedShare = pct(summary.unbonded_pending_amount_rupees, summary.total_pending_amount_rupees);

  return (
    <main className="mx-auto max-w-7xl px-4 py-8">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold">Vendor payables</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Supplier ledger — pending orders, overdue {">"} 30 days, bonded vs unbonded
          exposure, and the top 30 suppliers ranked by pending amount. Read-only view
          aggregated from spare_part_orders.
        </p>
      </header>

      {errMsg ? (
        <div className="mb-6 rounded border border-[var(--color-danger)] bg-[var(--color-danger)]/10 p-3 text-sm text-[var(--color-danger)]">
          Failed to load payables: {errMsg}
        </div>
      ) : null}

      <section className="mb-8 grid grid-cols-2 gap-3 md:grid-cols-3 lg:grid-cols-4">
        <Card label="Active suppliers (180d)" value={fmtRup(summary.total_active_suppliers)} />
        <Card label="Pending orders" value={fmtRup(summary.total_pending_orders)} />
        <Card label="Pending amount" value={`₹${fmtRup(summary.total_pending_amount_rupees)}`} tone="info" />
        <Card label="Overdue orders ( > 30d )" value={fmtRup(summary.total_overdue_orders_30d)} tone="warn" />
        <Card label="Overdue amount" value={`₹${fmtRup(summary.total_overdue_amount_rupees)}`} tone="danger" />
        <Card label="Largest single pending" value={`₹${fmtRup(summary.largest_pending_amount_rupees)}`} />
        <Card
          label="Top supplier (by pending)"
          value={summary.top_supplier_by_pending_name ?? "—"}
          sub={`₹${fmtRup(summary.top_supplier_by_pending_amount_rupees)}`}
        />
        <Card label="Bonded pending" value={`₹${fmtRup(summary.bonded_pending_amount_rupees)}`} sub={bondedShare} tone="ok" />
        <Card label="Unbonded pending" value={`₹${fmtRup(summary.unbonded_pending_amount_rupees)}`} sub={unbondedShare} tone="warn" />
        <Card label="Avg days to pay (180d)" value={`${fmtRup(summary.avg_days_to_pay)} d`} />
        <Card
          label="Bonded share of exposure"
          value={bondedShare}
          sub="signed/active bond suppliers"
          tone="info"
        />
        <Card
          label="Unbonded share of exposure"
          value={unbondedShare}
          sub="counterfeit risk surface"
          tone="danger"
        />
      </section>

      <section className="mb-4">
        <h2 className="text-lg font-medium">Top 30 suppliers by pending amount</h2>
        <p className="mt-1 text-xs text-[var(--color-muted)]">
          Pending order = spare_part_orders.payment_status NOT IN ('paid') AND order_status NOT IN ('cancelled','refunded') — verify with current vocabulary.
        </p>
      </section>

      <section className="overflow-x-auto rounded border border-[var(--color-border)]">
        <table className="min-w-full text-sm">
          <thead className="bg-[var(--color-surface-muted)] text-left">
            <tr>
              <th className="px-3 py-2 font-medium">Supplier</th>
              <th className="px-3 py-2 font-medium">Bond</th>
              <th className="px-3 py-2 text-right font-medium">Pending #</th>
              <th className="px-3 py-2 text-right font-medium">Pending ₹</th>
              <th className="px-3 py-2 text-right font-medium">Overdue # ({">"} 30d)</th>
              <th className="px-3 py-2 text-right font-medium">Overdue ₹</th>
              <th className="px-3 py-2 text-right font-medium">Oldest (days)</th>
              <th className="px-3 py-2 text-right font-medium">Last order</th>
            </tr>
          </thead>
          <tbody>
            {suppliers.length === 0 ? (
              <tr>
                <td colSpan={8} className="px-3 py-6 text-center text-[var(--color-muted)]">
                  No suppliers with pending payables.
                </td>
              </tr>
            ) : (
              suppliers.map((r, i) => {
                const oldest = Number(r.oldest_pending_days ?? 0);
                const oldClass =
                  oldest >= 60
                    ? "text-[var(--color-danger)]"
                    : oldest >= 30
                    ? "text-[var(--color-warn)]"
                    : "text-[var(--color-muted)]";
                return (
                  <tr key={`${r.supplier_org_id ?? "u"}-${i}`} className="border-t border-[var(--color-border)]">
                    <td className="px-3 py-2">{r.supplier_name ?? "Unknown supplier"}</td>
                    <td className="px-3 py-2">
                      {r.is_bonded ? (
                        <span className="rounded bg-[var(--color-ok)]/10 px-2 py-0.5 text-xs text-[var(--color-ok)]">
                          bonded
                        </span>
                      ) : (
                        <span className="rounded bg-[var(--color-warn)]/10 px-2 py-0.5 text-xs text-[var(--color-warn)]">
                          unbonded
                        </span>
                      )}
                    </td>
                    <td className="px-3 py-2 text-right">{fmtRup(r.pending_orders)}</td>
                    <td className="px-3 py-2 text-right">₹{fmtRup(r.pending_amount_rupees)}</td>
                    <td className="px-3 py-2 text-right">{fmtRup(r.overdue_orders_30d)}</td>
                    <td className="px-3 py-2 text-right text-[var(--color-danger)]">
                      ₹{fmtRup(r.overdue_amount_rupees)}
                    </td>
                    <td className={`px-3 py-2 text-right ${oldClass}`}>{fmtRup(r.oldest_pending_days)}</td>
                    <td className="px-3 py-2 text-right text-[var(--color-muted)]">
                      {r.last_order_at ? new Date(r.last_order_at).toISOString().slice(0, 10) : "—"}
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </section>

      <p className="mt-6 text-xs text-[var(--color-muted)]">
        Source: public.spare_part_orders joined to public.dental_bonded_parts_suppliers (r1323). Bonded
        = bonded_status IN ('signed','active'). Avg days to pay computed off paid orders in last 180 days
        using updated_at as paid_at proxy. Overdue threshold = 30 days since created_at.
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
