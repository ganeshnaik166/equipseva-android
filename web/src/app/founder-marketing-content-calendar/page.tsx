import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Marketing content calendar — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_pieces: number;
  idea_count: number;
  draft_count: number;
  review_count: number;
  scheduled_count: number;
  published_count: number;
  retired_count: number;
  upcoming_14d_count: number;
  overdue_count: number;
  published_last_30d: number;
  total_expected_reach: number;
  total_actual_reach: number;
  total_leads_generated: number;
  avg_actual_reach: number;
  reach_attainment_pct: number;
  top_channel_label: string;
};

type Piece = {
  id: string;
  piece_label: string;
  channel: string;
  topic_category: string;
  status: string;
  planned_publish_date: string;
  published_at: string | null;
  published_url: string | null;
  target_audience: string | null;
  author_label: string;
  expected_reach_count: number;
  actual_reach_count: number;
  leads_generated: number;
  is_overdue: boolean;
  created_at: string;
  updated_at: string;
};

type Engagement = {
  id: string;
  piece_id: string;
  piece_label: string;
  channel: string;
  snapshot_at: string;
  views: number;
  likes: number;
  shares: number;
  comments: number;
  link_clicks: number;
  leads_attributed: number;
};

type Upcoming = {
  id: string;
  piece_label: string;
  channel: string;
  topic_category: string;
  status: string;
  planned_publish_date: string;
  days_until: number;
  is_overdue: boolean;
  author_label: string;
  expected_reach_count: number;
};

