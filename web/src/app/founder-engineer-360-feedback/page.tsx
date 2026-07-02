import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpisRes, leaderRes, concernRes, breakdownRes, feedRes, gapsRes] = await Promise.all([
    supabase.rpc('founder_eng360_kpis'),
    supabase.rpc('founder_eng360_leaderboard'),
    supabase.rpc('founder_eng360_concerning_patterns'),
    supabase.rpc('founder_eng360_reviewer_breakdown'),
    supabase.rpc('founder_eng360_recent_feed'),
    supabase.rpc('founder_eng360_coverage_gaps'),
  ]);

  const k: any = kpisRes.data ?? {};
  const leader: any[] = (leaderRes.data as any[]) ?? [];
  const concerns: any[] = (concernRes.data as any[]) ?? [];
  const breakdown: any[] = (breakdownRes.data as any[]) ?? [];
  const feed: any[] = (feedRes.data as any[]) ?? [];
  const gaps: any[] = (gapsRes.data as any[]) ?? [];

  const cards: Array<{ label: string; value: string; sub?: string }> = [
    { label: 'submissions total', value: String(k.total_submissions ?? 0) },
    { label: 'submissions 30d', value: String(k.submissions_30d ?? 0) },
    { label: 'submissions 90d', value: String(k.submissions_90d ?? 0) },
    { label: 'engineers covered', value: String(k.engineers_covered ?? 0) },
    { label: 'engineers covered 30d', value: String(k.engineers_covered_30d ?? 0) },
    { label: 'avg composite (all)', value: String(k.avg_composite_all ?? 0), sub: 'out of 5' },
    { label: 'avg composite 30d', value: String(k.avg_composite_30d ?? 0), sub: 'out of 5' },
    { label: 'concerns total', value: String(k.concern_count_all ?? 0) },
    { label: 'concerns 30d', value: String(k.concern_count_30d ?? 0) },
    { label: 'hospital share 30d', value: (k.hospital_share_30d ?? 0) + '%' },
    { label: 'peer share 30d', value: (k.peer_share_30d ?? 0) + '%' },
    { label: 'founder share 30d', value: (k.founder_share_30d ?? 0) + '%' },
    { label: 'avg technical 30d', value: String(k.avg_technical_30d ?? 0) },
    { label: 'avg communication 30d', value: String(k.avg_communication_30d ?? 0) },
    { label: 'avg punctuality 30d', value: String(k.avg_punctuality_30d ?? 0) },
    { label: 'avg outcome 30d', value: String(k.avg_outcome_30d ?? 0) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8">
      <div className="mb-6">
        <h1 className="text-2xl font-semibold text-slate-900">engineer 360 feedback collector</h1>
        <p className="mt-1 text-sm text-slate-600">
          aggregate feedback from hospital contacts, peer engineers, founder. composite score is mean of 5 sub-scores (out of 5). concerning patterns surface engineers with {">="} 2 concerns in 90d.
        </p>
      </div>

      <section className="mb-8">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {cards.map((c) => (
            <div key={c.label} className="rounded-lg border border-slate-200 bg-white p-4">
              <div className="text-xs uppercase tracking-wide text-slate-500">{c.label}</div>
              <div className="mt-1 text-2xl font-semibold text-slate-900">{c.value}</div>
              {c.sub ? <div className="text-xs text-slate-500">{c.sub}</div> : null}
            </div>
          ))}
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">engineer leaderboard</h2>
        <p className="mb-2 text-xs text-slate-500">engineers ranked by avg composite (min 1 submission).</p>
        <DataTable
          rows={leader}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'engineer_label', header: 'engineer', render: (r: any) => r.engineer_label ?? '—' },
            { key: 'submissions', header: 'n', render: (r: any) => r.submissions ?? '—' },
            { key: 'hospital_submissions', header: 'hospital', render: (r: any) => r.hospital_submissions ?? '—' },
            { key: 'peer_submissions', header: 'peer', render: (r: any) => r.peer_submissions ?? '—' },
            { key: 'avg_composite', header: 'composite', render: (r: any) => r.avg_composite ?? '—' },
            { key: 'avg_technical', header: 'technical', render: (r: any) => r.avg_technical ?? '—' },
            { key: 'avg_communication', header: 'comm', render: (r: any) => r.avg_communication ?? '—' },
            { key: 'concern_count', header: 'concerns', render: (r: any) => r.concern_count ?? '—' },
            {
              key: 'last_submitted_at',
              header: 'last',
              render: (r: any) => (r.last_submitted_at ? new Date(r.last_submitted_at).toLocaleDateString() : '—'),
            },
          ]}
        />
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">concerning patterns</h2>
        <p className="mb-2 text-xs text-slate-500">engineers with {">="} 2 concerns in last 90 days. dominant category surfaces the most-repeated issue.</p>
        <DataTable
          rows={concerns}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'engineer_label', header: 'engineer', render: (r: any) => r.engineer_label ?? '—' },
            { key: 'concern_30d', header: '30d concerns', render: (r: any) => r.concern_30d ?? '—' },
            { key: 'concern_90d', header: '90d concerns', render: (r: any) => r.concern_90d ?? '—' },
            { key: 'dominant_category', header: 'dominant category', render: (r: any) => r.dominant_category ?? '—' },
            { key: 'avg_composite_30d', header: 'avg 30d', render: (r: any) => r.avg_composite_30d ?? '—' },
            {
              key: 'last_concern_at',
              header: 'last concern',
              render: (r: any) => (r.last_concern_at ? new Date(r.last_concern_at).toLocaleDateString() : '—'),
            },
          ]}
        />
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">reviewer-kind breakdown</h2>
        <p className="mb-2 text-xs text-slate-500">composite score per reviewer kind. high spread = perception gap between cohorts.</p>
        <DataTable
          rows={breakdown}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'engineer_label', header: 'engineer', render: (r: any) => r.engineer_label ?? '—' },
            { key: 'hospital_avg', header: 'hospital avg', render: (r: any) => r.hospital_avg ?? '—' },
            { key: 'peer_avg', header: 'peer avg', render: (r: any) => r.peer_avg ?? '—' },
            { key: 'founder_avg', header: 'founder avg', render: (r: any) => r.founder_avg ?? '—' },
            { key: 'hospital_n', header: 'hosp n', render: (r: any) => r.hospital_n ?? '—' },
            { key: 'peer_n', header: 'peer n', render: (r: any) => r.peer_n ?? '—' },
            { key: 'founder_n', header: 'founder n', render: (r: any) => r.founder_n ?? '—' },
            { key: 'spread', header: 'spread', render: (r: any) => r.spread ?? '—' },
          ]}
        />
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">coverage gaps</h2>
        <p className="mb-2 text-xs text-slate-500">engineers with {">="} 3 jobs in 90d but {"<="} 1 feedback submission. nudge hospital contacts.</p>
        <DataTable
          rows={gaps}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'engineer_label', header: 'engineer', render: (r: any) => r.engineer_label ?? '—' },
            { key: 'jobs_90d', header: 'jobs 90d', render: (r: any) => r.jobs_90d ?? '—' },
            { key: 'submissions_90d', header: 'submissions 90d', render: (r: any) => r.submissions_90d ?? '—' },
            {
              key: 'last_submission',
              header: 'last submission',
              render: (r: any) => (r.last_submission ? new Date(r.last_submission).toLocaleDateString() : '—'),
            },
            {
              key: 'days_since_submission',
              header: 'days since',
              render: (r: any) => (r.days_since_submission == null ? 'never' : r.days_since_submission),
            },
          ]}
        />
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">recent submissions feed</h2>
        <p className="mb-2 text-xs text-slate-500">last 100 submissions across all engineers.</p>
        <DataTable
          rows={feed}
          rowKey={(r: any) => r.id}
          columns={[
            {
              key: 'submitted_at',
              header: 'when',
              render: (r: any) => new Date(r.submitted_at).toLocaleString(),
            },
            { key: 'engineer_label', header: 'engineer', render: (r: any) => r.engineer_label ?? '—' },
            { key: 'reviewer_kind', header: 'reviewer', render: (r: any) => r.reviewer_kind ?? '—' },
            { key: 'reviewer_label', header: 'label', render: (r: any) => r.reviewer_label ?? '—' },
            { key: 'composite_score', header: 'score', render: (r: any) => r.composite_score ?? '—' },
            {
              key: 'concern_flag',
              header: 'concern',
              render: (r: any) => (r.concern_flag ? (r.concern_category ?? 'yes') : '—'),
            },
            { key: 'snippet', header: 'note', render: (r: any) => r.snippet ?? '—' },
          ]}
        />
      </section>

      <p className="mt-8 text-xs text-slate-400">
        formatRupees demo (unused on this page but imported per spec): {formatRupees(0)} placeholder. RLS-gated, founder-only, audit-logged.
      </p>
    </main>
  );
}
