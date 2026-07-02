import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder hospital engagement score detail — r1799" };
export const dynamic = "force-dynamic";

type ScoreRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  last_login_at: string | null;
  login_count_30d: number;
  tickets_opened_30d: number;
  nps_score: number | null;
  avg_rating: number | null;
  engagement_index: number;
  recorded_at: string;
  trend: string;
};

type TopRow = {
  hospital_user_id: string;
  hospital_email: string | null;
  engagement_index: number;
  trend: string;
  recorded_at: string;
};

type LowRow = {
  hospital_user_id: string;
  hospital_email: string | null;
  engagement_index: number;
  login_count_30d: number;
  tickets_opened_30d: number;
  trend: string;
  recorded_at: string;
};

type DistRow = {
  bucket: string;
  cnt: number;
  avg_login_count: number | null;
  avg_tickets: number | null;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function trendTone(t: string): string {
  if (t === "up") return "text-emerald-700";
  if (t === "down") return "text-rose-700";
  return "text-gray-600";
}

function indexTone(n: number): string {
  if (n >= 80) return "text-emerald-700 font-semibold";
  if (n >= 50) return "text-amber-700";
  if (n >= 25) return "text-orange-700";
  return "text-rose-700 font-semibold";
}

export default async function FounderHospitalEngagementScoreDetailPage() {
  const sb = await getSupabaseServerClient();
  const [scoresRes, topRes, lowRes, distRes] = await Promise.all([
    sb.rpc("list_scores_r1799"),
    sb.rpc("top_engaged_r1799"),
    sb.rpc("low_engagement_queue_r1799"),
    sb.rpc("engagement_distribution_r1799"),
  ]);

  if (scoresRes.error) throw new Error(`list_scores_r1799: ${scoresRes.error.message}`);
  if (topRes.error) throw new Error(`top_engaged_r1799: ${topRes.error.message}`);
  if (lowRes.error) throw new Error(`low_engagement_queue_r1799: ${lowRes.error.message}`);
  if (distRes.error) throw new Error(`engagement_distribution_r1799: ${distRes.error.message}`);

  const scores = (scoresRes.data ?? []) as ScoreRow[];
  const top = (topRes.data ?? []) as TopRow[];
  const low = (lowRes.data ?? []) as LowRow[];
  const dist = (distRes.data ?? []) as DistRow[];

  const totalCount = scores.length;
  const avgIndex =
    totalCount > 0
      ? Math.round(scores.reduce((acc, s) => acc + (s.engagement_index ?? 0), 0) / totalCount)
      : 0;
  const upCount = scores.filter((s) => s.trend === "up").length;
  const flatCount = scores.filter((s) => s.trend === "flat").length;
  const downCount = scores.filter((s) => s.trend === "down").length;
  const highCount = scores.filter((s) => s.engagement_index >= 80).length;
  const criticalCount = scores.filter((s) => s.engagement_index < 25).length;

  const scoreColumns: Column<ScoreRow>[] = [
    { key: "hospital_email", header: "Hospital", render: (r: any) => <span className="font-medium">{r.hospital_email ?? r.hospital_user_id?.slice(0, 8)}</span> },
    { key: "engagement_index", header: "Index", render: (r: any) => <span className={indexTone(r.engagement_index)}>{r.engagement_index}</span> },
    { key: "trend", header: "Trend", render: (r: any) => <span className={trendTone(r.trend)}>{r.trend}</span> },
    { key: "login_count_30d", header: "Logins 30d", render: (r: any) => r.login_count_30d },
    { key: "tickets_opened_30d", header: "Tickets 30d", render: (r: any) => r.tickets_opened_30d },
    { key: "nps_score", header: "NPS", render: (r: any) => r.nps_score ?? "—" },
    { key: "avg_rating", header: "Avg rating", render: (r: any) => (r.avg_rating != null ? Number(r.avg_rating).toFixed(2) : "—") },
    { key: "last_login_at", header: "Last login", render: (r: any) => fmtDate(r.last_login_at) },
    { key: "recorded_at", header: "Recorded", render: (r: any) => fmtDate(r.recorded_at) },
  ];

  const topColumns: Column<TopRow>[] = [
    { key: "hospital_email", header: "Hospital", render: (r: any) => <span className="font-medium">{r.hospital_email ?? r.hospital_user_id?.slice(0, 8)}</span> },
    { key: "engagement_index", header: "Index", render: (r: any) => <span className={indexTone(r.engagement_index)}>{r.engagement_index}</span> },
    { key: "trend", header: "Trend", render: (r: any) => <span className={trendTone(r.trend)}>{r.trend}</span> },
    { key: "recorded_at", header: "Recorded", render: (r: any) => fmtDate(r.recorded_at) },
  ];

  const lowColumns: Column<LowRow>[] = [
    { key: "hospital_email", header: "Hospital", render: (r: any) => <span className="font-medium">{r.hospital_email ?? r.hospital_user_id?.slice(0, 8)}</span> },
    { key: "engagement_index", header: "Index", render: (r: any) => <span className={indexTone(r.engagement_index)}>{r.engagement_index}</span> },
    { key: "login_count_30d", header: "Logins 30d", render: (r: any) => r.login_count_30d },
    { key: "tickets_opened_30d", header: "Tickets 30d", render: (r: any) => r.tickets_opened_30d },
    { key: "trend", header: "Trend", render: (r: any) => <span className={trendTone(r.trend)}>{r.trend}</span> },
    { key: "recorded_at", header: "Recorded", render: (r: any) => fmtDate(r.recorded_at) },
  ];

  const distColumns: Column<DistRow>[] = [
    { key: "bucket", header: "Bucket", render: (r: any) => <span className="font-medium uppercase">{r.bucket}</span> },
    { key: "cnt", header: "Hospitals", render: (r: any) => r.cnt },
    { key: "avg_login_count", header: "Avg logins 30d", render: (r: any) => (r.avg_login_count != null ? Number(r.avg_login_count).toFixed(1) : "—") },
    { key: "avg_tickets", header: "Avg tickets 30d", render: (r: any) => (r.avg_tickets != null ? Number(r.avg_tickets).toFixed(1) : "—") },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <p className="text-xs uppercase tracking-wide text-gray-500">Founder console · r1799</p>
        <h1 className="text-2xl font-semibold">Hospital engagement score detail</h1>
        <p className="text-sm text-gray-600">
          Per-hospital engagement breakdown across login frequency, ticket activity, NPS & ratings.
          Index range 0–100; trend up/flat/down vs last period.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded-lg border p-3">
          <p className="text-xs text-gray-500">Hospitals scored</p>
          <p className="text-xl font-semibold">{totalCount}</p>
        </div>
        <div className="rounded-lg border p-3">
          <p className="text-xs text-gray-500">Avg index</p>
          <p className={`text-xl font-semibold ${indexTone(avgIndex)}`}>{avgIndex}</p>
        </div>
        <div className="rounded-lg border p-3">
          <p className="text-xs text-gray-500">Trend up</p>
          <p className="text-xl font-semibold text-emerald-700">{upCount}</p>
        </div>
        <div className="rounded-lg border p-3">
          <p className="text-xs text-gray-500">Trend flat</p>
          <p className="text-xl font-semibold text-gray-600">{flatCount}</p>
        </div>
        <div className="rounded-lg border p-3">
          <p className="text-xs text-gray-500">Trend down</p>
          <p className="text-xl font-semibold text-rose-700">{downCount}</p>
        </div>
        <div className="rounded-lg border p-3">
          <p className="text-xs text-gray-500">High / critical</p>
          <p className="text-xl font-semibold">
            <span className="text-emerald-700">{highCount}</span>
            <span className="text-gray-400"> / </span>
            <span className="text-rose-700">{criticalCount}</span>
          </p>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Engagement distribution</h2>
        <p className="text-sm text-gray-600">
          Buckets: high (index &gt;= 80), medium (50–79), low (25–49), critical (&lt; 25).
        </p>
        <DataTable<DistRow>
          rows={dist}
          columns={distColumns}
          rowKey={(r, i) => String(r.bucket ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All hospital scores</h2>
        <p className="text-sm text-gray-600">
          Sorted by engagement index (highest first). Up to 500 most recent recordings.
        </p>
        <DataTable<ScoreRow>
          rows={scores}
          columns={scoreColumns}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Top engaged (index &gt;= 70)</h2>
        <p className="text-sm text-gray-600">Hospitals to feature as references & case studies.</p>
        <DataTable<TopRow>
          rows={top}
          columns={topColumns}
          rowKey={(r, i) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Low engagement queue (index &lt; 40)</h2>
        <p className="text-sm text-gray-600">
          Churn-risk accounts — trigger CSM outreach. Sorted by lowest index first.
        </p>
        <DataTable<LowRow>
          rows={low}
          columns={lowColumns}
          rowKey={(r, i) => String(r.hospital_user_id ?? i)}
        />
      </section>
    </main>
  );
}
