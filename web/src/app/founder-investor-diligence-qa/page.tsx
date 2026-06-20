import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-2xl border border-slate-200 bg-white p-4">
      <div className="text-xs font-medium uppercase tracking-wide text-slate-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold text-slate-900">{value}</div>
    </div>
  );
}

function Section({ title, subtitle, children }: { title: string; subtitle?: string; children: React.ReactNode }) {
  return (
    <section className="mt-8">
      <div className="mb-3">
        <h2 className="text-lg font-semibold text-slate-900">{title}</h2>
        {subtitle ? <p className="text-sm text-slate-500">{subtitle}</p> : null}
      </div>
      <div className="rounded-2xl border border-slate-200 bg-white p-2">
        {children}
      </div>
    </section>
  );
}

function fmtDt(v: any): string {
  if (!v) return '-';
  try { return new Date(v).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }); } catch { return String(v); }
}

function fmtNum(v: any, suffix = ''): string {
  if (v === null || v === undefined) return '-';
  const n = Number(v);
  if (!Number.isFinite(n)) return '-';
  return n.toLocaleString('en-IN') + suffix;
}

function priorityBadge(p: string) {
  const color =
    p === 'p0' ? 'bg-rose-100 text-rose-800' :
    p === 'p1' ? 'bg-amber-100 text-amber-800' :
    p === 'p2' ? 'bg-sky-100 text-sky-800' :
                 'bg-slate-100 text-slate-700';
  return <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${color}`}>{(p || '').toUpperCase()}</span>;
}

function statusBadge(s: string) {
  const color =
    s === 'answered' ? 'bg-emerald-100 text-emerald-800' :
    s === 'in_progress' ? 'bg-sky-100 text-sky-800' :
    s === 'blocked' ? 'bg-rose-100 text-rose-800' :
    s === 'wont_answer' ? 'bg-slate-200 text-slate-700' :
                          'bg-amber-100 text-amber-800';
  return <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${color}`}>{s}</span>;
}

export default async function FounderInvestorDiligenceQAPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpisRes, openRes, byInvRes, byCatRes, slaRes, recentRes] = await Promise.all([
    supabase.rpc('founder_diligence_qa_kpis'),
    supabase.rpc('founder_diligence_qa_open_queue'),
    supabase.rpc('founder_diligence_qa_by_investor'),
    supabase.rpc('founder_diligence_qa_by_category'),
    supabase.rpc('founder_diligence_qa_sla_breaches'),
    supabase.rpc('founder_diligence_qa_recent_answered'),
  ]);

  const k: any = kpisRes.data ?? {};
  const openQueue: any[] = openRes.data ?? [];
  const byInvestor: any[] = byInvRes.data ?? [];
  const byCategory: any[] = byCatRes.data ?? [];
  const slaBreaches: any[] = slaRes.data ?? [];
  const recentAnswered: any[] = recentRes.data ?? [];

  // touch unused import to satisfy lint without changing surface
  void formatRupees;

  return (
    <main className="mx-auto max-w-7xl px-4 py-8">
      <header className="mb-6">
        <div className="flex items-center gap-3">
          <h1 className="text-2xl font-bold text-slate-900">Investor Diligence Q&A Tracker</h1>
          <span className="rounded-full bg-indigo-100 px-2 py-0.5 text-xs font-semibold text-indigo-800">r1459</span>
        </div>
        <p className="mt-1 text-sm text-slate-600">
          Track every question raised by investors during diligence, the founder answer, supporting docs, and SLA on response time.
        </p>
      </header>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="Total questions" value={fmtNum(k.total_questions ?? 0)} />
        <Kpi label="Open" value={fmtNum(k.open_questions ?? 0)} />
        <Kpi label="In progress" value={fmtNum(k.in_progress_questions ?? 0)} />
        <Kpi label="Answered" value={fmtNum(k.answered_questions ?? 0)} />
        <Kpi label="Blocked" value={fmtNum(k.blocked_questions ?? 0)} />
        <Kpi label="Overdue" value={fmtNum(k.overdue_questions ?? 0)} />
        <Kpi label="P0 open" value={fmtNum(k.p0_open ?? 0)} />
        <Kpi label="P1 open" value={fmtNum(k.p1_open ?? 0)} />
        <Kpi label="Active investors" value={fmtNum(k.investors_active ?? 0)} />
        <Kpi label="Total investors" value={fmtNum(k.investors_total ?? 0)} />
        <Kpi label="Avg response (h)" value={fmtNum(k.avg_response_hours ?? 0)} />
        <Kpi label="P50 response (h)" value={fmtNum(k.p50_response_hours ?? 0)} />
        <Kpi label="P90 response (h)" value={fmtNum(k.p90_response_hours ?? 0)} />
        <Kpi label="SLA met" value={fmtNum(k.sla_met_count ?? 0)} />
        <Kpi label="SLA missed" value={fmtNum(k.sla_missed_count ?? 0)} />
        <Kpi label="Docs attached" value={fmtNum(k.docs_attached_total ?? 0)} />
      </div>

      <Section title="Open queue" subtitle="Sorted by priority then earliest SLA deadline.">
        <DataTable
          rows={openQueue}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'priority', header: 'Priority', render: (r: any) => priorityBadge(r.priority) },
            { key: 'investor_name', header: 'Investor', render: (r: any) => (
                <div>
                  <div className="font-medium text-slate-900">{r.investor_name}</div>
                  {r.investor_firm ? <div className="text-xs text-slate-500">{r.investor_firm}</div> : null}
                </div>
            ) },
            { key: 'category', header: 'Category', render: (r: any) => <span className="text-xs text-slate-700">{r.category}</span> },
            { key: 'question', header: 'Question', render: (r: any) => <div className="max-w-md text-sm text-slate-800">{r.question}</div> },
            { key: 'status', header: 'Status', render: (r: any) => statusBadge(r.status) },
            { key: 'asked_at', header: 'Asked', render: (r: any) => <span className="text-xs text-slate-600">{fmtDt(r.asked_at)}</span> },
            { key: 'due_at', header: 'Due', render: (r: any) => <span className="text-xs text-slate-600">{fmtDt(r.due_at)}</span> },
            { key: 'hours_remaining', header: 'Hours left', render: (r: any) => {
                const n = Number(r.hours_remaining ?? 0);
                const cls = n < 0 ? 'text-rose-700 font-semibold' : n < 12 ? 'text-amber-700' : 'text-slate-700';
                return <span className={cls}>{n.toFixed(1)}</span>;
            } },
          ]}
        />
      </Section>

      <Section title="By investor" subtitle="Aggregate counts and average response hours per investor.">
        <DataTable
          rows={byInvestor}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'investor_name', header: 'Investor', render: (r: any) => <span className="font-medium text-slate-900">{r.investor_name}</span> },
            { key: 'investor_firm', header: 'Firm', render: (r: any) => <span className="text-sm text-slate-700">{r.investor_firm ?? '-'}</span> },
            { key: 'total_questions', header: 'Total', render: (r: any) => fmtNum(r.total_questions) },
            { key: 'open_questions', header: 'Open', render: (r: any) => fmtNum(r.open_questions) },
            { key: 'answered_questions', header: 'Answered', render: (r: any) => fmtNum(r.answered_questions) },
            { key: 'overdue_questions', header: 'Overdue', render: (r: any) => {
                const n = Number(r.overdue_questions ?? 0);
                return <span className={n > 0 ? 'text-rose-700 font-semibold' : 'text-slate-700'}>{fmtNum(n)}</span>;
            } },
            { key: 'avg_response_hours', header: 'Avg resp (h)', render: (r: any) => fmtNum(r.avg_response_hours) },
            { key: 'last_activity', header: 'Last activity', render: (r: any) => <span className="text-xs text-slate-600">{fmtDt(r.last_activity)}</span> },
          ]}
        />
      </Section>

      <Section title="By category" subtitle="Which diligence topic generates the most questions and how fast we answer.">
        <DataTable
          rows={byCategory}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'category', header: 'Category', render: (r: any) => <span className="font-medium text-slate-900">{r.category}</span> },
            { key: 'total_questions', header: 'Total', render: (r: any) => fmtNum(r.total_questions) },
            { key: 'open_questions', header: 'Open', render: (r: any) => fmtNum(r.open_questions) },
            { key: 'answered_questions', header: 'Answered', render: (r: any) => fmtNum(r.answered_questions) },
            { key: 'avg_response_hours', header: 'Avg resp (h)', render: (r: any) => fmtNum(r.avg_response_hours) },
            { key: 'sla_met_pct', header: 'SLA met %', render: (r: any) => {
                const n = Number(r.sla_met_pct ?? 0);
                const cls = n >= 90 ? 'text-emerald-700' : n >= 70 ? 'text-amber-700' : 'text-rose-700';
                return <span className={`${cls} font-semibold`}>{n.toFixed(1)}%</span>;
            } },
          ]}
        />
      </Section>

      <Section title="SLA breaches" subtitle="Questions past their due time and still unanswered.">
        <DataTable
          rows={slaBreaches}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'priority', header: 'Priority', render: (r: any) => priorityBadge(r.priority) },
            { key: 'investor_name', header: 'Investor', render: (r: any) => <span className="font-medium text-slate-900">{r.investor_name}</span> },
            { key: 'category', header: 'Category', render: (r: any) => <span className="text-xs text-slate-700">{r.category}</span> },
            { key: 'question', header: 'Question', render: (r: any) => <div className="max-w-md text-sm text-slate-800">{r.question}</div> },
            { key: 'asked_at', header: 'Asked', render: (r: any) => <span className="text-xs text-slate-600">{fmtDt(r.asked_at)}</span> },
            { key: 'due_at', header: 'Due', render: (r: any) => <span className="text-xs text-slate-600">{fmtDt(r.due_at)}</span> },
            { key: 'hours_overdue', header: 'Hours overdue', render: (r: any) => <span className="text-rose-700 font-semibold">{fmtNum(r.hours_overdue)}</span> },
            { key: 'status', header: 'Status', render: (r: any) => statusBadge(r.status) },
          ]}
        />
      </Section>

      <Section title="Recently answered" subtitle="Latest 50 questions closed out with response time and SLA outcome.">
        <DataTable
          rows={recentAnswered}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'investor_name', header: 'Investor', render: (r: any) => <span className="font-medium text-slate-900">{r.investor_name}</span> },
            { key: 'category', header: 'Category', render: (r: any) => <span className="text-xs text-slate-700">{r.category}</span> },
            { key: 'priority', header: 'Priority', render: (r: any) => priorityBadge(r.priority) },
            { key: 'question', header: 'Question', render: (r: any) => <div className="max-w-sm text-sm text-slate-800">{r.question}</div> },
            { key: 'answer', header: 'Answer', render: (r: any) => <div className="max-w-sm text-sm text-slate-700">{r.answer ?? '-'}</div> },
            { key: 'response_hours', header: 'Resp (h)', render: (r: any) => fmtNum(r.response_hours) },
            { key: 'sla_hours', header: 'SLA (h)', render: (r: any) => fmtNum(r.sla_hours) },
            { key: 'sla_met', header: 'SLA', render: (r: any) => r.sla_met
                ? <span className="inline-flex items-center rounded-full bg-emerald-100 px-2 py-0.5 text-xs font-medium text-emerald-800">met</span>
                : <span className="inline-flex items-center rounded-full bg-rose-100 px-2 py-0.5 text-xs font-medium text-rose-800">missed</span> },
            { key: 'answered_at', header: 'Answered', render: (r: any) => <span className="text-xs text-slate-600">{fmtDt(r.answered_at)}</span> },
          ]}
        />
      </Section>
    </main>
  );
}
