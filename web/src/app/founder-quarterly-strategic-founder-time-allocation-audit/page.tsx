import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_hours_logged: number;
  total_target_hours: number;
  hours_variance: number;
  avg_energy_score: number;
  avg_outcome_score: number;
  delegatable_hours: number;
  delegatable_percent: number;
  total_blocks: number;
  quarters_covered: number;
};

type PillarRow = {
  strategic_pillar: string;
  total_hours: number;
  target_hours: number;
  variance: number;
  avg_outcome: number;
  block_count: number;
};

type CategoryRow = {
  category: string;
  total_hours: number;
  avg_energy: number;
  avg_outcome: number;
  delegatable_hours: number;
  block_count: number;
};

type QuarterRow = {
  quarter: string;
  total_hours: number;
  target_hours: number;
  variance: number;
  avg_energy: number;
  avg_outcome: number;
  block_count: number;
};

type BlockRow = {
  id: string;
  quarter: string;
  block_date: string;
  category: string;
  strategic_pillar: string;
  hours_spent: number;
  energy_score: number;
  outcome_score: number;
  delegatable: boolean;
  notes: string | null;
};

type SnapshotRow = {
  id: string;
  quarter: string;
  week_starting: string;
  strategic_pillar: string;
  hours_invested: number;
  decisions_made: number;
  decisions_deferred: number;
  outcomes_shipped: number;
  reflection: string | null;
};

