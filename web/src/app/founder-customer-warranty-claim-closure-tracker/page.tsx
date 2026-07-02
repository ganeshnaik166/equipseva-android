import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder customer warranty claim closure tracker — r2404" };
export const dynamic = "force-dynamic";

type ClaimRow = {
  id: string;
  customer_user_id: string;
  equipment_model: string;
  serial_no: string | null;
  vendor_name: string;
  defect_summary: string;
  claim_opened_at: string;
  rma_number: string | null;
  rma_status: string;
  rma_requested_at: string | null;
  rma_approved_at: string | null;
  closed_at: string | null;
  resolution: string | null;
  satisfaction_score: number | null;
  satisfaction_comment: string | null;
  satisfaction_collected_at: string | null;
  days_open: number;
  is_open: boolean;
};

type VendorRow = {
  vendor_name: string;
  total_claims: number;
  open_claims: number;
  closed_claims: number;
  avg_days_to_close: number | null;
  avg_satisfaction: number | null;
  last_claim_at: string | null;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function rmaBadge(status: string): string {
  if (status === "closed") return "text-gray-500";
  if (status === "rejected") return "text-red-700";
  if (status === "approved" || status === "shipped" || status === "received") return "text-emerald-700";
  if (status === "pending") return "text-amber-700";
  return "";
}

function daysOpenBadge(days: number, isOpen: boolean): string {
  if (!isOpen) return "text-gray-500";
  if (days >= 30) return "text-red-700 font-semibold";
  if (days >= 14) return "text-amber-700";
  return "text-emerald-700";
}

function satBadge(score: number | null): string {
  if (score === null) return "text-gray-500";
  if (score >= 4) return "text-emerald-700";
  if (score === 3) return "text-amber-700";
  return "text-red-700";
}

export default async function FounderWarrantyClaimClosureTrackerPage() {
  const sb = await getSupabaseServerClient();
  const [claimsRes, vendorRes] = await Promise.all([
    sb.rpc("list_warranty_claims_r2404"),
    sb.rpc("vendor_warranty_summary_r2404"),
  ]);

  if (claimsRes.error) throw new Error(`list_warranty_claims_r2404: ${claimsRes.error.message}`);
  if (vendorRes.error) throw new Error(`vendor_warranty_summary_r2404: ${vendorRes.error.message}`);

  const claims = (claimsRes.data ?? []) as ClaimRow[];
  const vendors = (vendorRes.data ?? []) as VendorRow[];

  const totalCount = claims.length;
  const openCount = claims.filter((c) => c.is_open).length;
  const closedCount = totalCount - openCount;
  const overdueCount = claims.filter((c) => c.is_open && c.days_open >= 14).length;
  const avgDaysOpen =
    openCount === 0
      ? 0
      : Math.round(
          claims.filter((c) => c.is_open).reduce((a, c) => a + (c.days_open ?? 0), 0) / openCount,
        );
  const satScores = claims
    .map((c) => c.satisfaction_score)
    .filter((s): s is number => typeof s === "number");
  const avgSat =
    satScores.length === 0
      ? 0
      : Math.round((satScores.reduce((a, s) => a + s, 0) / satScores.length) * 10) / 10;

  const claimColumns: Column<ClaimRow>[] = [
    {
      key: "equipment_model",
      header: "Equipment",
      render: (r: any) => (
        <div>
          <div className="font-medium">{r.equipment_model}</div>
          <div className="text-xs text-gray-500">{r.serial_no ?? "—"}</div>
        </div>
      ),
    },
    { key: "vendor_name", header: "Vendor", render: (r: any) => r.vendor_name },
    {
      key: "defect_summary",
      header: "Defect",
      render: (r: any) => <span className="text-xs">{r.defect_summary}</span>,
    },
    {
      key: "rma_status",
      header: "RMA",
      render: (r: any) => (
        <div>
          <div className={rmaBadge(r.rma_status)}>{r.rma_status}</div>
          <div className="text-xs text-gray-500">{r.rma_number ?? "—"}</div>
        </div>
      ),
    },
    {
      key: "days_open",
      header: "Days open",
      render: (r: any) => (
        <span className={daysOpenBadge(r.days_open, r.is_open)}>{String(r.days_open)}</span>
      ),
    },
    { key: "claim_opened_at", header: "Opened", render: (r: any) => fmtDate(r.claim_opened_at) },
    { key: "closed_at", header: "Closed", render: (r: any) => fmtDate(r.closed_at) },
    { key: "resolution", header: "Resolution", render: (r: any) => r.resolution ?? "—" },
    {
      key: "satisfaction_score",
      header: "CSAT",
      render: (r: any) => (
        <span className={satBadge(r.satisfaction_score)}>
          {r.satisfaction_score === null ? "—" : `${r.satisfaction_score}/5`}
        </span>
      ),
    },
  ];

  const vendorColumns: Column<VendorRow>[] = [
    { key: "vendor_name", header: "Vendor", render: (r: any) => <span className="font-medium">{r.vendor_name}</span> },
    { key: "total_claims", header: "Total", render: (r: any) => String(r.total_claims) },
    {
      key: "open_claims",
      header: "Open",
      render: (r: any) => (
        <span className={r.open_claims > 0 ? "text-amber-700 font-medium" : "text-gray-500"}>
          {String(r.open_claims)}
        </span>
      ),
    },
    { key: "closed_claims", header: "Closed", render: (r: any) => String(r.closed_claims) },
    {
      key: "avg_days_to_close",
      header: "Avg days to close",
      render: (r: any) => (r.avg_days_to_close === null ? "—" : String(r.avg_days_to_close)),
    },
    {
      key: "avg_satisfaction",
      header: "Avg CSAT",
      render: (r: any) => (
        <span className={satBadge(r.avg_satisfaction)}>
          {r.avg_satisfaction === null ? "—" : `${r.avg_satisfaction}/5`}
        </span>
      ),
    },
    { key: "last_claim_at", header: "Last claim", render: (r: any) => fmtDate(r.last_claim_at) },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder customer warranty claim closure tracker — r2404</h1>
        <p className="mt-1 text-xs text-gray-500">
          Open warranty claims, days-open burndown, vendor RMA status &amp; post-closure customer satisfaction. Anything
          open &gt;= 14 days is amber; &gt;= 30 days is red.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total claims</div>
          <div className="mt-1 text-lg font-semibold">{totalCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Open</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{openCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Closed</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{closedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Overdue (&gt;=14d)</div>
          <div className="mt-1 text-lg font-semibold text-red-700">{overdueCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg days open</div>
          <div className="mt-1 text-lg font-semibold">{avgDaysOpen}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg CSAT</div>
          <div className="mt-1 text-lg font-semibold">{avgSat === 0 ? "—" : `${avgSat}/5`}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All warranty claims</h2>
        <p className="text-xs text-gray-500">
          Sorted open-first, then newest-first. RMA flow: pending =&gt; approved =&gt; shipped =&gt; received =&gt;
          closed. Customer CSAT collected post-closure (1..5).
        </p>
        <DataTable
          rows={claims}
          columns={claimColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No warranty claims logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Vendor RMA summary</h2>
        <p className="text-xs text-gray-500">
          Vendor-level closure performance. High open count &amp; long avg-days-to-close =&gt; renegotiate warranty SLA
          or drop vendor.
        </p>
        <DataTable
          rows={vendors}
          columns={vendorColumns}
          rowKey={(r: any, i: number) => String(r.vendor_name ?? i)}
          emptyMessage="No vendor warranty data yet."
        />
      </section>
    </div>
  );
}
