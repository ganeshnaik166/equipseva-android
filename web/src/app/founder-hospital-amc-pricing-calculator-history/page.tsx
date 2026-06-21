import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder hospital AMC pricing calculator history — r1743" };
export const dynamic = "force-dynamic";

type QuoteRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  quote_date: string;
  base_price_rupees: number;
  equipment_count: number;
  hospital_tier: string;
  computed_price_rupees: number;
  discount_applied_pct: number;
  final_price_rupees: number;
  status: string;
  decided_at: string | null;
  notes: string | null;
  created_at: string;
};

type DiscountRow = {
  id: string;
  quote_id: string;
  hospital_user_id: string | null;
  discount_type: string;
  discount_pct: number;
  approved_by_email: string | null;
  approved_at: string;
  reason: string | null;
  created_at: string;
};

type AcceptanceRow = {
  hospital_tier: string;
  total_quotes: number;
  pending_count: number;
  sent_count: number;
  accepted_count: number;
  declined_count: number;
  expired_count: number;
  acceptance_rate_pct: number;
  avg_final_price_rupees: number;
};

type OveruseRow = {
  discount_type: string;
  usage_count: number;
  avg_discount_pct: number;
  max_discount_pct: number;
  distinct_approvers: number;
  last_used_at: string | null;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return "—";
  return "₹" + Number(n).toLocaleString("en-IN");
}

function statusBadge(status: string): string {
  if (status === "accepted") return "text-emerald-700";
  if (status === "sent") return "text-blue-700";
  if (status === "pending") return "text-amber-700";
  if (status === "declined") return "text-rose-700";
  if (status === "expired") return "text-gray-500";
  return "";
}

function tierBadge(tier: string): string {
  if (tier === "tier_1") return "text-violet-700 font-medium";
  if (tier === "tier_2") return "text-indigo-700";
  if (tier === "tier_3") return "text-slate-700";
  return "";
}

