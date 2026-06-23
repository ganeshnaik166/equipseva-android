import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    { data: scorecards },
    { data: distribution },
    { data: topBottom },
    { data: events },
    { data: kpis },
    { data: hotspots },
    { data: coverage },
  ] = await Promise.all([
    supabase.rpc('r2323_list_scorecards'),
    supabase.rpc('r2323_grade_distribution'),
    supabase.rpc('r2323_top_bottom_performers'),
    supabase.rpc('r2323_recent_events', { p_limit: 50 }),
    supabase.rpc('r2323_aggregate_kpis'),
    supabase.rpc('r2323_escalation_hotspots'),
    supabase.rpc('r2323_period_coverage'),
  ]);

  const k = (kpis as any[] | null)?.[0] ?? {};
  const cov = (coverage as any[] | null)?.[0] ?? {};

  const scorecardCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => <span className="font-medium">{r.chain_name}</span> },
    { key: 'chain_code', header: 'Code', render: (r) => <code className="text-xs">{r.chain_code}</code> },
    { key: 'hospital_count', header: 'Hospitals', render: (r) => r.hospital_count },
    { key: 'uptime_pct', header: 'Uptime %', render: (r) => `${Number(r.uptime_pct).toFixed(2)}%` },
    { key: 'sla_compliance_pct', header: 'SLA %', render: (r) => `${Number(r.sla_compliance_pct).toFixed(2)}%` },
    { key: 'escalation_count', header: 'Escalations', render: (r) => r.escalation_count },
    { key: 'avg_resolution_hours', header: 'Avg Resolve (h)', render: (r) => Number(r.avg_resolution_hours).toFixed(1) },
    { key: 'csat_score', header: 'CSAT', render: (r) => Number(r.csat_score).toFixed(2) },
    { key: 'composite_score', header: 'Composite', render: (r) => <span className="font-semibold">{Number(r.composite_score).toFixed(2)}</span> },
    { key: 'letter_grade', header: 'Grade', render: (r) => <GradeBadge grade={r.letter_grade} /> },
  ];

  const distributionCols: Column<any>[] = [
    { key: 'letter_grade', header: 'Grade', render: (r) => <GradeBadge grade={r.letter_grade} /> },
    { key: 'chain_count', header: 'Chains', render: (r) => r.chain_count },
    { key: 'avg_composite', header: 'Avg Composite', render: (r) => Number(r.avg_composite ?? 0).toFixed(2) },
    { key: 'avg_uptime', header: 'Avg Uptime %', render: (r) => `${Number(r.avg_uptime ?? 0).toFixed(2)}%` },
    { key: 'avg_sla', header: 'Avg SLA %', render: (r) => `${Number(r.avg_sla ?? 0).toFixed(2)}%` },
  ];

  const topBottomCols: Column<any>[] = [
    { key: 'bucket', header: 'Bucket', render: (r) => <span className={r.bucket === 'top' ? 'text-green-700' : 'text-red-700'}>{r.bucket === 'top' ? 'Top 5' : 'Bottom 5'}</span> },
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'chain_code', header: 'Code', render: (r) => <code className="text-xs">{r.chain_code}</code> },
    { key: 'composite_score', header: 'Composite', render: (r) => Number(r.composite_score).toFixed(2) },
    { key: 'letter_grade', header: 'Grade', render: (r) => <GradeBadge grade={r.letter_grade} /> },
  ];

  const eventCols: Column<any>[] = [
    { key: 'recorded_at', header: 'When', render: (r) => new Date(r.recorded_at).toLocaleString() },
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'event_type', header: 'Event', render: (r) => r.event_type },
    { key: 'severity', header: 'Severity', render: (r) => <SevBadge sev={r.severity} /> },
    { key: 'metric_name', header: 'Metric', render: (r) => r.metric_name },
    { key: 'metric_value', header: 'Value', render: (r) => (r.metric_value == null ? '—' : Number(r.metric_value).toFixed(2)) },
    { key: 'notes', header: 'Notes', render: (r) => <span className="text-xs text-slate-600">{r.notes ?? ''}</span> },
  ];

  const hotspotCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'chain_code', header: 'Code', render: (r) => <code className="text-xs">{r.chain_code}</code> },
    { key: 'escalation_count', header: 'Escalations', render: (r) => r.escalation_count },
    { key: 'failed_jobs', header: 'Failed Jobs', render: (r) => r.failed_jobs },
    { key: 'total_repair_jobs', header: 'Total Jobs', render: (r) => r.total_repair_jobs },
    { key: 'failure_rate_pct', header: 'Failure %', render: (r) => `${Number(r.failure_rate_pct).toFixed(2)}%` },
    { key: 'letter_grade', header: 'Grade', render: (r) => <GradeBadge grade={r.letter_grade} /> },
  ];

  return (
    <div className="p-6 space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold">Hospital Chain Operational-Excellence Scorecard</h1>
        <p className="text-sm text-slate-600">
          Operational metrics per chain — uptime, SLA, escalations & CSAT graded A–F.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="Chains tracked" value={k.total_chains ?? 0} />
        <Kpi label="Hospitals covered" value={k.total_hospitals ?? 0} />
        <Kpi label="Avg uptime" value={`${Number(k.avg_uptime ?? 0).toFixed(2)}%`} />
        <Kpi label="Avg SLA" value={`${Number(k.avg_sla ?? 0).toFixed(2)}%`} />
        <Kpi label="Avg CSAT" value={Number(k.avg_csat ?? 0).toFixed(2)} />
        <Kpi label="Escalations" value={k.total_escalations ?? 0} />
        <Kpi label="A-grade chains" value={k.a_grade_chains ?? 0} tone="good" />
        <Kpi label="Failing (D/F)" value={k.failing_chains ?? 0} tone="bad" />
      </section>

      <section className="text-xs text-slate-500">
        Coverage: {cov.earliest_period ?? '—'} → {cov.latest_period ?? '—'} ·{' '}
        {cov.scorecards_logged ?? 0} scorecards · {cov.events_logged ?? 0} events
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All chain scorecards</h2>
        <DataTable
          columns={scorecardCols}
          rows={(scorecards as any[]) ?? []}
          rowKey={(r) => r.id}
          emptyMessage="No scorecards logged yet."
        />
      </section>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Grade distribution</h2>
          <DataTable
            columns={distributionCols}
            rows={(distribution as any[]) ?? []}
            rowKey={(r) => r.letter_grade}
            emptyMessage="No grades yet."
          />
        </div>
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Top & bottom performers</h2>
          <DataTable
            columns={topBottomCols}
            rows={(topBottom as any[]) ?? []}
            rowKey={(r) => `${r.bucket}-${r.chain_code}`}
            emptyMessage="No performer ranking yet."
          />
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Escalation hotspots (failure rate &gt;= threshold)</h2>
        <DataTable
          columns={hotspotCols}
          rows={(hotspots as any[]) ?? []}
          rowKey={(r) => r.chain_code}
          emptyMessage="No escalation hotspots."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent metric events</h2>
        <DataTable
          columns={eventCols}
          rows={(events as any[]) ?? []}
          rowKey={(r) => r.id}
          emptyMessage="No events recorded."
        />
      </section>
    </div>
  );
}

