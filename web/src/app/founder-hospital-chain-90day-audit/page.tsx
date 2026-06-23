import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder hospital chain 90-day audit — r2331" };
export const dynamic = "force-dynamic";

type AuditRow = {
  id: string;
  chain_user_id: string;
  chain_name: string;
  chain_email: string | null;
  amc_start_date: string;
  audit_due_date: string;
  audit_status: string;
  csat_score: number | null;
  nps_score: number | null;
  uptime_actual_pct: number | null;
  uptime_promised_pct: number | null;
  response_sla_hit_pct: number | null;
  total_repairs: number;
  total_complaints: number;
  health_band: string;
  renewal_intent: string;
  founder_call_done: boolean;
  founder_call_at: string | null;
  audit_completed_at: string | null;
  created_at: string;
};

type StatusSummaryRow = {
  audit_status: string;
  audit_count: number;
  avg_csat: number | null;
  avg_nps: number | null;
  avg_uptime_gap: number | null;
};

type HealthBandRow = {
  health_band: string;
  chain_count: number;
  avg_csat: number | null;
  avg_total_complaints: number | null;
  at_risk_count: number;
};

type OverdueRow = {
  id: string;
  chain_name: string;
  audit_due_date: string;
  days_overdue: number;
  amc_start_date: string;
  audit_status: string;
  founder_call_done: boolean;
};

type IssueCategoryRow = {
  issue_category: string;
  issue_count: number;
  open_count: number;
  resolved_count: number;
  critical_count: number;
};

type CriticalIssueRow = {
  id: string;
  audit_id: string;
  chain_name: string;
  issue_category: string;
  severity: string;
  issue_description: string;
  corrective_action: string | null;
  due_date: string | null;
  status: string;
  created_at: string;
};

