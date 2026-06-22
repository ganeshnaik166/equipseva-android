import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRelativeTime, shortId } from "@/lib/format";

export const metadata = { title: "250-Batch Milestone Retro — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type RetroRow = {
  id: string;
  batch_number: number;
  ships_at_milestone: number;
  heavy_ships_at_milestone: number;
  hit_at: string;
  ships_delta: number | null;
  velocity_ships_per_day: number | null;
  audit_bugs_caught: number;
  prod_incidents: number;
  retro_summary: string | null;
  top_win: string | null;
  next_250_north_star: string | null;
  pattern_count: number;
  shipped_pattern_count: number;
};

type PatternRow = {
  id: string;
  rank: number;
  pattern_title: string;
  pattern_category: string;
  observation: string | null;
  evidence_round_refs: string | null;
  impact_level: string;
  proposed_next_250_change: string | null;
  status: string;
  shipped_round: number | null;
  noted_by_email: string | null;
  created_at: string;
};

export default async function Founder250BatchMilestoneRetroPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const { data: retrosRaw } = await supabase.rpc("r2305_list_retros", { p_limit: 50 });
  const retros: RetroRow[] = (retrosRaw as RetroRow[] | null) ?? [];

  const latest = retros[0];
  let patterns: PatternRow[] = [];
  if (latest) {
    const { data: patternsRaw } = await supabase.rpc("r2305_list_patterns", {
      p_retro_id: latest.id,
    });
    patterns = (patternsRaw as PatternRow[] | null) ?? [];
  }

  const totalRetros = retros.length;
  const totalBugsCaught = retros.reduce((acc, r) => acc + (r.audit_bugs_caught ?? 0), 0);
  const totalIncidents = retros.reduce((acc, r) => acc + (r.prod_incidents ?? 0), 0);
  const totalShipped = patterns.filter((p) => p.status === "shipped").length;

  const retroCols: Column<RetroRow>[] = [
    {
      key: "batch",
      header: "Batch #",
      render: (r) => <span className="font-mono">{r.batch_number}</span>,
    },
    {
      key: "ships",
      header: "Ships",
      render: (r) => (
        <span className="font-mono">
          {formatNumber(r.ships_at_milestone)}
          {r.ships_delta != null ? (
            <span className="text-xs text-[var(--color-muted)] ml-1">
              (+{formatNumber(r.ships_delta)})
            </span>
          ) : null}
        </span>
      ),
    },
    {
      key: "heavy",
      header: "Heavy",
      render: (r) => <span className="font-mono">{formatNumber(r.heavy_ships_at_milestone)}</span>,
    },
    {
      key: "velocity",
      header: "Ships/day",
      render: (r) =>
        r.velocity_ships_per_day != null
          ? <span className="font-mono">{Number(r.velocity_ships_per_day).toFixed(1)}</span>
          : "—",
    },
    {
      key: "bugs",
      header: "Audit bugs",
      render: (r) => (
        <span className="font-mono text-[var(--color-warning)]">
          {formatNumber(r.audit_bugs_caught)}
        </span>
      ),
    },
    {
      key: "incidents",
      header: "Prod incidents",
      render: (r) => (
        <span className={`font-mono ${r.prod_incidents > 0 ? "text-[var(--color-danger)]" : ""}`}>
          {formatNumber(r.prod_incidents)}
        </span>
      ),
    },
    {
      key: "patterns",
      header: "Patterns",
      render: (r) => (
        <span className="font-mono">
          {formatNumber(r.shipped_pattern_count)} / {formatNumber(r.pattern_count)}
        </span>
      ),
    },
    {
      key: "north_star",
      header: "Next-250 north star",
      render: (r) => (
        <span className="text-sm">{r.next_250_north_star ?? "—"}</span>
      ),
    },
    {
      key: "hit",
      header: "Hit",
      render: (r) => (
        <span className="text-xs text-[var(--color-muted)]">
          {formatRelativeTime(r.hit_at)}
        </span>
      ),
    },
  ];

  const patternCols: Column<PatternRow>[] = [
    {
      key: "rank",
      header: "#",
      render: (p) => <span className="font-mono">{p.rank}</span>,
    },
    {
      key: "title",
      header: "Pattern",
      render: (p) => (
        <div>
          <div className="font-medium">{p.pattern_title}</div>
          {p.observation ? (
            <div className="text-xs text-[var(--color-muted)] mt-1 max-w-md">
              {p.observation}
            </div>
          ) : null}
        </div>
      ),
    },
    {
      key: "category",
      header: "Category",
      render: (p) => (
        <span className="text-xs px-2 py-0.5 rounded bg-[var(--color-surface-2)]">
          {p.pattern_category}
        </span>
      ),
    },
    {
      key: "impact",
      header: "Impact",
      render: (p) => {
        const cls =
          p.impact_level === "critical"
            ? "text-[var(--color-danger)]"
            : p.impact_level === "high"
              ? "text-[var(--color-warning)]"
              : "text-[var(--color-muted)]";
        return <span className={`text-xs uppercase ${cls}`}>{p.impact_level}</span>;
      },
    },
    {
      key: "evidence",
      header: "Evidence",
      render: (p) => (
        <span className="font-mono text-xs">{p.evidence_round_refs ?? "—"}</span>
      ),
    },
    {
      key: "change",
      header: "Proposed next-250 change",
      render: (p) => (
        <span className="text-sm">{p.proposed_next_250_change ?? "—"}</span>
      ),
    },
    {
      key: "status",
      header: "Status",
      render: (p) => {
        const tone =
          p.status === "shipped"
            ? "text-[var(--color-success)]"
            : p.status === "accepted"
              ? "text-[var(--color-accent)]"
              : p.status === "rejected"
                ? "text-[var(--color-muted)]"
                : "";
        return (
          <span className={`text-xs uppercase ${tone}`}>
            {p.status}
            {p.shipped_round != null ? (
              <span className="ml-1 font-mono text-[var(--color-muted)]">
                r{p.shipped_round}
              </span>
            ) : null}
          </span>
        );
      },
    },
    {
      key: "noted",
      header: "Noted by",
      render: (p) => (
        <span className="text-xs text-[var(--color-muted)]">
          {p.noted_by_email ?? shortId(p.id)}
        </span>
      ),
    },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-2">
        <div className="flex items-center gap-2 text-sm text-[var(--color-muted)]">
          <Link href="/ops" className="hover:underline">Ops</Link>
          <span>&gt;</span>
          <span>250-Batch Milestone Retro</span>
        </div>
        <h1 className="text-2xl font-semibold">250-Batch Milestone Retro</h1>
        <p className="text-sm text-[var(--color-muted)] max-w-3xl">
          What we learned at each 250-batch mark — ships, velocity, audit bugs
          caught pre-deploy, prod incidents, plus the top 10 system-level patterns and
          the proposed next-250 design changes. Every pattern carries an evidence
          trail (round refs) and a status that moves proposed =&gt; accepted =&gt;
          shipped.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded-lg border border-[var(--color-border)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Milestones logged</div>
          <div className="text-2xl font-semibold mt-1">{formatNumber(totalRetros)}</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Audit bugs caught</div>
          <div className="text-2xl font-semibold mt-1 text-[var(--color-warning)]">
            {formatNumber(totalBugsCaught)}
          </div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Prod incidents</div>
          <div
            className={`text-2xl font-semibold mt-1 ${
              totalIncidents > 0 ? "text-[var(--color-danger)]" : ""
            }`}
          >
            {formatNumber(totalIncidents)}
          </div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Patterns shipped (latest)</div>
          <div className="text-2xl font-semibold mt-1 text-[var(--color-success)]">
            {formatNumber(totalShipped)}
          </div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Milestone log</h2>
        <p className="text-xs text-[var(--color-muted)]">
          One row per 250-batch mark. Velocity is ships/day across the window. Audit
          bugs &gt;= 0 = bugs caught pre-deploy; prod incidents should stay at 0.
        </p>
        <DataTable
          columns={retroCols}
          rows={retros}
          rowKey={(r: RetroRow) => r.id}
          emptyMessage="No milestone retros logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">
          {latest
            ? `Top patterns from batch ${latest.batch_number}`
            : "Top patterns"}
        </h2>
        {latest?.retro_summary ? (
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-2)] p-4 text-sm">
            <div className="font-medium mb-1">Retro summary</div>
            <p className="text-[var(--color-muted)]">{latest.retro_summary}</p>
            {latest.top_win ? (
              <p className="mt-2">
                <span className="text-xs uppercase text-[var(--color-success)] mr-2">
                  Top win
                </span>
                {latest.top_win}
              </p>
            ) : null}
          </div>
        ) : null}
        <DataTable
          columns={patternCols}
          rows={patterns}
          rowKey={(p: PatternRow) => p.id}
          emptyMessage="No patterns logged for the latest milestone yet."
        />
      </section>

      <section className="text-xs text-[var(--color-muted)] space-y-1">
        <p>
          Workflow: call <code>r2305_log_milestone_retro</code> at each 250-batch
          mark, then <code>r2305_add_pattern</code> for ranks 1..10 (or up to 50).
          Move ideas via <code>r2305_accept_pattern</code> /
          <code>r2305_reject_pattern</code>, and close the loop with
          <code>r2305_mark_pattern_shipped(round)</code> once the change lands.
        </p>
        <p>
          Categories: schema_typo, rls_gap, workflow_hygiene, agent_drift,
          normalizer, founder_gate, perf, data_model, ux, process.
        </p>
      </section>
    </div>
  );
}
