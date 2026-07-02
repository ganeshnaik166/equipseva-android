import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_topics: number;
  open_topics: number;
  resolved_topics: number;
  escalated_topics: number;
  avg_delta: number;
  avg_bond: number;
};

type TopicRow = {
  id: string;
  cofounder_name: string;
  topic: string;
  founder_position: string;
  cofounder_position: string;
  delta_score: number;
  energy_level: string;
  status: string;
  bond_score: number;
};

type ResolutionRow = {
  id: string;
  topic: string;
  cofounder_name: string;
  resolution_date: string;
  resolution_path: string;
  follow_up_action: string;
  follow_up_due: string;
  follow_up_status: string;
  bond_delta: number;
  outcome: string;
};

type EnergyRow = {
  energy_level: string;
  topic_count: number;
  avg_delta: number;
  avg_bond: number;
};

type BondRow = {
  cofounder_name: string;
  topics_count: number;
  avg_bond: number;
  total_bond_delta: number;
};

type FollowUpRow = {
  topic: string;
  cofounder_name: string;
  follow_up_action: string;
  follow_up_due: string;
  follow_up_status: string;
  days_to_due: number;
};

type OutcomeRow = {
  outcome: string;
  resolution_count: number;
  avg_bond_delta: number;
};

type CriticalRow = {
  cofounder_name: string;
  topic: string;
  delta_score: number;
  bond_score: number;
  status: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    overviewRes,
    topicsRes,
    resolutionsRes,
    energyRes,
    bondRes,
    followUpsRes,
    outcomeRes,
    criticalRes,
  ] = await Promise.all([
    supabase.rpc('r2729_topics_overview'),
    supabase.rpc('r2729_topics_list'),
    supabase.rpc('r2729_resolutions_list'),
    supabase.rpc('r2729_energy_breakdown'),
    supabase.rpc('r2729_cofounder_bond_summary'),
    supabase.rpc('r2729_follow_ups_pending'),
    supabase.rpc('r2729_outcome_breakdown'),
    supabase.rpc('r2729_critical_topics'),
  ]);

  const overview: Overview = (overviewRes.data?.[0] ?? {
    total_topics: 0,
    open_topics: 0,
    resolved_topics: 0,
    escalated_topics: 0,
    avg_delta: 0,
    avg_bond: 0,
  }) as Overview;

  const topics: TopicRow[] = (topicsRes.data ?? []) as TopicRow[];
  const resolutions: ResolutionRow[] = (resolutionsRes.data ?? []) as ResolutionRow[];
  const energy: EnergyRow[] = (energyRes.data ?? []) as EnergyRow[];
  const bonds: BondRow[] = (bondRes.data ?? []) as BondRow[];
  const followUps: FollowUpRow[] = (followUpsRes.data ?? []) as FollowUpRow[];
  const outcomes: OutcomeRow[] = (outcomeRes.data ?? []) as OutcomeRow[];
  const critical: CriticalRow[] = (criticalRes.data ?? []) as CriticalRow[];

  return (
    <main style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Monthly Cofounder Energy Alignment
      </h1>
      <p style={{ color: '#555', marginBottom: '24px' }}>
        Track cofounder topics, position deltas, resolutions, follow-ups &amp; bond scores. Delta &gt;= 60 flags critical.
      </p>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))',
          gap: '12px',
          marginBottom: '32px',
        }}
      >
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#6b7280' }}>Total topics</div>
          <div style={{ fontSize: '22px', fontWeight: 600 }}>{overview.total_topics}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#6b7280' }}>Open</div>
          <div style={{ fontSize: '22px', fontWeight: 600 }}>{overview.open_topics}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#6b7280' }}>Resolved</div>
          <div style={{ fontSize: '22px', fontWeight: 600 }}>{overview.resolved_topics}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#6b7280' }}>Escalated</div>
          <div style={{ fontSize: '22px', fontWeight: 600 }}>{overview.escalated_topics}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#6b7280' }}>Avg delta</div>
          <div style={{ fontSize: '22px', fontWeight: 600 }}>{overview.avg_delta}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#6b7280' }}>Avg bond</div>
          <div style={{ fontSize: '22px', fontWeight: 600 }}>{overview.avg_bond}</div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Critical topics (delta &gt;= 60)</h2>
        <DataTable
          rows={critical}
          columns={[
            { key: 'cofounder_name', header: 'Cofounder', render: (r: CriticalRow) => r.cofounder_name },
            { key: 'topic', header: 'Topic', render: (r: CriticalRow) => r.topic },
            { key: 'delta_score', header: 'Delta', render: (r: CriticalRow) => String(r.delta_score) },
            { key: 'bond_score', header: 'Bond', render: (r: CriticalRow) => String(r.bond_score) },
            { key: 'status', header: 'Status', render: (r: CriticalRow) => r.status },
          ]}
          emptyMessage="No data"
          rowKey={(r: CriticalRow, i: number) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Topics</h2>
        <DataTable
          rows={topics}
          columns={[
            { key: 'cofounder_name', header: 'Cofounder', render: (r: TopicRow) => r.cofounder_name },
            { key: 'topic', header: 'Topic', render: (r: TopicRow) => r.topic },
            { key: 'founder_position', header: 'Founder position', render: (r: TopicRow) => r.founder_position },
            { key: 'cofounder_position', header: 'Cofounder position', render: (r: TopicRow) => r.cofounder_position },
            { key: 'delta_score', header: 'Delta', render: (r: TopicRow) => String(r.delta_score) },
            { key: 'energy_level', header: 'Energy', render: (r: TopicRow) => r.energy_level },
            { key: 'status', header: 'Status', render: (r: TopicRow) => r.status },
            { key: 'bond_score', header: 'Bond', render: (r: TopicRow) => String(r.bond_score) },
          ]}
          emptyMessage="No data"
          rowKey={(r: TopicRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Resolutions</h2>
        <DataTable
          rows={resolutions}
          columns={[
            { key: 'resolution_date', header: 'Date', render: (r: ResolutionRow) => r.resolution_date },
            { key: 'topic', header: 'Topic', render: (r: ResolutionRow) => r.topic },
            { key: 'cofounder_name', header: 'Cofounder', render: (r: ResolutionRow) => r.cofounder_name },
            { key: 'resolution_path', header: 'Resolution', render: (r: ResolutionRow) => r.resolution_path },
            { key: 'follow_up_action', header: 'Follow-up', render: (r: ResolutionRow) => r.follow_up_action },
            { key: 'follow_up_due', header: 'Due', render: (r: ResolutionRow) => r.follow_up_due },
            { key: 'follow_up_status', header: 'F/U status', render: (r: ResolutionRow) => r.follow_up_status },
            { key: 'bond_delta', header: 'Bond delta', render: (r: ResolutionRow) => String(r.bond_delta) },
            { key: 'outcome', header: 'Outcome', render: (r: ResolutionRow) => r.outcome },
          ]}
          emptyMessage="No data"
          rowKey={(r: ResolutionRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Energy level breakdown</h2>
        <DataTable
          rows={energy}
          columns={[
            { key: 'energy_level', header: 'Energy', render: (r: EnergyRow) => r.energy_level },
            { key: 'topic_count', header: 'Topics', render: (r: EnergyRow) => String(r.topic_count) },
            { key: 'avg_delta', header: 'Avg delta', render: (r: EnergyRow) => String(r.avg_delta) },
            { key: 'avg_bond', header: 'Avg bond', render: (r: EnergyRow) => String(r.avg_bond) },
          ]}
          emptyMessage="No data"
          rowKey={(r: EnergyRow, i: number) => String(r.energy_level ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Cofounder bond summary</h2>
        <DataTable
          rows={bonds}
          columns={[
            { key: 'cofounder_name', header: 'Cofounder', render: (r: BondRow) => r.cofounder_name },
            { key: 'topics_count', header: 'Topics', render: (r: BondRow) => String(r.topics_count) },
            { key: 'avg_bond', header: 'Avg bond', render: (r: BondRow) => String(r.avg_bond) },
            { key: 'total_bond_delta', header: 'Total bond delta', render: (r: BondRow) => String(r.total_bond_delta) },
          ]}
          emptyMessage="No data"
          rowKey={(r: BondRow, i: number) => String(r.cofounder_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Pending follow-ups</h2>
        <DataTable
          rows={followUps}
          columns={[
            { key: 'topic', header: 'Topic', render: (r: FollowUpRow) => r.topic },
            { key: 'cofounder_name', header: 'Cofounder', render: (r: FollowUpRow) => r.cofounder_name },
            { key: 'follow_up_action', header: 'Action', render: (r: FollowUpRow) => r.follow_up_action },
            { key: 'follow_up_due', header: 'Due', render: (r: FollowUpRow) => r.follow_up_due },
            { key: 'follow_up_status', header: 'Status', render: (r: FollowUpRow) => r.follow_up_status },
            { key: 'days_to_due', header: 'Days to due', render: (r: FollowUpRow) => String(r.days_to_due) },
          ]}
          emptyMessage="No data"
          rowKey={(r: FollowUpRow, i: number) => String(i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Outcome breakdown</h2>
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => r.outcome },
            { key: 'resolution_count', header: 'Count', render: (r: OutcomeRow) => String(r.resolution_count) },
            { key: 'avg_bond_delta', header: 'Avg bond delta', render: (r: OutcomeRow) => String(r.avg_bond_delta) },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeRow, i: number) => String(r.outcome ?? i)}
        />
      </section>
    </main>
  );
}
