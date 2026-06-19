import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder cron status — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_jobs: number; active_jobs: number; inactive_jobs: number;
  recent_runs_24h: number; recent_failures_24h: number; recent_successes_24h: number;
  failure_rate_24h_pct: number; oldest_job_no_recent_run: number;
  longest_running_job_seconds: number; jobs_with_recent_failure_count: number;
};

type Job = {
  jobid: number; jobname: string; schedule: string; active: boolean;
  last_run_at: string | null; last_status: string | null;
  last_duration_seconds: number | null; recent_failure_count: number;
};

export default async function FounderCronStatusPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [sRes, jRes] = await Promise.all([
    supabase.rpc("founder_cron_status_summary"),
    supabase.rpc("founder_cron_jobs_recent", { p_limit: 100 }),
  ]);
  if (sRes.error) throw new Error(`founder_cron_status_summary: ${sRes.error.message}`);
  if (jRes.error) throw new Error(`founder_cron_jobs_recent: ${jRes.error.message}`);
  const s = (sRes.data?.[0] ?? null) as Summary | null;
  const jobs = (jRes.data ?? []) as Job[];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder cron status ★ r1312</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">pg_cron jobs · last-run state · 24h failure rate · drives DPDP routing, spot-audit invites, incident auto-creation, AMC reapers</p>
      </header>

      {s ? (
        <section className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <Card title="Active jobs" val={formatNumber(s.active_jobs)} sub={`${formatNumber(s.inactive_jobs)} inactive`} />
          <Card title="Runs 24h" val={formatNumber(s.recent_runs_24h)} />
          <Card title="Failures 24h" val={formatNumber(s.recent_failures_24h)} danger={s.recent_failures_24h > 0} />
          <Card title="Failure rate 24h" val={`${Number(s.failure_rate_24h_pct).toFixed(1)}%`} danger={s.failure_rate_24h_pct > 5} ok={s.failure_rate_24h_pct === 0} />
          <Card title="Jobs w/ recent failure" val={formatNumber(s.jobs_with_recent_failure_count)} danger={s.jobs_with_recent_failure_count > 0} />
          <Card title="Active jobs no recent run" val={formatNumber(s.oldest_job_no_recent_run)} danger={s.oldest_job_no_recent_run > 0} />
          <Card title="Longest run 24h (sec)" val={Number(s.longest_running_job_seconds).toFixed(1)} />
          <Card title="Successes 24h" val={formatNumber(s.recent_successes_24h)} ok />
        </section>
      ) : null}

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Cron jobs ({jobs.length})</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs text-[var(--color-muted)] uppercase tracking-wider">
                <th className="py-2 pr-3 tabular-nums">ID</th>
                <th className="py-2 pr-3">Name</th>
                <th className="py-2 pr-3 font-mono">Schedule</th>
                <th className="py-2 pr-3">Active</th>
                <th className="py-2 pr-3">Last run</th>
                <th className="py-2 pr-3">Last status</th>
                <th className="py-2 pr-3 tabular-nums">Duration (s)</th>
                <th className="py-2 tabular-nums">Recent failures</th>
              </tr>
            </thead>
            <tbody>
              {jobs.map((j) => (
                <tr key={j.jobid} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-3 tabular-nums text-[var(--color-muted)]">{j.jobid}</td>
                  <td className="py-2 pr-3 text-xs font-mono">{j.jobname}</td>
                  <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)]">{j.schedule}</td>
                  <td className="py-2 pr-3 text-xs">{j.active ? <span className="text-[var(--color-ok)]">✓</span> : <span className="text-[var(--color-muted)]">—</span>}</td>
                  <td className="py-2 pr-3 text-xs">{j.last_run_at ? new Date(j.last_run_at).toLocaleString("en-IN", { timeZone: "Asia/Kolkata" }) : <span className="text-[var(--color-muted)]">never</span>}</td>
                  <td className={`py-2 pr-3 text-xs ${j.last_status === "succeeded" ? "text-[var(--color-ok)]" : j.last_status ? "text-[var(--color-danger)]" : "text-[var(--color-muted)]"}`}>{j.last_status ?? "—"}</td>
                  <td className="py-2 pr-3 tabular-nums text-xs">{j.last_duration_seconds ? Number(j.last_duration_seconds).toFixed(2) : "—"}</td>
                  <td className={`py-2 tabular-nums text-xs ${j.recent_failure_count > 0 ? "text-[var(--color-danger)] font-semibold" : ""}`}>{formatNumber(j.recent_failure_count)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}

function Card({ title, val, sub, danger, ok }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${danger ? "text-[var(--color-danger)]" : ok ? "text-[var(--color-ok)]" : ""}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}
