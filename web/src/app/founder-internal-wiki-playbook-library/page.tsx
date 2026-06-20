import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Internal wiki + playbook library — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_articles: number;
  published_count: number;
  draft_count: number;
  distinct_categories: number;
  distinct_sections: number;
  total_revisions: number;
  total_views: number;
  articles_due_review: number;
  articles_overdue_review: number;
  articles_never_reviewed: number;
  top_category: string | null;
  top_category_count: number;
  top_section: string | null;
  top_section_count: number;
  most_viewed_article_title: string | null;
  most_viewed_article_views: number;
  generated_at: string;
};

type ArticleRow = {
  id: string;
  slug: string;
  title: string;
  category: string;
  section: string;
  version: number;
  is_published: boolean;
  tags: string[] | null;
  view_count: number;
  last_reviewed_at: string | null;
  next_review_due_at: string | null;
  updated_at: string;
};

type DueRow = {
  id: string;
  slug: string;
  title: string;
  category: string;
  section: string;
  next_review_due_at: string | null;
  days_until_due: number | null;
  last_reviewed_at: string | null;
  is_overdue: boolean;
};

type RevisionRow = {
  id: string;
  article_id: string;
  article_title: string | null;
  article_slug: string | null;
  version: number;
  change_summary: string | null;
  edited_at: string;
};

