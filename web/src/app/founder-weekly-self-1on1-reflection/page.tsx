import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder weekly self 1:1 reflection — r2577" };
export const dynamic = "force-dynamic";

type ReflectionRow = {
  id: string;
  week_start: string;
  wins_md: string | null;
  misses_md: string | null;
  lessons_md: string | null;
  dominant_emotion: string;
  calibration_score: number;
  next_week_commitment_md: string | null;
  owner_email: string | null;
  status: string;
  notes: string | null;
  created_at: string;
};

type OutcomeRow = {
  id: string;
  reflection_id: string;
  week_start: string;
  observed_at: string;
  commitment_kind: string;
  outcome: string;
  lessons_md: string | null;
  notes: string | null;
};

type EmotionTrendRow = {
  week_start: string;
  dominant_emotion: string;
  calibration_score: number;
  status: string;
};

type CalibrationTrendRow = {
  week_start: string;
  calibration_score: number;
  rolling_4w_avg: number;
};

type AchievementRow = {
  commitment_kind: string;
  total_count: number;
  achieved_count: number;
  partial_count: number;
  missed_count: number;
  dropped_count: number;
  achievement_rate: number;
};

type LessonRow = {
  week_start: string;
  dominant_emotion: string;
  calibration_score: number;
  lessons_md: string | null;
  source: string;
};

