import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalOpsExcellenceScorePage() {
  const sb = await getSupabaseServerClient();

  const [scoresRes, actionsRes, topRes, needsRes] = await Promise.all([
    sb.rpc('list_hops_excl_scores_r1775'),
    sb.rpc('list_hops_actions_r1775', { p_score_id: null }),
    sb.rpc('top_excellent_hops_r1775'),
    sb.rpc('needing_improvement_hops_r1775'),
  ]);

  const scores: any[] = Array.isArray(scoresRes.data) ? scoresRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const needs: any[] = Array.isArray(needsRes.data) ? needsRes.data : [];

  const scoreCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id ?? '—' },
    { key: 'composite_score', header: 'Score', render: (r: any) => String(r.composite_score ?? 0) },
    { key: 'uptime_pct', header: 'Uptime %', render: (r: any) => `${Number(r.uptime_pct ?? 0).toFixed(1)}%` },
    { key: 'avg_response_min', header: 'Avg Resp (min)', render: (r: any) => String(r.avg_response_min ?? 0) },
    { key: 'satisfaction_score', header: 'CSAT', render: (r: any) => Number(r.satisfaction_score ?? 0).toFixed(2) },
    { key: 'staff_training_pct', header: 'Training %', render: (r: any) => `${Number(r.staff_training_pct ?? 0).toFixed(1)}%` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '—' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_text', header: 'Action', render: (r: any) => String(r.action_text ?? '—') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'due_date', header: 'Due', render: (r: any) => r.due_date ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'completed_at', header: 'Completed', render: (r: any) => r.completed_at ? new Date(r.completed_at).toLocaleString() : '—' },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '—' },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id ?? '—' },
    { key: 'latest_score', header: 'Latest Score', render: (r: any) => String(r.latest_score ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '—' },
  ];

  const needsCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id ?? '—' },
    { key: 'latest_score', header: 'Latest Score', render: (r: any) => String(r.latest_score ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '—' },
  ];

  const excellentCount = scores.filter((s) => s.status === 'excellent').length;
  const criticalCount = scores.filter((s) => s.status === 'critical').length;
  const avgScore = scores.length
    ? Math.round(scores.reduce((a, s) => a + Number(s.composite_score ?? 0), 0) / scores.length)
    : 0;

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Hospital Operational Excellence Score</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Per-hospital composite score: uptime, response time, satisfaction, staff training. Composite range 0–100.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Excellent (&gt;= 90)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{excellentCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Critical (&lt; 50)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{criticalCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Avg Composite</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{avgScore}</div>
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Recorded Scores</h2>
        <DataTable
          rows={scores}
          columns={scoreCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Excellent Hospitals</h2>
        <DataTable
          rows={top}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Needing Improvement</h2>
        <DataTable
          rows={needs}
          columns={needsCols}
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Action Plans</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
