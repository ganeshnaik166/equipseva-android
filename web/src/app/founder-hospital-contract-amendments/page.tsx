import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const dynamic = "force-dynamic";

type Amendment = {
  id: string;
  contract_id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  amendment_kind: string;
  title: string;
  status: string;
  prior_tier: string | null;
  new_tier: string | null;
  prior_monthly_fee_rupees: number | null;
  new_monthly_fee_rupees: number | null;
  effective_from: string | null;
  effective_to: string | null;
  approval_required: boolean;
  approved_by_founder: boolean;
  signed_by_hospital: boolean;
  created_at: string;
};

type Summary = {
  total: number;
  drafts: number;
  pending: number;
  approved: number;
  rejected: number;
  signed: number;
  active: number;
  rescinded: number;
  price_changes: number;
  scope_expansions: number;
  exclusions: number;
  net_monthly_delta_rupees: number;
};

type ByKind = {
  amendment_kind: string;
  total: number;
  approved: number;
  pending: number;
  rejected: number;
  net_fee_delta_rupees: number;
};

type AuditRow = {
  id: string;
  amendment_id: string;
  amendment_title: string | null;
  event: string;
  prior_status: string | null;
  new_status: string | null;
  notes: string | null;
  actor_email: string | null;
  created_at: string;
};

type TopHospital = {
  hospital_user_id: string;
  hospital_email: string | null;
  total: number;
  price_changes: number;
  scope_expansions: number;
  exclusions: number;
  net_monthly_delta_rupees: number;
  last_amendment_at: string | null;
};

type PendingRow = {
  id: string;
  contract_id: string;
  hospital_email: string | null;
  amendment_kind: string;
  title: string;
  prior_tier: string | null;
  new_tier: string | null;
  fee_delta_rupees: number;
  effective_from: string | null;
  age_hours: number;
  created_at: string;
};

type TrendRow = {
  month_start: string;
  total: number;
  approved: number;
  rejected: number;
  signed: number;
  net_monthly_delta_rupees: number;
};

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  const sign = n < 0 ? "-" : "";
  return sign + "₹" + Math.abs(n).toLocaleString("en-IN");
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return "—";
  try {
    return new Date(s).toLocaleString("en-IN", { dateStyle: "medium", timeStyle: "short" });
  } catch {
    return s;
  }
}

function fmtMonth(s: string | null | undefined): string {
  if (!s) return "—";
  try {
    return new Date(s).toLocaleDateString("en-IN", { year: "numeric", month: "short" });
  } catch {
    return s;
  }
}

