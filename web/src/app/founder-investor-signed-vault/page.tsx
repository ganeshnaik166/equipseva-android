import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const dynamic = "force-dynamic";

type Kpi = { label: string; value: string };

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "₹0";
  return "₹" + Number(n).toLocaleString("en-IN");
}

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return "0";
  return Number(n).toLocaleString("en-IN");
}

export default async function FounderInvestorSignedVaultPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let overview: any = {};
  let pending: any[] = [];
  let recent: any[] = [];
  let byType: any[] = [];
  let events: any[] = [];

  try {
    const r = await sb.rpc("rpc_founder_isv_overview");
    overview = (r.data && r.data[0]) || {};
  } catch {
    overview = {};
  }
  try {
    const r = await sb.rpc("rpc_founder_isv_pending_queue");
    pending = r.data || [];
  } catch {
    pending = [];
  }
  try {
    const r = await sb.rpc("rpc_founder_isv_recent_docs");
    recent = r.data || [];
  } catch {
    recent = [];
  }
  try {
    const r = await sb.rpc("rpc_founder_isv_by_doc_type");
    byType = r.data || [];
  } catch {
    byType = [];
  }
  try {
    const r = await sb.rpc("rpc_founder_isv_recent_events");
    events = r.data || [];
  } catch {
    events = [];
  }

  const kpis: Kpi[] = [
    { label: "Total Docs", value: fmtNum(overview.total_docs) },
    { label: "Pending Counter-Sign", value: fmtNum(overview.pending_counter_sign) },
    { label: "Counter-Signed", value: fmtNum(overview.counter_signed) },
    { label: "Executed", value: fmtNum(overview.executed) },
    { label: "Rejected", value: fmtNum(overview.rejected) },
    { label: "Draft", value: fmtNum(overview.draft_count) },
    { label: "Archived", value: fmtNum(overview.archived_count) },
    { label: "SAFEs", value: fmtNum(overview.safe_count) },
    { label: "Term Sheets", value: fmtNum(overview.term_sheet_count) },
    { label: "SPAs", value: fmtNum(overview.spa_count) },
    { label: "SHAs", value: fmtNum(overview.sha_count) },
    { label: "NDAs", value: fmtNum(overview.nda_count) },
    { label: "Capital Locked", value: fmtRupees(overview.total_capital_rupees) },
    { label: "Signed Last 30d", value: fmtNum(overview.signed_last_30d) },
    { label: "Pending Over 7d", value: fmtNum(overview.pending_over_7d) },
    { label: "Avg Days To C-Sign", value: (Number(overview.avg_days_to_countersign) || 0).toFixed(1) },
  ];

  const pendingCols: Column<any>[] = [
    { key: "doc_type", header: "Type", render: (r: any) => r.doc_type ?? "—" },
    { key: "doc_title", header: "Title", render: (r: any) => r.doc_title ?? "—" },
    { key: "investor_name", header: "Investor", render: (r: any) => r.investor_name ?? "—" },
    { key: "amount_rupees", header: "Amount", render: (r: any) => fmtRupees(r.amount_rupees) },
    { key: "days_pending", header: "Days Pending", render: (r: any) => String(r.days_pending ?? "—") },
    { key: "pdf_url", header: "PDF", render: (r: any) => r.pdf_url ?? "—" },
  ];

  const recentCols: Column<any>[] = [
    { key: "doc_type", header: "Type", render: (r: any) => r.doc_type ?? "—" },
    { key: "doc_title", header: "Title", render: (r: any) => r.doc_title ?? "—" },
    { key: "investor_name", header: "Investor", render: (r: any) => r.investor_name ?? "—" },
    { key: "status", header: "Status", render: (r: any) => r.status ?? "—" },
    { key: "amount_rupees", header: "Amount", render: (r: any) => fmtRupees(r.amount_rupees) },
    { key: "signing_date", header: "Signed", render: (r: any) => r.signing_date ?? "—" },
  ];

  const byTypeCols: Column<any>[] = [
    { key: "doc_type", header: "Doc Type", render: (r: any) => r.doc_type ?? "—" },
    { key: "doc_count", header: "Count", render: (r: any) => fmtNum(r.doc_count) },
    { key: "total_rupees", header: "Total", render: (r: any) => fmtRupees(r.total_rupees) },
    { key: "pending_count", header: "Pending", render: (r: any) => fmtNum(r.pending_count) },
    { key: "executed_count", header: "Executed", render: (r: any) => fmtNum(r.executed_count) },
  ];

  const eventsCols: Column<any>[] = [
    { key: "created_at", header: "When", render: (r: any) => (r.created_at ? new Date(r.created_at).toLocaleString("en-IN") : "—") },
    { key: "doc_title", header: "Doc", render: (r: any) => r.doc_title ?? "—" },
    { key: "event_type", header: "Event", render: (r: any) => r.event_type ?? "—" },
    { key: "actor_email", header: "Actor", render: (r: any) => r.actor_email ?? "—" },
    { key: "event_notes", header: "Notes", render: (r: any) => r.event_notes ?? "—" },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Investor Signed Agreements Vault</h1>
        <p className="text-sm text-gray-600">Central vault for SAFEs, term sheets, SPAs. Per-doc PDF, signing date, parties, founder counter-sign queue.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        {kpis.map((k) => (
          <div key={k.label} className="border rounded p-3 bg-white">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold">{k.value}</div>
          </div>
        ))}
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Counter-Sign Queue</h2>
        <DataTable rows={pending} columns={pendingCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Documents</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Doc Type</h2>
        <DataTable rows={byType} columns={byTypeCols} rowKey={(r: any) => r.doc_type} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Vault Events</h2>
        <DataTable rows={events} columns={eventsCols} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
