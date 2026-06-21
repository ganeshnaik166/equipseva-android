import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [scoresRes, auditRes, distRes, topRes, recentRes, avgRes] = await Promise.all([
    sb.rpc('list_conviction_scores_r1842'),
    sb.rpc('list_conviction_audit_log_r1842'),
    sb.rpc('conviction_distribution_r1842'),
    sb.rpc('top_conviction_hospitals_r1842'),
    sb.rpc('recent_conviction_changes_r1842'),
    sb.rpc('founder_avg_conviction_r1842'),
  ]);

  const scores: any[] = Array.isArray(scoresRes.data) ? scoresRes.data : [];
  const audit: any[] = Array.isArray(auditRes.data) ? auditRes.data : [];
  const dist: any[] = Array.isArray(distRes.data) ? distRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];
  const avg: any = Array.isArray(avgRes.data) ? avgRes.data[0] : avgRes.data;

  const scoreCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? r.hospital_user_id ?? '—') },
    { key: 'conviction_score', header: 'Score', render: (r: any) => String(r.conviction_score ?? '—') + ' / 10' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'conviction_reason_md', header: 'Reason', render: (r: any) => String(r.conviction_reason_md ?? '—').slice(0, 80) },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleDateString('en-IN') : '—' },
  ];

  const auditCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? r.hospital_user_id ?? '—') },
    { key: 'prior_score', header: 'Prior', render: (r: any) => r.prior_score == null ? '—' : String(r.prior_score) },
    { key: 'new_score', header: 'New', render: (r: any) => String(r.new_score ?? '—') },
    { key: 'change_reason', header: 'Reason', render: (r: any) => String(r.change_reason ?? '—').slice(0, 80) },
    { key: 'changed_at', header: 'Changed', render: (r: any) => r.changed_at ? new Date(r.changed_at).toLocaleDateString('en-IN') : '—' },
  ];

  const distCols: Column<any>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: any) => String(r.bucket ?? '—') },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => Number(r.hospital_count ?? 0).toLocaleString('en-IN') },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? r.hospital_user_id ?? '—') },
    { key: 'conviction_score', header: 'Score', render: (r: any) => String(r.conviction_score ?? '—') + ' / 10' },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleDateString('en-IN') : '—' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '—') },
    { key: 'prior_score', header: 'Prior', render: (r: any) => r.prior_score == null ? '—' : String(r.prior_score) },
    { key: 'new_score', header: 'New', render: (r: any) => String(r.new_score ?? '—') },
    { key: 'delta', header: 'Delta', render: (r: any) => {
      const d = Number(r.delta ?? 0);
      const sign = d > 0 ? '+' : '';
      return sign + String(d);
    } },
    { key: 'change_reason', header: 'Reason', render: (r: any) => String(r.change_reason ?? '—').slice(0, 80) },
    { key: 'changed_at', header: 'Changed', render: (r: any) => r.changed_at ? new Date(r.changed_at).toLocaleDateString('en-IN') : '—' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Founder Customer Conviction Score</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track founder confidence per customer hospital (1-10) over time. Score change history audited.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-3">Conviction Summary</h2>
        <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Avg Conviction</div>
            <div className="text-2xl font-semibold">{avg?.avg_conviction == null ? '—' : Number(avg.avg_conviction).toFixed(2)}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Hospitals Scored</div>
            <div className="text-2xl font-semibold">{Number(avg?.total_hospitals_scored ?? 0).toLocaleString('en-IN')}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Score Events</div>
            <div className="text-2xl font-semibold">{Number(avg?.total_score_events ?? 0).toLocaleString('en-IN')}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">High (≥7)</div>
            <div className="text-2xl font-semibold">{Number(avg?.high_conviction_count ?? 0).toLocaleString('en-IN')}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Low (≤3)</div>
            <div className="text-2xl font-semibold">{Number(avg?.low_conviction_count ?? 0).toLocaleString('en-IN')}</div>
          </div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Conviction Distribution</h2>
        <DataTable
          rows={dist}
          columns={distCols}
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Top Conviction Hospitals</h2>
        <DataTable
          rows={top}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">All Conviction Scores</h2>
        <DataTable
          rows={scores}
          columns={scoreCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Recent Score Changes</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Full Audit Log</h2>
        <DataTable
          rows={audit}
          columns={auditCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
