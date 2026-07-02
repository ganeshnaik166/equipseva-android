import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [famRes, attemptsRes, topExpertsRes, gapsRes, summaryRes] = await Promise.all([
    sb.rpc('list_familiarity_r1800'),
    sb.rpc('list_attempts_r1800', { p_familiarity_id: null }),
    sb.rpc('top_brand_experts_r1800'),
    sb.rpc('no_coverage_brands_r1800'),
    sb.rpc('certification_summary_r1800'),
  ]);

  const familiarity: any[] = Array.isArray(famRes.data) ? famRes.data : [];
  const attempts: any[] = Array.isArray(attemptsRes.data) ? attemptsRes.data : [];
  const topExperts: any[] = Array.isArray(topExpertsRes.data) ? topExpertsRes.data : [];
  const gaps: any[] = Array.isArray(gapsRes.data) ? gapsRes.data : [];
  const summaryRow: any = Array.isArray(summaryRes.data) ? summaryRes.data[0] : summaryRes.data;
  const summary = summaryRow ?? {
    total_rows: 0,
    certified_rows: 0,
    experts: 0,
    proficient: 0,
    intermediate: 0,
    beginner: 0,
    no_exposure: 0,
    total_attempts: 0,
    attempts_passed: 0,
    attempts_failed: 0,
  };

  const fmtDate = (s: string | null | undefined) => {
    if (!s) return '—';
    try {
      return new Date(s).toLocaleString('en-IN', {
        year: 'numeric',
        month: 'short',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
      });
    } catch {
      return s;
    }
  };

  const levelBadge = (lvl: string) => {
    const map: Record<string, string> = {
      expert: 'bg-emerald-100 text-emerald-800',
      proficient: 'bg-blue-100 text-blue-800',
      intermediate: 'bg-amber-100 text-amber-800',
      beginner: 'bg-orange-100 text-orange-800',
      no_exposure: 'bg-rose-100 text-rose-800',
    };
    const cls = map[lvl] ?? 'bg-slate-100 text-slate-800';
    return (
      <span className={`inline-flex items-center rounded px-2 py-0.5 text-xs font-medium ${cls}`}>
        {lvl}
      </span>
    );
  };

  const famColumns: Column<any>[] = [
    {
      key: 'engineer_email',
      header: 'Engineer',
      render: (r: any) => <span className="font-mono text-xs">{r.engineer_email ?? r.engineer_user_id ?? '—'}</span>,
    },
    {
      key: 'brand_name',
      header: 'Brand',
      render: (r: any) => <span className="font-medium">{r.brand_name ?? '—'}</span>,
    },
    {
      key: 'familiarity_level',
      header: 'Level',
      render: (r: any) => levelBadge(String(r.familiarity_level ?? '')),
    },
    {
      key: 'total_repairs_count',
      header: 'Repairs',
      render: (r: any) => <span className="tabular-nums">{r.total_repairs_count ?? 0}</span>,
    },
    {
      key: 'cert_obtained',
      header: 'Cert',
      render: (r: any) => (r.cert_obtained ? <span className="text-emerald-700">yes</span> : <span className="text-slate-400">no</span>),
    },
    {
      key: 'cert_date',
      header: 'Cert Date',
      render: (r: any) => <span className="text-xs">{r.cert_date ?? '—'}</span>,
    },
    {
      key: 'last_serviced_at',
      header: 'Last Serviced',
      render: (r: any) => <span className="text-xs">{fmtDate(r.last_serviced_at)}</span>,
    },
  ];

  const attemptColumns: Column<any>[] = [
    {
      key: 'attempt_at',
      header: 'When',
      render: (r: any) => <span className="text-xs">{fmtDate(r.attempt_at)}</span>,
    },
    {
      key: 'engineer_email',
      header: 'Engineer',
      render: (r: any) => <span className="font-mono text-xs">{r.engineer_email ?? '—'}</span>,
    },
    {
      key: 'brand_name',
      header: 'Brand',
      render: (r: any) => <span className="font-medium">{r.brand_name ?? '—'}</span>,
    },
    {
      key: 'passed',
      header: 'Passed',
      render: (r: any) =>
        r.passed ? (
          <span className="inline-flex items-center rounded bg-emerald-100 px-2 py-0.5 text-xs font-medium text-emerald-800">pass</span>
        ) : (
          <span className="inline-flex items-center rounded bg-rose-100 px-2 py-0.5 text-xs font-medium text-rose-800">fail</span>
        ),
    },
    {
      key: 'score',
      header: 'Score',
      render: (r: any) => <span className="tabular-nums">{r.score ?? '—'}</span>,
    },
    {
      key: 'notes',
      header: 'Notes',
      render: (r: any) => <span className="text-xs text-slate-600">{r.notes ?? '—'}</span>,
    },
  ];

  const topExpertColumns: Column<any>[] = [
    {
      key: 'brand_name',
      header: 'Brand',
      render: (r: any) => <span className="font-medium">{r.brand_name ?? '—'}</span>,
    },
    {
      key: 'expert_count',
      header: 'Experts',
      render: (r: any) => <span className="tabular-nums font-semibold text-emerald-700">{r.expert_count ?? 0}</span>,
    },
    {
      key: 'proficient_count',
      header: 'Proficient',
      render: (r: any) => <span className="tabular-nums">{r.proficient_count ?? 0}</span>,
    },
    {
      key: 'certified_count',
      header: 'Certified',
      render: (r: any) => <span className="tabular-nums">{r.certified_count ?? 0}</span>,
    },
    {
      key: 'sample_emails',
      header: 'Sample Experts',
      render: (r: any) => <span className="font-mono text-xs text-slate-600">{r.sample_emails ?? '—'}</span>,
    },
  ];

  const gapColumns: Column<any>[] = [
    {
      key: 'brand_name',
      header: 'Brand',
      render: (r: any) => <span className="font-medium">{r.brand_name ?? '—'}</span>,
    },
    {
      key: 'total_engineers',
      header: 'Total Engineers',
      render: (r: any) => <span className="tabular-nums">{r.total_engineers ?? 0}</span>,
    },
    {
      key: 'experts_or_proficient',
      header: 'Experts + Proficient',
      render: (r: any) => <span className="tabular-nums">{r.experts_or_proficient ?? 0}</span>,
    },
    {
      key: 'coverage_gap_flag',
      header: 'Status',
      render: (r: any) => {
        const flag = String(r.coverage_gap_flag ?? '');
        const cls =
          flag === 'NO_COVERAGE'
            ? 'bg-rose-100 text-rose-800'
            : flag === 'THIN_COVERAGE'
              ? 'bg-amber-100 text-amber-800'
              : 'bg-emerald-100 text-emerald-800';
        return <span className={`inline-flex items-center rounded px-2 py-0.5 text-xs font-medium ${cls}`}>{flag}</span>;
      },
    },
  ];

  const passRate =
    Number(summary.total_attempts) > 0
      ? Math.round((Number(summary.attempts_passed) / Number(summary.total_attempts)) * 100)
      : 0;

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header className="space-y-1">
        <p className="text-xs uppercase tracking-wide text-slate-500">Round 1800 · Founder Console</p>
        <h1 className="text-2xl font-semibold text-slate-900">Engineer Equipment Brand Familiarity</h1>
        <p className="text-sm text-slate-600">
          Per-engineer × brand familiarity matrix for matching to repair jobs. Tracks expertise levels, certifications, and coverage gaps.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-5">
        <div className="rounded-lg border border-slate-200 bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-slate-500">Rows</div>
          <div className="mt-1 text-2xl font-semibold text-slate-900 tabular-nums">{summary.total_rows ?? 0}</div>
        </div>
        <div className="rounded-lg border border-slate-200 bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-slate-500">Certified</div>
          <div className="mt-1 text-2xl font-semibold text-emerald-700 tabular-nums">{summary.certified_rows ?? 0}</div>
        </div>
        <div className="rounded-lg border border-slate-200 bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-slate-500">Experts</div>
          <div className="mt-1 text-2xl font-semibold text-emerald-700 tabular-nums">{summary.experts ?? 0}</div>
        </div>
        <div className="rounded-lg border border-slate-200 bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-slate-500">Proficient</div>
          <div className="mt-1 text-2xl font-semibold text-blue-700 tabular-nums">{summary.proficient ?? 0}</div>
        </div>
        <div className="rounded-lg border border-slate-200 bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-slate-500">Attempt Pass Rate</div>
          <div className="mt-1 text-2xl font-semibold text-slate-900 tabular-nums">{passRate}%</div>
          <div className="text-xs text-slate-500">
            {summary.attempts_passed ?? 0} pass / {summary.attempts_failed ?? 0} fail
          </div>
        </div>
      </section>

      <section className="space-y-3">
        <div className="flex items-baseline justify-between">
          <h2 className="text-lg font-semibold text-slate-900">Top Brand Experts</h2>
          <span className="text-xs text-slate-500">brands ranked by expert headcount</span>
        </div>
        <DataTable rows={topExperts} columns={topExpertColumns} rowKey={(r: any, i: number) => String(r.brand_name ?? i)} />
      </section>

      <section className="space-y-3">
        <div className="flex items-baseline justify-between">
          <h2 className="text-lg font-semibold text-slate-900">Coverage Gaps</h2>
          <span className="text-xs text-slate-500">brands with &lt; 2 experts or proficient engineers</span>
        </div>
        <DataTable rows={gaps} columns={gapColumns} rowKey={(r: any, i: number) => String(r.brand_name ?? i)} />
      </section>

      <section className="space-y-3">
        <div className="flex items-baseline justify-between">
          <h2 className="text-lg font-semibold text-slate-900">Familiarity Matrix</h2>
          <span className="text-xs text-slate-500">engineer × brand grid</span>
        </div>
        <DataTable rows={familiarity} columns={famColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <div className="flex items-baseline justify-between">
          <h2 className="text-lg font-semibold text-slate-900">Recent Certification Attempts</h2>
          <span className="text-xs text-slate-500">most recent 500</span>
        </div>
        <DataTable rows={attempts} columns={attemptColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <footer className="border-t border-slate-200 pt-4 text-xs text-slate-500">
        Data via list_familiarity_r1800 · list_attempts_r1800 · top_brand_experts_r1800 · no_coverage_brands_r1800 · certification_summary_r1800. Write ops gated by is_founder().
      </footer>
    </div>
  );
}
