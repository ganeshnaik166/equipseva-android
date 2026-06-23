import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Customer contract renewal discount justification ledger — r2536" };
export const dynamic = "force-dynamic";

type DiscountRow = {
  id: string;
  hospital_user_id: string | null;
  contract_external_ref: string;
  renewal_at: string | null;
  discount_asked_pct: number;
  discount_given_pct: number;
  reason_kind: string;
  roi_estimate_rupees: number;
  founder_approval_required: boolean;
  founder_approved: boolean;
  status: string;
  owner_email: string | null;
  created_at: string;
};

type DecisionLogRow = {
  id: string;
  discount_id: string;
  decision_at: string;
  decision_kind: string;
  decision_summary: string | null;
  owner_email: string | null;
  notes: string | null;
};

type TopFocusRow = {
  id: string;
  contract_external_ref: string;
  discount_asked_pct: number;
  discount_given_pct: number;
  reason_kind: string;
  roi_estimate_rupees: number;
  status: string;
  renewal_at: string | null;
};

type ReasonBreakdownRow = {
  reason_kind: string;
  cases_count: number;
  avg_asked: number;
  avg_given: number;
  total_roi_rupees: number;
};

type ApprovalSummaryRow = {
  total_required: number;
  total_approved: number;
  total_pending: number;
  approved_avg_given: number | null;
  approved_total_roi: number;
};

type MonthlyTrendRow = {
  month_label: string;
  cases_count: number;
  avg_given: number;
  total_roi_rupees: number;
};

type RoiDistRow = {
  bucket: string;
  cases_count: number;
  total_roi_rupees: number;
  avg_given: number;
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
  return "Rs " + Number(n).toLocaleString("en-IN");
}

function fmtPct(n: number | null | undefined): string {
  if (n == null) return "—";
  return `${Number(n).toFixed(2)}%`;
}

function statusBadge(status: string): string {
  if (status === "approved") return "text-emerald-700";
  if (status === "open") return "text-amber-700";
  if (status === "rejected") return "text-rose-700";
  if (status === "withdrawn") return "text-gray-500";
  return "";
}

function decisionBadge(kind: string): string {
  if (kind === "approve") return "text-emerald-700";
  if (kind === "reject") return "text-rose-700";
  if (kind === "counter_offer") return "text-amber-700";
  if (kind === "escalate") return "text-indigo-700";
  return "";
}

