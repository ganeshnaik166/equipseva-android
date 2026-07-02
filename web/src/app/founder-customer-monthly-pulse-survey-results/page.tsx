import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder customer monthly pulse survey results — r2576" };
export const dynamic = "force-dynamic";

type SurveyRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  survey_wave_label: string;
  sent_at: string | null;
  completed_at: string | null;
  nps: number | null;
  csat: number | null;
  verbatim_md: string | null;
  top_concern: string | null;
  owner_email: string | null;
  status: string;
  notes: string | null;
  created_at: string;
};

type FollowupRow = {
  id: string;
  survey_id: string;
  survey_wave_label: string | null;
  hospital_email: string | null;
  action_kind: string;
  action_at: string | null;
  owner_email: string | null;
  outcome: string;
  follow_up_at: string | null;
  status: string;
  notes: string | null;
  created_at: string;
};

type NpsBucket = { bucket: string; response_count: number; pct: number };
type CsatBucket = { csat_score: number; response_count: number; pct: number };
type ConcernRow = { top_concern: string; mention_count: number; avg_nps: number | null; avg_csat: number | null };
type TrendRow = {
  survey_wave_label: string;
  sent_count: number;
  completed_count: number;
  completion_pct: number;
  avg_nps: number | null;
  avg_csat: number | null;
};
type TopHospitalRow = {
  hospital_user_id: string;
  hospital_email: string | null;
  survey_count: number;
  avg_nps: number | null;
  avg_csat: number | null;
  last_wave: string | null;
  last_completed_at: string | null;
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
  if (status === "completed" || status === "done") return "text-emerald-700";
  if (status === "sent" || status === "open" || status === "in_progress") return "text-amber-700";
  if (status === "expired" || status === "dropped") return "text-red-700";
  if (status === "skipped") return "text-gray-500";
  return "";
}

function outcomeBadge(outcome: string): string {
  if (outcome === "positive") return "text-emerald-700";
  if (outcome === "neutral") return "text-amber-700";
  if (outcome === "negative") return "text-red-700";
  return "text-gray-500";
}

function npsBadge(nps: number | null): string {
  if (nps === null) return "";
  if (nps >= 9) return "text-emerald-700 font-medium";
  if (nps >= 7) return "text-amber-700";
  return "text-red-700";
}

