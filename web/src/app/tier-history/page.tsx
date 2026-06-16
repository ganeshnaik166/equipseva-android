import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRelativeTime, shortId } from "@/lib/format";

export const metadata = { title: "Tier history — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  id: string;
  engineer_user_id: string;
  prev_tier: string;
  new_tier: string;
  change_kind: string;
  reason: string | null;
  jobs_completed_at_change: number | null;
  dispute_rate_pct_at_change: number | null;
  supervised_completions_at_change: number | null;
  verified_tier_at_change: string | null;
  changed_at: string;
};

const TIER_TONE: Record<string, string> = {
  gold: "bg-yellow-100 text-yellow-800",
  silver: "bg-gray-200",
  bronze: "bg-orange-100 text-orange-800",
  none: "bg-gray-50 text-[var(--color-muted)]",
};

const KIND_TONE: Record<string, string> = {
  cron_compute: "bg-blue-50 text-blue-700",
  founder_override: "bg-purple-50 text-purple-700",
  founder_promote: "bg-green-50 text-[var(--color-ok)]",
  founder_demote: "bg-red-50 text-[var(--color-danger)]",
};

const KIND_LABEL: Record<string, string> = {
  cron_compute: "auto",
  founder_override: "override",
  founder_promote: "promote",
  founder_demote: "demote",
};

function tierRank(t: string): number {
  switch (t) {
    case "none":
      return 0;
    case "bronze":
      return 1;
    case "silver":
      return 2;
    case "gold":
      return 3;
    default:
      return 0;
  }
}

export default async function TierHistoryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const { data, error } = await supabase.rpc("founder_tier_history_recent", {
    p_limit: 200,
  });
  if (error) throw new Error(`founder_tier_history_recent: ${error.message}`);

  const rows = (data ?? []) as Row[];

  const promotions = rows.filter((r) => tierRank(r.new_tier) > tierRank(r.prev_tier));
  const demotions = rows.filter((r) => tierRank(r.new_tier) < tierRank(r.prev_tier));
  const founderActions = rows.filter((r) => r.change_kind !== "cron_compute");

  const cols: Column<Row>[] = [
    {
      key: "when",
      header: "Changed",
      render: (r) => <span title={r.changed_at}>{formatRelativeTime(r.changed_at)}</span>,
    },
    {
      key: "engineer",
      header: "Engineer",
      render: (r) => (
        <Link
          href={`/engineers/${r.engineer_user_id}`}
          className="text-[var(--color-accent)] hover:underline"
        >
          {shortId(r.engineer_user_id)}
        </Link>
      ),
    },
    {
      key: "move",
      header: "Move",
      render: (r) => (
        <div className="flex items-center gap-1.5">
          <span
            className={`rounded px-1.5 py-0.5 text-[10px] uppercase ${TIER_TONE[r.prev_tier] ?? "bg-gray-100"}`}
          >
            {r.prev_tier}
          </span>
          <span className="text-[var(--color-muted)]">→</span>
          <span
            className={`rounded px-1.5 py-0.5 text-[10px] uppercase ${TIER_TONE[r.new_tier] ?? "bg-gray-100"}`}
          >
            {r.new_tier}
          </span>
        </div>
      ),
    },
    {
      key: "direction",
      header: "Direction",
      render: (r) => {
        const dr = tierRank(r.new_tier) - tierRank(r.prev_tier);
        const tone =
          dr > 0
            ? "text-[var(--color-ok)]"
            : dr < 0
              ? "text-[var(--color-danger)]"
              : "text-[var(--color-muted)]";
        return <span className={`text-xs ${tone}`}>{dr > 0 ? "↑" : dr < 0 ? "↓" : "–"}</span>;
      },
    },
    {
      key: "kind",
      header: "Kind",
      render: (r) => (
        <span
          className={`rounded px-1.5 py-0.5 text-xs ${KIND_TONE[r.change_kind] ?? "bg-gray-100"}`}
          title={r.reason ?? ""}
        >
          {KIND_LABEL[r.change_kind] ?? r.change_kind}
        </span>
      ),
    },
    {
      key: "jobs",
      header: "Jobs",
      render: (r) => formatNumber(r.jobs_completed_at_change),
    },
    {
      key: "disp",
      header: "Dispute%",
      render: (r) => (
        <span className="text-xs tabular-nums">
          {r.dispute_rate_pct_at_change != null
            ? `${r.dispute_rate_pct_at_change}%`
            : "—"}
        </span>
      ),
    },
    {
      key: "sup",
      header: "Supervised",
      render: (r) =>
        (r.supervised_completions_at_change ?? 0) > 0 ? (
          <span className="rounded bg-blue-50 px-1.5 py-0.5 text-xs tabular-nums">
            {r.supervised_completions_at_change}
          </span>
        ) : (
          <span className="text-xs text-[var(--color-muted)]">—</span>
        ),
    },
    {
      key: "verified",
      header: "Verified ceiling",
      render: (r) => <code className="text-xs">{r.verified_tier_at_change ?? "—"}</code>,
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer tier history</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Last {rows.length} tier changes · Source: r593 ledger
        </span>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard
            label="Total moves (in view)"
            value={formatNumber(rows.length)}
          />
          <StatCard
            label="Promotions"
            value={formatNumber(promotions.length)}
            tone="ok"
          />
          <StatCard
            label="Demotions"
            value={formatNumber(demotions.length)}
            tone={demotions.length > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="Founder actions"
            value={formatNumber(founderActions.length)}
            tone={founderActions.length > 0 ? "warn" : "ok"}
          />
        </div>
      </section>

      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.id}
        emptyMessage="No tier changes yet — the 03:17 daily cron writes a row here every time an engineer crosses a tier gate."
      />

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>r593 tier history ledger.</strong> Append-only — no UPDATE or
        DELETE RPCs exposed. <code>compute_engineer_certification_tier</code>
        writes each row inside the same transaction as the progress upsert, so
        a rolled-back compute also rolls back its history row. founder_promote
        / founder_demote / founder_override are reserved kinds for future
        manual-override migrations (not currently wired). The dispute% +
        supervised + verified columns are point-in-time snapshots of the
        signals that drove the decision.
      </section>
    </div>
  );
}
