import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder hospital win stories library — r1815" };
export const dynamic = "force-dynamic";

type StoryRow = {
  id: string;
  hospital_user_id: string;
  story_title: string;
  problem_md: string | null;
  solution_md: string | null;
  outcome_md: string | null;
  quantified_impact: string | null;
  photo_url: string | null;
  video_url: string | null;
  status: string;
  published_at: string | null;
  created_at: string;
  use_count: number;
};

type TopUsedRow = {
  story_id: string;
  story_title: string;
  status: string;
  use_count: number;
  sales_pitch_count: number;
  investor_deck_count: number;
  blog_count: number;
  social_count: number;
  email_campaign_count: number;
  last_used_at: string | null;
};

type RecentPubRow = {
  id: string;
  story_title: string;
  status: string;
  quantified_impact: string | null;
  published_at: string | null;
  created_at: string;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function statusBadge(status: string): string {
  if (status === "published") return "text-emerald-700";
  if (status === "featured") return "text-indigo-700 font-semibold";
  if (status === "draft") return "text-amber-700";
  if (status === "archived") return "text-gray-500";
  return "";
}

export default async function FounderHospitalWinStoriesLibraryPage() {
  const sb = await getSupabaseServerClient();
  const [storiesRes, topUsedRes, recentRes] = await Promise.all([
    sb.rpc("list_stories_r1815"),
    sb.rpc("top_used_stories_r1815"),
    sb.rpc("recent_published_r1815"),
  ]);

  if (storiesRes.error) throw new Error(`list_stories_r1815: ${storiesRes.error.message}`);
  if (topUsedRes.error) throw new Error(`top_used_stories_r1815: ${topUsedRes.error.message}`);
  if (recentRes.error) throw new Error(`recent_published_r1815: ${recentRes.error.message}`);

  const stories = (storiesRes.data ?? []) as StoryRow[];
  const topUsed = (topUsedRes.data ?? []) as TopUsedRow[];
  const recent = (recentRes.data ?? []) as RecentPubRow[];

  const totalCount = stories.length;
  const draftCount = stories.filter((s) => s.status === "draft").length;
  const publishedCount = stories.filter((s) => s.status === "published").length;
  const featuredCount = stories.filter((s) => s.status === "featured").length;
  const archivedCount = stories.filter((s) => s.status === "archived").length;
  const totalUses = stories.reduce((a, s) => a + (s.use_count || 0), 0);

  const storyColumns: Column<StoryRow>[] = [
    { key: "story_title", header: "Title", render: (r: any) => <span className="font-medium">{r.story_title}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "quantified_impact", header: "Quantified impact", render: (r: any) => r.quantified_impact ?? "—" },
    { key: "use_count", header: "Uses", render: (r: any) => String(r.use_count) },
    { key: "photo_url", header: "Photo", render: (r: any) => (r.photo_url ? "yes" : "—") },
    { key: "video_url", header: "Video", render: (r: any) => (r.video_url ? "yes" : "—") },
    { key: "published_at", header: "Published", render: (r: any) => fmtDate(r.published_at) },
    { key: "created_at", header: "Created", render: (r: any) => fmtDate(r.created_at) },
  ];

  const topUsedColumns: Column<TopUsedRow>[] = [
    { key: "story_title", header: "Title", render: (r: any) => <span className="font-medium">{r.story_title}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "use_count", header: "Total uses", render: (r: any) => String(r.use_count) },
    { key: "sales_pitch_count", header: "Sales", render: (r: any) => String(r.sales_pitch_count) },
    { key: "investor_deck_count", header: "Deck", render: (r: any) => String(r.investor_deck_count) },
    { key: "blog_count", header: "Blog", render: (r: any) => String(r.blog_count) },
    { key: "social_count", header: "Social", render: (r: any) => String(r.social_count) },
    { key: "email_campaign_count", header: "Email", render: (r: any) => String(r.email_campaign_count) },
    { key: "last_used_at", header: "Last used", render: (r: any) => fmtDate(r.last_used_at) },
  ];

  const recentColumns: Column<RecentPubRow>[] = [
    { key: "story_title", header: "Title", render: (r: any) => <span className="font-medium">{r.story_title}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "quantified_impact", header: "Quantified impact", render: (r: any) => r.quantified_impact ?? "—" },
    { key: "published_at", header: "Published", render: (r: any) => fmtDate(r.published_at) },
    { key: "created_at", header: "Created", render: (r: any) => fmtDate(r.created_at) },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder hospital win stories library — r1815</h1>
        <p className="mt-1 text-xs text-gray-500">
          Customer success stories suitable for sales pitches, investor decks, blog & social. Draft a story, publish
          when polished, and log every reuse. Higher reuse =&gt; stronger social-proof asset.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total stories</div>
          <div className="mt-1 text-lg font-semibold">{totalCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Draft</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{draftCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Published</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{publishedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Featured</div>
          <div className="mt-1 text-lg font-semibold text-indigo-700">{featuredCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Archived</div>
          <div className="mt-1 text-lg font-semibold text-gray-500">{archivedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total uses</div>
          <div className="mt-1 text-lg font-semibold">{totalUses}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All win stories</h2>
        <p className="text-xs text-gray-500">
          Founder-only library. Each story captures problem → solution → outcome with quantified impact and
          optional photo / video assets.
        </p>
        <DataTable
          rows={stories}
          columns={storyColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No stories drafted yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Top used stories</h2>
        <p className="text-xs text-gray-500">
          Ranked by total reuse across sales pitches, investor decks, blog, social & email campaigns. Use this list
          to know which assets resonate.
        </p>
        <DataTable
          rows={topUsed}
          columns={topUsedColumns}
          rowKey={(r: any, i: number) => String(r.story_id ?? i)}
          emptyMessage="No use events logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Recently published</h2>
        <p className="text-xs text-gray-500">
          Latest stories in published or featured status, freshest first. Use this list to find the newest material for
          outbound comms.
        </p>
        <DataTable
          rows={recent}
          columns={recentColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No published stories yet."
        />
      </section>
    </div>
  );
}
