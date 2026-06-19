import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder product feedback inbox — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_items: number;
  open_count: number;
  triaged_count: number;
  planned_count: number;
  in_progress_count: number;
  shipped_count: number;
  wont_do_count: number;
  top_kind: string | null;
  top_kind_count: number;
  avg_vote_count: number;
  most_voted_id: string | null;
  most_voted_title: string | null;
  most_voted_votes: number;
  items_last_30d: number;
  sentiment_positive_pct: number;
  oldest_open_age_days: number;
};

type RecentRow = {
  id: string;
  title: string;
  kind: string;
  submitted_by_kind: string | null;
  description: string | null;
  sentiment: string | null;
  priority: string;
  vote_count: number;
  status: string;
  shipped_round: string | null;
  related_surface: string | null;
  created_at: string;
  age_days: number;
};

type MostVotedRow = {
  id: string;
  title: string;
  kind: string;
  status: string;
  priority: string;
  sentiment: string | null;
  vote_count: number;
  submitted_by_kind: string | null;
  related_surface: string | null;
  created_at: string;
};

const KIND_LABEL: Record<string, string> = {
  feature_request: "Feature",
  bug_report: "Bug",
  ux_friction: "UX friction",
  pricing_concern: "Pricing",
  integration_request: "Integration",
  compliment: "Compliment",
  other: "Other",
};

const STATUS_TONE: Record<string, string> = {
  open: "text-[var(--color-info)] border-[var(--color-info)]",
  triaged: "text-[var(--color-warn)] border-[var(--color-warn)]",
  planned: "text-[var(--color-accent)] border-[var(--color-accent)]",
  in_progress: "text-[var(--color-warn)] border-[var(--color-warn)]",
  shipped: "text-[var(--color-ok)] border-[var(--color-ok)]",
  wont_do: "text-[var(--color-muted)] border-[var(--color-border)]",
  duplicate: "text-[var(--color-muted)] border-[var(--color-border)]",
};

const SENTIMENT_TONE: Record<string, string> = {
  very_positive: "text-[var(--color-ok)]",
  positive: "text-[var(--color-ok)]",
  neutral: "text-[var(--color-muted)]",
  negative: "text-[var(--color-warn)]",
  very_negative: "text-[var(--color-danger)]",
};

const PRIORITY_TONE: Record<string, string> = {
  p0: "text-[var(--color-danger)] border-[var(--color-danger)]",
  p1: "text-[var(--color-warn)] border-[var(--color-warn)]",
  p2: "text-[var(--color-info)] border-[var(--color-info)]",
  p3: "text-[var(--color-muted)] border-[var(--color-border)]",
};

const SUBMITTER_LABEL: Record<string, string> = {
  engineer: "Engineer",
  hospital_admin: "Hospital",
  founder_team: "Founder",
  investor: "Investor",
  prospect: "Prospect",
  external_user: "External",
};

export default async function FounderProductFeedbackInboxPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [sumRes, recRes, votedRes] = await Promise.all([
    supabase.rpc("founder_product_feedback_summary"),
    supabase.rpc("founder_product_feedback_recent", { p_limit: 100 }),
    supabase.rpc("founder_product_feedback_most_voted", { p_limit: 30 }),
  ]);
  if (sumRes.error) throw new Error(`founder_product_feedback_summary: ${sumRes.error.message}`);
  if (recRes.error) throw new Error(`founder_product_feedback_recent: ${recRes.error.message}`);
  if (votedRes.error) throw new Error(`founder_product_feedback_most_voted: ${votedRes.error.message}`);

  const s = (sumRes.data?.[0] ?? null) as Summary | null;
  const recent = (recRes.data ?? []) as RecentRow[];
  const voted = (votedRes.data ?? []) as MostVotedRow[];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder product feedback inbox · r1355</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Feature requests · bug reports · UX friction · pricing signal · vote-weighted demand · sentiment band · status ladder open → triaged → planned → in_progress → shipped/wont_do/duplicate · evidence we listen, not just ship
        </p>
      </header>

      {s ? (
        <section className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-8">
          <div className="rounded-lg border-2 border-[var(--color-accent)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Total items</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-accent)]">{formatNumber(s.total_items)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Open</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-info)]">{formatNumber(s.open_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Triaged</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-warn)]">{formatNumber(s.triaged_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Planned</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-accent)]">{formatNumber(s.planned_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">In progress</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-warn)]">{formatNumber(s.in_progress_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Shipped</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{formatNumber(s.shipped_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Won't do</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-muted)]">{formatNumber(s.wont_do_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Top kind</div>
            <div className="mt-1 text-sm font-semibold">{s.top_kind ? KIND_LABEL[s.top_kind] ?? s.top_kind : "—"}</div>
            <div className="text-xs text-[var(--color-muted)] tabular-nums">{formatNumber(s.top_kind_count)} items</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Avg votes/item</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{Number(s.avg_vote_count ?? 0).toFixed(2)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 col-span-2">
            <div className="text-xs text-[var(--color-muted)]">Most voted (open)</div>
            <div className="mt-1 text-sm font-semibold truncate" title={s.most_voted_title ?? undefined}>{s.most_voted_title ?? "—"}</div>
            <div className="text-xs text-[var(--color-muted)] tabular-nums">{formatNumber(s.most_voted_votes ?? 0)} votes</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Last 30d</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.items_last_30d)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Sentiment + %</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${s.sentiment_positive_pct >= 60 ? "text-[var(--color-ok)]" : s.sentiment_positive_pct >= 40 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]"}`}>{Number(s.sentiment_positive_pct ?? 0).toFixed(1)}%</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Oldest open age</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${s.oldest_open_age_days > 30 ? "text-[var(--color-danger)]" : s.oldest_open_age_days > 14 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]"}`}>{formatNumber(s.oldest_open_age_days)}d</div>
          </div>
        </section>
      ) : null}

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-accent)]">Most-voted top 30 (open + triaged + planned + in_progress)</h2>
        {voted.length === 0 ? (
          <p className="text-sm text-[var(--color-muted)]">No active items yet. Submit via <code className="font-mono">log_founder_product_feedback_submit()</code>.</p>
        ) : (
          <div className="overflow-x-auto rounded-lg border border-[var(--color-accent)] bg-[color-mix(in_srgb,var(--color-accent)_4%,transparent)]">
            <table className="w-full text-xs">
              <thead className="text-left text-[var(--color-muted)] border-b border-[var(--color-border)]">
                <tr>
                  <th className="py-2 px-3 text-right">Votes</th>
                  <th className="py-2 pr-3">Title</th>
                  <th className="py-2 pr-3">Kind</th>
                  <th className="py-2 pr-3">Status</th>
                  <th className="py-2 pr-3">Priority</th>
                  <th className="py-2 pr-3">Sentiment</th>
                  <th className="py-2 pr-3">Submitter</th>
                  <th className="py-2 pr-3">Surface</th>
                  <th className="py-2 pr-3 text-right">Created</th>
                </tr>
              </thead>
              <tbody>
                {voted.map((v, i) => (
                  <tr key={v.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 px-3 text-right tabular-nums font-bold text-[var(--color-accent)]">{i + 1}. {formatNumber(v.vote_count)}</td>
                    <td className="py-2 pr-3 max-w-[320px] truncate" title={v.title}>{v.title}</td>
                    <td className="py-2 pr-3">{KIND_LABEL[v.kind] ?? v.kind}</td>
                    <td className="py-2 pr-3">
                      <span className={`px-1.5 py-0.5 rounded border text-[10px] uppercase ${STATUS_TONE[v.status] ?? ""}`}>{v.status}</span>
                    </td>
                    <td className="py-2 pr-3">
                      <span className={`px-1.5 py-0.5 rounded border text-[10px] uppercase ${PRIORITY_TONE[v.priority] ?? ""}`}>{v.priority}</span>
                    </td>
                    <td className={`py-2 pr-3 text-[10px] uppercase tracking-wider ${v.sentiment ? SENTIMENT_TONE[v.sentiment] ?? "" : "text-[var(--color-muted)]"}`}>{v.sentiment ?? "—"}</td>
                    <td className="py-2 pr-3 text-[var(--color-muted)]">{v.submitted_by_kind ? SUBMITTER_LABEL[v.submitted_by_kind] ?? v.submitted_by_kind : "—"}</td>
                    <td className="py-2 pr-3 text-[var(--color-muted)] max-w-[160px] truncate" title={v.related_surface ?? undefined}>{v.related_surface ?? "—"}</td>
                    <td className="py-2 pr-3 text-right tabular-nums text-[var(--color-muted)]">{new Date(v.created_at).toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata" })}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Recent 100 feedback items</h2>
        {recent.length === 0 ? (
          <p className="text-sm text-[var(--color-muted)]">No feedback captured yet.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead className="text-left text-[var(--color-muted)] border-b border-[var(--color-border)]">
                <tr>
                  <th className="py-2 pr-3">Created</th>
                  <th className="py-2 pr-3">Title</th>
                  <th className="py-2 pr-3">Kind</th>
                  <th className="py-2 pr-3">Submitter</th>
                  <th className="py-2 pr-3">Status</th>
                  <th className="py-2 pr-3">Priority</th>
                  <th className="py-2 pr-3">Sentiment</th>
                  <th className="py-2 pr-3 text-right">Votes</th>
                  <th className="py-2 pr-3">Shipped</th>
                  <th className="py-2 pr-3 text-right">Age</th>
                </tr>
              </thead>
              <tbody>
                {recent.map(r => (
                  <tr key={r.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-3 tabular-nums text-[var(--color-muted)] whitespace-nowrap">{new Date(r.created_at).toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata" })}</td>
                    <td className="py-2 pr-3 max-w-[280px] truncate" title={r.description ?? r.title}>{r.title}</td>
                    <td className="py-2 pr-3">{KIND_LABEL[r.kind] ?? r.kind}</td>
                    <td className="py-2 pr-3 text-[var(--color-muted)]">{r.submitted_by_kind ? SUBMITTER_LABEL[r.submitted_by_kind] ?? r.submitted_by_kind : "—"}</td>
                    <td className="py-2 pr-3">
                      <span className={`px-1.5 py-0.5 rounded border text-[10px] uppercase ${STATUS_TONE[r.status] ?? ""}`}>{r.status}</span>
                    </td>
                    <td className="py-2 pr-3">
                      <span className={`px-1.5 py-0.5 rounded border text-[10px] uppercase ${PRIORITY_TONE[r.priority] ?? ""}`}>{r.priority}</span>
                    </td>
                    <td className={`py-2 pr-3 text-[10px] uppercase tracking-wider ${r.sentiment ? SENTIMENT_TONE[r.sentiment] ?? "" : "text-[var(--color-muted)]"}`}>{r.sentiment ?? "—"}</td>
                    <td className="py-2 pr-3 text-right tabular-nums font-semibold">{formatNumber(r.vote_count)}</td>
                    <td className="py-2 pr-3 text-[var(--color-muted)] font-mono text-[10px]">{r.shipped_round ?? "—"}</td>
                    <td className={`py-2 pr-3 text-right tabular-nums ${r.age_days > 30 ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]"}`}>{r.age_days}d</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
          <h3 className="text-sm font-semibold text-[var(--color-fg)]">Feedback discipline</h3>
          <ul className="list-disc list-inside space-y-1">
            <li>Every customer call, demo, support ticket, or engineer complaint logs at least 1 item — no exceptions.</li>
            <li>Title is verbatim from the user, not the founder's re-interpretation.</li>
            <li>Sentiment is captured AT submission — captures the affective signal, not retro mood.</li>
            <li>Status ladder: <code className="font-mono">open</code> → <code className="font-mono">triaged</code> → <code className="font-mono">planned</code> → <code className="font-mono">in_progress</code> → <code className="font-mono">shipped</code> / <code className="font-mono">wont_do</code> / <code className="font-mono">duplicate</code>.</li>
            <li>When closing as <code className="font-mono">wont_do</code> write <code className="font-mono">wont_do_reason</code> — silence rots trust.</li>
            <li>When closing as <code className="font-mono">shipped</code> stamp <code className="font-mono">shipped_round</code> — closes the loop with the submitter.</li>
          </ul>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
          <h3 className="text-sm font-semibold text-[var(--color-fg)]">Voting model</h3>
          <ul className="list-disc list-inside space-y-1">
            <li><code className="font-mono">upvote</code> = +1 weight (default — "I want this").</li>
            <li><code className="font-mono">strong_upvote</code> = +3 weight — "I will churn without this" / "blocking my workflow".</li>
            <li><code className="font-mono">downvote</code> = -1 weight — signals "please do NOT build this".</li>
            <li>Unique (feedback_id, voter_user_id) — re-voting updates kind, never duplicates count.</li>
            <li>Most-voted hero list ranks by raw <code className="font-mono">vote_count</code>, excludes shipped/wont_do/duplicate.</li>
            <li>vote_count is the demand signal — sentiment is the affective signal — priority is the founder call. Three independent axes.</li>
          </ul>
        </div>
      </section>
    </div>
  );
}
