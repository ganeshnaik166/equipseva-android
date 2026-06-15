import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRelativeTime, shortId } from "@/lib/format";
import { RevokeAssignmentButton } from "./RevokeAssignmentButton";
import { ThresholdEditor } from "./ThresholdEditor";

export const metadata = { title: "Supervised training — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type StatusRow = {
  status: string;
  assignment_count: number | null;
  total_in_progress: number | null;
};

type AssignmentRow = {
  id: string;
  trainee_user_id: string;
  supervisor_user_id: string;
  repair_job_id: string;
  trainee_tier_at_assignment: string;
  supervisor_tier_at_assignment: string;
  status: string;
  decline_reason: string | null;
  signoff_outcome: string | null;
  signoff_notes: string | null;
  requested_at: string;
  accepted_at: string | null;
  completed_at: string | null;
  signoff_at: string | null;
};

const STATUS_TONE: Record<string, string> = {
  pending_supervisor_accept: "bg-yellow-100 text-[var(--color-warn)]",
  active: "bg-blue-100",
  completed_successful: "bg-green-100 text-[var(--color-ok)]",
  completed_failed: "bg-red-100 text-[var(--color-danger)]",
  declined: "bg-gray-100",
  revoked: "bg-gray-100",
};

const STATUS_LABELS: Record<string, string> = {
  pending_supervisor_accept: "Awaiting accept",
  active: "Active",
  completed_successful: "Completed (success)",
  completed_failed: "Completed (failed)",
  declined: "Declined",
  revoked: "Revoked",
};

const TIER_TONE: Record<string, string> = {
  none: "bg-gray-100",
  bronze: "bg-orange-100 text-orange-800",
  silver: "bg-gray-200",
  gold: "bg-yellow-100 text-yellow-800",
};

