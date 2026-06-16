import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Cron status — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  job_name: string;
  schedule: string;
  active: boolean;
  last_start_time: string | null;
  last_status: string | null;
  last_runtime_ms: number | null;
  total_runs_24h: number | null;
  failed_runs_24h: number | null;
};

function statusTone(status: string | null, failed24h: number) {
  if (failed24h > 0) return "danger" as const;
  if (status === "succeeded") return "ok" as const;
  if (status === "running") return "warn" as const;
  return "neutral" as const;
}

export default async function CronStatusPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const { data, error } = await supabase.rpc("founder_cron_status");
  if (error) throw new Error(`founder_cron_status: ${error.message}`);

  const rows = (data ?? []) as Row[];
  const pgCronEnabled = rows.length > 0;

  const totalJobs = rows.length;
  const failingJobs = rows.filter((r) => (r.failed_runs_24h ?? 0) > 0).length;
  const inactiveJobs = rows.filter((r) => !r.active).length;
  const totalRuns24h = rows.reduce((s, r) => s + (r.total_runs_24h ?? 0), 0);

  const cols: Column<Row>[] = [
    {
      key: "job",
      header: "Job",
      render: (r) => (
        <code className="text-xs">
          {r.job_name}
        </code>
      ),
    },
    {
      key: "sched",
      header: "Schedule",
      render: (r) => <span className="text-xs tabular-nums">{r.schedule}</span>,
    },
    {
      key: "active",
      header: "Active",
      render: (r) =>
        r.active ? (
          <span className="rounded bg-green-50 px-1.5 py-0.5 text-xs text-[var(--color-ok)]">
            yes
          </span>
        ) : (
          <span className="rounded bg-gray-100 px-1.5 py-0.5 text-xs">paused</span>
        ),
    },
    {
      key: "last",
      header: "Last run",
      render: (r) =>
        r.last_start_time ? (
          <span title={r.last_start_time}>{formatRelativeTime(r.last_start_time)}</span>
        ) : (
          <span className="text-xs text-[var(--color-muted)]">never</span>
        ),
    },
    {
      key: "status",
      header: "Status",
      render: (r) => {
        const tone =
          r.last_status === "succeeded"
            ? "bg-green-50 text-[var(--color-ok)]"
            : r.last_status === "failed"
              ? "bg-red-50 text-[var(--color-danger)]"
              : r.last_status === "running"
                ? "bg-yellow-50 text-[var(--color-warn)]"
                : "bg-gray-100";
        return (
          <span className={`rounded px-1.5 py-0.5 text-xs ${tone}`}>
            {r.last_status ?? "—"}
          </span>
        );
      },
    },
    {
      key: "runtime",
      header: "Runtime",
      render: (r) =>
        r.last_runtime_ms != null ? (
          <span className="text-xs tabular-nums">{Math.round(r.last_runtime_ms)} ms</span>
        ) : (
          <span className="text-xs text-[var(--color-muted)]">—</span>
        ),
    },
    {
      key: "24h",
      header: "24h runs",
      render: (r) => (
        <span className="text-xs tabular-nums">{formatNumber(r.total_runs_24h)}</span>
      ),
    },
    {
      key: "fail24h",
      header: "24h failed",
      render: (r) =>
        (r.failed_runs_24h ?? 0) > 0 ? (
          <span className="rounded bg-red-100 px-1.5 py-0.5 text-xs text-[var(--color-danger)]">
            {r.failed_runs_24h}
          </span>
        ) : (
          <span className="text-xs text-[var(--color-muted)]">0</span>
        ),
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Cron status</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {pgCronEnabled ? `${totalJobs} registered jobs` : "pg_cron not enabled"}
        </span>
      </header>

      {pgCronEnabled ? (
        <>
          <section>
            <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
              <StatCard label="Total jobs" value={formatNumber(totalJobs)} />
              <StatCard
                label="Jobs failing (24h)"
                value={formatNumber(failingJobs)}
                tone={failingJobs > 0 ? "danger" : "ok"}
              />
              <StatCard
                label="Paused jobs"
                value={formatNumber(inactiveJobs)}
                tone={inactiveJobs > 0 ? "warn" : "ok"}
              />
              <StatCard label="Runs (24h)" value={formatNumber(totalRuns24h)} />
            </div>
          </section>

          <DataTable
            columns={cols}
            rows={rows}
            rowKey={(r) => r.job_name}
            emptyMessage="No cron jobs registered — schedule via cron.schedule(name, schedule, sql)."
          />
        </>
      ) : (
        <section className="rounded border border-[var(--color-border)] bg-yellow-50 p-4">
          <h2 className="text-sm font-semibold text-[var(--color-warn)]">
            pg_cron not enabled on this database
          </h2>
          <p className="mt-2 text-sm text-[var(--color-muted)]">
            Scheduled jobs are running via edge functions or external triggers
            instead. Known periodic surfaces:
          </p>
          <ul className="mt-2 list-disc pl-6 text-sm text-[var(--color-muted)]">
            <li>
              <code>compute_engineer_certification_tier</code> — daily ladder
              recompute (per-engineer); needed for r578 + r593
            </li>
            <li>
              <code>investor_share_view_log_retention_sweep</code> — 04:37 UTC
              daily (r563)
            </li>
            <li>
              <code>auto_renew_expiring_amc_contracts</code> — AMC renewal queue
            </li>
            <li>
              <code>amc_pending_payment_reaper</code> — stranded pending-payment
              AMCs &gt; 24h
            </li>
            <li>
              <code>reap_stranded_requested_repair_jobs</code> — r479 audit-8 HIGH
            </li>
            <li>
              <code>engineer_referral_bounty_evaluator</code> — 04:47 UTC daily
              (r564 + r568)
            </li>
          </ul>
        </section>
      )}

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>r599 ops view.</strong> Reads pg_cron&apos;s{" "}
        <code>cron.job</code> + <code>cron.job_run_details</code> tables via a
        founder-only SECDEF wrapper. Rows sorted by 24h-failure count DESC so
        broken jobs surface first. Runtime is wall-clock end-time − start-time;
        running rows have NULL runtime until completion. If pg_cron isn&apos;t
        enabled, this page degrades to a docs view of the known periodic
        surfaces — Supabase tier varies; the platform team can flip pg_cron on
        from the dashboard if visibility here matters.
      </section>
    </div>
  );
}