type MonthlyPulseRow = {
  month_label: string;
  reflection_count: number;
  avg_calibration: number;
  most_common_emotion: string | null;
  closed_count: number;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function emotionBadge(e: string): string {
  if (e === "joy" || e === "excitement") return "text-emerald-700";
  if (e === "focus" || e === "calm") return "text-sky-700";
  if (e === "frustration" || e === "anxiety") return "text-amber-700";
  if (e === "overwhelm" || e === "sadness") return "text-rose-700";
  return "";
}

function outcomeBadge(o: string): string {
  if (o === "achieved") return "text-emerald-700";
  if (o === "partial") return "text-sky-700";
  if (o === "missed") return "text-amber-700";
  if (o === "dropped") return "text-rose-700";
  return "";
}

function statusBadge(s: string): string {
  if (s === "closed") return "text-emerald-700";
  if (s === "done") return "text-sky-700";
  if (s === "draft") return "text-amber-700";
  return "";
}

function preview(s: string | null, n: number): string {
  if (!s) return "—";
  const t = s.replace(/\s+/g, " ").trim();
  return t.length > n ? t.slice(0, n) + "…" : t;
}

export default async function FounderWeeklySelf1on1ReflectionPage() {
  const sb = await getSupabaseServerClient();
  const [
    reflectionsRes,
    outcomesRes,
    emotionTrendRes,
    calibrationTrendRes,
    achievementRes,
    lessonsRes,
    monthlyPulseRes,
  ] = await Promise.all([
    sb.rpc("list_reflections_r2577"),
    sb.rpc("list_commitment_outcomes_r2577"),
    sb.rpc("weekly_emotion_trend_r2577"),
    sb.rpc("calibration_trend_r2577"),
    sb.rpc("commitment_achievement_rate_r2577"),
    sb.rpc("top_lessons_r2577"),
    sb.rpc("monthly_pulse_summary_r2577"),
  ]);

  if (reflectionsRes.error) throw new Error(`list_reflections_r2577: ${reflectionsRes.error.message}`);
  if (outcomesRes.error) throw new Error(`list_commitment_outcomes_r2577: ${outcomesRes.error.message}`);
  if (emotionTrendRes.error) throw new Error(`weekly_emotion_trend_r2577: ${emotionTrendRes.error.message}`);
  if (calibrationTrendRes.error) throw new Error(`calibration_trend_r2577: ${calibrationTrendRes.error.message}`);
  if (achievementRes.error) throw new Error(`commitment_achievement_rate_r2577: ${achievementRes.error.message}`);
  if (lessonsRes.error) throw new Error(`top_lessons_r2577: ${lessonsRes.error.message}`);
  if (monthlyPulseRes.error) throw new Error(`monthly_pulse_summary_r2577: ${monthlyPulseRes.error.message}`);

  const reflections = (reflectionsRes.data ?? []) as ReflectionRow[];
  const outcomes = (outcomesRes.data ?? []) as OutcomeRow[];
  const emotionTrend = (emotionTrendRes.data ?? []) as EmotionTrendRow[];
  const calibrationTrend = (calibrationTrendRes.data ?? []) as CalibrationTrendRow[];
  const achievement = (achievementRes.data ?? []) as AchievementRow[];
  const lessons = (lessonsRes.data ?? []) as LessonRow[];
  const monthlyPulse = (monthlyPulseRes.data ?? []) as MonthlyPulseRow[];

  const totalReflections = reflections.length;
  const closedCount = reflections.filter((r) => r.status === "closed").length;
  const draftCount = reflections.filter((r) => r.status === "draft").length;
  const avgCalibration =
    reflections.length > 0
      ? (reflections.reduce((acc, r) => acc + (r.calibration_score ?? 0), 0) / reflections.length).toFixed(1)
      : "—";
  const totalOutcomes = outcomes.length;
  const achievedOutcomes = outcomes.filter((o) => o.outcome === "achieved").length;

  const reflectionColumns: Column<ReflectionRow>[] = [
    { key: "week_start", header: "Week", render: (r: any) => fmtDate(r.week_start) },
    {
      key: "dominant_emotion",
      header: "Emotion",
      render: (r: any) => <span className={emotionBadge(r.dominant_emotion)}>{r.dominant_emotion}</span>,
    },
    { key: "calibration_score", header: "Calibration", render: (r: any) => `${r.calibration_score}/10` },
    { key: "wins_md", header: "Wins", render: (r: any) => preview(r.wins_md, 60) },
    { key: "misses_md", header: "Misses", render: (r: any) => preview(r.misses_md, 60) },
    { key: "next_week_commitment_md", header: "Next week", render: (r: any) => preview(r.next_week_commitment_md, 60) },
    {
      key: "status",
      header: "Status",
      render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span>,
    },
  ];

  const outcomeColumns: Column<OutcomeRow>[] = [
    { key: "week_start", header: "Week", render: (r: any) => fmtDate(r.week_start) },
    { key: "observed_at", header: "Observed", render: (r: any) => fmtDate(r.observed_at) },
    { key: "commitment_kind", header: "Kind", render: (r: any) => r.commitment_kind },
    {
      key: "outcome",
      header: "Outcome",
      render: (r: any) => <span className={outcomeBadge(r.outcome)}>{r.outcome}</span>,
    },
    { key: "lessons_md", header: "Lessons", render: (r: any) => preview(r.lessons_md, 80) },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const emotionTrendColumns: Column<EmotionTrendRow>[] = [
    { key: "week_start", header: "Week", render: (r: any) => fmtDate(r.week_start) },
    {
      key: "dominant_emotion",
      header: "Emotion",
      render: (r: any) => <span className={emotionBadge(r.dominant_emotion)}>{r.dominant_emotion}</span>,
    },
    { key: "calibration_score", header: "Calibration", render: (r: any) => `${r.calibration_score}/10` },
    {
      key: "status",
      header: "Status",
      render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span>,
    },
  ];

  const calibrationTrendColumns: Column<CalibrationTrendRow>[] = [
    { key: "week_start", header: "Week", render: (r: any) => fmtDate(r.week_start) },
    { key: "calibration_score", header: "Score", render: (r: any) => `${r.calibration_score}/10` },
    {
      key: "rolling_4w_avg",
      header: "Rolling 4w avg",
      render: (r: any) => Number(r.rolling_4w_avg ?? 0).toFixed(2),
    },
  ];

  const achievementColumns: Column<AchievementRow>[] = [
    { key: "commitment_kind", header: "Kind", render: (r: any) => r.commitment_kind },
    { key: "total_count", header: "Total", render: (r: any) => String(r.total_count) },
    { key: "achieved_count", header: "Achieved", render: (r: any) => String(r.achieved_count) },
    { key: "partial_count", header: "Partial", render: (r: any) => String(r.partial_count) },
    { key: "missed_count", header: "Missed", render: (r: any) => String(r.missed_count) },
    { key: "dropped_count", header: "Dropped", render: (r: any) => String(r.dropped_count) },
    {
      key: "achievement_rate",
      header: "Rate",
      render: (r: any) => `${(Number(r.achievement_rate ?? 0) * 100).toFixed(0)}%`,
    },
  ];

  const lessonColumns: Column<LessonRow>[] = [
    { key: "week_start", header: "Week", render: (r: any) => fmtDate(r.week_start) },
    { key: "source", header: "Source", render: (r: any) => r.source },
    {
      key: "dominant_emotion",
      header: "Emotion",
      render: (r: any) => <span className={emotionBadge(r.dominant_emotion)}>{r.dominant_emotion}</span>,
    },
    { key: "calibration_score", header: "Calibration", render: (r: any) => `${r.calibration_score}/10` },
    { key: "lessons_md", header: "Lesson", render: (r: any) => preview(r.lessons_md, 120) },
  ];

  const monthlyPulseColumns: Column<MonthlyPulseRow>[] = [
    { key: "month_label", header: "Month", render: (r: any) => r.month_label },
    { key: "reflection_count", header: "Reflections", render: (r: any) => String(r.reflection_count) },
    {
      key: "avg_calibration",
      header: "Avg calibration",
      render: (r: any) => Number(r.avg_calibration ?? 0).toFixed(2),
    },
    {
      key: "most_common_emotion",
      header: "Dominant emotion",
      render: (r: any) =>
        r.most_common_emotion ? (
          <span className={emotionBadge(r.most_common_emotion)}>{r.most_common_emotion}</span>
        ) : (
          "—"
        ),
    },
    { key: "closed_count", header: "Closed", render: (r: any) => String(r.closed_count) },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder weekly self 1:1 reflection — r2577</h1>
        <p className="mt-1 text-xs text-gray-500">
          Weekly founder reflection: 3 wins, 3 misses, 3 lessons, dominant emotion, calibration score, and next-week
          commitment. Track follow-through on commitments & spot energy patterns over time.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total reflections</div>
          <div className="mt-1 text-lg font-semibold">{totalReflections}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Closed</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{closedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Draft</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{draftCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg calibration</div>
          <div className="mt-1 text-lg font-semibold">{avgCalibration}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Commitments tracked</div>
          <div className="mt-1 text-lg font-semibold">{totalOutcomes}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Achieved</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{achievedOutcomes}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All weekly reflections</h2>
        <p className="text-xs text-gray-500">
          One reflection per week. Wins =&gt; what landed. Misses =&gt; what slipped. Lessons =&gt; what changes next
          week.
        </p>
        <DataTable
          rows={reflections}
          columns={reflectionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No weekly reflections logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Commitment outcomes</h2>
        <p className="text-xs text-gray-500">
          How each next-week commitment actually played out: achieved & partial = good signal; missed & dropped
          = follow-up needed.
        </p>
        <DataTable
          rows={outcomes}
          columns={outcomeColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No commitment outcomes logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Weekly emotion trend</h2>
        <p className="text-xs text-gray-500">
          Chronological view of dominant emotion & calibration score week-over-week. Spot streaks of overwhelm or
          frustration early.
        </p>
        <DataTable
          rows={emotionTrend}
          columns={emotionTrendColumns}
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
          emptyMessage="No emotion trend data yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Calibration trend (rolling 4-week)</h2>
        <p className="text-xs text-gray-500">
          Calibration score & rolling 4-week moving average. Smooths out single-week noise so trend direction is
          clearer.
        </p>
        <DataTable
          rows={calibrationTrend}
          columns={calibrationTrendColumns}
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
          emptyMessage="No calibration trend data yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Commitment achievement rate by kind</h2>
        <p className="text-xs text-gray-500">
          Which commitment kinds (strategic / tactical / relationship / health / family) actually land vs slip.
          Persistent drops in family / health =&gt; founder burnout risk.
        </p>
        <DataTable
          rows={achievement}
          columns={achievementColumns}
          rowKey={(r: any, i: number) => String(r.commitment_kind ?? i)}
          emptyMessage="No commitment data yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Top lessons</h2>
        <p className="text-xs text-gray-500">
          Lessons captured directly in weekly reflections & per-commitment outcome retrospectives. Most recent 50.
        </p>
        <DataTable
          rows={lessons}
          columns={lessonColumns}
          rowKey={(r: any, i: number) => String(`${r.week_start}-${r.source}-${i}`)}
          emptyMessage="No lessons captured yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Monthly pulse summary</h2>
        <p className="text-xs text-gray-500">
          Monthly roll-up: reflection count, average calibration, dominant emotion of the month & how many weeks
          closed clean.
        </p>
        <DataTable
          rows={monthlyPulse}
          columns={monthlyPulseColumns}
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
          emptyMessage="No monthly pulse data yet."
        />
      </section>
    </div>
  );
}
