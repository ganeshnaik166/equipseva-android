import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalCustomerHealthScorePage() {
  const sb = await getSupabaseServerClient();

  const [scoresRes, atRiskRes, healthyRes] = await Promise.all([
    sb.rpc('list_hospital_health_scores_r1691'),
    sb.rpc('top_at_risk_hospitals_r1691'),
    sb.rpc('healthy_hospitals_r1691'),
  ]);

  const scores = (scoresRes.data ?? []) as any[];
  const atRisk = (atRiskRes.data ?? []) as any[];
  const healthy = (healthyRes.data ?? []) as any[];

  const scoreColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => <span>{r.hospital_name ?? '—'}</span> },
    { key: 'window_start', header: 'Window', render: (r: any) => <span>{r.window_start ?? '—'}</span> },
    { key: 'avg_rating', header: 'Avg Rating', render: (r: any) => <span>{r.avg_rating != null ? Number(r.avg_rating).toFixed(2) : '—'}</span> },
    { key: 'nps_score', header: 'NPS', render: (r: any) => <span>{r.nps_score ?? '—'}</span> },
    { key: 'payment_lag_days', header: 'Pay Lag (d)', render: (r: any) => <span>{r.payment_lag_days ?? '—'}</span> },
    { key: 'open_tickets', header: 'Open Tickets', render: (r: any) => <span>{r.open_tickets ?? '—'}</span> },
    {
      key: 'health_score',
      header: 'Health',
      render: (r: any) => {
        const s = Number(r.health_score ?? 0);
        const tone = s >= 80 ? '#16a34a' : s >= 50 ? '#d97706' : '#dc2626';
        return <span style={{ fontWeight: 600, color: tone }}>{s}</span>;
      },
    },
    { key: 'computed_at', header: 'Computed', render: (r: any) => <span>{r.computed_at ? new Date(r.computed_at).toLocaleString() : '—'}</span> },
  ];

  const atRiskColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => <span>{r.hospital_name ?? '—'}</span> },
    { key: 'health_score', header: 'Health', render: (r: any) => <span style={{ color: '#dc2626', fontWeight: 600 }}>{r.health_score}</span> },
    { key: 'avg_rating', header: 'Rating', render: (r: any) => <span>{r.avg_rating != null ? Number(r.avg_rating).toFixed(2) : '—'}</span> },
    { key: 'payment_lag_days', header: 'Pay Lag (d)', render: (r: any) => <span>{r.payment_lag_days ?? '—'}</span> },
    { key: 'open_tickets', header: 'Tickets', render: (r: any) => <span>{r.open_tickets ?? '—'}</span> },
    { key: 'computed_at', header: 'Computed', render: (r: any) => <span>{r.computed_at ? new Date(r.computed_at).toLocaleString() : '—'}</span> },
  ];

  const healthyColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => <span>{r.hospital_name ?? '—'}</span> },
    { key: 'health_score', header: 'Health', render: (r: any) => <span style={{ color: '#16a34a', fontWeight: 600 }}>{r.health_score}</span> },
    { key: 'avg_rating', header: 'Rating', render: (r: any) => <span>{r.avg_rating != null ? Number(r.avg_rating).toFixed(2) : '—'}</span> },
    { key: 'nps_score', header: 'NPS', render: (r: any) => <span>{r.nps_score ?? '—'}</span> },
    { key: 'computed_at', header: 'Computed', render: (r: any) => <span>{r.computed_at ? new Date(r.computed_at).toLocaleString() : '—'}</span> },
  ];

  const totalScores = scores.length;
  const avgHealth = totalScores > 0
    ? Math.round(scores.reduce((a, r) => a + Number(r.health_score ?? 0), 0) / totalScores)
    : 0;
  const atRiskCount = atRisk.length;
  const healthyCount = healthy.length;

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Hospital Customer Health Score</h1>
        <p style={{ color: '#666', fontSize: 14 }}>
          Per-hospital health composite from rating, NPS, payment lag, and support tickets.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>Total Scores</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalScores}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>Avg Health</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{avgHealth}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #fecaca', borderRadius: 8, background: '#fef2f2' }}>
          <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>At Risk (&lt;50)</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#dc2626' }}>{atRiskCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #bbf7d0', borderRadius: 8, background: '#f0fdf4' }}>
          <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>Healthy (&gt;=80)</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#16a34a' }}>{healthyCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>At-Risk Hospitals (Health &lt; 50)</h2>
        <DataTable
          rows={atRisk}
          columns={atRiskColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Healthy Hospitals (Health &gt;= 80)</h2>
        <DataTable
          rows={healthy}
          columns={healthyColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Recent Scores</h2>
        <DataTable
          rows={scores}
          columns={scoreColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
