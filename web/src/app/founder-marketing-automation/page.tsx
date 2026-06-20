import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { formatNumber } from '@/lib/format';

export const dynamic = 'force-dynamic';

type Summary = {
  leads_total: number;
  leads_captured_30d: number;
  leads_qualified: number;
  leads_closed_won: number;
  leads_closed_lost: number;
  leads_disqualified: number;
  leads_in_flight: number;
  avg_lead_score: number;
  high_score_leads: number;
  sequences_total: number;
  sequences_active: number;
  runs_total: number;
  runs_active: number;
  runs_converted: number;
  runs_dropped: number;
  overall_conversion_rate_pct: number;
};

type Lead = {
  id: string;
  lead_email: string;
  lead_name: string | null;
  lead_phone: string | null;
  lead_company: string | null;
  lead_source: string;
  lead_kind: string;
  lead_score: number;
  funnel_stage: string;
  captured_at: string;
  notes: string | null;
  created_at: string;
};

type Sequence = {
  id: string;
  sequence_label: string;
  target_lead_kind: string | null;
  total_steps: number;
  days_to_complete: number;
  is_active: boolean;
  sent_count: number;
  conversion_rate_pct: number;
  created_at: string;
};

type Run = {
  id: string;
  lead_id: string;
  sequence_id: string | null;
  lead_email: string | null;
  sequence_label: string | null;
  current_step: number;
  total_steps_completed: number;
  status: string;
  started_at: string;
  completed_at: string | null;
  last_action_at: string | null;
};

const STAGE_TONE: Record<string, string> = {
  captured: 'bg-slate-100 text-slate-700',
  engaged: 'bg-blue-100 text-blue-800',
  qualified: 'bg-indigo-100 text-indigo-800',
  meeting_booked: 'bg-violet-100 text-violet-800',
  proposal_sent: 'bg-amber-100 text-amber-800',
  closed_won: 'bg-emerald-100 text-emerald-800',
  closed_lost: 'bg-rose-100 text-rose-800',
  disqualified: 'bg-zinc-200 text-zinc-700',
};

const RUN_STATUS_TONE: Record<string, string> = {
  active: 'bg-blue-100 text-blue-800',
  paused: 'bg-amber-100 text-amber-800',
  completed: 'bg-emerald-100 text-emerald-800',
  dropped: 'bg-rose-100 text-rose-800',
  converted: 'bg-emerald-200 text-emerald-900',
};

function Card({ label, value, hint, tone = 'slate' }: { label: string; value: string | number; hint?: string; tone?: string }) {
  const toneClass =
    tone === 'red' ? 'border-red-200 bg-red-50' :
    tone === 'amber' ? 'border-amber-200 bg-amber-50' :
    tone === 'emerald' ? 'border-emerald-200 bg-emerald-50' :
    tone === 'blue' ? 'border-blue-200 bg-blue-50' :
    tone === 'violet' ? 'border-violet-200 bg-violet-50' :
    'border-slate-200 bg-white';
  return (
    <div className={`rounded-lg border p-4 ${toneClass}`}>
      <div className="text-xs uppercase tracking-wide text-slate-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold text-slate-900">{value}</div>
      {hint ? <div className="mt-1 text-xs text-slate-500">{hint}</div> : null}
    </div>
  );
}

function Pill({ value, palette }: { value: string; palette: Record<string, string> }) {
  const cls = palette[value] || 'bg-slate-100 text-slate-700';
  return <span className={`inline-block rounded px-2 py-0.5 text-xs font-medium ${cls}`}>{value}</span>;
}

function scoreTone(score: number): string {
  if (score >= 75) return 'text-emerald-700 font-semibold';
  if (score >= 50) return 'text-blue-700';
  if (score >= 25) return 'text-amber-700';
  return 'text-slate-500';
}

