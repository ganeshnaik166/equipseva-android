import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { formatNumber } from '@/lib/format';
import Link from 'next/link';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type Summary = {
  model_count: number | null;
  active_model_label: string | null;
  active_model_family: string | null;
  shadow_mode_active: boolean | null;
  predictions_lifetime: number | null;
  predictions_last_7d: number | null;
  predictions_last_30d: number | null;
  feedback_received: number | null;
  feedback_pending: number | null;
  correct_pct: number | null;
  followed_pct: number | null;
  avg_confidence_pct: number | null;
  avg_predicted_minutes: number | null;
  avg_actual_minutes: number | null;
  false_positive_count: number | null;
  false_negative_count: number | null;
};

type ActiveModel = {
  id: string | null;
  model_label: string | null;
  model_family: string | null;
  accuracy_pct: number | null;
  precision_pct: number | null;
  recall_pct: number | null;
  f1_score: number | null;
  false_positive_rate_pct: number | null;
  false_negative_rate_pct: number | null;
  training_data_through_date: string | null;
  shadow_mode: boolean | null;
  activated_at: string | null;
};

type PredRow = {
  id: string;
  model_label: string | null;
  code_red_request_id: string | null;
  recommended_engineer_id: string | null;
  confidence_pct: number | null;
  predicted_response_minutes: number | null;
  prediction_basis_summary: string | null;
  predicted_at: string | null;
  has_feedback: boolean | null;
};

type FbRow = {
  id: string;
  prediction_id: string;
  model_label: string | null;
  recommendation_was_correct: boolean | null;
  recommendation_was_followed: boolean | null;
  actual_response_minutes: number | null;
  founder_notes: string | null;
  reviewed_at: string | null;
};

function fmtPct(n: number | null | undefined) {
  if (n === null || n === undefined) return '—';
  return `${formatNumber(n)}%`;
}

function fmtMin(n: number | null | undefined) {
  if (n === null || n === undefined) return '—';
  return `${formatNumber(n)} min`;
}

function fmtBool(b: boolean | null | undefined) {
  if (b === null || b === undefined) return '—';
  return b ? 'Yes' : 'No';
}

function fmtDate(s: string | null | undefined) {
  if (!s) return '—';
  return new Date(s).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
}

export default async function FounderAiCodeRedTriagePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [sumRes, activeRes, predsRes, fbRes] = await Promise.all([
    supabase.rpc('founder_ai_triage_summary'),
    supabase.rpc('founder_ai_triage_active_model'),
    supabase.rpc('founder_ai_triage_predictions_recent', { p_limit: 50 }),
    supabase.rpc('founder_ai_triage_feedback_recent', { p_limit: 50 }),
  ]);

  const s: Summary = (sumRes.data?.[0] ?? {}) as Summary;
  const active: ActiveModel = (activeRes.data?.[0] ?? {}) as ActiveModel;
  const preds: PredRow[] = (predsRes.data ?? []) as PredRow[];
  const fb: FbRow[] = (fbRes.data ?? []) as FbRow[];

  const cards: Array<{ label: string; value: string; hint?: string }> = [
    { label: 'Models registered', value: formatNumber(s.model_count ?? 0) },
    { label: 'Active model', value: s.active_model_label ?? '—', hint: s.active_model_family ?? '' },
    { label: 'Shadow mode', value: s.shadow_mode_active ? 'LIVE' : 'SHADOW' },
    { label: 'Predictions (lifetime)', value: formatNumber(s.predictions_lifetime ?? 0) },
    { label: 'Predictions (7d)', value: formatNumber(s.predictions_last_7d ?? 0) },
    { label: 'Predictions (30d)', value: formatNumber(s.predictions_last_30d ?? 0) },
    { label: 'Feedback received', value: formatNumber(s.feedback_received ?? 0) },
    { label: 'Feedback pending', value: formatNumber(s.feedback_pending ?? 0) },
    { label: 'Correct %', value: fmtPct(s.correct_pct) },
    { label: 'Followed %', value: fmtPct(s.followed_pct) },
    { label: 'Avg confidence', value: fmtPct(s.avg_confidence_pct) },
    { label: 'Avg predicted', value: fmtMin(s.avg_predicted_minutes) },
    { label: 'Avg actual', value: fmtMin(s.avg_actual_minutes) },
    { label: 'False positives', value: formatNumber(s.false_positive_count ?? 0) },
    { label: 'False negatives', value: formatNumber(s.false_negative_count ?? 0) },
    {
      label: 'Drift (pred - actual)',
      value:
        s.avg_predicted_minutes !== null && s.avg_actual_minutes !== null
          ? `${formatNumber((s.avg_predicted_minutes ?? 0) - (s.avg_actual_minutes ?? 0))} min`
          : '—',
    },
  ];

  const shadowBadge = s.shadow_mode_active ? (
    <span className="px-2 py-1 rounded bg-emerald-100 text-emerald-800 text-xs font-medium">LIVE routing</span>
  ) : (
    <span className="px-2 py-1 rounded bg-amber-100 text-amber-800 text-xs font-medium">SHADOW mode</span>
  );

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="mb-2 text-sm text-gray-500">
        <Link href="/" className="hover:underline">Ops</Link> {'/'} AI Code Red Triage
      </div>
      <div className="flex items-center gap-3 mb-1">
        <h1 className="text-2xl font-bold">AI Code Red Triage</h1>
        {shadowBadge}
      </div>
      <p className="text-gray-600 mb-6">
        AI-assisted engineer-recommendation infrastructure for Code Red dispatch.
        Models register in shadow mode by default; activate to route live.
      </p>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-8">
        {cards.map((c) => (
          <div key={c.label} className="rounded-lg border border-gray-200 bg-white p-4">
            <div className="text-xs uppercase tracking-wide text-gray-500">{c.label}</div>
            <div className="mt-1 text-xl font-semibold text-gray-900">{c.value}</div>
            {c.hint ? <div className="mt-1 text-xs text-gray-500">{c.hint}</div> : null}
          </div>
        ))}
      </div>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">Active model</h2>
        <div className="rounded-lg border border-gray-200 bg-white p-4">
          {active.id ? (
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm">
              <div><div className="text-xs text-gray-500">Label</div><div className="font-medium">{active.model_label}</div></div>
              <div><div className="text-xs text-gray-500">Family</div><div className="font-medium">{active.model_family}</div></div>
              <div><div className="text-xs text-gray-500">Trained through</div><div className="font-medium">{active.training_data_through_date ?? '—'}</div></div>
              <div><div className="text-xs text-gray-500">Shadow</div><div className="font-medium">{fmtBool(active.shadow_mode)}</div></div>
              <div><div className="text-xs text-gray-500">Accuracy</div><div className="font-medium">{fmtPct(active.accuracy_pct)}</div></div>
              <div><div className="text-xs text-gray-500">Precision</div><div className="font-medium">{fmtPct(active.precision_pct)}</div></div>
              <div><div className="text-xs text-gray-500">Recall</div><div className="font-medium">{fmtPct(active.recall_pct)}</div></div>
              <div><div className="text-xs text-gray-500">F1</div><div className="font-medium">{active.f1_score ?? '—'}</div></div>
              <div><div className="text-xs text-gray-500">FPR</div><div className="font-medium">{fmtPct(active.false_positive_rate_pct)}</div></div>
              <div><div className="text-xs text-gray-500">FNR</div><div className="font-medium">{fmtPct(active.false_negative_rate_pct)}</div></div>
              <div className="md:col-span-2"><div className="text-xs text-gray-500">Activated</div><div className="font-medium">{fmtDate(active.activated_at)}</div></div>
            </div>
          ) : (
            <div className="text-sm text-gray-500">No active model yet. Register one via log_founder_ai_register_model_version.</div>
          )}
        </div>
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">Recent predictions</h2>
        <div className="overflow-x-auto rounded-lg border border-gray-200 bg-white">
          <table className="min-w-full text-sm">
            <thead className="bg-gray-50 text-left text-xs uppercase tracking-wide text-gray-500">
              <tr>
                <th className="px-3 py-2">When</th>
                <th className="px-3 py-2">Model</th>
                <th className="px-3 py-2">Code Red</th>
                <th className="px-3 py-2">Recommended eng</th>
                <th className="px-3 py-2">Confidence</th>
                <th className="px-3 py-2">Predicted</th>
                <th className="px-3 py-2">Feedback</th>
                <th className="px-3 py-2">Basis</th>
              </tr>
            </thead>
            <tbody>
              {preds.length === 0 ? (
                <tr><td colSpan={8} className="px-3 py-4 text-gray-500">No predictions yet.</td></tr>
              ) : preds.map((r) => (
                <tr key={r.id} className="border-t border-gray-100">
                  <td className="px-3 py-2 whitespace-nowrap">{fmtDate(r.predicted_at)}</td>
                  <td className="px-3 py-2">{r.model_label ?? '—'}</td>
                  <td className="px-3 py-2 font-mono text-xs">{r.code_red_request_id ? r.code_red_request_id.slice(0, 8) : '—'}</td>
                  <td className="px-3 py-2 font-mono text-xs">{r.recommended_engineer_id ? r.recommended_engineer_id.slice(0, 8) : '—'}</td>
                  <td className="px-3 py-2">{fmtPct(r.confidence_pct)}</td>
                  <td className="px-3 py-2">{fmtMin(r.predicted_response_minutes)}</td>
                  <td className="px-3 py-2">{r.has_feedback ? 'Yes' : 'pending'}</td>
                  <td className="px-3 py-2 max-w-md truncate" title={r.prediction_basis_summary ?? ''}>{r.prediction_basis_summary ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">Recent feedback</h2>
        <div className="overflow-x-auto rounded-lg border border-gray-200 bg-white">
          <table className="min-w-full text-sm">
            <thead className="bg-gray-50 text-left text-xs uppercase tracking-wide text-gray-500">
              <tr>
                <th className="px-3 py-2">When</th>
                <th className="px-3 py-2">Model</th>
                <th className="px-3 py-2">Correct?</th>
                <th className="px-3 py-2">Followed?</th>
                <th className="px-3 py-2">Actual</th>
                <th className="px-3 py-2">Notes</th>
              </tr>
            </thead>
            <tbody>
              {fb.length === 0 ? (
                <tr><td colSpan={6} className="px-3 py-4 text-gray-500">No feedback recorded yet.</td></tr>
              ) : fb.map((r) => (
                <tr key={r.id} className="border-t border-gray-100">
                  <td className="px-3 py-2 whitespace-nowrap">{fmtDate(r.reviewed_at)}</td>
                  <td className="px-3 py-2">{r.model_label ?? '—'}</td>
                  <td className="px-3 py-2">{fmtBool(r.recommendation_was_correct)}</td>
                  <td className="px-3 py-2">{fmtBool(r.recommendation_was_followed)}</td>
                  <td className="px-3 py-2">{fmtMin(r.actual_response_minutes)}</td>
                  <td className="px-3 py-2 max-w-md truncate" title={r.founder_notes ?? ''}>{r.founder_notes ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="text-xs text-gray-500">
        <p>
          Models default to shadow mode (predictions logged but not routed). Promote to live via
          log_founder_ai_activate_model_version(model_id), which auto-deactivates the previous live model.
          Feedback can be recorded manually or auto-flipped when the underlying Code Red request resolves.
        </p>
      </section>
    </div>
  );
}
