import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type MilestoneRow = {
  id: string;
  engineer_user_id: string;
  milestone_type: string;
  achieved_at: string;
  recognition_status: string;
  status: string;
  notes_md: string | null;
  created_at: string;
};

type PendingRow = {
  id: string;
  engineer_user_id: string;
  milestone_type: string;
  achieved_at: string;
  recognition_status: string;
  notes_md: string | null;
};

type CelebrationRow = {
  id: string;
  milestone_id: string;
  celebration_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

function fmtDate(v: string | null | undefined): string {
  if (!v) return '';
  try {
    return new Date(v).toISOString().slice(0, 16).replace('T', ' ');
  } catch {
    return String(v);
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const milestonesRes = await sb.rpc('list_milestones_r2000');
  const pendingRes = await sb.rpc('pending_recognition_r2000');
  const recentRes = await sb.rpc('recent_celebrations_r2000');

  const milestones = (milestonesRes.data ?? []) as MilestoneRow[];
  const pending = (pendingRes.data ?? []) as PendingRow[];
  const celebrations = (recentRes.data ?? []) as CelebrationRow[];

  const totalCount = milestones.length;
  const pendingCount = pending.length;
  const celebratedCount = milestones.filter((m) => m.recognition_status === 'celebrated').length;
  const promotedCount = milestones.filter((m) => m.recognition_status === 'promoted').length;

  const milestoneCols: Column<MilestoneRow>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span style={{ fontFamily: 'monospace', fontSize: 12 }}>{String(r.engineer_user_id ?? '').slice(0, 8)}</span> },
    { key: 'milestone_type', header: 'Milestone', render: (r: any) => <strong>{String(r.milestone_type ?? '').replace(/_/g, ' ')}</strong> },
    { key: 'achieved_at', header: 'Achieved', render: (r: any) => fmtDate(r.achieved_at) },
    { key: 'recognition_status', header: 'Recognition', render: (r: any) => String(r.recognition_status ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 60) },
  ];

  const pendingCols: Column<PendingRow>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span style={{ fontFamily: 'monospace', fontSize: 12 }}>{String(r.engineer_user_id ?? '').slice(0, 8)}</span> },
    { key: 'milestone_type', header: 'Milestone', render: (r: any) => <strong>{String(r.milestone_type ?? '').replace(/_/g, ' ')}</strong> },
    { key: 'achieved_at', header: 'Achieved', render: (r: any) => fmtDate(r.achieved_at) },
    { key: 'recognition_status', header: 'Status', render: (r: any) => String(r.recognition_status ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  const celebrationCols: Column<CelebrationRow>[] = [
    { key: 'milestone_id', header: 'Milestone', render: (r: any) => <span style={{ fontFamily: 'monospace', fontSize: 12 }}>{String(r.milestone_id ?? '').slice(0, 8)}</span> },
    { key: 'celebration_type', header: 'Celebration', render: (r: any) => <strong>{String(r.celebration_type ?? '').replace(/_/g, ' ')}</strong> },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => fmtDate(r.taken_at) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>Engineer 2000-Milestone Recognition</h1>
        <p style={{ color: '#666', marginTop: 8 }}>
          Round r2000 milestone tracker. Recognize engineers who hit founder thresholds and celebrate properly.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, background: '#f5f5f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total milestones</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalCount}</div>
        </div>
        <div style={{ padding: 16, background: '#fff7ed', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Pending recognition</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{pendingCount}</div>
        </div>
        <div style={{ padding: 16, background: '#ecfdf5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Celebrated</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{celebratedCount}</div>
        </div>
        <div style={{ padding: 16, background: '#eff6ff', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Promoted</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{promotedCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Pending Recognition</h2>
        <p style={{ color: '#666', marginBottom: 12 }}>
          Engineers awaiting founder acknowledgement. Tackle oldest first.
        </p>
        <DataTable
          rows={pending}
          columns={pendingCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Milestones</h2>
        <p style={{ color: '#666', marginBottom: 12 }}>
          Full milestone roster. Most recent on top.
        </p>
        <DataTable
          rows={milestones}
          columns={milestoneCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Celebrations</h2>
        <p style={{ color: '#666', marginBottom: 12 }}>
          Latest celebration actions: announcements, bonuses, promotions, founder visits.
        </p>
        <DataTable
          rows={celebrations}
          columns={celebrationCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