export default async function FounderHospitalAmcPricingCalculatorHistoryPage() {
  const sb = await getSupabaseServerClient();
  const [quotesRes, discountsRes, acceptanceRes, overuseRes] = await Promise.all([
    sb.rpc("list_quotes_r1743"),
    sb.rpc("list_discounts_r1743"),
    sb.rpc("acceptance_rate_summary_r1743"),
    sb.rpc("discount_overuse_r1743"),
  ]);

  if (quotesRes.error) throw new Error(`list_quotes_r1743: ${quotesRes.error.message}`);
  if (discountsRes.error) throw new Error(`list_discounts_r1743: ${discountsRes.error.message}`);
  if (acceptanceRes.error) throw new Error(`acceptance_rate_summary_r1743: ${acceptanceRes.error.message}`);
  if (overuseRes.error) throw new Error(`discount_overuse_r1743: ${overuseRes.error.message}`);

  const quotes = (quotesRes.data ?? []) as QuoteRow[];
  const discounts = (discountsRes.data ?? []) as DiscountRow[];
  const acceptance = (acceptanceRes.data ?? []) as AcceptanceRow[];
  const overuse = (overuseRes.data ?? []) as OveruseRow[];

  const totalQuotes = quotes.length;
  const pendingCount = quotes.filter((q) => q.status === "pending").length;
  const sentCount = quotes.filter((q) => q.status === "sent").length;
  const acceptedCount = quotes.filter((q) => q.status === "accepted").length;
  const declinedCount = quotes.filter((q) => q.status === "declined").length;
  const expiredCount = quotes.filter((q) => q.status === "expired").length;
  const decidedCount = acceptedCount + declinedCount + expiredCount;
  const overallAcceptancePct = decidedCount === 0 ? 0 : Math.round((acceptedCount / decidedCount) * 10000) / 100;
  const totalDiscounts = discounts.length;
  const totalPipelineRupees = quotes
    .filter((q) => q.status === "pending" || q.status === "sent")
    .reduce((s, q) => s + Number(q.final_price_rupees || 0), 0);

  const quoteColumns: Column<QuoteRow>[] = [
    { key: "quote_date", header: "Date", render: (r: any) => fmtDate(r.quote_date) },
    { key: "hospital_email", header: "Hospital", render: (r: any) => r.hospital_email ?? "—" },
    { key: "hospital_tier", header: "Tier", render: (r: any) => <span className={tierBadge(r.hospital_tier)}>{r.hospital_tier}</span> },
    { key: "equipment_count", header: "Equipment", render: (r: any) => String(r.equipment_count) },
    { key: "base_price_rupees", header: "Base", render: (r: any) => fmtRupees(r.base_price_rupees) },
    { key: "computed_price_rupees", header: "Computed", render: (r: any) => fmtRupees(r.computed_price_rupees) },
    { key: "discount_applied_pct", header: "Disc %", render: (r: any) => `${r.discount_applied_pct}%` },
    { key: "final_price_rupees", header: "Final", render: (r: any) => <span className="font-medium">{fmtRupees(r.final_price_rupees)}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "decided_at", header: "Decided", render: (r: any) => fmtDate(r.decided_at) },
    { key: "created_at", header: "Created", render: (r: any) => fmtDate(r.created_at) },
  ];

  const discountColumns: Column<DiscountRow>[] = [
    { key: "approved_at", header: "Approved", render: (r: any) => fmtDate(r.approved_at) },
    { key: "discount_type", header: "Type", render: (r: any) => <span className="font-medium">{r.discount_type}</span> },
    { key: "discount_pct", header: "Pct", render: (r: any) => `${r.discount_pct}%` },
    { key: "approved_by_email", header: "Approver", render: (r: any) => r.approved_by_email ?? "—" },
    { key: "quote_id", header: "Quote", render: (r: any) => <span className="font-mono text-xs">{String(r.quote_id).slice(0, 8)}</span> },
    { key: "reason", header: "Reason", render: (r: any) => r.reason ?? "—" },
  ];

  const acceptanceColumns: Column<AcceptanceRow>[] = [
    { key: "hospital_tier", header: "Tier", render: (r: any) => <span className={tierBadge(r.hospital_tier)}>{r.hospital_tier}</span> },
    { key: "total_quotes", header: "Total", render: (r: any) => String(r.total_quotes) },
    { key: "pending_count", header: "Pending", render: (r: any) => String(r.pending_count) },
    { key: "sent_count", header: "Sent", render: (r: any) => String(r.sent_count) },
    { key: "accepted_count", header: "Accepted", render: (r: any) => <span className="text-emerald-700">{r.accepted_count}</span> },
    { key: "declined_count", header: "Declined", render: (r: any) => <span className="text-rose-700">{r.declined_count}</span> },
    { key: "expired_count", header: "Expired", render: (r: any) => <span className="text-gray-500">{r.expired_count}</span> },
    { key: "acceptance_rate_pct", header: "Accept %", render: (r: any) => <span className="font-medium">{r.acceptance_rate_pct}%</span> },
    { key: "avg_final_price_rupees", header: "Avg final", render: (r: any) => fmtRupees(r.avg_final_price_rupees) },
  ];

  const overuseColumns: Column<OveruseRow>[] = [
    { key: "discount_type", header: "Type", render: (r: any) => <span className="font-medium">{r.discount_type}</span> },
    { key: "usage_count", header: "Uses", render: (r: any) => String(r.usage_count) },
    { key: "avg_discount_pct", header: "Avg %", render: (r: any) => `${r.avg_discount_pct}%` },
    { key: "max_discount_pct", header: "Max %", render: (r: any) => `${r.max_discount_pct}%` },
    { key: "distinct_approvers", header: "Approvers", render: (r: any) => String(r.distinct_approvers) },
    { key: "last_used_at", header: "Last used", render: (r: any) => fmtDate(r.last_used_at) },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder hospital AMC pricing calculator history — r1743</h1>
        <p className="mt-1 text-xs text-gray-500">
          Every AMC quote generated, the tier multiplier applied, discount stack, and the eventual accept / decline
          outcome. Use this to spot pricing leaks and discount overuse.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total quotes</div>
          <div className="mt-1 text-lg font-semibold">{totalQuotes}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Pending</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{pendingCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Sent</div>
          <div className="mt-1 text-lg font-semibold text-blue-700">{sentCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Accepted</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{acceptedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Declined</div>
          <div className="mt-1 text-lg font-semibold text-rose-700">{declinedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Expired</div>
          <div className="mt-1 text-lg font-semibold text-gray-500">{expiredCount}</div>
        </div>
      </section>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-3">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Accept rate (decided)</div>
          <div className="mt-1 text-lg font-semibold">{overallAcceptancePct}%</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Discounts logged</div>
          <div className="mt-1 text-lg font-semibold">{totalDiscounts}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Open pipeline value</div>
          <div className="mt-1 text-lg font-semibold">{fmtRupees(totalPipelineRupees)}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Quote history</h2>
        <p className="text-xs text-gray-500">
          Most recent 200 quotes. Tier multiplier: tier_1 = 1.25x, tier_2 = 1.10x, tier_3 = 1.00x of base price per
          unit. Final price reflects any discount applied.
        </p>
        <DataTable
          rows={quotes}
          columns={quoteColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No quotes generated yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Acceptance rate by tier</h2>
        <p className="text-xs text-gray-500">
          Acceptance percentage is calculated on decided quotes only (accepted + declined + expired). Pending and
          sent quotes are excluded from the denominator.
        </p>
        <DataTable
          rows={acceptance}
          columns={acceptanceColumns}
          rowKey={(r: any, i: number) => String(r.hospital_tier ?? i)}
          emptyMessage="No tier data yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Discount stack</h2>
        <p className="text-xs text-gray-500">
          Every discount approval with type, percentage, approver, and reason. Use this for audit trail and to spot
          unauthorized overrides.
        </p>
        <DataTable
          rows={discounts}
          columns={discountColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No discounts applied yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Discount overuse signal</h2>
        <p className="text-xs text-gray-500">
          Discount types ranked by usage. Watch for founder_override climbing &gt;= 10% of total quotes — that means
          the pricing model is under-calibrated and needs a rebase, not more overrides.
        </p>
        <DataTable
          rows={overuse}
          columns={overuseColumns}
          rowKey={(r: any, i: number) => String(r.discount_type ?? i)}
          emptyMessage="No discount history yet."
        />
      </section>
    </div>
  );
}