export default async function HospitalContractAmendmentsPage() {
  const sb = await getSupabaseServerClient();

  const summaryRes = await sb.rpc("founder_amendments_summary");
  const listRes = await sb.rpc("founder_amendments_list", { p_status: null, p_limit: 200 });
  const byKindRes = await sb.rpc("founder_amendments_by_kind");
  const auditRes = await sb.rpc("founder_amendments_recent_audit", { p_limit: 100 });
  const topRes = await sb.rpc("founder_amendments_top_hospitals", { p_limit: 20 });
  const pendingRes = await sb.rpc("founder_amendments_pending_queue", { p_limit: 50 });
  const trendRes = await sb.rpc("founder_amendments_monthly_trend");

  const summary: Summary | null = (summaryRes.data?.[0] as Summary) ?? null;
  const amendments: Amendment[] = (listRes.data as Amendment[]) ?? [];
  const byKind: ByKind[] = (byKindRes.data as ByKind[]) ?? [];
  const audit: AuditRow[] = (auditRes.data as AuditRow[]) ?? [];
  const topHospitals: TopHospital[] = (topRes.data as TopHospital[]) ?? [];
  const pending: PendingRow[] = (pendingRes.data as PendingRow[]) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];

  const amendmentColumns: Column<Amendment>[] = [
    { key: "title", header: "Amendment", render: (r) => r.title ?? "—" },
    { key: "kind", header: "Kind", render: (r) => r.amendment_kind ?? "—" },
    { key: "hospital", header: "Hospital", render: (r) => r.hospital_email ?? "—" },
    { key: "status", header: "Status", render: (r) => r.status ?? "—" },
    { key: "tier", header: "Tier", render: (r) => (r.prior_tier ?? "—") + " → " + (r.new_tier ?? "—") },
    { key: "fee_prior", header: "Prior Fee", render: (r) => fmtRupees(r.prior_monthly_fee_rupees) },
    { key: "fee_new", header: "New Fee", render: (r) => fmtRupees(r.new_monthly_fee_rupees) },
    { key: "approval", header: "Approval", render: (r) => (r.approved_by_founder ? "approved" : r.approval_required ? "required" : "n/a") },
    { key: "signed", header: "Signed", render: (r) => (r.signed_by_hospital ? "yes" : "no") },
    { key: "effective", header: "Effective From", render: (r) => r.effective_from ?? "—" },
    { key: "created", header: "Created", render: (r) => fmtDate(r.created_at) },
  ];

  const byKindColumns: Column<ByKind>[] = [
    { key: "kind", header: "Kind", render: (r) => r.amendment_kind ?? "—" },
    { key: "total", header: "Total", render: (r) => String(r.total ?? 0) },
    { key: "approved", header: "Approved", render: (r) => String(r.approved ?? 0) },
    { key: "pending", header: "Pending", render: (r) => String(r.pending ?? 0) },
    { key: "rejected", header: "Rejected", render: (r) => String(r.rejected ?? 0) },
    { key: "delta", header: "Net Fee Delta", render: (r) => fmtRupees(r.net_fee_delta_rupees) },
  ];

  const pendingColumns: Column<PendingRow>[] = [
    { key: "title", header: "Amendment", render: (r) => r.title ?? "—" },
    { key: "hospital", header: "Hospital", render: (r) => r.hospital_email ?? "—" },
    { key: "kind", header: "Kind", render: (r) => r.amendment_kind ?? "—" },
    { key: "tier", header: "Tier", render: (r) => (r.prior_tier ?? "—") + " → " + (r.new_tier ?? "—") },
    { key: "delta", header: "Fee Delta", render: (r) => fmtRupees(r.fee_delta_rupees) },
    { key: "effective", header: "Effective", render: (r) => r.effective_from ?? "—" },
    { key: "age", header: "Age (hrs)", render: (r) => String(r.age_hours ?? 0) },
    { key: "created", header: "Created", render: (r) => fmtDate(r.created_at) },
  ];

  const topColumns: Column<TopHospital>[] = [
    { key: "hospital", header: "Hospital", render: (r) => r.hospital_email ?? "—" },
    { key: "total", header: "Total", render: (r) => String(r.total ?? 0) },
    { key: "price", header: "Price Changes", render: (r) => String(r.price_changes ?? 0) },
    { key: "scope", header: "Scope Expansions", render: (r) => String(r.scope_expansions ?? 0) },
    { key: "excl", header: "Exclusions", render: (r) => String(r.exclusions ?? 0) },
    { key: "delta", header: "Net Monthly Delta", render: (r) => fmtRupees(r.net_monthly_delta_rupees) },
    { key: "last", header: "Last Amendment", render: (r) => fmtDate(r.last_amendment_at) },
  ];

  const auditColumns: Column<AuditRow>[] = [
    { key: "created", header: "When", render: (r) => fmtDate(r.created_at) },
    { key: "title", header: "Amendment", render: (r) => r.amendment_title ?? "—" },
    { key: "event", header: "Event", render: (r) => r.event ?? "—" },
    { key: "transition", header: "Transition", render: (r) => (r.prior_status ?? "—") + " → " + (r.new_status ?? "—") },
    { key: "actor", header: "Actor", render: (r) => r.actor_email ?? "—" },
    { key: "notes", header: "Notes", render: (r) => r.notes ?? "—" },
  ];

  const trendColumns: Column<TrendRow>[] = [
    { key: "month", header: "Month", render: (r) => fmtMonth(r.month_start) },
    { key: "total", header: "Total", render: (r) => String(r.total ?? 0) },
    { key: "approved", header: "Approved", render: (r) => String(r.approved ?? 0) },
    { key: "signed", header: "Signed", render: (r) => String(r.signed ?? 0) },
    { key: "rejected", header: "Rejected", render: (r) => String(r.rejected ?? 0) },
    { key: "delta", header: "Net Monthly Delta", render: (r) => fmtRupees(r.net_monthly_delta_rupees) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-6 py-8 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Hospital Contract Amendments</h1>
        <p className="text-sm text-gray-600">
          Tracks every AMC amendment — price changes, scope expansion, exclusions — with per-amendment approval and signature audit.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total Amendments</div>
          <div className="text-2xl font-semibold">{summary?.total ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Pending Approval</div>
          <div className="text-2xl font-semibold">{summary?.pending ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Signed / Active</div>
          <div className="text-2xl font-semibold">{(summary?.signed ?? 0) + (summary?.active ?? 0)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Net Monthly Delta</div>
          <div className="text-2xl font-semibold">{fmtRupees(summary?.net_monthly_delta_rupees ?? 0)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Price Changes</div>
          <div className="text-2xl font-semibold">{summary?.price_changes ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Scope Expansions</div>
          <div className="text-2xl font-semibold">{summary?.scope_expansions ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Exclusions</div>
          <div className="text-2xl font-semibold">{summary?.exclusions ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Rejected</div>
          <div className="text-2xl font-semibold">{summary?.rejected ?? 0}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Pending Approval Queue</h2>
        <DataTable
          rows={pending}
          columns={pendingColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All Amendments</h2>
        <DataTable
          rows={amendments}
          columns={amendmentColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">By Amendment Kind</h2>
        <DataTable
          rows={byKind}
          columns={byKindColumns}
          rowKey={(r: any, i: number) => String(r.amendment_kind ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Top Hospitals by Amendment Volume</h2>
        <DataTable
          rows={topHospitals}
          columns={topColumns}
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Monthly Trend (last 12 mo)</h2>
        <DataTable
          rows={trend}
          columns={trendColumns}
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent Audit Trail</h2>
        <DataTable
          rows={audit}
          columns={auditColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
