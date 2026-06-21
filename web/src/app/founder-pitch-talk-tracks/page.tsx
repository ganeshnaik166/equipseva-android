import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const dynamic = "force-dynamic";

type TrackRow = {
  id: string;
  topic: string;
  audience: string;
  version: string;
  headline: string;
  status: string;
  word_count: number;
  est_seconds: number;
  last_rehearsed_at: string | null;
  mastered_at: string | null;
  rehearsal_count: number;
  avg_self_score: number | null;
  updated_at: string;
};

type UsageRow = {
  id: string;
  track_id: string;
  topic: string;
  version: string;
  used_kind: string;
  audience_note: string | null;
  self_score: number | null;
  duration_seconds: number | null;
  used_at: string;
};

type TopicRow = {
  topic: string;
  versions_count: number;
  mastered_versions: number;
  total_rehearsals: number;
  last_touched: string | null;
};

type StatsRow = {
  total_tracks: number;
  topics_covered: number;
  mastered_count: number;
  draft_count: number;
  rehearsals_last_7d: number;
  live_pitches_last_30d: number;
  avg_score_last_30d: number | null;
};

function fmtDate(iso: string | null): string {
  if (!iso) return "—";
  try {
    return new Date(iso).toLocaleString("en-IN", { dateStyle: "medium", timeStyle: "short" });
  } catch {
    return iso;
  }
}

export default async function FounderPitchTalkTracksPage() {
  const sb = await getSupabaseServerClient();

  let tracks: TrackRow[] = [];
  let usage: UsageRow[] = [];
  let topics: TopicRow[] = [];
  let stats: StatsRow | null = null;
  let errMsg: string | null = null;

  try {
    const r1 = await sb.rpc("rpc_founder_pitch_tracks_list");
    if (r1.error) throw r1.error;
    tracks = (r1.data ?? []) as TrackRow[];
  } catch (e: any) {
    errMsg = e?.message ?? "failed loading tracks";
  }

  try {
    const r2 = await sb.rpc("rpc_founder_pitch_tracks_stats");
    if (!r2.error) {
      const rows = (r2.data ?? []) as StatsRow[];
      stats = rows[0] ?? null;
    }
  } catch {
    stats = null;
  }

  try {
    const r3 = await sb.rpc("rpc_founder_pitch_tracks_recent_usage");
    if (!r3.error) usage = (r3.data ?? []) as UsageRow[];
  } catch {
    usage = [];
  }

  try {
    const r4 = await sb.rpc("rpc_founder_pitch_tracks_topic_rollup");
    if (!r4.error) topics = (r4.data ?? []) as TopicRow[];
  } catch {
    topics = [];
  }

  const trackCols: Column<TrackRow>[] = [
    { key: "topic", header: "Topic", render: (r: TrackRow) => r.topic ?? "—" },
    { key: "version", header: "Version", render: (r: TrackRow) => r.version ?? "—" },
    { key: "audience", header: "Audience", render: (r: TrackRow) => r.audience ?? "—" },
    { key: "headline", header: "Headline", render: (r: TrackRow) => r.headline ?? "—" },
    { key: "status", header: "Status", render: (r: TrackRow) => r.status ?? "—" },
    { key: "word_count", header: "Words", render: (r: TrackRow) => String(r.word_count ?? 0) },
    { key: "est_seconds", header: "Target sec", render: (r: TrackRow) => String(r.est_seconds ?? 0) },
    { key: "rehearsal_count", header: "Rehearsals", render: (r: TrackRow) => String(r.rehearsal_count ?? 0) },
    { key: "avg_self_score", header: "Avg score", render: (r: TrackRow) => (r.avg_self_score == null ? "—" : String(r.avg_self_score)) },
    { key: "last_rehearsed_at", header: "Last rehearsed", render: (r: TrackRow) => fmtDate(r.last_rehearsed_at) },
    { key: "mastered_at", header: "Mastered", render: (r: TrackRow) => fmtDate(r.mastered_at) },
  ];

  const usageCols: Column<UsageRow>[] = [
    { key: "used_at", header: "When", render: (r: UsageRow) => fmtDate(r.used_at) },
    { key: "topic", header: "Topic", render: (r: UsageRow) => r.topic ?? "—" },
    { key: "version", header: "Version", render: (r: UsageRow) => r.version ?? "—" },
    { key: "used_kind", header: "Kind", render: (r: UsageRow) => r.used_kind ?? "—" },
    { key: "audience_note", header: "Audience", render: (r: UsageRow) => r.audience_note ?? "—" },
    { key: "self_score", header: "Score", render: (r: UsageRow) => (r.self_score == null ? "—" : String(r.self_score)) },
    { key: "duration_seconds", header: "Sec", render: (r: UsageRow) => (r.duration_seconds == null ? "—" : String(r.duration_seconds)) },
  ];

  const topicCols: Column<TopicRow>[] = [
    { key: "topic", header: "Topic", render: (r: TopicRow) => r.topic ?? "—" },
    { key: "versions_count", header: "Versions", render: (r: TopicRow) => String(r.versions_count ?? 0) },
    { key: "mastered_versions", header: "Mastered", render: (r: TopicRow) => String(r.mastered_versions ?? 0) },
    { key: "total_rehearsals", header: "Rehearsals", render: (r: TopicRow) => String(r.total_rehearsals ?? 0) },
    { key: "last_touched", header: "Last touched", render: (r: TopicRow) => fmtDate(r.last_touched) },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Founder Pitch Talk Tracks</h1>
        <p className="text-sm text-gray-600">
          Central library of memorized pitch versions. 1-min for hallway, 5-min for first meeting, 30-min for deep dive.
          Rehearse, score yourself, log live uses.
        </p>
      </div>

      {errMsg ? (
        <div className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-800">
          {errMsg}
        </div>
      ) : null}

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Total tracks</div>
          <div className="text-xl font-semibold">{stats?.total_tracks ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Topics covered</div>
          <div className="text-xl font-semibold">{stats?.topics_covered ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Mastered</div>
          <div className="text-xl font-semibold">{stats?.mastered_count ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Draft</div>
          <div className="text-xl font-semibold">{stats?.draft_count ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Rehearsals last 7d</div>
          <div className="text-xl font-semibold">{stats?.rehearsals_last_7d ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Live pitches last 30d</div>
          <div className="text-xl font-semibold">{stats?.live_pitches_last_30d ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Avg score last 30d</div>
          <div className="text-xl font-semibold">{stats?.avg_score_last_30d ?? "—"}</div>
        </div>
      </div>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Topic rollup</h2>
        <DataTable<TopicRow>
          columns={topicCols}
          rows={topics}
          rowKey={(r: any, i: number) => String(r.id ?? r.topic ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All tracks</h2>
        <DataTable<TrackRow>
          columns={trackCols}
          rows={tracks}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent usage</h2>
        <DataTable<UsageRow>
          columns={usageCols}
          rows={usage}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
