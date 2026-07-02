import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder engineer side-gig tracker — r1768" };
export const dynamic = "force-dynamic";

type DisclosureRow = {
  id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  side_activity_name: string;
  side_activity_type: string;
  hours_per_week: number;
  disclosed_at: string;
  status: string;
  founder_decision: string | null;
  check_count: number;
  created_at: string;
};

type CheckRow = {
  id: string;
  disclosure_id: string;
  check_type: string;
  checked_at: string;
  by_email: string | null;
  finding: string | null;
  disclosure_status: string;
  disclosure_activity_type: string;
};

type SummaryRow = {
  total_disclosed: number;
  total_approved: number;
  total_blocked: number;
  total_withdrawn: number;
  competitor_open: number;
  high_hours_open: number;
  avg_hours_per_week: number | null;
  disclosures_last_30d: number;
  approvals_last_30d: number;
};

type RiskRow = {
  side_activity_type: string;
  total_count: number;
  disclosed_count: number;
  approved_count: number;
  blocked_count: number;
  withdrawn_count: number;
  total_hours: number | null;
  flagged_check_count: number;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 16).replace("T", " ");
  } catch {
    return "—";
  }
}

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return Number(n).toLocaleString();
}

function activityBadge(t: string): string {
  if (t === "competitor") return "text-red-700 font-semibold";
  if (t === "freelance") return "text-orange-700";
  if (t === "research") return "text-blue-700";
  if (t === "teaching") return "text-indigo-700";
  if (t === "family_biz") return "text-amber-700";
  if (t === "non_competitor") return "text-emerald-700";
  return "";
}

function statusBadge(st: string): string {
  if (st === "disclosed") return "text-amber-700";
  if (st === "approved") return "text-emerald-700";
  if (st === "blocked") return "text-red-700 font-semibold";
  if (st === "withdrawn") return "text-gray-500";
  return "";
}

function shortId(s: string): string {
  if (!s) return "—";
  return s.slice(0, 8);
}