export default async function FounderCustomerMonthlyPulseSurveyResultsPage() {
  const sb = await getSupabaseServerClient();
  const [surveysRes, followupsRes, npsRes, csatRes, concernsRes, trendRes, topHospRes] = await Promise.all([
    sb.rpc("list_surveys_r2576"),
    sb.rpc("list_followups_r2576"),
    sb.rpc("nps_distribution_r2576"),
    sb.rpc("csat_distribution_r2576"),
    sb.rpc("top_concerns_r2576"),
    sb.rpc("monthly_completion_trend_r2576"),
    sb.rpc("top_hospitals_by_nps_r2576"),
  ]);

  if (surveysRes.error) throw new Error(`list_surveys_r2576: ${surveysRes.error.message}`);
  if (followupsRes.error) throw new Error(`list_followups_r2576: ${followupsRes.error.message}`);
  if (npsRes.error) throw new Error(`nps_distribution_r2576: ${npsRes.error.message}`);
  if (csatRes.error) throw new Error(`csat_distribution_r2576: ${csatRes.error.message}`);
  if (concernsRes.error) throw new Error(`top_concerns_r2576: ${concernsRes.error.message}`);
  if (trendRes.error) throw new Error(`monthly_completion_trend_r2576: ${trendRes.error.message}`);
  if (topHospRes.error) throw new Error(`top_hospitals_by_nps_r2576: ${topHospRes.error.message}`);

  const surveys = (surveysRes.data ?? []) as SurveyRow[];
  const followups = (followupsRes.data ?? []) as FollowupRow[];
  const npsDist = (npsRes.data ?? []) as NpsBucket[];
  const csatDist = (csatRes.data ?? []) as CsatBucket[];
  const concerns = (concernsRes.data ?? []) as ConcernRow[];
  const trend = (trendRes.data ?? []) as TrendRow[];
  const topHosp = (topHospRes.data ?? []) as TopHospitalRow[];

  const totalSurveys = surveys.length;
  const completedSurveys = surveys.filter((s) => s.status === "completed").length;
  const sentSurveys = surveys.filter((s) => s.status === "sent").length;
  const expiredSurveys = surveys.filter((s) => s.status === "expired").length;
  const npsValues = surveys.map((s) => s.nps).filter((n): n is number => n !== null);
  const avgNps = npsValues.length ? (npsValues.reduce((a, b) => a + b, 0) / npsValues.length).toFixed(2) : "—";
  const csatValues = surveys.map((s) => s.csat).filter((n): n is number => n !== null);
  const avgCsat = csatValues.length ? (csatValues.reduce((a, b) => a + b, 0) / csatValues.length).toFixed(2) : "—";
  const promoters = npsValues.filter((n) => n >= 9).length;
  const detractors = npsValues.filter((n) => n <= 6).length;
  const npsScore = npsValues.length
    ? Math.round(((promoters - detractors) / npsValues.length) * 100)
    : null;
  const openFollowups = followups.filter((f) => f.status === "open" || f.status === "in_progress").length;

  const surveyColumns: Column<SurveyRow>[] = [
    { key: "survey_wave_label", header: "Wave", render: (r: any) => <span className="font-medium">{r.survey_wave_label}</span> },
    { key: "hospital_email", header: "Hospital", render: (r: any) => r.hospital_email ?? "—" },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "nps", header: "NPS", render: (r: any) => <span className={npsBadge(r.nps)}>{r.nps ?? "—"}</span> },
    { key: "csat", header: "CSAT", render: (r: any) => (r.csat ?? "—") },
    { key: "top_concern", header: "Top concern", render: (r: any) => r.top_concern ?? "—" },
    { key: "sent_at", header: "Sent", render: (r: any) => fmtDate(r.sent_at) },
    { key: "completed_at", header: "Completed", render: (r: any) => fmtDate(r.completed_at) },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
  ];

  const followupColumns: Column<FollowupRow>[] = [
    { key: "survey_wave_label", header: "Wave", render: (r: any) => r.survey_wave_label ?? "—" },
    { key: "hospital_email", header: "Hospital", render: (r: any) => r.hospital_email ?? "—" },
    { key: "action_kind", header: "Action", render: (r: any) => <span className="font-medium">{r.action_kind}</span> },
    { key: "outcome", header: "Outcome", render: (r: any) => <span className={outcomeBadge(r.outcome)}>{r.outcome}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "action_at", header: "Action at", render: (r: any) => fmtDate(r.action_at) },
    { key: "follow_up_at", header: "Follow-up", render: (r: any) => fmtDate(r.follow_up_at) },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const npsColumns: Column<NpsBucket>[] = [
    { key: "bucket", header: "Bucket", render: (r: any) => <span className="font-medium">{r.bucket}</span> },
    { key: "response_count", header: "Responses", render: (r: any) => String(r.response_count) },
    { key: "pct", header: "%", render: (r: any) => `${r.pct}%` },
  ];

  const csatColumns: Column<CsatBucket>[] = [
    { key: "csat_score", header: "CSAT", render: (r: any) => <span className="font-medium">{r.csat_score}</span> },
    { key: "response_count", header: "Responses", render: (r: any) => String(r.response_count) },
    { key: "pct", header: "%", render: (r: any) => `${r.pct}%` },
  ];

  const concernColumns: Column<ConcernRow>[] = [
    { key: "top_concern", header: "Concern", render: (r: any) => <span className="font-medium">{r.top_concern}</span> },
    { key: "mention_count", header: "Mentions", render: (r: any) => String(r.mention_count) },
    { key: "avg_nps", header: "Avg NPS", render: (r: any) => (r.avg_nps ?? "—") },
    { key: "avg_csat", header: "Avg CSAT", render: (r: any) => (r.avg_csat ?? "—") },
  ];

  const trendColumns: Column<TrendRow>[] = [
    { key: "survey_wave_label", header: "Wave", render: (r: any) => <span className="font-medium">{r.survey_wave_label}</span> },
    { key: "sent_count", header: "Sent", render: (r: any) => String(r.sent_count) },
    { key: "completed_count", header: "Completed", render: (r: any) => String(r.completed_count) },
    { key: "completion_pct", header: "Completion %", render: (r: any) => `${r.completion_pct}%` },
    { key: "avg_nps", header: "Avg NPS", render: (r: any) => (r.avg_nps ?? "—") },
    { key: "avg_csat", header: "Avg CSAT", render: (r: any) => (r.avg_csat ?? "—") },
  ];

  const topHospColumns: Column<TopHospitalRow>[] = [
    { key: "hospital_email", header: "Hospital", render: (r: any) => <span className="font-medium">{r.hospital_email ?? "—"}</span> },
    { key: "survey_count", header: "Surveys", render: (r: any) => String(r.survey_count) },
    { key: "avg_nps", header: "Avg NPS", render: (r: any) => (r.avg_nps ?? "—") },
    { key: "avg_csat", header: "Avg CSAT", render: (r: any) => (r.avg_csat ?? "—") },
    { key: "last_wave", header: "Last wave", render: (r: any) => r.last_wave ?? "—" },
    { key: "last_completed_at", header: "Last completed", render: (r: any) => fmtDate(r.last_completed_at) },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder customer monthly pulse survey results — r2576</h1>
        <p className="mt-1 text-xs text-gray-500">
          Monthly hospital pulse: NPS, CSAT, verbatims, top concerns & follow-up actions. Catch detractors early => close the loop fast.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-7">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total surveys</div>
          <div className="mt-1 text-lg font-semibold">{totalSurveys}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Completed</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{completedSurveys}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Sent (open)</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{sentSurveys}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Expired</div>
          <div className="mt-1 text-lg font-semibold text-red-700">{expiredSurveys}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">NPS score</div>
          <div className="mt-1 text-lg font-semibold">{npsScore === null ? "—" : npsScore}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg NPS / CSAT</div>
          <div className="mt-1 text-lg font-semibold">{avgNps} / {avgCsat}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Open follow-ups</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{openFollowups}</div>
        </div>
      </section>

      <section className="grid grid-cols-1 gap-6 md:grid-cols-2">
        <div className="space-y-3">
          <h2 className="text-base font-semibold">NPS distribution</h2>
          <p className="text-xs text-gray-500">
            Promoter (9-10) > Passive (7-8) > Detractor (0-6). NPS = %promoter − %detractor.
          </p>
          <DataTable
            rows={npsDist}
            columns={npsColumns}
            rowKey={(r: any, i: number) => String(r.bucket ?? i)}
            emptyMessage="No NPS responses yet."
          />
        </div>
        <div className="space-y-3">
          <h2 className="text-base font-semibold">CSAT distribution</h2>
          <p className="text-xs text-gray-500">
            CSAT 0-5 scale. 5 => delighted, 0 => furious. Watch the <= 3 tail.
          </p>
          <DataTable
            rows={csatDist}
            columns={csatColumns}
            rowKey={(r: any, i: number) => String(r.csat_score ?? i)}
            emptyMessage="No CSAT responses yet."
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Monthly completion trend</h2>
        <p className="text-xs text-gray-500">
          Survey wave => sent vs completed, plus avg NPS & CSAT per wave. Low completion => channel/timing issue.
        </p>
        <DataTable
          rows={trend}
          columns={trendColumns}
          rowKey={(r: any, i: number) => String(r.survey_wave_label ?? i)}
          emptyMessage="No waves yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Top concerns</h2>
        <p className="text-xs text-gray-500">
          Verbatim-tagged top concern. Cluster mentions => product/process roadmap input.
        </p>
        <DataTable
          rows={concerns}
          columns={concernColumns}
          rowKey={(r: any, i: number) => String(r.top_concern ?? i)}
          emptyMessage="No concerns logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Top hospitals by avg NPS</h2>
        <p className="text-xs text-gray-500">
          Highest-loyalty hospitals first => spotlight, case study & referral candidates.
        </p>
        <DataTable
          rows={topHosp}
          columns={topHospColumns}
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
          emptyMessage="No NPS scores yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All surveys</h2>
        <p className="text-xs text-gray-500">
          Per-hospital monthly pulse. Detractors (NPS 0-6) => trigger same-week follow-up action.
        </p>
        <DataTable
          rows={surveys}
          columns={surveyColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No surveys yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Follow-up actions</h2>
        <p className="text-xs text-gray-500">
          Close-the-loop log: call > visit > training > refund > feature_request. Open + in_progress => founder owns until done.
        </p>
        <DataTable
          rows={followups}
          columns={followupColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No follow-up actions logged."
        />
      </section>
    </div>
  );
}
