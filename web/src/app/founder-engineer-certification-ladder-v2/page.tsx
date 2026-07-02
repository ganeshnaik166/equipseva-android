import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type SummaryRow = {
  total_exams: number;
  active_exams: number;
  draft_exams: number;
  sunset_exams: number;
  proctored_exams: number;
  total_attempts: number;
  attempts_scheduled: number;
  attempts_in_progress: number;
  attempts_submitted: number;
  attempts_passed: number;
  attempts_failed: number;
  attempts_disqualified: number;
  pass_rate_pct: number;
  avg_score_pct: number;
  unique_candidates: number;
  attempts_30d: number;
};

type AttemptRow = {
  attempt_id: string;
  engineer_user_id: string;
  exam_label: string;
  exam_kind: string;
  attempt_status: string;
  score_pct: number | null;
  is_proctored: boolean;
  started_at: string | null;
  submitted_at: string | null;
  created_at: string;
};

type ExamRow = {
  exam_id: string;
  exam_label: string;
  exam_kind: string;
  passing_score_pct: number;
  total_questions: number;
  time_limit_minutes: number;
  is_proctored: boolean;
  status: string;
  attempts_count: number;
  created_at: string;
};

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, attemptsRes, examsRes] = await Promise.all([
    supabase.rpc("founder_engineer_cert_v2_summary"),
    supabase.rpc("founder_engineer_cert_v2_attempts_recent", { p_limit: 30 }),
    supabase.rpc("founder_engineer_cert_v2_exams_recent", { p_limit: 30 }),
  ]);

  const s: SummaryRow = (summaryRes.data?.[0] as SummaryRow) ?? {
    total_exams: 0, active_exams: 0, draft_exams: 0, sunset_exams: 0,
    proctored_exams: 0, total_attempts: 0, attempts_scheduled: 0,
    attempts_in_progress: 0, attempts_submitted: 0, attempts_passed: 0,
    attempts_failed: 0, attempts_disqualified: 0, pass_rate_pct: 0,
    avg_score_pct: 0, unique_candidates: 0, attempts_30d: 0,
  };
  const attempts: AttemptRow[] = (attemptsRes.data as AttemptRow[]) ?? [];
  const exams: ExamRow[] = (examsRes.data as ExamRow[]) ?? [];

  const cards = [
    { label: "Total exams", value: formatNumber(s.total_exams) },
    { label: "Active exams", value: formatNumber(s.active_exams) },
    { label: "Draft exams", value: formatNumber(s.draft_exams) },
    { label: "Sunset exams", value: formatNumber(s.sunset_exams) },
    { label: "Proctored exams", value: formatNumber(s.proctored_exams) },
    { label: "Total attempts", value: formatNumber(s.total_attempts) },
    { label: "Scheduled", value: formatNumber(s.attempts_scheduled) },
    { label: "In progress", value: formatNumber(s.attempts_in_progress) },
    { label: "Submitted", value: formatNumber(s.attempts_submitted) },
    { label: "Passed", value: formatNumber(s.attempts_passed) },
    { label: "Failed", value: formatNumber(s.attempts_failed) },
    { label: "Disqualified", value: formatNumber(s.attempts_disqualified) },
    { label: "Pass rate %", value: `${s.pass_rate_pct}%` },
    { label: "Avg score %", value: `${s.avg_score_pct}%` },
    { label: "Unique candidates", value: formatNumber(s.unique_candidates) },
    { label: "Attempts (30d)", value: formatNumber(s.attempts_30d) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Certification Ladder v2</h1>
        <p className="text-sm text-gray-600 mt-1">
          Proctored exam infrastructure for engineer training {"<"}/{">"} tier progression.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">KPI summary</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {cards.map((c) => (
            <div key={c.label} className="rounded-lg border border-gray-200 bg-white p-4">
              <div className="text-xs uppercase tracking-wide text-gray-500">{c.label}</div>
              <div className="mt-1 text-xl font-semibold tabular-nums">{c.value}</div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent attempts</h2>
        <div className="overflow-x-auto rounded-lg border border-gray-200 bg-white">
          <table className="min-w-full text-sm">
            <thead className="bg-gray-50 text-gray-600">
              <tr>
                <th className="px-3 py-2 text-left">Exam</th>
                <th className="px-3 py-2 text-left">Kind</th>
                <th className="px-3 py-2 text-left">Status</th>
                <th className="px-3 py-2 text-right">Score %</th>
                <th className="px-3 py-2 text-left">Proctored</th>
                <th className="px-3 py-2 text-left">Created</th>
              </tr>
            </thead>
            <tbody>
              {attempts.length === 0 ? (
                <tr><td colSpan={6} className="px-3 py-4 text-gray-500 text-center">No attempts yet.</td></tr>
              ) : attempts.map((a) => (
                <tr key={a.attempt_id} className="border-t border-gray-100">
                  <td className="px-3 py-2 font-medium">{a.exam_label}</td>
                  <td className="px-3 py-2 text-gray-600">{a.exam_kind}</td>
                  <td className="px-3 py-2">{a.attempt_status}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{a.score_pct ?? "—"}</td>
                  <td className="px-3 py-2">{a.is_proctored ? "yes" : "no"}</td>
                  <td className="px-3 py-2 text-gray-500">{new Date(a.created_at).toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Exam catalog</h2>
        <div className="overflow-x-auto rounded-lg border border-gray-200 bg-white">
          <table className="min-w-full text-sm">
            <thead className="bg-gray-50 text-gray-600">
              <tr>
                <th className="px-3 py-2 text-left">Label</th>
                <th className="px-3 py-2 text-left">Kind</th>
                <th className="px-3 py-2 text-right">Pass %</th>
                <th className="px-3 py-2 text-right">Qs</th>
                <th className="px-3 py-2 text-right">Mins</th>
                <th className="px-3 py-2 text-left">Proctored</th>
                <th className="px-3 py-2 text-left">Status</th>
                <th className="px-3 py-2 text-right">Attempts</th>
              </tr>
            </thead>
            <tbody>
              {exams.length === 0 ? (
                <tr><td colSpan={8} className="px-3 py-4 text-gray-500 text-center">No exams yet.</td></tr>
              ) : exams.map((e) => (
                <tr key={e.exam_id} className="border-t border-gray-100">
                  <td className="px-3 py-2 font-medium">{e.exam_label}</td>
                  <td className="px-3 py-2 text-gray-600">{e.exam_kind}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{e.passing_score_pct}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{e.total_questions}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{e.time_limit_minutes}</td>
                  <td className="px-3 py-2">{e.is_proctored ? "yes" : "no"}</td>
                  <td className="px-3 py-2">{e.status}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(e.attempts_count)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
