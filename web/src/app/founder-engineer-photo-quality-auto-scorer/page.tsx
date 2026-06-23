import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, recentRes, worstRes, kindRes, nudgesRes, nudgeEffRes, trendRes] = await Promise.all([
    supabase.rpc('r2346_summary'),
    supabase.rpc('r2346_recent_scores', { p_limit: 100 }),
    supabase.rpc('r2346_worst_offenders'),
    supabase.rpc('r2346_kind_breakdown'),
    supabase.rpc('r2346_recent_nudges', { p_limit: 50 }),
    supabase.rpc('r2346_nudge_effectiveness'),
    supabase.rpc('r2346_daily_trend'),
  ]);

  const summary = (summaryRes.data ?? [])[0] ?? null;
  const recent = recentRes.data ?? [];
  const worst = worstRes.data ?? [];
  const kinds = kindRes.data ?? [];
  const nudges = nudgesRes.data ?? [];
  const nudgeEff = nudgeEffRes.data ?? [];
  const trend = trendRes.data ?? [];

  const recentCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => r.engineer_email ?? '-' },
    { key: 'photo_kind', header: 'Kind', render: (r) => r.photo_kind },
    { key: 'blur_score', header: 'Blur', render: (r) => r.blur_score },
    { key: 'lighting_score', header: 'Light', render: (r) => r.lighting_score },
    { key: 'coverage_score', header: 'Cover', render: (r) => r.coverage_score },
    { key: 'composite_score', header: 'Composite', render: (r) => r.composite_score },
    { key: 'verdict', header: 'Verdict', render: (r) => r.verdict },
    { key: 'retake_reason', header: 'Reason', render: (r) => r.retake_reason ?? '-' },
    { key: 'scored_at', header: 'Scored', render: (r) => new Date(r.scored_at).toLocaleString() },
  ];

  const worstCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => r.engineer_email ?? '-' },
    { key: 'total_photos', header: 'Photos', render: (r) => r.total_photos },
    { key: 'retake_count', header: 'Retakes', render: (r) => r.retake_count },
    { key: 'retake_rate', header: 'Retake %', render: (r) => `${r.retake_rate ?? 0}%` },
    { key: 'avg_composite', header: 'Avg Composite', render: (r) => r.avg_composite },
  ];

  const kindCols: Column<any>[] = [
    { key: 'photo_kind', header: 'Kind', render: (r) => r.photo_kind },
    { key: 'total', header: 'Total', render: (r) => r.total },
    { key: 'pass_count', header: 'Pass', render: (r) => r.pass_count },
    { key: 'retake_count', header: 'Retakes', render: (r) => r.retake_count },
    { key: 'avg_composite', header: 'Avg Composite', render: (r) => r.avg_composite },
  ];

  const nudgeCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => r.engineer_email ?? '-' },
    { key: 'nudge_channel', header: 'Channel', render: (r) => r.nudge_channel },
    { key: 'nudge_text', header: 'Message', render: (r) => r.nudge_text },
    { key: 'sent_at', header: 'Sent', render: (r) => new Date(r.sent_at).toLocaleString() },
    { key: 'acknowledged_at', header: 'Ack', render: (r) => (r.acknowledged_at ? new Date(r.acknowledged_at).toLocaleString() : '-') },
    { key: 'retake_completed_at', header: 'Retake done', render: (r) => (r.retake_completed_at ? new Date(r.retake_completed_at).toLocaleString() : '-') },
    { key: 'ack_latency_seconds', header: 'Ack secs', render: (r) => r.ack_latency_seconds ?? '-' },
  ];

  const nudgeEffCols: Column<any>[] = [
    { key: 'nudge_channel', header: 'Channel', render: (r) => r.nudge_channel },
    { key: 'sent_count', header: 'Sent', render: (r) => r.sent_count },
    { key: 'ack_count', header: 'Ack', render: (r) => r.ack_count },
    { key: 'retake_count', header: 'Retook', render: (r) => r.retake_count },
    { key: 'ack_rate', header: 'Ack %', render: (r) => `${r.ack_rate ?? 0}%` },
    { key: 'retake_rate', header: 'Retake %', render: (r) => `${r.retake_rate ?? 0}%` },
    { key: 'avg_ack_seconds', header: 'Avg ack secs', render: (r) => r.avg_ack_seconds ?? '-' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'day', header: 'Day', render: (r) => r.day },
    { key: 'total', header: 'Total', render: (r) => r.total },
    { key: 'pass_count', header: 'Pass', render: (r) => r.pass_count },
    { key: 'retake_count', header: 'Retakes', render: (r) => r.retake_count },
    { key: 'avg_composite', header: 'Avg Composite', render: (r) => r.avg_composite },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Photo Quality Auto-Scorer</h1>
        <p className="text-sm text-gray-600 mt-1">
          Photos uploaded by engineers are auto-scored for blur, lighting &amp; coverage. Retake nudges fire when composite &lt; threshold.
        </p>
      </header>

      {summary && (
        <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="p-4 border rounded">
            <div className="text-xs text-gray-500">Total scored (30d)</div>
            <div className="text-2xl font-bold">{summary.total_scored}</div>
          </div>
          <div className="p-4 border rounded">
            <div className="text-xs text-gray-500">Pass</div>
            <div className="text-2xl font-bold text-green-700">{summary.pass_count}</div>
          </div>
          <div className="p-4 border rounded">
            <div className="text-xs text-gray-500">Soft warn</div>
            <div className="text-2xl font-bold text-amber-700">{summary.soft_warn_count}</div>
          </div>
          <div className="p-4 border rounded">
            <div className="text-xs text-gray-500">Retake required</div>
            <div className="text-2xl font-bold text-red-700">{summary.retake_required_count}</div>
          </div>
          <div className="p-4 border rounded">
            <div className="text-xs text-gray-500">Avg composite</div>
            <div className="text-2xl font-bold">{summary.avg_composite ?? '-'}</div>
          </div>
          <div className="p-4 border rounded">
            <div className="text-xs text-gray-500">Avg blur</div>
            <div className="text-2xl font-bold">{summary.avg_blur ?? '-'}</div>
          </div>
          <div className="p-4 border rounded">
            <div className="text-xs text-gray-500">Avg lighting</div>
            <div className="text-2xl font-bold">{summary.avg_lighting ?? '-'}</div>
          </div>
          <div className="p-4 border rounded">
            <div className="text-xs text-gray-500">Avg coverage</div>
            <div className="text-2xl font-bold">{summary.avg_coverage ?? '-'}</div>
          </div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Daily trend (14d)</h2>
        <DataTable
          rows={trend}
          emptyMessage="No trend data."
          rowKey={(r: any) => r.day}
          columns={trendCols}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Worst offenders (retake rate &gt;= threshold)</h2>
        <DataTable
          rows={worst}
          emptyMessage="No offenders."
          rowKey={(r: any) => r.engineer_user_id}
          columns={worstCols}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By photo kind</h2>
        <DataTable
          rows={kinds}
          emptyMessage="No kind breakdown."
          rowKey={(r: any) => r.photo_kind}
          columns={kindCols}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Nudge effectiveness</h2>
        <DataTable
          rows={nudgeEff}
          emptyMessage="No nudges."
          rowKey={(r: any) => r.nudge_channel}
          columns={nudgeEffCols}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent nudges</h2>
        <DataTable
          rows={nudges}
          emptyMessage="No nudges sent."
          rowKey={(r: any) => r.id}
          columns={nudgeCols}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent scored photos</h2>
        <DataTable
          rows={recent}
          emptyMessage="No photos scored."
          rowKey={(r: any) => r.id}
          columns={recentCols}
        />
      </section>
    </div>
  );
}
