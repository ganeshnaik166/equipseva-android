import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder customer spotlight library — r1706" };
export const dynamic = "force-dynamic";

type SpotlightRow = {
  id: string;
  hospital_user_id: string;
  headline: string;
  story_md: string | null;
  metric_summary: string | null;
  photo_url: string | null;
  video_url: string | null;
  status: string;
  published_at: string | null;
  used_in_deck: boolean;
  used_in_blog: boolean;
  created_at: string;
};

type TopUsedRow = {
  spotlight_id: string;
  headline: string;
  status: string;
  usage_count: number;
  total_audience: number;
  total_engagement: number;
  last_used_at: string | null;
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
  if (status === "draft") return "text-amber-700";
  if (status === "archived") return "text-gray-500";
  return "";
}

export default async function FounderCustomerSpotlightLibraryPage() {
  const sb = await getSupabaseServerClient();
  const [spotlightsRes, topUsedRes] = await Promise.all([
    sb.rpc("list_spotlights_r1706"),
    sb.rpc("top_used_spotlights_r1706"),
  ]);

  if (spotlightsRes.error) throw new Error(`list_spotlights_r1706: ${spotlightsRes.error.message}`);
  if (topUsedRes.error) throw new Error(`top_used_spotlights_r1706: ${topUsedRes.error.message}`);

  const spotlights = (spotlightsRes.data ?? []) as SpotlightRow[];
  const topUsed = (topUsedRes.data ?? []) as TopUsedRow[];

  const totalCount = spotlights.length;
  const publishedCount = spotlights.filter((s) => s.status === "published").length;
  const draftCount = spotlights.filter((s) => s.status === "draft").length;
  const archivedCount = spotlights.filter((s) => s.status === "archived").length;
  const usedInDeckCount = spotlights.filter((s) => s.used_in_deck).length;
  const usedInBlogCount = spotlights.filter((s) => s.used_in_blog).length;

  const spotlightColumns: Column<SpotlightRow>[] = [
    { key: "headline", header: "Headline", render: (r: any) => <span className="font-medium">{r.headline}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "metric_summary", header: "Metric summary", render: (r: any) => r.metric_summary ?? "—" },
    { key: "published_at", header: "Published", render: (r: any) => fmtDate(r.published_at) },
    { key: "used_in_deck", header: "Deck", render: (r: any) => (r.used_in_deck ? "yes" : "no") },
    { key: "used_in_blog", header: "Blog", render: (r: any) => (r.used_in_blog ? "yes" : "no") },
    { key: "photo_url", header: "Photo", render: (r: any) => (r.photo_url ? "yes" : "—") },
    { key: "video_url", header: "Video", render: (r: any) => (r.video_url ? "yes" : "—") },
    { key: "created_at", header: "Created", render: (r: any) => fmtDate(r.created_at) },
  ];

  const topUsedColumns: Column<TopUsedRow>[] = [
    { key: "headline", header: "Headline", render: (r: any) => <span className="font-medium">{r.headline}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "usage_count", header: "Uses", render: (r: any) => String(r.usage_count) },
    { key: "total_audience", header: "Audience", render: (r: any) => String(r.total_audience) },
    { key: "total_engagement", header: "Engagement", render: (r: any) => String(r.total_engagement) },
    { key: "last_used_at", header: "Last used", render: (r: any) => fmtDate(r.last_used_at) },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder customer spotlight library — r1706</h1>
        <p className="mt-1 text-xs text-gray-500">
          Hospital success stories for marketing & investor comms. Draft, publish, and track usage across deck, blog,
          website, social & email.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total stories</div>
          <div className="mt-1 text-lg font-semibold">{totalCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Published</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{publishedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Draft</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{draftCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Archived</div>
          <div className="mt-1 text-lg font-semibold text-gray-500">{archivedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">In deck</div>
          <div className="mt-1 text-lg font-semibold">{usedInDeckCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">In blog</div>
          <div className="mt-1 text-lg font-semibold">{usedInBlogCount}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All spotlights</h2>
        <p className="text-xs text-gray-500">
          Founder-only library. Draft a story, attach metrics & media, then publish when polished.
        </p>
        <DataTable
          rows={spotlights}
          columns={spotlightColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No spotlight stories yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Top used spotlights</h2>
        <p className="text-xs text-gray-500">
          Ranked by total usage across channels (deck, blog, website, social & email). Higher usage =&gt; stronger
          social proof asset.
        </p>
        <DataTable
          rows={topUsed}
          columns={topUsedColumns}
          rowKey={(r: any, i: number) => String(r.spotlight_id ?? i)}
          emptyMessage="No engagement logged yet."
        />
      </section>
    </div>
  );
}
