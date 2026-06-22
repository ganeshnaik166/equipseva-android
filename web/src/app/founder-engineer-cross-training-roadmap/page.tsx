import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerCrossTrainingRoadmapPage() {
  const sb = await getSupabaseServerClient();

  const [roadmapsRes, blockedRes, recentRes] = await Promise.all([
    sb.rpc('list_roadmaps_r1912'),
    sb.rpc('engineers_blocked_r1912'),
    sb.rpc('recent_milestones_r1912'),
  ]);

  const roadmaps: any[] = Array.isArray(roadmapsRes.data) ? roadmapsRes.data : [];
  const blocked: any[] = Array.isArray(blockedRes.data) ? blockedRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const totalRoadmaps = roadmaps.length;
  const inProgress = roadmaps.filter((r) => r.status === 'in_progress').length;
  const completed = roadmaps.filter((r) => r.status === 'completed').length;
  const blockedCount = roadmaps.filter((r) => r.status === 'blocked').length;

  const roadmapColumns: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => <span>{r.engineer_email ?? r.engineer_user_id ?? '—'}</span> },
    { key: 'target_skill', header: 'Target Skill', render: (r: any) => <span>{r.target_skill ?? '—'}</span> },
    { key: 'baseline_level', header: 'Baseline', render: (r: any) => <span>{r.baseline_level ?? '—'}</span> },
    { key: 'current_level', header: 'Current', render: (r: any) => <span>{r.current_level ?? '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status ?? '—'}</span> },
    { key: 'target_completion_date', header: 'Target Date', render: (r: any) => <span>{r.target_completion_date ?? '—'}</span> },
    { key: 'started_at', header: 'Started', render: (r: any) => <span>{r.started_at ? new Date(r.started_at).toLocaleDateString() : '—'}</span> },
    { key: 'created_at', header: 'Created', render: (r: any) => <span>{r.created_at ? new Date(r.created_at).toLocaleDateString() : '—'}</span> },
  ];

  const blockedColumns: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => <span>{r.engineer_email ?? r.engineer_user_id ?? '—'}</span> },
    { key: 'blocked_count', header: 'Blocked', render: (r: any) => <span>{r.blocked_count ?? 0}</span> },
    { key: 'in_progress_count', header: 'In Progress', render: (r: any) => <span>{r.in_progress_count ?? 0}</span> },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => <span>{r.engineer_email ?? '—'}</span> },
    { key: 'target_skill', header: 'Skill', render: (r: any) => <span>{r.target_skill ?? '—'}</span> },
    { key: 'milestone_type', header: 'Type', render: (r: any) => <span>{r.milestone_type ?? '—'}</span> },
    { key: 'score', header: 'Score', render: (r: any) => <span>{r.score ?? '—'}</span> },
    { key: 'by_email', header: 'Logged By', render: (r: any) => <span>{r.by_email ?? '—'}</span> },
    { key: 'milestone_at', header: 'When', render: (r: any) => <span>{r.milestone_at ? new Date(r.milestone_at).toLocaleString() : '—'}</span> },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>Engineer Cross-Training Roadmap</h1>
        <p style={{ color: '#6b7280', fontSize: '14px' }}>
          Track cross-training progress per engineer and skill. Plan upskilling, log milestones, and flag blocked learners.
        </p>
      </header>

      <section style={{ marginBottom: '32px' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px' }}>
          <StatCard label="Total Roadmaps" value={totalRoadmaps} description="All cross-training plans on file" />
          <StatCard label="In Progress" value={inProgress} description="Active learners working through plan" />
          <StatCard label="Completed" value={completed} description="Engineers who hit target level" />
          <StatCard label="Blocked" value={blockedCount} description="Plans flagged as blocked, need intervention" />
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>All Roadmaps</h2>
        <p style={{ color: '#6b7280', fontSize: '13px', marginBottom: '12px' }}>
          Roadmaps sorted by most recently created. Limit of two hundred most recent rows.
        </p>
        <DataTable rows={roadmaps} columns={roadmapColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Engineers With Blocked Roadmaps</h2>
        <p style={{ color: '#6b7280', fontSize: '13px', marginBottom: '12px' }}>
          Engineers who have at least one blocked plan. Sorted by number of blocked plans, highest first.
        </p>
        <DataTable rows={blocked} columns={blockedColumns} rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Recent Milestones</h2>
        <p style={{ color: '#6b7280', fontSize: '13px', marginBottom: '12px' }}>
          Latest milestone events across all roadmaps. Includes assessments, practicals, certifications, and peer reviews.
        </p>
        <DataTable rows={recent} columns={recentColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}

function StatCard({ label, value, description }: { label: string; value: number | string; description: string }) {
  return (
    <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px', background: '#fff' }}>
      <div style={{ fontSize: '12px', color: '#6b7280', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{label}</div>
      <div style={{ fontSize: '28px', fontWeight: 700, marginTop: '4px' }}>{value}</div>
      <div style={{ fontSize: '12px', color: '#6b7280', marginTop: '4px' }}>{description}</div>
    </div>
  );
}