type DelegationRow = {
  category: string;
  strategic_pillar: string;
  delegatable_hours: number;
  avg_energy: number;
  avg_outcome: number;
  block_count: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    kpiRes,
    pillarRes,
    categoryRes,
    quarterRes,
    topBlocksRes,
    snapshotsRes,
    delegationRes,
  ] = await Promise.all([
    supabase.rpc('founder_r2913_kpi_summary'),
    supabase.rpc('founder_r2913_time_by_pillar'),
    supabase.rpc('founder_r2913_time_by_category'),
    supabase.rpc('founder_r2913_quarter_rollup'),
    supabase.rpc('founder_r2913_top_blocks'),
    supabase.rpc('founder_r2913_pillar_snapshots'),
    supabase.rpc('founder_r2913_delegation_candidates'),
  ]);

  const kpi: KpiRow | null = (kpiRes.data?.[0] as KpiRow) ?? null;
  const pillars: PillarRow[] = (pillarRes.data as PillarRow[]) ?? [];
  const categories: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const quarters: QuarterRow[] = (quarterRes.data as QuarterRow[]) ?? [];
  const topBlocks: BlockRow[] = (topBlocksRes.data as BlockRow[]) ?? [];
  const snapshots: SnapshotRow[] = (snapshotsRes.data as SnapshotRow[]) ?? [];
  const delegations: DelegationRow[] = (delegationRes.data as DelegationRow[]) ?? [];

  const pillarColumns: Column<PillarRow>[] = [
    { key: 'strategic_pillar', header: 'Pillar', render: (r) => r.strategic_pillar },
    { key: 'total_hours', header: 'Hours', render: (r) => Number(r.total_hours).toFixed(2) },
    { key: 'target_hours', header: 'Target', render: (r) => Number(r.target_hours).toFixed(2) },
    { key: 'variance', header: 'Variance', render: (r) => Number(r.variance).toFixed(2) },
    { key: 'avg_outcome', header: 'Avg Outcome', render: (r) => Number(r.avg_outcome).toFixed(2) },
    { key: 'block_count', header: 'Blocks', render: (r) => String(r.block_count) },
  ];

  const categoryColumns: Column<CategoryRow>[] = [
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'total_hours', header: 'Hours', render: (r) => Number(r.total_hours).toFixed(2) },
    { key: 'avg_energy', header: 'Avg Energy', render: (r) => Number(r.avg_energy).toFixed(2) },
    { key: 'avg_outcome', header: 'Avg Outcome', render: (r) => Number(r.avg_outcome).toFixed(2) },
    { key: 'delegatable_hours', header: 'Delegatable Hrs', render: (r) => Number(r.delegatable_hours).toFixed(2) },
    { key: 'block_count', header: 'Blocks', render: (r) => String(r.block_count) },
  ];

  const quarterColumns: Column<QuarterRow>[] = [
    { key: 'quarter', header: 'Quarter', render: (r) => r.quarter },
    { key: 'total_hours', header: 'Hours', render: (r) => Number(r.total_hours).toFixed(2) },
    { key: 'target_hours', header: 'Target', render: (r) => Number(r.target_hours).toFixed(2) },
    { key: 'variance', header: 'Variance', render: (r) => Number(r.variance).toFixed(2) },
    { key: 'avg_energy', header: 'Avg Energy', render: (r) => Number(r.avg_energy).toFixed(2) },
    { key: 'avg_outcome', header: 'Avg Outcome', render: (r) => Number(r.avg_outcome).toFixed(2) },
    { key: 'block_count', header: 'Blocks', render: (r) => String(r.block_count) },
  ];

  const blockColumns: Column<BlockRow>[] = [
    { key: 'block_date', header: 'Date', render: (r) => r.block_date },
    { key: 'quarter', header: 'Quarter', render: (r) => r.quarter },
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'strategic_pillar', header: 'Pillar', render: (r) => r.strategic_pillar },
    { key: 'hours_spent', header: 'Hours', render: (r) => Number(r.hours_spent).toFixed(2) },
    { key: 'energy_score', header: 'Energy', render: (r) => String(r.energy_score) },
    { key: 'outcome_score', header: 'Outcome', render: (r) => String(r.outcome_score) },
    { key: 'delegatable', header: 'Delegatable', render: (r) => (r.delegatable ? 'yes' : 'no') },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '' },
  ];

  const snapshotColumns: Column<SnapshotRow>[] = [
    { key: 'week_starting', header: 'Week', render: (r) => r.week_starting },
    { key: 'quarter', header: 'Quarter', render: (r) => r.quarter },
    { key: 'strategic_pillar', header: 'Pillar', render: (r) => r.strategic_pillar },
    { key: 'hours_invested', header: 'Hours', render: (r) => Number(r.hours_invested).toFixed(2) },
    { key: 'decisions_made', header: 'Decisions Made', render: (r) => String(r.decisions_made) },
    { key: 'decisions_deferred', header: 'Deferred', render: (r) => String(r.decisions_deferred) },
    { key: 'outcomes_shipped', header: 'Shipped', render: (r) => String(r.outcomes_shipped) },
    { key: 'reflection', header: 'Reflection', render: (r) => r.reflection ?? '' },
  ];

  const delegationColumns: Column<DelegationRow>[] = [
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'strategic_pillar', header: 'Pillar', render: (r) => r.strategic_pillar },
    { key: 'delegatable_hours', header: 'Delegatable Hrs', render: (r) => Number(r.delegatable_hours).toFixed(2) },
    { key: 'avg_energy', header: 'Avg Energy', render: (r) => Number(r.avg_energy).toFixed(2) },
    { key: 'avg_outcome', header: 'Avg Outcome', render: (r) => Number(r.avg_outcome).toFixed(2) },
    { key: 'block_count', header: 'Blocks', render: (r) => String(r.block_count) },
  ];

  const cardStyle: React.CSSProperties = {
    border: '1px solid #e5e7eb',
    borderRadius: 8,
    padding: 16,
    background: '#fff',
    minWidth: 180,
  };

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
          Quarterly Strategic Founder-Time Allocation Audit
        </h1>
        <p style={{ color: '#6b7280' }}>
          Founder console — r2913. Where founder hours go vs where they should go, by quarter, pillar & category.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 32 }}>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Total Hours Logged</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{kpi ? Number(kpi.total_hours_logged).toFixed(2) : '0'}</div>
        </div>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Target Hours</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{kpi ? Number(kpi.total_target_hours).toFixed(2) : '0'}</div>
        </div>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Variance (actual − target)</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{kpi ? Number(kpi.hours_variance).toFixed(2) : '0'}</div>
        </div>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Avg Energy</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{kpi ? Number(kpi.avg_energy_score).toFixed(2) : '0'}</div>
        </div>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Avg Outcome</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{kpi ? Number(kpi.avg_outcome_score).toFixed(2) : '0'}</div>
        </div>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Delegatable Hours</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{kpi ? Number(kpi.delegatable_hours).toFixed(2) : '0'}</div>
        </div>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Delegatable %</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{kpi ? Number(kpi.delegatable_percent).toFixed(2) : '0'}</div>
        </div>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Total Blocks</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{kpi ? kpi.total_blocks : 0}</div>
        </div>
        <div style={cardStyle}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Quarters Covered</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{kpi ? kpi.quarters_covered : 0}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Time by Strategic Pillar</h2>
        <DataTable
          rows={pillars}
          columns={pillarColumns}
          emptyMessage="No pillar data yet"
          rowKey={(r, i) => String(r.strategic_pillar ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Time by Category</h2>
        <DataTable
          rows={categories}
          columns={categoryColumns}
          emptyMessage="No category data yet"
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Quarter Rollup</h2>
        <DataTable
          rows={quarters}
          columns={quarterColumns}
          emptyMessage="No quarter data yet"
          rowKey={(r, i) => String(r.quarter ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Time Blocks (highest hours)</h2>
        <DataTable
          rows={topBlocks}
          columns={blockColumns}
          emptyMessage="No time blocks yet"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Weekly Pillar Snapshots</h2>
        <DataTable
          rows={snapshots}
          columns={snapshotColumns}
          emptyMessage="No snapshots yet"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Delegation Candidates</h2>
        <DataTable
          rows={delegations}
          columns={delegationColumns}
          emptyMessage="No delegation candidates"
          rowKey={(r, i) => `${r.category}-${r.strategic_pillar}-${i}`}
        />
      </section>
    </main>
  );
}
