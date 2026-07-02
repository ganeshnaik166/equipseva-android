import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type GapRow = {
  category: string;
  target_count: number;
  current_count: number;
  gap: number;
  criticality: string;
  min_tier: string;
  amc_contracts_count: number;
  open_jobs_count: number;
};

type BreakdownRow = {
  category: string;
  tier: string;
  engineer_count: number;
};

type QueueRow = {
  id: string;
  category: string;
  action_kind: string;
  candidate_email: string | null;
  target_city: string | null;
  status: string;
  priority: number;
  notes: string | null;
  created_at: string;
  closed_at: string | null;
};

export default async function FounderEngineerSkillGapsPage() {
  const sb = await getSupabaseServerClient();

  const overviewRes = await sb.rpc('founder_skill_gap_overview');
  const breakdownRes = await sb.rpc('founder_skill_gap_engineer_breakdown');
  const queueRes = await sb.rpc('founder_skill_gap_queue_list', { p_status: null });

  const overview: GapRow[] = (overviewRes.data as GapRow[]) ?? [];
  const breakdown: BreakdownRow[] = (breakdownRes.data as BreakdownRow[]) ?? [];
  const queue: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const totalGap = overview.reduce((acc, r) => acc + (r.gap ?? 0), 0);
  const criticalGap = overview.filter((r) => r.criticality === 'critical' && r.gap > 0).length;
  const openQueue = queue.filter((q) => q.status === 'open').length;
  const inProgressQueue = queue.filter((q) => q.status === 'in_progress').length;

  const overviewCols: Column<GapRow>[] = [
    { key: 'category', header: 'Category', render: (r) => r.category ?? '—' },
    { key: 'target_count', header: 'Target', render: (r) => String(r.target_count ?? '—') },
    { key: 'current_count', header: 'Current', render: (r) => String(r.current_count ?? 0) },
    {
      key: 'gap',
      header: 'Gap',
      render: (r) => {
        const gap = r.gap ?? 0;
        const color = gap === 0 ? '#16a34a' : gap >= 3 ? '#dc2626' : '#d97706';
        return <span style={{ color, fontWeight: 600 }}>{gap}</span>;
      },
    },
    {
      key: 'criticality',
      header: 'Criticality',
      render: (r) => {
        const c = r.criticality ?? '—';
        const color =
          c === 'critical' ? '#dc2626' : c === 'high' ? '#d97706' : c === 'medium' ? '#0369a1' : '#64748b';
        return <span style={{ color, textTransform: 'uppercase', fontSize: 11, fontWeight: 700 }}>{c}</span>;
      },
    },
    { key: 'min_tier', header: 'Min Tier', render: (r) => r.min_tier ?? '—' },
    { key: 'amc_contracts_count', header: 'Active AMCs', render: (r) => String(r.amc_contracts_count ?? 0) },
    { key: 'open_jobs_count', header: 'Open Jobs', render: (r) => String(r.open_jobs_count ?? 0) },
  ];

  const breakdownCols: Column<BreakdownRow>[] = [
    { key: 'category', header: 'Category', render: (r) => r.category ?? '—' },
    { key: 'tier', header: 'Tier', render: (r) => r.tier ?? '—' },
    { key: 'engineer_count', header: 'Engineers', render: (r) => String(r.engineer_count ?? 0) },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'category', header: 'Category', render: (r) => r.category ?? '—' },
    {
      key: 'action_kind',
      header: 'Action',
      render: (r) => {
        const k = r.action_kind ?? '—';
        const color = k === 'hire' ? '#0369a1' : k === 'train' ? '#7c3aed' : '#64748b';
        return <span style={{ color, fontWeight: 600, textTransform: 'uppercase', fontSize: 11 }}>{k}</span>;
      },
    },
    { key: 'candidate_email', header: 'Candidate', render: (r) => r.candidate_email ?? '—' },
    { key: 'target_city', header: 'City', render: (r) => r.target_city ?? '—' },
    {
      key: 'status',
      header: 'Status',
      render: (r) => {
        const s = r.status ?? '—';
        const color =
          s === 'done' ? '#16a34a' : s === 'in_progress' ? '#d97706' : s === 'cancelled' ? '#64748b' : '#0369a1';
        return <span style={{ color, fontWeight: 600 }}>{s}</span>;
      },
    },
    { key: 'priority', header: 'Priority', render: (r) => String(r.priority ?? '—') },
    {
      key: 'created_at',
      header: 'Created',
      render: (r) => (r.created_at ? new Date(r.created_at).toLocaleDateString('en-IN') : '—'),
    },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
  ];

  const cardStyle: React.CSSProperties = {
    padding: 16,
    border: '1px solid #e5e7eb',
    borderRadius: 8,
    background: '#fff',
  };

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, margin: 0 }}>Engineer Skill Gaps Map</h1>
        <p style={{ color: '#64748b', marginTop: 4 }}>
          Identify skill gaps by equipment category. Founder hiring + training queue.
        </p>
      </header>

      <section
        style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}
      >
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#64748b' }}>Total Engineer Gap</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: totalGap > 0 ? '#dc2626' : '#16a34a' }}>
            {totalGap}
          </div>
        </div>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#64748b' }}>Critical Categories Short</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: criticalGap > 0 ? '#dc2626' : '#16a34a' }}>
            {criticalGap}
          </div>
        </div>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#64748b' }}>Queue Open</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{openQueue}</div>
        </div>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#64748b' }}>Queue In Progress</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: '#d97706' }}>{inProgressQueue}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Gap Overview by Category</h2>
        <DataTable
          columns={overviewCols}
          rows={overview}
          rowKey={(r: any, i: number) => String(r.category ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Engineer Tier Breakdown</h2>
        <DataTable
          columns={breakdownCols}
          rows={breakdown}
          rowKey={(r: any, i: number) => String((r.category ?? '') + ':' + (r.tier ?? '') + ':' + i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Hiring + Training Queue</h2>
        <DataTable
          columns={queueCols}
          rows={queue}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