function Card({ label, value, sub, tone }: { label: string; value: string; sub?: string; tone?: "ok" | "warn" | "danger" }) {
  const t = tone === "ok" ? "text-[var(--color-ok)]" : tone === "warn" ? "text-[var(--color-warn)]" : tone === "danger" ? "text-[var(--color-danger)]" : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${t}`}>{value}</div>
      {sub ? <div className="text-xs text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

function statusTone(s: string): "ok" | "warn" | "danger" | undefined {
  if (s === "published") return "ok";
  if (s === "idea" || s === "draft" || s === "review" || s === "scheduled") return "warn";
  if (s === "retired") return "danger";
  return undefined;
}

function StatusPill({ s }: { s: string }) {
  const t = statusTone(s);
  const cls = t === "ok" ? "text-[var(--color-ok)] border-[var(--color-ok)]" : t === "warn" ? "text-[var(--color-warn)] border-[var(--color-warn)]" : t === "danger" ? "text-[var(--color-danger)] border-[var(--color-danger)]" : "text-[var(--color-muted)] border-[var(--color-border)]";
  return <span className={`inline-block rounded-full border px-2 py-0.5 text-xs ${cls}`}>{s}</span>;
}

function ChannelPill({ c }: { c: string }) {
  return <span className="inline-block rounded-full border border-[var(--color-border)] px-2 py-0.5 text-xs text-[var(--color-muted)]">{c}</span>;
}

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try { return new Date(s).toISOString().slice(0, 10); } catch { return "—"; }
}

function fmtDays(n: number): string {
  if (n < 0) return `${Math.abs(n)}d overdue`;
  if (n === 0) return "today";
  return `in ${n}d`;
}

export default async function FounderMarketingContentCalendarPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();
  const [sRes, pRes, eRes, uRes] = await Promise.all([
    sb.rpc("founder_marketing_content_calendar_summary"),
    sb.rpc("founder_marketing_content_pieces_recent"),
    sb.rpc("founder_marketing_content_engagement_recent"),
    sb.rpc("founder_marketing_content_upcoming"),
  ]);
  if (sRes.error) throw new Error(`mkt_content_summary: ${sRes.error.message}`);
  if (pRes.error) throw new Error(`mkt_content_pieces: ${pRes.error.message}`);
  if (eRes.error) throw new Error(`mkt_content_engagement: ${eRes.error.message}`);
  if (uRes.error) throw new Error(`mkt_content_upcoming: ${uRes.error.message}`);
  const s = (sRes.data?.[0] ?? null) as Summary | null;
  const pieces = (pRes.data ?? []) as Piece[];
  const engagement = (eRes.data ?? []) as Engagement[];
  const upcoming = (uRes.data ?? []) as Upcoming[];

  return (
    <main className="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
      <header className="mb-6">
        <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">r1443 · founder console · HEAVY</div>
        <h1 className="mt-1 text-2xl font-semibold">Marketing content calendar</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Plan + schedule + measure every blog post, social, email and PR piece in one place. 10 channels · 8 topic categories · 6-state pipeline (idea {"->"} draft {"->"} review {"->"} scheduled {"->"} published {"->"} retired).
        </p>
      </header>

      <section className="mb-8">
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Calendar KPIs</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          <Card label="Total pieces" value={formatNumber(s?.total_pieces ?? 0)} />
          <Card label="Idea" value={formatNumber(s?.idea_count ?? 0)} tone="warn" />
          <Card label="Draft" value={formatNumber(s?.draft_count ?? 0)} tone="warn" />
          <Card label="Review" value={formatNumber(s?.review_count ?? 0)} tone="warn" />
          <Card label="Scheduled" value={formatNumber(s?.scheduled_count ?? 0)} tone="warn" />
          <Card label="Published" value={formatNumber(s?.published_count ?? 0)} tone="ok" />
          <Card label="Retired" value={formatNumber(s?.retired_count ?? 0)} tone="danger" />
          <Card label="Upcoming 14d" value={formatNumber(s?.upcoming_14d_count ?? 0)} />
          <Card label="Overdue" value={formatNumber(s?.overdue_count ?? 0)} tone="danger" sub="planned date passed" />
          <Card label="Published last 30d" value={formatNumber(s?.published_last_30d ?? 0)} tone="ok" />
          <Card label="Total expected reach" value={formatNumber(s?.total_expected_reach ?? 0)} />
          <Card label="Total actual reach" value={formatNumber(s?.total_actual_reach ?? 0)} tone="ok" />
          <Card label="Total leads generated" value={formatNumber(s?.total_leads_generated ?? 0)} tone="ok" />
          <Card label="Avg reach (published)" value={formatNumber(s?.avg_actual_reach ?? 0)} />
          <Card label="Reach attainment" value={`${formatNumber(s?.reach_attainment_pct ?? 0)}%`} sub="actual vs expected" />
          <Card label="Top channel" value={s?.top_channel_label ?? "—"} sub="most published" />
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Upcoming 14 days</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
          <table className="min-w-full text-sm">
            <thead className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2">Label</th>
                <th className="px-3 py-2">Channel</th>
                <th className="px-3 py-2">Topic</th>
                <th className="px-3 py-2">Status</th>
                <th className="px-3 py-2">Planned</th>
                <th className="px-3 py-2">When</th>
                <th className="px-3 py-2">Author</th>
                <th className="px-3 py-2">Expected reach</th>
              </tr>
            </thead>
            <tbody>
              {upcoming.length === 0 ? (
                <tr><td colSpan={8} className="px-3 py-6 text-center text-[var(--color-muted)]">Nothing planned in the next 14 days.</td></tr>
              ) : upcoming.map((u) => (
                <tr key={u.id} className="border-b border-[var(--color-border)]/40 last:border-0">
                  <td className="px-3 py-2 font-medium">{u.piece_label}</td>
                  <td className="px-3 py-2"><ChannelPill c={u.channel} /></td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{u.topic_category}</td>
                  <td className="px-3 py-2"><StatusPill s={u.status} /></td>
                  <td className="px-3 py-2 tabular-nums">{fmtDate(u.planned_publish_date)}</td>
                  <td className={`px-3 py-2 tabular-nums ${u.is_overdue ? "text-[var(--color-danger)]" : ""}`}>{fmtDays(u.days_until)}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{u.author_label}</td>
                  <td className="px-3 py-2 tabular-nums">{formatNumber(u.expected_reach_count)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Pieces ledger (40 most recent)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
          <table className="min-w-full text-sm">
            <thead className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2">Label</th>
                <th className="px-3 py-2">Channel</th>
                <th className="px-3 py-2">Topic</th>
                <th className="px-3 py-2">Status</th>
                <th className="px-3 py-2">Author</th>
                <th className="px-3 py-2">Audience</th>
                <th className="px-3 py-2">Planned</th>
                <th className="px-3 py-2">Published</th>
                <th className="px-3 py-2">Exp reach</th>
                <th className="px-3 py-2">Actual reach</th>
                <th className="px-3 py-2">Leads</th>
                <th className="px-3 py-2">Updated</th>
              </tr>
            </thead>
            <tbody>
              {pieces.length === 0 ? (
                <tr><td colSpan={12} className="px-3 py-6 text-center text-[var(--color-muted)]">No content pieces registered yet.</td></tr>
              ) : pieces.map((p) => (
                <tr key={p.id} className="border-b border-[var(--color-border)]/40 last:border-0">
                  <td className="px-3 py-2 font-medium">
                    {p.piece_label}
                    {p.is_overdue ? <span className="ml-2 text-xs text-[var(--color-danger)]">overdue</span> : null}
                  </td>
                  <td className="px-3 py-2"><ChannelPill c={p.channel} /></td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{p.topic_category}</td>
                  <td className="px-3 py-2"><StatusPill s={p.status} /></td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{p.author_label}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{p.target_audience ?? "—"}</td>
                  <td className="px-3 py-2 tabular-nums">{fmtDate(p.planned_publish_date)}</td>
                  <td className="px-3 py-2 tabular-nums">{fmtDate(p.published_at)}</td>
                  <td className="px-3 py-2 tabular-nums">{formatNumber(p.expected_reach_count)}</td>
                  <td className="px-3 py-2 tabular-nums">{formatNumber(p.actual_reach_count)}</td>
                  <td className="px-3 py-2 tabular-nums">{formatNumber(p.leads_generated)}</td>
                  <td className="px-3 py-2 tabular-nums">{fmtDate(p.updated_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Engagement feed (60 most recent snapshots)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
          <table className="min-w-full text-sm">
            <thead className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2">Piece</th>
                <th className="px-3 py-2">Channel</th>
                <th className="px-3 py-2">Snapshot at</th>
                <th className="px-3 py-2">Views</th>
                <th className="px-3 py-2">Likes</th>
                <th className="px-3 py-2">Shares</th>
                <th className="px-3 py-2">Comments</th>
                <th className="px-3 py-2">Link clicks</th>
                <th className="px-3 py-2">Leads attributed</th>
              </tr>
            </thead>
            <tbody>
              {engagement.length === 0 ? (
                <tr><td colSpan={9} className="px-3 py-6 text-center text-[var(--color-muted)]">No engagement snapshots recorded yet.</td></tr>
              ) : engagement.map((m) => (
                <tr key={m.id} className="border-b border-[var(--color-border)]/40 last:border-0">
                  <td className="px-3 py-2 font-medium">{m.piece_label}</td>
                  <td className="px-3 py-2"><ChannelPill c={m.channel} /></td>
                  <td className="px-3 py-2 tabular-nums">{fmtDate(m.snapshot_at)}</td>
                  <td className="px-3 py-2 tabular-nums">{formatNumber(m.views)}</td>
                  <td className="px-3 py-2 tabular-nums">{formatNumber(m.likes)}</td>
                  <td className="px-3 py-2 tabular-nums">{formatNumber(m.shares)}</td>
                  <td className="px-3 py-2 tabular-nums">{formatNumber(m.comments)}</td>
                  <td className="px-3 py-2 tabular-nums">{formatNumber(m.link_clicks)}</td>
                  <td className="px-3 py-2 tabular-nums">{formatNumber(m.leads_attributed)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <footer className="mt-10 border-t border-[var(--color-border)] pt-4 text-xs text-[var(--color-muted)]">
        r1443 · founder-only · is_founder() gate enforced on all 7 RPCs · 10 channels (blog/linkedin/twitter/email/PR/podcast/youtube/case_study/whitepaper/webinar) · 8 topic categories · 6-state pipeline · engagement snapshots auto-roll into piece-level actual_reach + leads_generated
      </footer>
    </main>
  );
}
