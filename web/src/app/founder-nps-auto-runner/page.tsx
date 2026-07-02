import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "NPS auto-runner — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  jobs_total: number;
  jobs_scheduled: number;
  jobs_sending: number;
  jobs_collecting: number;
  jobs_closing: number;
  jobs_closed: number;
  jobs_aborted: number;
  current_quarter_label: string | null;
  current_quarter_status: string | null;
  current_target_hospitals: number;
  current_hospitals_sent: number;
  current_hospitals_responded: number;
  current_response_rate_pct: number | null;
  latest_closed_nps: number | null;
  latest_closed_promoter_pct: number | null;
  latest_closed_detractor_pct: number | null;
};

type Job = {
  id: string;
  quarter_label: string;
  status: string;
  scheduled_for_send_at: string | null;
  scheduled_for_close_at: string | null;
  target_hospital_count: number;
  hospitals_sent: number;
  hospitals_responded: number;
  response_rate_pct: number | null;
  final_nps_score: number | null;
  last_action_at: string | null;
  created_at: string;
};

function fmtPct(v: number | null | undefined): string {
  if (v === null || v === undefined) return "—";
  return `${Number(v).toFixed(1)}%`;
}
function fmtScore(v: number | null | undefined): string {
  if (v === null || v === undefined) return "—";
  return Number(v).toFixed(1);
}
function fmtDate(v: string | null | undefined): string {
  if (!v) return "—";
  return new Date(v).toLocaleString("en-IN", { timeZone: "Asia/Kolkata", dateStyle: "short", timeStyle: "short" });
}
function statusColor(s: string): string {
  if (s === "closed") return "text-[var(--color-ok)]";
  if (s === "aborted") return "text-[var(--color-danger)]";
  if (s === "scheduled") return "text-[var(--color-muted)]";
  return "text-[var(--color-warn)]";
}

export default async function FounderNpsAutoRunnerPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, jobsRes] = await Promise.all([
    supabase.rpc("founder_nps_auto_runner_summary"),
    supabase.rpc("founder_nps_auto_runner_jobs_recent", { p_limit: 20 }),
  ]);
  if (summaryRes.error) throw new Error(`founder_nps_auto_runner_summary: ${summaryRes.error.message}`);
  if (jobsRes.error) throw new Error(`founder_nps_auto_runner_jobs_recent: ${jobsRes.error.message}`);

  const s: Summary = ((summaryRes.data ?? [])[0] ?? {
    jobs_total: 0, jobs_scheduled: 0, jobs_sending: 0, jobs_collecting: 0,
    jobs_closing: 0, jobs_closed: 0, jobs_aborted: 0,
    current_quarter_label: null, current_quarter_status: null,
    current_target_hospitals: 0, current_hospitals_sent: 0, current_hospitals_responded: 0,
    current_response_rate_pct: null, latest_closed_nps: null,
    latest_closed_promoter_pct: null, latest_closed_detractor_pct: null,
  }) as Summary;

  const jobs = (jobsRes.data ?? []) as Job[];

  const cards: { label: string; value: string; tone?: string }[] = [
    { label: "Jobs total", value: formatNumber(s.jobs_total) },
    { label: "Scheduled", value: formatNumber(s.jobs_scheduled), tone: "text-[var(--color-muted)]" },
    { label: "Sending", value: formatNumber(s.jobs_sending), tone: "text-[var(--color-warn)]" },
    { label: "Collecting", value: formatNumber(s.jobs_collecting), tone: "text-[var(--color-warn)]" },
    { label: "Closing", value: formatNumber(s.jobs_closing), tone: "text-[var(--color-warn)]" },
    { label: "Closed", value: formatNumber(s.jobs_closed), tone: "text-[var(--color-ok)]" },
    { label: "Aborted", value: formatNumber(s.jobs_aborted), tone: "text-[var(--color-danger)]" },
    { label: "Current quarter", value: s.current_quarter_label ?? "—" },
    { label: "Current status", value: s.current_quarter_status ?? "—", tone: s.current_quarter_status ? statusColor(s.current_quarter_status) : undefined },
    { label: "Target hospitals", value: formatNumber(s.current_target_hospitals) },
    { label: "Sent (current Q)", value: formatNumber(s.current_hospitals_sent) },
    { label: "Responded (current Q)", value: formatNumber(s.current_hospitals_responded), tone: "text-[var(--color-ok)]" },
    { label: "Response rate (current Q)", value: fmtPct(s.current_response_rate_pct) },
    { label: "Latest closed NPS", value: fmtScore(s.latest_closed_nps), tone: (s.latest_closed_nps ?? 0) >= 30 ? "text-[var(--color-ok)]" : "text-[var(--color-warn)]" },
    { label: "Latest promoters %", value: fmtPct(s.latest_closed_promoter_pct), tone: "text-[var(--color-ok)]" },
    { label: "Latest detractors %", value: fmtPct(s.latest_closed_detractor_pct), tone: "text-[var(--color-danger)]" },
  ];

  const cols: Column<Job>[] = [
    { key: "q", header: "Quarter", render: (r) => <span className="text-xs font-medium tabular-nums">{r.quarter_label}</span> },
    { key: "s", header: "Status", render: (r) => <span className={`text-xs uppercase tracking-wide ${statusColor(r.status)}`}>{r.status}</span> },
    { key: "snd", header: "Send at", render: (r) => <span className="text-xs text-[var(--color-muted)]">{fmtDate(r.scheduled_for_send_at)}</span> },
    { key: "cls", header: "Close at", render: (r) => <span className="text-xs text-[var(--color-muted)]">{fmtDate(r.scheduled_for_close_at)}</span> },
    { key: "tg", header: "Target", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.target_hospital_count)}</span> },
    { key: "st", header: "Sent", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.hospitals_sent)}</span> },
    { key: "rp", header: "Resp", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.hospitals_responded)}</span> },
    { key: "rr", header: "Resp rate", render: (r) => <span className="text-xs tabular-nums">{fmtPct(r.response_rate_pct)}</span> },
    { key: "nps", header: "Final NPS", render: (r) => <span className={`text-xs tabular-nums font-medium ${(r.final_nps_score ?? 0) >= 30 ? "text-[var(--color-ok)]" : "text-[var(--color-warn)]"}`}>{fmtScore(r.final_nps_score)}</span> },
    { key: "la", header: "Last action", render: (r) => <span className="text-xs text-[var(--color-muted)]">{fmtDate(r.last_action_at)}</span> },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">NPS auto-runner</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Quarterly NPS survey cron — kickoff → send → collect → close · final score auto-computed
        </span>
      </header>

      <section>
        <h2 className="mb-2 text-sm font-medium text-[var(--color-muted)]">Auto-runner KPIs (16)</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-4">
          {cards.map((c) => (
            <div key={c.label} className="rounded-lg border border-[var(--color-border)] bg-[var(--color-card)] p-3">
              <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">{c.label}</div>
              <div className={`mt-1 text-base font-semibold tabular-nums ${c.tone ?? ""}`}>{c.value}</div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-medium text-[var(--color-muted)]">Recent jobs (last 20)</h2>
        <DataTable columns={cols} rows={jobs} rowKey={(r) => r.id} emptyMessage="No NPS auto-runner jobs yet." />
      </section>
    </div>
  );
}