export default async function FounderEngineerSideGigTrackerPage() {
  const sb = await getSupabaseServerClient();
  const [disclosuresRes, checksRes, summaryRes, risksRes] = await Promise.all([
    sb.rpc("list_disclosures_r1768"),
    sb.rpc("list_checks_r1768", { p_disclosure_id: null }),
    sb.rpc("active_disclosures_summary_r1768"),
    sb.rpc("conflict_risks_r1768"),
  ]);

  if (disclosuresRes.error) throw new Error(`list_disclosures_r1768: ${disclosuresRes.error.message}`);
  if (checksRes.error) throw new Error(`list_checks_r1768: ${checksRes.error.message}`);
  if (summaryRes.error) throw new Error(`active_disclosures_summary_r1768: ${summaryRes.error.message}`);
  if (risksRes.error) throw new Error(`conflict_risks_r1768: ${risksRes.error.message}`);

  const disclosures = (disclosuresRes.data ?? []) as DisclosureRow[];
  const checks = (checksRes.data ?? []) as CheckRow[];
  const risks = (risksRes.data ?? []) as RiskRow[];
  const summaryArr = (summaryRes.data ?? []) as SummaryRow[];
  const summary: SummaryRow = summaryArr[0] ?? {
    total_disclosed: 0,
    total_approved: 0,
    total_blocked: 0,
    total_withdrawn: 0,
    competitor_open: 0,
    high_hours_open: 0,
    avg_hours_per_week: null,
    disclosures_last_30d: 0,
    approvals_last_30d: 0,
  };

  const disclosureColumns: Column<DisclosureRow>[] = [
    { key: "disclosed_at", header: "Disclosed", render: (r: any) => fmtDate(r.disclosed_at) },
    { key: "engineer_email", header: "Engineer", render: (r: any) => r.engineer_email ?? shortId(r.engineer_user_id) },
    { key: "side_activity_name", header: "Activity", render: (r: any) => <span className="text-sm">{(r.side_activity_name ?? "").slice(0, 60)}</span> },
    { key: "side_activity_type", header: "Type", render: (r: any) => <span className={activityBadge(r.side_activity_type)}>{r.side_activity_type}</span> },
    { key: "hours_per_week", header: "Hrs/wk", render: (r: any) => <span className={Number(r.hours_per_week) > 10 ? "text-red-700 font-semibold" : ""}>{fmtNum(r.hours_per_week)}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "check_count", header: "Checks", render: (r: any) => fmtNum(r.check_count) },
    { key: "founder_decision", header: "Decision", render: (r: any) => <span className="text-sm">{(r.founder_decision ?? "—").slice(0, 60)}</span> },
  ];

  const checkColumns: Column<CheckRow>[] = [
    { key: "checked_at", header: "Checked", render: (r: any) => fmtDate(r.checked_at) },
    { key: "check_type", header: "Check", render: (r: any) => <span className="font-medium">{r.check_type}</span> },
    { key: "by_email", header: "By", render: (r: any) => r.by_email ?? "—" },
    { key: "finding", header: "Finding", render: (r: any) => <span className="text-sm">{(r.finding ?? "—").slice(0, 80)}</span> },
    { key: "disclosure_activity_type", header: "Activity type", render: (r: any) => <span className={activityBadge(r.disclosure_activity_type)}>{r.disclosure_activity_type}</span> },
    { key: "disclosure_status", header: "Disc. status", render: (r: any) => <span className={statusBadge(r.disclosure_status)}>{r.disclosure_status}</span> },
    { key: "disclosure_id", header: "Disclosure", render: (r: any) => <span className="font-mono text-xs">{shortId(r.disclosure_id)}</span> },
  ];

  const riskColumns: Column<RiskRow>[] = [
    { key: "side_activity_type", header: "Activity type", render: (r: any) => <span className={activityBadge(r.side_activity_type)}>{r.side_activity_type}</span> },
    { key: "total_count", header: "Total", render: (r: any) => fmtNum(r.total_count) },
    { key: "disclosed_count", header: "Disclosed", render: (r: any) => <span className="text-amber-700">{fmtNum(r.disclosed_count)}</span> },
    { key: "approved_count", header: "Approved", render: (r: any) => <span className="text-emerald-700">{fmtNum(r.approved_count)}</span> },
    { key: "blocked_count", header: "Blocked", render: (r: any) => <span className="text-red-700">{fmtNum(r.blocked_count)}</span> },
    { key: "withdrawn_count", header: "Withdrawn", render: (r: any) => <span className="text-gray-500">{fmtNum(r.withdrawn_count)}</span> },
    { key: "total_hours", header: "Total hrs/wk", render: (r: any) => r.total_hours === null ? "—" : fmtNum(r.total_hours) },
    { key: "flagged_check_count", header: "Flagged checks", render: (r: any) => <span className={Number(r.flagged_check_count) > 0 ? "text-red-700 font-semibold" : ""}>{fmtNum(r.flagged_check_count)}</span> },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Engineer side-gig tracker</h1>
        <p className="text-sm text-gray-600">
          Track engineer moonlighting disclosures and conflict-of-interest checks. Activity types span competitor, non-competitor, freelance, teaching, research, and family business. Status flow: disclosed &gt; approved or blocked or withdrawn.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Summary</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Disclosed (pending)</div>
            <div className="text-2xl font-semibold text-amber-700">{fmtNum(summary.total_disclosed)}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Approved</div>
            <div className="text-2xl font-semibold text-emerald-700">{fmtNum(summary.total_approved)}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Blocked</div>
            <div className="text-2xl font-semibold text-red-700">{fmtNum(summary.total_blocked)}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Withdrawn</div>
            <div className="text-2xl font-semibold text-gray-600">{fmtNum(summary.total_withdrawn)}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Competitor open</div>
            <div className="text-2xl font-semibold text-red-700">{fmtNum(summary.competitor_open)}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">High hours open (&gt;10/wk)</div>
            <div className="text-2xl font-semibold text-orange-700">{fmtNum(summary.high_hours_open)}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Avg hours/week</div>
            <div className="text-2xl font-semibold">{summary.avg_hours_per_week === null ? "—" : fmtNum(summary.avg_hours_per_week)}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Disclosures (last 30d)</div>
            <div className="text-2xl font-semibold">{fmtNum(summary.disclosures_last_30d)}</div>
          </div>
        </div>
        <p className="text-xs text-gray-500">
          Competitor-open rows are the highest-risk class — any row with hours_per_week &gt;= 10 or activity_type = competitor should land a founder decision within 5 business days. Approvals (last 30d): {fmtNum(summary.approvals_last_30d)}.
        </p>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Conflict risks by activity type</h2>
        <p className="text-sm text-gray-600">
          Cross-section by activity type, with status splits, total hours, and flagged-check counts. A competitor row with flagged_check_count &gt;= 1 is grounds for immediate block.
        </p>
        <DataTable rows={risks} columns={riskColumns} rowKey={(r: any, i: number) => String(r.side_activity_type ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Disclosures ({disclosures.length})</h2>
        <p className="text-sm text-gray-600">
          Most recent first. Hours/week &gt; 10 highlighted red — engineers approaching half-time elsewhere are a retention and conflict risk. Pending rows older than &gt;= 5 days need a decision.
        </p>
        <DataTable rows={disclosures} columns={disclosureColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Compliance checks ({checks.length})</h2>
        <p className="text-sm text-gray-600">
          Recent checks across all disclosures. Findings tied to schedule_conflict or customer_overlap on a competitor disclosure are blocking by default; equipment_use and code_overlap findings require founder review within &lt;= 48 hours.
        </p>
        <DataTable rows={checks} columns={checkColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