export default async function TrainingPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [dashRes, listRes, tiersRes] = await Promise.all([
    supabase.rpc("founder_supervision_dashboard"),
    supabase.rpc("founder_list_supervision_assignments", { p_limit: 200 }),
    supabase
      .from("engineer_certification_tiers")
      .select("tier, min_supervised_completions, display_order")
      .order("display_order", { ascending: true }),
  ]);
  if (dashRes.error)
    throw new Error(`founder_supervision_dashboard: ${dashRes.error.message}`);

  const statuses = (dashRes.data ?? []) as StatusRow[];
  const list = (listRes.error ? [] : (listRes.data ?? [])) as AssignmentRow[];
  const totalInProgress = statuses[0]?.total_in_progress ?? 0;
  const tiers = (tiersRes.error ? [] : (tiersRes.data ?? [])) as Array<{
    tier: string;
    min_supervised_completions: number;
    display_order: number;
  }>;
  const thresholdRows = tiers.map((t) => ({
    tier: t.tier,
    min: t.min_supervised_completions ?? 0,
  }));

  const successCount =
    statuses.find((s) => s.status === "completed_successful")?.assignment_count ?? 0;
  const failedCount =
    statuses.find((s) => s.status === "completed_failed")?.assignment_count ?? 0;
  const pendingCount =
    statuses.find((s) => s.status === "pending_supervisor_accept")?.assignment_count ?? 0;
  const activeCount =
    statuses.find((s) => s.status === "active")?.assignment_count ?? 0;

  const cols: Column<AssignmentRow>[] = [
    {
      key: "when",
      header: "Requested",
      render: (r) => <span title={r.requested_at}>{formatRelativeTime(r.requested_at)}</span>,
    },
    {
      key: "trainee",
      header: "Trainee",
      render: (r) => (
        <div className="flex items-center gap-1">
          <Link
            href={`/engineers/${r.trainee_user_id}`}
            className="text-[var(--color-accent)] hover:underline"
          >
            {shortId(r.trainee_user_id)}
          </Link>
          <span
            className={`rounded px-1.5 py-0.5 text-[10px] ${TIER_TONE[r.trainee_tier_at_assignment] ?? "bg-gray-100"}`}
          >
            {r.trainee_tier_at_assignment}
          </span>
        </div>
      ),
    },
    {
      key: "supervisor",
      header: "Supervisor",
      render: (r) => (
        <div className="flex items-center gap-1">
          <Link
            href={`/engineers/${r.supervisor_user_id}`}
            className="text-[var(--color-accent)] hover:underline"
          >
            {shortId(r.supervisor_user_id)}
          </Link>
          <span
            className={`rounded px-1.5 py-0.5 text-[10px] ${TIER_TONE[r.supervisor_tier_at_assignment] ?? "bg-gray-100"}`}
          >
            {r.supervisor_tier_at_assignment}
          </span>
        </div>
      ),
    },
    {
      key: "job",
      header: "Job",
      render: (r) => (
        <Link
          href={`/jobs/${r.repair_job_id}`}
          className="font-mono text-xs text-[var(--color-accent)] hover:underline"
        >
          {shortId(r.repair_job_id)}
        </Link>
      ),
    },
    {
      key: "status",
      header: "Status",
      render: (r) => (
        <span
          className={`rounded px-1.5 py-0.5 text-xs ${STATUS_TONE[r.status] ?? "bg-gray-100"}`}
          title={r.decline_reason ?? r.signoff_notes ?? ""}
        >
          {STATUS_LABELS[r.status] ?? r.status}
        </span>
      ),
    },
    {
      key: "outcome",
      header: "Outcome",
      render: (r) =>
        r.signoff_outcome ? (
          <span className="text-xs">{r.signoff_outcome}</span>
        ) : (
          <span className="text-xs text-[var(--color-muted)]">—</span>
        ),
    },
    {
      key: "completed",
      header: "Closed",
      render: (r) =>
        r.completed_at ? (
          <span title={r.completed_at}>{formatRelativeTime(r.completed_at)}</span>
        ) : (
          <span className="text-xs text-[var(--color-muted)]">—</span>
        ),
    },
    {
      key: "act",
      header: "Action",
      render: (r) =>
        !["completed_successful", "completed_failed", "declined", "revoked"].includes(
          r.status,
        ) ? (
          <RevokeAssignmentButton assignmentId={r.id} />
        ) : (
          <span className="text-xs text-[var(--color-muted)]">—</span>
        ),
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Supervised training</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {totalInProgress.toLocaleString("en-IN")} in progress (pending + active)
        </span>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard
            label="Awaiting accept"
            value={formatNumber(pendingCount)}
            tone={pendingCount > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="Active"
            value={formatNumber(activeCount)}
            tone={activeCount > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="Completed (success)"
            value={formatNumber(successCount)}
            tone="ok"
          />
          <StatCard
            label="Completed (failed)"
            value={formatNumber(failedCount)}
            tone={failedCount > 0 ? "warn" : "ok"}
          />
        </div>
      </section>

      {thresholdRows.length > 0 && <ThresholdEditor rows={thresholdRows} />}

      <DataTable
        columns={cols}
        rows={list}
        rowKey={(r) => r.id}
        emptyMessage="No supervised assignments yet — trainees call request_supervision(p_job_id, p_supervisor_user_id) to open one."
      />

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>r576 supervised training program (v0.5 P2 #2).</strong>{" "}
        Lower-tier engineers (trainees) request supervision from a strictly
        higher-tier engineer (supervisor) on a real repair job they have
        been awarded. State flow: pending_supervisor_accept → active →
        completed_successful | completed_failed (terminal); founder can
        revoke any non-terminal row. Signoff requires the hospital to
        have already signed the DSR (r494 enum value{" "}
        <code>signed</code>) — supervisors cannot rubber-stamp before the
        hospital accepts. Audit-22 caught the original architect&apos;s
        DSR enum mismatch (would have permanently blocked all signoffs)
        and a missing audit-log column wrapper bug before this round
        landed. Future round (r577+) will wire successful supervised
        completions into the r550 compute fn as a stronger promotion
        signal than plain unsupervised count.
      </section>
    </div>
  );
}
