import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalEngineerMatchQualityPage() {
  const sb = await getSupabaseServerClient();

  const [matchesRes, actionsRes, topRes, recentRes] = await Promise.all([
    sb.rpc('list_matches_r1975'),
    sb.rpc('list_actions_r1975'),
    sb.rpc('top_matches_r1975'),
    sb.rpc('recent_actions_r1975'),
  ]);

  const matches = (matchesRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const topMatches = (topRes.data ?? []) as any[];
  const recentActions = (recentRes.data ?? []) as any[];

  const matchColumns: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'match_score', header: 'Score', render: (r: any) => String(r.match_score ?? '—') },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'total_jobs', header: 'Jobs', render: (r: any) => String(r.total_jobs ?? 0) },
    { key: 'csat_avg', header: 'CSAT Avg', render: (r: any) => r.csat_avg != null ? Number(r.csat_avg).toFixed(2) : '—' },
    { key: 'repeat_request_count', header: 'Repeats', render: (r: any) => String(r.repeat_request_count ?? 0) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleDateString() : '—' },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '—' },
  ];

  const topColumns: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'match_score', header: 'Score', render: (r: any) => String(r.match_score ?? '—') },
    { key: 'total_jobs', header: 'Jobs', render: (r: any) => String(r.total_jobs ?? 0) },
    { key: 'csat_avg', header: 'CSAT Avg', render: (r: any) => r.csat_avg != null ? Number(r.csat_avg).toFixed(2) : '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '—' },
  ];

  const totalMatches = matches.length;
  const excellentCount = matches.filter((m: any) => m.status === 'excellent').length;
  const blockedCount = matches.filter((m: any) => m.status === 'blocked').length;
  const avgScore = totalMatches > 0
    ? Math.round(matches.reduce((s: number, m: any) => s + (m.match_score ?? 0), 0) / totalMatches)
    : 0;

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Hospital Engineer Match Quality Score
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Score hospital and engineer pairings for match quality. Track assignments, locked pairs, and avoid sets.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 16, marginBottom: 32 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Matches</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalMatches}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Excellent</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{excellentCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Blocked</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{blockedCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Avg Score</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{avgScore}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Match Quality Scores</h2>
        <DataTable
          rows={matches}
          columns={matchColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Matches</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Best pairings ranked by match score (excellent and good only).
        </p>
        <DataTable
          rows={topMatches}
          columns={topColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Match Action Log</h2>
        <DataTable
          rows={actions}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable
          rows={recentActions}
          columns={recentColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
