import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderDecisionVelocityPage() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, decisionsRes, outliersRes] = await Promise.all([
    sb.rpc('velocity_summary_r1850'),
    sb.rpc('list_decisions_r1850'),
    sb.rpc('recent_outliers_r1850', { p_limit: 25 }),
  ]);

  const summary = (summaryRes.data && summaryRes.data[0]) || {
    total_decisions: 0,
    pending_count: 0,
    decided_count: 0,
    parked_count: 0,
    escalated_count: 0,
    avg_queue_minutes: 0,
    avg_quality_score: 0,
    reversible_share_pct: 0,
    outlier_count: 0,
  };
  const decisions: any[] = decisionsRes.data || [];
  const outliers: any[] = outliersRes.data || [];

  const decisionColumns: Column<any>[] = [
    { key: 'decision_topic', header: 'Topic', render: (r: any) => <span>{r.decision_topic}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="uppercase text-xs">{r.status}</span> },
    { key: 'asked_at', header: 'Asked', render: (r: any) => <span>{r.asked_at ? new Date(r.asked_at).toLocaleString() : '—'}</span> },
    { key: 'decided_at', header: 'Decided', render: (r: any) => <span>{r.decided_at ? new Date(r.decided_at).toLocaleString() : '—'}</span> },
    { key: 'queue_minutes', header: 'Queue (min)', render: (r: any) => <span>{r.queue_minutes ?? '—'}</span> },
    { key: 'decision_quality_score', header: 'Quality', render: (r: any) => <span>{r.decision_quality_score ? `${r.decision_quality_score}/10` : '—'}</span> },
    { key: 'was_reversible', header: 'Reversible', render: (r: any) => <span>{r.was_reversible ? 'yes' : 'no'}</span> },
  ];

  const outlierColumns: Column<any>[] = [
    { key: 'decision_topic', header: 'Topic', render: (r: any) => <span>{r.decision_topic ?? '—'}</span> },
    { key: 'outlier_type', header: 'Type', render: (r: any) => <span className="uppercase text-xs">{r.outlier_type}</span> },
    { key: 'recorded_at', header: 'When', render: (r: any) => <span>{r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '—'}</span> },
    { key: 'founder_note', header: 'Note', render: (r: any) => <span>{r.founder_note ?? '—'}</span> },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Founder Decision Velocity</h1>
        <p className="text-sm text-gray-600">
          Track how fast decisions move from queue to decision. Lower queue minutes & higher quality scores =
          sharper founder throughput. Reversible calls should move fast; irreversible calls earn the wait.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-3">Velocity Summary</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <Stat label="Total Decisions" value={summary.total_decisions} />
          <Stat label="Pending" value={summary.pending_count} />
          <Stat label="Decided" value={summary.decided_count} />
          <Stat label="Parked" value={summary.parked_count} />
          <Stat label="Escalated" value={summary.escalated_count} />
          <Stat label="Avg Queue (min)" value={summary.avg_queue_minutes ?? 0} />
          <Stat label="Avg Quality" value={summary.avg_quality_score ?? 0} />
          <Stat label="Reversible %" value={`${summary.reversible_share_pct ?? 0}%`} />
        </div>
        <p className="text-xs text-gray-500 mt-2">
          Outliers logged: {summary.outlier_count}. Target: queue &lt; 60 min for reversible, quality &gt; 7/10.
        </p>
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Recent Decisions</h2>
        <DataTable
          rows={decisions}
          columns={decisionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Recent Outliers</h2>
        <p className="text-xs text-gray-500 mb-2">
          Outliers flag decisions that were too slow, too fast, reversed, or later regretted. Use these to tune
          the &gt; 60min threshold and avoid premature commits on irreversible calls.
        </p>
        <DataTable
          rows={outliers}
          columns={outlierColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: any }) {
  return (
    <div className="border rounded-lg p-3">
      <div className="text-xs text-gray-500">{label}</div>
      <div className="text-xl font-semibold">{value ?? 0}</div>
    </div>
  );
}