type RenewalRow = {
  renewal_intent: string;
  chain_count: number;
  avg_csat: number | null;
  avg_complaints: number | null;
  founder_calls_done: number;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function fmtNum(n: number | null, digits = 1): string {
  if (n === null || n === undefined) return "—";
  return Number(n).toFixed(digits);
}

function healthClass(b: string): string {
  if (b === "green") return "text-emerald-700";
  if (b === "amber") return "text-amber-700";
  if (b === "red") return "text-red-700 font-semibold";
  return "text-gray-500";
}

function renewalClass(r: string): string {
  if (r === "strong") return "text-emerald-700";
  if (r === "likely") return "text-emerald-600";
  if (r === "at_risk") return "text-amber-700";
  if (r === "will_churn") return "text-red-700 font-semibold";
  return "text-gray-500";
}

function severityClass(s: string): string {
  if (s === "critical") return "text-red-700 font-semibold";
  if (s === "high") return "text-amber-700";
  if (s === "medium") return "text-gray-700";
  return "text-gray-500";
}

export default async function FounderHospitalChain90dayAuditPage() {
  const sb = await getSupabaseServerClient();
  const [auditsRes, statusRes, healthRes, overdueRes, issuesRes, criticalRes, renewalRes] = await Promise.all([
    sb.rpc("list_chain_90day_audits_r2331"),
    sb.rpc("audit_status_summary_r2331"),
    sb.rpc("audit_health_band_summary_r2331"),
    sb.rpc("overdue_audits_r2331"),
    sb.rpc("top_issue_categories_r2331"),
    sb.rpc("open_critical_issues_r2331"),
    sb.rpc("renewal_intent_breakdown_r2331"),
  ]);

  if (auditsRes.error) throw new Error(`list_chain_90day_audits_r2331: ${auditsRes.error.message}`);
  if (statusRes.error) throw new Error(`audit_status_summary_r2331: ${statusRes.error.message}`);
  if (healthRes.error) throw new Error(`audit_health_band_summary_r2331: ${healthRes.error.message}`);
  if (overdueRes.error) throw new Error(`overdue_audits_r2331: ${overdueRes.error.message}`);
  if (issuesRes.error) throw new Error(`top_issue_categories_r2331: ${issuesRes.error.message}`);
  if (criticalRes.error) throw new Error(`open_critical_issues_r2331: ${criticalRes.error.message}`);
  if (renewalRes.error) throw new Error(`renewal_intent_breakdown_r2331: ${renewalRes.error.message}`);

  const audits = (auditsRes.data ?? []) as AuditRow[];
  const statusRows = (statusRes.data ?? []) as StatusSummaryRow[];
  const healthRows = (healthRes.data ?? []) as HealthBandRow[];
  const overdueRows = (overdueRes.data ?? []) as OverdueRow[];
  const issueRows = (issuesRes.data ?? []) as IssueCategoryRow[];
  const criticalRows = (criticalRes.data ?? []) as CriticalIssueRow[];
  const renewalRows = (renewalRes.data ?? []) as RenewalRow[];

  const totalAudits = audits.length;
  const completedCount = audits.filter((a) => a.audit_status === "completed").length;
  const pendingCount = audits.filter((a) => a.audit_status === "pending" || a.audit_status === "in_progress").length;
  const overdueCount = overdueRows.length;
  const redChains = audits.filter((a) => a.health_band === "red").length;
  const atRiskRenewal = audits.filter((a) => a.renewal_intent === "at_risk" || a.renewal_intent === "will_churn").length;

  const auditColumns: Column<AuditRow>[] = [
    { key: "chain_name", header: "Chain", render: (r: any) => <span className="font-medium">{r.chain_name}</span> },
    { key: "amc_start_date", header: "AMC start", render: (r: any) => fmtDate(r.amc_start_date) },
    { key: "audit_due_date", header: "Audit due", render: (r: any) => fmtDate(r.audit_due_date) },
    { key: "audit_status", header: "Status", render: (r: any) => r.audit_status },
    { key: "csat_score", header: "CSAT", render: (r: any) => fmtNum(r.csat_score, 1) },
    { key: "nps_score", header: "NPS", render: (r: any) => (r.nps_score === null ? "—" : String(r.nps_score)) },
    { key: "uptime_actual_pct", header: "Uptime", render: (r: any) => (r.uptime_actual_pct === null ? "—" : `${fmtNum(r.uptime_actual_pct, 1)}%`) },
    { key: "total_complaints", header: "Complaints", render: (r: any) => String(r.total_complaints) },
    { key: "health_band", header: "Health", render: (r: any) => <span className={healthClass(r.health_band)}>{r.health_band}</span> },
    { key: "renewal_intent", header: "Renewal", render: (r: any) => <span className={renewalClass(r.renewal_intent)}>{r.renewal_intent}</span> },
    { key: "founder_call_done", header: "Founder call", render: (r: any) => (r.founder_call_done ? "yes" : "no") },
  ];

  const statusColumns: Column<StatusSummaryRow>[] = [
    { key: "audit_status", header: "Status", render: (r: any) => r.audit_status },
    { key: "audit_count", header: "Count", render: (r: any) => String(r.audit_count) },
    { key: "avg_csat", header: "Avg CSAT", render: (r: any) => fmtNum(r.avg_csat, 2) },
    { key: "avg_nps", header: "Avg NPS", render: (r: any) => fmtNum(r.avg_nps, 1) },
    { key: "avg_uptime_gap", header: "Avg uptime gap", render: (r: any) => fmtNum(r.avg_uptime_gap, 2) },
  ];

  const healthColumns: Column<HealthBandRow>[] = [
    { key: "health_band", header: "Health band", render: (r: any) => <span className={healthClass(r.health_band)}>{r.health_band}</span> },
    { key: "chain_count", header: "Chains", render: (r: any) => String(r.chain_count) },
    { key: "avg_csat", header: "Avg CSAT", render: (r: any) => fmtNum(r.avg_csat, 2) },
    { key: "avg_total_complaints", header: "Avg complaints", render: (r: any) => fmtNum(r.avg_total_complaints, 1) },
    { key: "at_risk_count", header: "Renewal at risk", render: (r: any) => String(r.at_risk_count) },
  ];

  const overdueColumns: Column<OverdueRow>[] = [
    { key: "chain_name", header: "Chain", render: (r: any) => <span className="font-medium">{r.chain_name}</span> },
    { key: "audit_due_date", header: "Due", render: (r: any) => fmtDate(r.audit_due_date) },
    { key: "days_overdue", header: "Days overdue", render: (r: any) => <span className="text-red-700 font-semibold">{r.days_overdue}</span> },
    { key: "amc_start_date", header: "AMC start", render: (r: any) => fmtDate(r.amc_start_date) },
    { key: "audit_status", header: "Status", render: (r: any) => r.audit_status },
    { key: "founder_call_done", header: "Founder call", render: (r: any) => (r.founder_call_done ? "yes" : "no") },
  ];

  const issueColumns: Column<IssueCategoryRow>[] = [
    { key: "issue_category", header: "Category", render: (r: any) => <span className="font-medium">{r.issue_category}</span> },
    { key: "issue_count", header: "Total", render: (r: any) => String(r.issue_count) },
    { key: "open_count", header: "Open", render: (r: any) => <span className="text-amber-700">{r.open_count}</span> },
    { key: "resolved_count", header: "Resolved", render: (r: any) => <span className="text-emerald-700">{r.resolved_count}</span> },
    { key: "critical_count", header: "Critical", render: (r: any) => <span className="text-red-700">{r.critical_count}</span> },
  ];

  const criticalColumns: Column<CriticalIssueRow>[] = [
    { key: "chain_name", header: "Chain", render: (r: any) => <span className="font-medium">{r.chain_name}</span> },
    { key: "issue_category", header: "Category", render: (r: any) => r.issue_category },
    { key: "severity", header: "Severity", render: (r: any) => <span className={severityClass(r.severity)}>{r.severity}</span> },
    { key: "issue_description", header: "Issue", render: (r: any) => r.issue_description },
    { key: "corrective_action", header: "Corrective action", render: (r: any) => r.corrective_action ?? "—" },
    { key: "due_date", header: "Due", render: (r: any) => fmtDate(r.due_date) },
    { key: "status", header: "Status", render: (r: any) => r.status },
  ];

  const renewalColumns: Column<RenewalRow>[] = [
    { key: "renewal_intent", header: "Intent", render: (r: any) => <span className={renewalClass(r.renewal_intent)}>{r.renewal_intent}</span> },
    { key: "chain_count", header: "Chains", render: (r: any) => String(r.chain_count) },
    { key: "avg_csat", header: "Avg CSAT", render: (r: any) => fmtNum(r.avg_csat, 2) },
    { key: "avg_complaints", header: "Avg complaints", render: (r: any) => fmtNum(r.avg_complaints, 1) },
    { key: "founder_calls_done", header: "Founder calls done", render: (r: any) => String(r.founder_calls_done) },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder hospital chain 90-day audit — r2331</h1>
        <p className="mt-1 text-xs text-gray-500">
          At day 90 after AMC start, audit chain satisfaction, surface issues, and trigger course correction before
          renewal risk hits. Red health band &amp; will_churn intent =&gt; immediate founder call.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total audits</div>
          <div className="mt-1 text-lg font-semibold">{totalAudits}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Completed</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{completedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Pending</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{pendingCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Overdue</div>
          <div className="mt-1 text-lg font-semibold text-red-700">{overdueCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Red health chains</div>
          <div className="mt-1 text-lg font-semibold text-red-700">{redChains}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Renewal at risk</div>
          <div className="mt-1 text-lg font-semibold text-red-700">{atRiskRenewal}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All 90-day audits</h2>
        <p className="text-xs text-gray-500">
          Ordered by audit due date. CSAT &lt; 7 or uptime gap &gt;= 5% =&gt; investigate immediately.
        </p>
        <DataTable
          rows={audits}
          columns={auditColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No 90-day audits scheduled yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Audit status summary</h2>
        <DataTable
          rows={statusRows}
          columns={statusColumns}
          rowKey={(r: any, i: number) => String(r.audit_status ?? i)}
          emptyMessage="No audit status data."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Health band breakdown</h2>
        <p className="text-xs text-gray-500">
          Red &amp; amber chains are course-correction targets — engineer rotation, parts SLA escalation, or
          founder call.
        </p>
        <DataTable
          rows={healthRows}
          columns={healthColumns}
          rowKey={(r: any, i: number) => String(r.health_band ?? i)}
          emptyMessage="No health band data."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Overdue audits</h2>
        <p className="text-xs text-gray-500">
          Audits past due date with status not completed. Days overdue &gt;= 14 =&gt; founder must call within 48h.
        </p>
        <DataTable
          rows={overdueRows}
          columns={overdueColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No overdue audits."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Top issue categories</h2>
        <p className="text-xs text-gray-500">
          Aggregated across all 90-day audits. Recurring categories =&gt; systemic fix needed (training, hiring, SOP).
        </p>
        <DataTable
          rows={issueRows}
          columns={issueColumns}
          rowKey={(r: any, i: number) => String(r.issue_category ?? i)}
          emptyMessage="No issues logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Open critical &amp; high-severity issues</h2>
        <p className="text-xs text-gray-500">
          Severity &gt;= high &amp; status in (open, in_progress). These are renewal blockers.
        </p>
        <DataTable
          rows={criticalRows}
          columns={criticalColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No open critical issues."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Renewal intent breakdown</h2>
        <p className="text-xs text-gray-500">
          Audit-driven renewal forecast. will_churn &amp; at_risk =&gt; founder must intervene before contract end.
        </p>
        <DataTable
          rows={renewalRows}
          columns={renewalColumns}
          rowKey={(r: any, i: number) => String(r.renewal_intent ?? i)}
          emptyMessage="No renewal intent data."
        />
      </section>
    </div>
  );
}
