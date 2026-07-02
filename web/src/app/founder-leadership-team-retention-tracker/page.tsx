import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder leadership team retention tracker — r2317" };
export const dynamic = "force-dynamic";

type MemberRow = {
  id: string;
  full_name: string;
  role_title: string;
  department: string;
  is_direct_report: boolean;
  hired_on: string;
  tenure_days: number;
  last_satisfaction_score: number | null;
  last_satisfaction_at: string | null;
  retention_risk_score: number;
  status: string;
  play_count: number;
  open_followup_count: number;
};

type AtRiskRow = {
  id: string;
  full_name: string;
  role_title: string;
  department: string;
  tenure_days: number;
  last_satisfaction_score: number | null;
  retention_risk_score: number;
  status: string;
  last_play_on: string | null;
  last_play_type: string | null;
};

type PlayRow = {
  id: string;
  member_id: string;
  full_name: string;
  role_title: string;
  play_type: string;
  play_summary: string;
  played_on: string;
  outcome: string;
  followup_due_on: string | null;
};

type DeptRow = {
  department: string;
  headcount: number;
  direct_reports: number;
  active_members: number;
  at_risk_members: number;
  on_notice_members: number;
  departed_members: number;
  avg_tenure_days: number | null;
  avg_satisfaction: number | null;
  avg_risk_score: number | null;
  plays_last_30d: number;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function fmtYears(days: number): string {
  if (!days || days <= 0) return "0d";
  const years = (days / 365).toFixed(1);
  return `${years}y (${days}d)`;
}

function statusBadge(status: string): string {
  if (status === "active") return "text-emerald-700";
  if (status === "at_risk") return "text-amber-700";
  if (status === "on_notice") return "text-red-700";
  if (status === "departed") return "text-gray-500";
  return "";
}

function riskBadge(score: number): string {
  if (score >= 70) return "text-red-700 font-semibold";
  if (score >= 40) return "text-amber-700 font-semibold";
  return "text-emerald-700";
}

function outcomeBadge(outcome: string): string {
  if (outcome === "positive") return "text-emerald-700";
  if (outcome === "negative") return "text-red-700";
  if (outcome === "neutral") return "text-gray-600";
  if (outcome === "pending") return "text-amber-700";
  return "";
}

export default async function FounderLeadershipTeamRetentionTrackerPage() {
  const sb = await getSupabaseServerClient();
  const [membersRes, atRiskRes, playsRes, deptRes] = await Promise.all([
    sb.rpc("list_team_members_r2317"),
    sb.rpc("at_risk_roster_r2317"),
    sb.rpc("list_recent_plays_r2317"),
    sb.rpc("department_retention_summary_r2317"),
  ]);

  if (membersRes.error) throw new Error(`list_team_members_r2317: ${membersRes.error.message}`);
  if (atRiskRes.error) throw new Error(`at_risk_roster_r2317: ${atRiskRes.error.message}`);
  if (playsRes.error) throw new Error(`list_recent_plays_r2317: ${playsRes.error.message}`);
  if (deptRes.error) throw new Error(`department_retention_summary_r2317: ${deptRes.error.message}`);

  const members = (membersRes.data ?? []) as MemberRow[];
  const atRisk = (atRiskRes.data ?? []) as AtRiskRow[];
  const plays = (playsRes.data ?? []) as PlayRow[];
  const depts = (deptRes.data ?? []) as DeptRow[];

  const totalCount = members.length;
  const directReportCount = members.filter((m) => m.is_direct_report).length;
  const activeCount = members.filter((m) => m.status === "active").length;
  const atRiskCount = members.filter((m) => m.status === "at_risk").length;
  const onNoticeCount = members.filter((m) => m.status === "on_notice").length;
  const departedCount = members.filter((m) => m.status === "departed").length;
  const avgRisk =
    members.length > 0
      ? (members.reduce((sum, m) => sum + (m.retention_risk_score ?? 0), 0) / members.length).toFixed(1)
      : "0.0";

  const memberColumns: Column<MemberRow>[] = [
    {
      key: "full_name",
      header: "Name",
      render: (r: any) => (
        <div>
          <div className="font-medium">{r.full_name}</div>
          <div className="text-xs text-gray-500">{r.role_title}</div>
        </div>
      ),
    },
    { key: "department", header: "Dept", render: (r: any) => r.department },
    {
      key: "is_direct_report",
      header: "Direct",
      render: (r: any) => (r.is_direct_report ? "yes" : "no"),
    },
    { key: "tenure_days", header: "Tenure", render: (r: any) => fmtYears(r.tenure_days) },
    {
      key: "last_satisfaction_score",
      header: "Sat (1-10)",
      render: (r: any) => (r.last_satisfaction_score == null ? "—" : String(r.last_satisfaction_score)),
    },
    {
      key: "retention_risk_score",
      header: "Risk",
      render: (r: any) => <span className={riskBadge(r.retention_risk_score)}>{r.retention_risk_score}</span>,
    },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "play_count", header: "Plays", render: (r: any) => String(r.play_count) },
    {
      key: "open_followup_count",
      header: "Followups due",
      render: (r: any) =>
        r.open_followup_count > 0 ? (
          <span className="font-semibold text-red-700">{r.open_followup_count}</span>
        ) : (
          "0"
        ),
    },
  ];

  const atRiskColumns: Column<AtRiskRow>[] = [
    {
      key: "full_name",
      header: "Name",
      render: (r: any) => (
        <div>
          <div className="font-medium">{r.full_name}</div>
          <div className="text-xs text-gray-500">
            {r.role_title} · {r.department}
          </div>
        </div>
      ),
    },
    { key: "tenure_days", header: "Tenure", render: (r: any) => fmtYears(r.tenure_days) },
    {
      key: "last_satisfaction_score",
      header: "Sat",
      render: (r: any) => (r.last_satisfaction_score == null ? "—" : String(r.last_satisfaction_score)),
    },
    {
      key: "retention_risk_score",
      header: "Risk",
      render: (r: any) => <span className={riskBadge(r.retention_risk_score)}>{r.retention_risk_score}</span>,
    },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "last_play_on", header: "Last play", render: (r: any) => fmtDate(r.last_play_on) },
    { key: "last_play_type", header: "Last play type", render: (r: any) => r.last_play_type ?? "—" },
  ];

  const playColumns: Column<PlayRow>[] = [
    { key: "played_on", header: "Date", render: (r: any) => fmtDate(r.played_on) },
    {
      key: "full_name",
      header: "Member",
      render: (r: any) => (
        <div>
          <div className="font-medium">{r.full_name}</div>
          <div className="text-xs text-gray-500">{r.role_title}</div>
        </div>
      ),
    },
    { key: "play_type", header: "Play", render: (r: any) => r.play_type },
    {
      key: "play_summary",
      header: "Summary",
      render: (r: any) => <span className="text-sm">{r.play_summary}</span>,
    },
    {
      key: "outcome",
      header: "Outcome",
      render: (r: any) => <span className={outcomeBadge(r.outcome)}>{r.outcome}</span>,
    },
    { key: "followup_due_on", header: "Followup due", render: (r: any) => fmtDate(r.followup_due_on) },
  ];

  const deptColumns: Column<DeptRow>[] = [
    { key: "department", header: "Dept", render: (r: any) => <span className="font-medium">{r.department}</span> },
    { key: "headcount", header: "Headcount", render: (r: any) => String(r.headcount) },
    { key: "direct_reports", header: "Direct reports", render: (r: any) => String(r.direct_reports) },
    { key: "active_members", header: "Active", render: (r: any) => <span className="text-emerald-700">{r.active_members}</span> },
    { key: "at_risk_members", header: "At risk", render: (r: any) => <span className="text-amber-700">{r.at_risk_members}</span> },
    { key: "on_notice_members", header: "On notice", render: (r: any) => <span className="text-red-700">{r.on_notice_members}</span> },
    { key: "departed_members", header: "Departed", render: (r: any) => <span className="text-gray-500">{r.departed_members}</span> },
    {
      key: "avg_tenure_days",
      header: "Avg tenure",
      render: (r: any) => (r.avg_tenure_days == null ? "—" : fmtYears(r.avg_tenure_days)),
    },
    {
      key: "avg_satisfaction",
      header: "Avg sat",
      render: (r: any) => (r.avg_satisfaction == null ? "—" : String(r.avg_satisfaction)),
    },
    {
      key: "avg_risk_score",
      header: "Avg risk",
      render: (r: any) => (r.avg_risk_score == null ? "—" : String(r.avg_risk_score)),
    },
    { key: "plays_last_30d", header: "Plays (30d)", render: (r: any) => String(r.plays_last_30d) },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder leadership team retention tracker — r2317</h1>
        <p className="mt-1 text-xs text-gray-500">
          Direct reports, tenure, satisfaction signals & retention risk score. Log retention plays (1:1s, comp
          reviews, equity grants) and watch follow-ups so high-risk leaders don't walk before the next round.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-7">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total leaders</div>
          <div className="mt-1 text-lg font-semibold">{totalCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Direct reports</div>
          <div className="mt-1 text-lg font-semibold">{directReportCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Active</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{activeCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">At risk</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{atRiskCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">On notice</div>
          <div className="mt-1 text-lg font-semibold text-red-700">{onNoticeCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Departed</div>
          <div className="mt-1 text-lg font-semibold text-gray-500">{departedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg risk score</div>
          <div className="mt-1 text-lg font-semibold">{avgRisk}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">At-risk roster</h2>
        <p className="text-xs text-gray-500">
          Leaders with retention risk score &gt;= 40, sorted by risk. Top of list = highest probability of attrition
          without intervention. Open follow-ups overdue =&gt; ship a play today.
        </p>
        <DataTable
          rows={atRisk}
          columns={atRiskColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No leaders flagged at risk. Keep signaling."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All team members</h2>
        <p className="text-xs text-gray-500">
          Full leadership roster. Risk score derives from latest satisfaction signal (10 =&gt; 0 risk, 1 =&gt; 90
          risk). Tenure in years &amp; days. Followups due column flags overdue retention work.
        </p>
        <DataTable
          rows={members}
          columns={memberColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No leadership team members yet. Add direct reports to start tracking."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Department retention summary</h2>
        <p className="text-xs text-gray-500">
          Per-department health: headcount, status mix, avg tenure, avg satisfaction & avg risk. Departments with
          high at-risk counts & low play-rate (last 30d) need founder attention.
        </p>
        <DataTable
          rows={depts}
          columns={deptColumns}
          rowKey={(r: any, i: number) => String(r.department ?? i)}
          emptyMessage="No department roll-up yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Recent retention plays</h2>
        <p className="text-xs text-gray-500">
          Last 200 retention actions logged (1:1s, comp reviews, equity grants, promotions, scope expansion,
          recognition, coaching). Outcome rolls up the play's effect on the leader's risk score.
        </p>
        <DataTable
          rows={plays}
          columns={playColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No retention plays logged yet. Schedule a 1:1 with each at-risk leader this week."
        />
      </section>
    </div>
  );
}