function Kpi({ label, value, tone }: { label: string; value: string | number; tone?: 'good' | 'bad' }) {
  const toneCls =
    tone === 'good' ? 'text-green-700' : tone === 'bad' ? 'text-red-700' : 'text-slate-900';
  return (
    <div className="rounded-lg border border-slate-200 p-3">
      <div className="text-xs uppercase tracking-wide text-slate-500">{label}</div>
      <div className={`text-xl font-semibold ${toneCls}`}>{value}</div>
    </div>
  );
}

function GradeBadge({ grade }: { grade: string }) {
  const map: Record<string, string> = {
    A: 'bg-green-100 text-green-800 border-green-300',
    B: 'bg-emerald-100 text-emerald-800 border-emerald-300',
    C: 'bg-yellow-100 text-yellow-800 border-yellow-300',
    D: 'bg-orange-100 text-orange-800 border-orange-300',
    F: 'bg-red-100 text-red-800 border-red-300',
  };
  const cls = map[grade] ?? 'bg-slate-100 text-slate-800 border-slate-300';
  return <span className={`inline-block rounded border px-2 py-0.5 text-xs font-semibold ${cls}`}>{grade}</span>;
}

function SevBadge({ sev }: { sev: string }) {
  const map: Record<string, string> = {
    info: 'bg-slate-100 text-slate-700',
    warn: 'bg-yellow-100 text-yellow-800',
    high: 'bg-orange-100 text-orange-800',
    critical: 'bg-red-100 text-red-800',
  };
  const cls = map[sev] ?? 'bg-slate-100 text-slate-700';
  return <span className={`inline-block rounded px-2 py-0.5 text-xs ${cls}`}>{sev}</span>;
}