export default async function FounderMarketingAutomationPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [{ data: summary }, { data: leads }, { data: sequences }, { data: runs }] = await Promise.all([
    supabase.rpc('founder_marketing_automation_summary'),
    supabase.rpc('founder_marketing_leads_recent', { p_stage: null, p_kind: null, p_limit: 40 }),
    supabase.rpc('founder_marketing_sequences_recent', { p_active: null, p_limit: 40 }),
    supabase.rpc('founder_marketing_active_runs_recent', { p_status: null, p_limit: 40 }),
  ]);

  const s: Summary = (summary as Summary) || ({} as Summary);
  const leadRows: Lead[] = (leads as Lead[]) || [];
  const seqRows: Sequence[] = (sequences as Sequence[]) || [];
  const runRows: Run[] = (runs as Run[]) || [];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8">
      <header className="mb-6">
        <div className="text-xs uppercase tracking-widest text-slate-500">r1410 — Founder Marketing Automation</div>
        <h1 className="mt-1 text-2xl font-semibold text-slate-900">Marketing Automation</h1>
        <p className="mt-1 text-sm text-slate-600">
          Lead capture pipeline + nurturing sequences. 8-stage funnel (captured → engaged → qualified → meeting → proposal → won/lost). Founder-only.
        </p>
      </header>

      <section className="mb-6 grid grid-cols-2 gap-3 md:grid-cols-4 lg:grid-cols-8">
        <Card label="Leads total" value={formatNumber(s.leads_total || 0)} />
        <Card label="Captured 30d" value={formatNumber(s.leads_captured_30d || 0)} tone="blue" />
        <Card label="In flight" value={formatNumber(s.leads_in_flight || 0)} />
        <Card label="Qualified" value={formatNumber(s.leads_qualified || 0)} tone="violet" />
        <Card label="Closed won" value={formatNumber(s.leads_closed_won || 0)} tone="emerald" />
        <Card label="Closed lost" value={formatNumber(s.leads_closed_lost || 0)} tone={s.leads_closed_lost ? 'red' : 'slate'} />
        <Card label="Disqualified" value={formatNumber(s.leads_disqualified || 0)} />
        <Card label="Conv. rate" value={`${s.overall_conversion_rate_pct || 0}%`} tone="emerald" />
        <Card label="Avg score" value={s.avg_lead_score || 0} />
        <Card label="High-score (≥75)" value={formatNumber(s.high_score_leads || 0)} tone="emerald" />
        <Card label="Sequences total" value={formatNumber(s.sequences_total || 0)} />
        <Card label="Sequences active" value={formatNumber(s.sequences_active || 0)} tone="blue" />
        <Card label="Runs total" value={formatNumber(s.runs_total || 0)} />
        <Card label="Runs active" value={formatNumber(s.runs_active || 0)} tone="blue" />
        <Card label="Runs converted" value={formatNumber(s.runs_converted || 0)} tone="emerald" />
        <Card label="Runs dropped" value={formatNumber(s.runs_dropped || 0)} tone={s.runs_dropped ? 'amber' : 'slate'} />
      </section>

      <section className="mb-6 rounded-lg border border-slate-200 bg-white">
        <div className="flex items-center justify-between border-b border-slate-200 px-4 py-3">
          <h2 className="text-sm font-semibold text-slate-900">Leads ledger</h2>
          <span className="text-xs text-slate-500">{leadRows.length} rows</span>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-600">
              <tr>
                <th className="px-4 py-2">Email</th>
                <th className="px-4 py-2">Name</th>
                <th className="px-4 py-2">Company</th>
                <th className="px-4 py-2">Kind</th>
                <th className="px-4 py-2">Source</th>
                <th className="px-4 py-2">Score</th>
                <th className="px-4 py-2">Stage</th>
                <th className="px-4 py-2">Captured</th>
              </tr>
            </thead>
            <tbody>
              {leadRows.length === 0 ? (
                <tr><td colSpan={8} className="px-4 py-6 text-center text-slate-500">No leads captured yet.</td></tr>
              ) : leadRows.map((l) => (
                <tr key={l.id} className="border-t border-slate-100">
                  <td className="px-4 py-2 font-mono text-xs">{l.lead_email}</td>
                  <td className="px-4 py-2">{l.lead_name || '—'}</td>
                  <td className="px-4 py-2">{l.lead_company || '—'}</td>
                  <td className="px-4 py-2 font-mono text-xs">{l.lead_kind}</td>
                  <td className="px-4 py-2 font-mono text-xs">{l.lead_source}</td>
                  <td className={`px-4 py-2 ${scoreTone(l.lead_score)}`}>{l.lead_score}</td>
                  <td className="px-4 py-2"><Pill value={l.funnel_stage} palette={STAGE_TONE} /></td>
                  <td className="px-4 py-2 text-xs text-slate-600">{new Date(l.captured_at).toISOString().slice(0, 10)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="mb-6 rounded-lg border border-slate-200 bg-white">
        <div className="flex items-center justify-between border-b border-slate-200 px-4 py-3">
          <h2 className="text-sm font-semibold text-slate-900">Nurturing sequences</h2>
          <span className="text-xs text-slate-500">{seqRows.length} rows</span>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-600">
              <tr>
                <th className="px-4 py-2">Sequence</th>
                <th className="px-4 py-2">Target kind</th>
                <th className="px-4 py-2">Steps</th>
                <th className="px-4 py-2">Days</th>
                <th className="px-4 py-2">Active</th>
                <th className="px-4 py-2">Sent</th>
                <th className="px-4 py-2">Conv %</th>
                <th className="px-4 py-2">Created</th>
              </tr>
            </thead>
            <tbody>
              {seqRows.length === 0 ? (
                <tr><td colSpan={8} className="px-4 py-6 text-center text-slate-500">No sequences registered yet.</td></tr>
              ) : seqRows.map((q) => (
                <tr key={q.id} className="border-t border-slate-100">
                  <td className="px-4 py-2 font-medium">{q.sequence_label}</td>
                  <td className="px-4 py-2 font-mono text-xs">{q.target_lead_kind || '—'}</td>
                  <td className="px-4 py-2">{q.total_steps}</td>
                  <td className="px-4 py-2">{q.days_to_complete}</td>
                  <td className="px-4 py-2">{q.is_active ? <span className="text-emerald-700">✓</span> : <span className="text-slate-400">paused</span>}</td>
                  <td className="px-4 py-2">{formatNumber(q.sent_count)}</td>
                  <td className="px-4 py-2 font-semibold">{Number(q.conversion_rate_pct).toFixed(2)}%</td>
                  <td className="px-4 py-2 text-xs text-slate-600">{new Date(q.created_at).toISOString().slice(0, 10)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="rounded-lg border border-slate-200 bg-white">
        <div className="flex items-center justify-between border-b border-slate-200 px-4 py-3">
          <h2 className="text-sm font-semibold text-slate-900">Active sequence runs</h2>
          <span className="text-xs text-slate-500">{runRows.length} rows</span>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-600">
              <tr>
                <th className="px-4 py-2">Lead</th>
                <th className="px-4 py-2">Sequence</th>
                <th className="px-4 py-2">Step</th>
                <th className="px-4 py-2">Completed</th>
                <th className="px-4 py-2">Status</th>
                <th className="px-4 py-2">Started</th>
                <th className="px-4 py-2">Last action</th>
              </tr>
            </thead>
            <tbody>
              {runRows.length === 0 ? (
                <tr><td colSpan={7} className="px-4 py-6 text-center text-slate-500">No sequence runs in flight.</td></tr>
              ) : runRows.map((r) => (
                <tr key={r.id} className="border-t border-slate-100">
                  <td className="px-4 py-2 font-mono text-xs">{r.lead_email || r.lead_id.slice(0, 8)}</td>
                  <td className="px-4 py-2">{r.sequence_label || '—'}</td>
                  <td className="px-4 py-2">{r.current_step}</td>
                  <td className="px-4 py-2">{r.total_steps_completed}</td>
                  <td className="px-4 py-2"><Pill value={r.status} palette={RUN_STATUS_TONE} /></td>
                  <td className="px-4 py-2 text-xs text-slate-600">{new Date(r.started_at).toISOString().slice(0, 10)}</td>
                  <td className="px-4 py-2 text-xs text-slate-600">{r.last_action_at ? new Date(r.last_action_at).toISOString().slice(0, 10) : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <footer className="mt-8 text-xs text-slate-500">
        Founder-only · RLS + SECURITY DEFINER · 8 RPCs · 3 tables · r1410
      </footer>
    </main>
  );
}
