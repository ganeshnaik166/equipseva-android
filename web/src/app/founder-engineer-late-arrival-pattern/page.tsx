import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerLateArrivalPatternPage() {
  const sb = await getSupabaseServerClient();

  const [patternsRes, offendersRes, recentRes] = await Promise.all([
    sb.rpc('list_late_arrival_patterns_r1848'),
    sb.rpc('top_late_arrival_offenders_r1848'),
    sb.rpc('recent_late_arrival_interventions_r1848'),
  ]);

  const patterns: any[] = Array.isArray(patternsRes.data) ? patternsRes.data : [];
  const offenders: any[] = Array.isArray(offendersRes.data) ? offendersRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const patternCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start ?? '—' },
    { key: 'late_count', header: 'Late', render: (r: any) => String(r.late_count ?? 0) },
    { key: 'total_jobs', header: 'Jobs', render: (r: any) => String(r.total_jobs ?? 0) },
    { key: 'late_rate_pct', header: 'Rate %', render: (r: any) => `${r.late_rate_pct ?? 0}%` },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '—' },
  ];

  const offenderCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'total_late', header: 'Total Late', render: (r: any) => String(r.total_late ?? 0) },
    { key: 'total_jobs', header: 'Total Jobs', render: (r: any) => String(r.total_jobs ?? 0) },
    { key: 'avg_late_rate', header: 'Avg Late Rate %', render: (r: any) => `${r.avg_late_rate ?? 0}%` },
    { key: 'months_tracked', header: 'Months', render: (r: any) => String(r.months_tracked ?? 0) },
  ];

  const interventionCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'intervention_type', header: 'Type', render: (r: any) => r.intervention_type ?? '—' },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
  ];

  const watchingCount = patterns.filter((p) => p.status === 'watching' || p.status === 'intervention').length;
  const improvedCount = patterns.filter((p) => p.status === 'improved').length;

  return (
    <main style={{ padding: '24px', maxWidth: '1200px', margin: '0 auto' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '6px' }}>
          Engineer Late Arrival Pattern
        </h1>
        <p style={{ color: '#666', fontSize: '14px' }}>
          Detect chronic late-arrival patterns & track interventions. Late rate &gt; 20% flags watching tier.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '12px', marginBottom: '24px' }}>
        <div style={{ padding: '16px', border: '1px solid #eee', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Tracked patterns</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{patterns.length}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #eee', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Watching / Intervention</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{watchingCount}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #eee', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Improved</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{improvedCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Monthly Patterns</h2>
        <DataTable
          rows={patterns}
          columns={patternCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Top Offenders</h2>
        <DataTable
          rows={offenders}
          columns={offenderCols}
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Recent Interventions</h2>
        <DataTable
          rows={recent}
          columns={interventionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