export default async function CustomerContractRenewalDiscountJustificationLedgerPage() {
  const sb = await getSupabaseServerClient();
  const [
    discountsRes,
    logRes,
    topRes,
    reasonRes,
    approvalRes,
    monthlyRes,
    roiRes,
  ] = await Promise.all([
    sb.rpc("list_renewal_discounts_r2536"),
    sb.rpc("list_decision_log_r2536"),
    sb.rpc("top_discount_focus_r2536"),
    sb.rpc("reason_kind_breakdown_r2536"),
    sb.rpc("founder_approval_summary_r2536"),
    sb.rpc("monthly_discount_trend_r2536"),
    sb.rpc("roi_distribution_r2536"),
  ]);

  if (discountsRes.error) throw new Error(`list_renewal_discounts_r2536: ${discountsRes.error.message}`);
  if (logRes.error) throw new Error(`list_decision_log_r2536: ${logRes.error.message}`);
  if (topRes.error) throw new Error(`top_discount_focus_r2536: ${topRes.error.message}`);
  if (reasonRes.error) throw new Error(`reason_kind_breakdown_r2536: ${reasonRes.error.message}`);
  if (approvalRes.error) throw new Error(`founder_approval_summary_r2536: ${approvalRes.error.message}`);
  if (monthlyRes.error) throw new Error(`monthly_discount_trend_r2536: ${monthlyRes.error.message}`);
  if (roiRes.error) throw new Error(`roi_distribution_r2536: ${roiRes.error.message}`);

  const discounts = (discountsRes.data ?? []) as DiscountRow[];
  const log = (logRes.data ?? []) as DecisionLogRow[];
  const top = (topRes.data ?? []) as TopFocusRow[];
  const reasons = (reasonRes.data ?? []) as ReasonBreakdownRow[];
  const approval = ((approvalRes.data ?? []) as ApprovalSummaryRow[])[0] ?? {
    total_required: 0,
    total_approved: 0,
    total_pending: 0,
    approved_avg_given: null,
    approved_total_roi: 0,
  };
  const monthly = (monthlyRes.data ?? []) as MonthlyTrendRow[];
  const roi = (roiRes.data ?? []) as RoiDistRow[];

  const totalCases = discounts.length;
  const openCount = discounts.filter((d) => d.status === "open").length;
  const approvedCount = discounts.filter((d) => d.status === "approved").length;
  const rejectedCount = discounts.filter((d) => d.status === "rejected").length;
  const totalRoi = discounts.reduce((acc, d) => acc + Number(d.roi_estimate_rupees ?? 0), 0);
  const avgGiven =
    totalCases > 0
      ? discounts.reduce((acc, d) => acc + Number(d.discount_given_pct ?? 0), 0) / totalCases
      : 0;

  const discountColumns: Column<DiscountRow>[] = [
    { key: "contract_external_ref", header: "Contract", render: (r: any) => <span className="font-medium">{r.contract_external_ref}</span> },
    { key: "renewal_at", header: "Renewal", render: (r: any) => fmtDate(r.renewal_at) },
    { key: "discount_asked_pct", header: "Asked", render: (r: any) => fmtPct(r.discount_asked_pct) },
    { key: "discount_given_pct", header: "Given", render: (r: any) => fmtPct(r.discount_given_pct) },
    { key: "reason_kind", header: "Reason", render: (r: any) => r.reason_kind },
    { key: "roi_estimate_rupees", header: "ROI", render: (r: any) => fmtRupees(r.roi_estimate_rupees) },
    { key: "founder_approval_required", header: "Founder req", render: (r: any) => (r.founder_approval_required ? "yes" : "no") },
    { key: "founder_approved", header: "Founder OK", render: (r: any) => (r.founder_approved ? "yes" : "no") },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
  ];

  const logColumns: Column<DecisionLogRow>[] = [
    { key: "decision_at", header: "When", render: (r: any) => fmtDate(r.decision_at) },
    { key: "decision_kind", header: "Decision", render: (r: any) => <span className={decisionBadge(r.decision_kind)}>{r.decision_kind}</span> },
    { key: "decision_summary", header: "Summary", render: (r: any) => r.decision_summary ?? "—" },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const topColumns: Column<TopFocusRow>[] = [
    { key: "contract_external_ref", header: "Contract", render: (r: any) => <span className="font-medium">{r.contract_external_ref}</span> },
    { key: "discount_asked_pct", header: "Asked", render: (r: any) => fmtPct(r.discount_asked_pct) },
    { key: "discount_given_pct", header: "Given", render: (r: any) => fmtPct(r.discount_given_pct) },
    { key: "reason_kind", header: "Reason", render: (r: any) => r.reason_kind },
    { key: "roi_estimate_rupees", header: "ROI", render: (r: any) => fmtRupees(r.roi_estimate_rupees) },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "renewal_at", header: "Renewal", render: (r: any) => fmtDate(r.renewal_at) },
  ];

  const reasonColumns: Column<ReasonBreakdownRow>[] = [
    { key: "reason_kind", header: "Reason", render: (r: any) => <span className="font-medium">{r.reason_kind}</span> },
    { key: "cases_count", header: "Cases", render: (r: any) => String(r.cases_count) },
    { key: "avg_asked", header: "Avg asked", render: (r: any) => fmtPct(r.avg_asked) },
    { key: "avg_given", header: "Avg given", render: (r: any) => fmtPct(r.avg_given) },
    { key: "total_roi_rupees", header: "Total ROI", render: (r: any) => fmtRupees(r.total_roi_rupees) },
  ];

  const monthlyColumns: Column<MonthlyTrendRow>[] = [
    { key: "month_label", header: "Month", render: (r: any) => <span className="font-medium">{r.month_label}</span> },
    { key: "cases_count", header: "Cases", render: (r: any) => String(r.cases_count) },
    { key: "avg_given", header: "Avg given", render: (r: any) => fmtPct(r.avg_given) },
    { key: "total_roi_rupees", header: "Total ROI", render: (r: any) => fmtRupees(r.total_roi_rupees) },
  ];

  const roiColumns: Column<RoiDistRow>[] = [
    { key: "bucket", header: "Bucket", render: (r: any) => <span className="font-medium">{r.bucket}</span> },
    { key: "cases_count", header: "Cases", render: (r: any) => String(r.cases_count) },
    { key: "total_roi_rupees", header: "Total ROI", render: (r: any) => fmtRupees(r.total_roi_rupees) },
    { key: "avg_given", header: "Avg given", render: (r: any) => fmtPct(r.avg_given) },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Customer contract renewal discount justification ledger — r2536</h1>
        <p className="mt-1 text-xs text-gray-500">
          Every renewal discount: asked vs given & reason & ROI estimate & founder approval.
          Forces explicit justification => stops casual margin leak.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total cases</div>
          <div className="mt-1 text-lg font-semibold">{totalCases}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Open</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{openCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Approved</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{approvedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Rejected</div>
          <div className="mt-1 text-lg font-semibold text-rose-700">{rejectedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg given</div>
          <div className="mt-1 text-lg font-semibold">{fmtPct(avgGiven)}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total ROI</div>
          <div className="mt-1 text-lg font-semibold">{fmtRupees(totalRoi)}</div>
        </div>
      </section>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-5">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Founder req</div>
          <div className="mt-1 text-lg font-semibold">{approval.total_required}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Founder approved</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{approval.total_approved}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Founder pending</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{approval.total_pending}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Approved avg given</div>
          <div className="mt-1 text-lg font-semibold">{fmtPct(approval.approved_avg_given ?? 0)}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Approved ROI</div>
          <div className="mt-1 text-lg font-semibold">{fmtRupees(approval.approved_total_roi)}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All renewal discount cases</h2>
        <p className="text-xs text-gray-500">
          Asked vs given & reason & ROI estimate. Anything > founder threshold needs explicit founder OK.
        </p>
        <DataTable
          rows={discounts}
          columns={discountColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No renewal discount cases yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Top discount focus</h2>
        <p className="text-xs text-gray-500">
          Ranked by given pct & ROI. Use to spot margin leak => biggest givebacks at top.
        </p>
        <DataTable
          rows={top}
          columns={topColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No cases yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Reason-kind breakdown</h2>
        <p className="text-xs text-gray-500">
          Where do we leak margin? Competitive_pressure & founder_judgement => usually deeper givebacks.
        </p>
        <DataTable
          rows={reasons}
          columns={reasonColumns}
          rowKey={(r: any, i: number) => `${r.reason_kind}-${i}`}
          emptyMessage="No reason breakdown."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Monthly trend</h2>
        <p className="text-xs text-gray-500">
          Cases & avg given & total ROI per renewal month. Watch the line — drift up => bad.
        </p>
        <DataTable
          rows={monthly}
          columns={monthlyColumns}
          rowKey={(r: any, i: number) => `${r.month_label}-${i}`}
          emptyMessage="No monthly trend yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">ROI distribution</h2>
        <p className="text-xs text-gray-500">
          Bucket by ROI estimate. 0_no_roi cases => discount with no quantified payback => investigate.
        </p>
        <DataTable
          rows={roi}
          columns={roiColumns}
          rowKey={(r: any, i: number) => `${r.bucket}-${i}`}
          emptyMessage="No ROI distribution."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Decision log</h2>
        <p className="text-xs text-gray-500">
          Every approve & reject & counter_offer & escalate event. Audit trail for renewal pricing.
        </p>
        <DataTable
          rows={log}
          columns={logColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No decision log entries yet."
        />
      </section>
    </div>
  );
}