function Card({ title, val, sub, danger, ok, warn }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean; warn?: boolean }) {
  const color = danger ? "text-[var(--color-danger)]" : warn ? "text-[var(--color-warn)]" : ok ? "text-[var(--color-ok)]" : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${color}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

function CategoryBadge({ v }: { v: string }) {
  const cls =
    v === "engineering" || v === "security"
      ? "bg-blue-100 text-blue-700"
      : v === "operations" || v === "playbook"
        ? "bg-purple-100 text-purple-700"
        : v === "sales" || v === "customer_success"
          ? "bg-green-100 text-[var(--color-ok)]"
          : v === "finance" || v === "legal"
            ? "bg-yellow-100 text-[var(--color-warn)]"
            : "bg-gray-100 text-[var(--color-muted)]";
  return <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>{v}</span>;
}

function SectionBadge({ v }: { v: string }) {
  const cls =
    v === "runbook" || v === "escalation_playbook"
      ? "bg-red-100 text-[var(--color-danger)]"
      : v === "decision_record" || v === "retrospective"
        ? "bg-purple-100 text-purple-700"
        : v === "how_to" || v === "template"
          ? "bg-blue-100 text-blue-700"
          : "bg-gray-100 text-[var(--color-muted)]";
  return <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>{v}</span>;
}

function PubBadge({ p }: { p: boolean }) {
  return p
    ? <span className="rounded bg-green-100 px-1.5 py-0.5 text-xs text-[var(--color-ok)]">published</span>
    : <span className="rounded bg-gray-100 px-1.5 py-0.5 text-xs text-[var(--color-muted)]">draft</span>;
}

export default async function FounderInternalWikiPlaybookLibraryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [sumRes, recRes, dueRes, revRes] = await Promise.all([
    supabase.rpc("founder_internal_wiki_summary"),
    supabase.rpc("founder_internal_wiki_articles_recent", { p_limit: 50 }),
    supabase.rpc("founder_internal_wiki_articles_due_review"),
    supabase.rpc("founder_internal_wiki_revisions_recent", { p_limit: 30 }),
  ]);
  if (sumRes.error) throw new Error(`internal_wiki_summary: ${sumRes.error.message}`);
  if (recRes.error) throw new Error(`internal_wiki_articles_recent: ${recRes.error.message}`);
  if (dueRes.error) throw new Error(`internal_wiki_articles_due_review: ${dueRes.error.message}`);
  if (revRes.error) throw new Error(`internal_wiki_revisions_recent: ${revRes.error.message}`);

  const s = (sumRes.data?.[0] ?? null) as SummaryRow | null;
  const articles = (recRes.data ?? []) as ArticleRow[];
  const due = (dueRes.data ?? []) as DueRow[];
  const revisions = (revRes.data ?? []) as RevisionRow[];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between gap-4">
        <h1 className="text-xl font-semibold">Internal wiki + playbook library</h1>
        <span className="text-xs text-[var(--color-muted)]">
          16 KPIs · 50-article ledger · 30-revision feed · 10 categories · 7 sections · review-due banner
        </span>
      </header>

      {due.length > 0 ? (
        <section className="rounded-lg border border-[var(--color-warn)]/50 bg-yellow-50 p-4">
          <div className="flex items-baseline justify-between gap-3">
            <h2 className="text-sm font-semibold text-[var(--color-warn)]">
              {due.length} article{due.length === 1 ? "" : "s"} due for review in next 30d
              {due.filter(d => d.is_overdue).length > 0 ? ` · ${due.filter(d => d.is_overdue).length} OVERDUE` : ""}
            </h2>
            <span className="text-xs text-[var(--color-muted)]">top 50</span>
          </div>
          <div className="mt-3 overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead className="text-xs uppercase text-[var(--color-muted)]">
                <tr>
                  <th className="px-3 py-2 text-left">Title</th>
                  <th className="px-3 py-2 text-left">Category</th>
                  <th className="px-3 py-2 text-left">Section</th>
                  <th className="px-3 py-2 text-left">Due</th>
                  <th className="px-3 py-2 text-right">Days</th>
                  <th className="px-3 py-2 text-left">Last reviewed</th>
                </tr>
              </thead>
              <tbody>
                {due.map((d) => (
                  <tr key={d.id} className="border-t border-[var(--color-border)]">
                    <td className="px-3 py-2">{d.title}</td>
                    <td className="px-3 py-2"><CategoryBadge v={d.category} /></td>
                    <td className="px-3 py-2"><SectionBadge v={d.section} /></td>
                    <td className="px-3 py-2 tabular-nums">{d.next_review_due_at ?? "—"}</td>
                    <td className={`px-3 py-2 text-right tabular-nums ${d.is_overdue ? "text-[var(--color-danger)] font-medium" : ""}`}>
                      {d.days_until_due == null ? "—" : d.days_until_due}
                    </td>
                    <td className="px-3 py-2">{d.last_reviewed_at ? formatRelativeTime(d.last_reviewed_at) : "never"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      ) : null}

      {s ? (
        <section>
          <h2 className="mb-2 text-sm font-medium text-[var(--color-muted)]">Library summary</h2>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Card title="Total articles" val={formatNumber(s.total_articles)} />
            <Card title="Published" val={formatNumber(s.published_count)} ok />
            <Card title="Draft" val={formatNumber(s.draft_count)} warn={s.draft_count > 0} />
            <Card title="Distinct categories" val={formatNumber(s.distinct_categories)} sub="of 10" />
            <Card title="Distinct sections" val={formatNumber(s.distinct_sections)} sub="of 7" />
            <Card title="Total revisions" val={formatNumber(s.total_revisions)} />
            <Card title="Total views" val={formatNumber(s.total_views)} />
            <Card title="Due review (30d)" val={formatNumber(s.articles_due_review)} warn={s.articles_due_review > 0} />
            <Card title="Overdue review" val={formatNumber(s.articles_overdue_review)} danger={s.articles_overdue_review > 0} />
            <Card title="Never reviewed" val={formatNumber(s.articles_never_reviewed)} warn={s.articles_never_reviewed > 0} />
            <Card title="Top category" val={s.top_category ?? "—"} sub={`${formatNumber(s.top_category_count)} articles`} />
            <Card title="Top section" val={s.top_section ?? "—"} sub={`${formatNumber(s.top_section_count)} articles`} />
            <Card title="Most viewed article" val={s.most_viewed_article_title ?? "—"} />
            <Card title="Most viewed · views" val={formatNumber(s.most_viewed_article_views)} ok={s.most_viewed_article_views > 0} />
            <Card title="Generated" val={formatRelativeTime(s.generated_at)} sub={s.generated_at} />
            <Card title="Schema rev" val="r1415" sub="2 tables · 7 RPCs" />
          </div>
        </section>
      ) : <p className="text-sm text-[var(--color-muted)]">No summary data.</p>}

      <section>
        <h2 className="mb-2 text-sm font-medium text-[var(--color-muted)]">Article ledger (50 most recently updated)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)]">
          <table className="min-w-full text-sm">
            <thead className="bg-[var(--color-surface)] text-xs uppercase text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2 text-left">Title</th>
                <th className="px-3 py-2 text-left">Slug</th>
                <th className="px-3 py-2 text-left">Category</th>
                <th className="px-3 py-2 text-left">Section</th>
                <th className="px-3 py-2 text-right">v</th>
                <th className="px-3 py-2 text-left">State</th>
                <th className="px-3 py-2 text-right">Views</th>
                <th className="px-3 py-2 text-left">Tags</th>
                <th className="px-3 py-2 text-left">Last reviewed</th>
                <th className="px-3 py-2 text-left">Next review</th>
                <th className="px-3 py-2 text-left">Updated</th>
              </tr>
            </thead>
            <tbody>
              {articles.length === 0 ? (
                <tr><td className="px-3 py-3 text-[var(--color-muted)]" colSpan={11}>No articles yet.</td></tr>
              ) : articles.map((a) => (
                <tr key={a.id} className="border-t border-[var(--color-border)]">
                  <td className="px-3 py-2">{a.title}</td>
                  <td className="px-3 py-2 font-mono text-xs text-[var(--color-muted)]">{a.slug}</td>
                  <td className="px-3 py-2"><CategoryBadge v={a.category} /></td>
                  <td className="px-3 py-2"><SectionBadge v={a.section} /></td>
                  <td className="px-3 py-2 text-right tabular-nums">{a.version}</td>
                  <td className="px-3 py-2"><PubBadge p={a.is_published} /></td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(a.view_count)}</td>
                  <td className="px-3 py-2 text-xs text-[var(--color-muted)]">{(a.tags ?? []).join(", ") || "—"}</td>
                  <td className="px-3 py-2">{a.last_reviewed_at ? formatRelativeTime(a.last_reviewed_at) : "—"}</td>
                  <td className="px-3 py-2 tabular-nums">{a.next_review_due_at ?? "—"}</td>
                  <td className="px-3 py-2">{formatRelativeTime(a.updated_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-medium text-[var(--color-muted)]">Recent revisions (30)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)]">
          <table className="min-w-full text-sm">
            <thead className="bg-[var(--color-surface)] text-xs uppercase text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2 text-left">Article</th>
                <th className="px-3 py-2 text-left">Slug</th>
                <th className="px-3 py-2 text-right">v</th>
                <th className="px-3 py-2 text-left">Change summary</th>
                <th className="px-3 py-2 text-left">Edited</th>
              </tr>
            </thead>
            <tbody>
              {revisions.length === 0 ? (
                <tr><td className="px-3 py-3 text-[var(--color-muted)]" colSpan={5}>No revisions.</td></tr>
              ) : revisions.map((r) => (
                <tr key={r.id} className="border-t border-[var(--color-border)]">
                  <td className="px-3 py-2">{r.article_title ?? "—"}</td>
                  <td className="px-3 py-2 font-mono text-xs text-[var(--color-muted)]">{r.article_slug ?? "—"}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{r.version}</td>
                  <td className="px-3 py-2">{r.change_summary ?? "—"}</td>
                  <td className="px-3 py-2">{formatRelativeTime(r.edited_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
