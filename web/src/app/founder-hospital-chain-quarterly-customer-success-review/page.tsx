import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_chains: number;
  thriving_chains: number;
  at_risk_chains: number;
  critical_chains: number;
  total_arr_rupees: number;
  avg_health_score: number;
  avg_net_retention: number;
  avg_csat: number;
  open_p0_risks: number;
  total_impact_at_risk_rupees: number;
};

type ChainRow = {
  id: string;
  chain_code: string;
  chain_name: string;
  qbr_quarter: string;
  cs_owner: string;
  health_score: number;
  health_tier: string;
  arr_rupees: number;
  net_retention_pct: number;
  uptime_pct: number;
  csat_score: number;
  exec_sponsor: string;
  status: string;
  review_date: string;
  next_review_date: string;
};

type RiskRow = {
  id: string;
  chain_name: string;
  title: string;
  detail: string;
  owner: string;
  priority: string;
  state: string;
  due_date: string | null;
  impact_rupees: number;
};

type MilestoneRow = {
  id: string;
  chain_name: string;
  title: string;
  detail: string;
  target_value: string | null;
  actual_value: string | null;
  owner: string;
  state: string;
  impact_rupees: number;
};

type OutcomeRow = {
  id: string;
  chain_name: string;
  title: string;
  detail: string;
  target_value: string | null;
  actual_value: string | null;
  state: string;
  impact_rupees: number;
};

type ActionRow = {
  id: string;
  chain_name: string;
  title: string;
  detail: string;
  owner: string;
  priority: string;
  state: string;
  due_date: string | null;
};

type TierRollupRow = {
  health_tier: string;
  chain_count: number;
  total_arr_rupees: number;
  avg_health: number;
  avg_csat: number;
};

type UpcomingRow = {
  id: string;
  chain_name: string;
  cs_owner: string;
  exec_sponsor: string;
  health_tier: string;
  next_review_date: string;
  days_until: number;
};

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '-';
  const sign = n < 0 ? '-' : '';
  const abs = Math.abs(n);
  if (abs >= 10000000) return sign + '₹' + (abs / 10000000).toFixed(2) + ' Cr';
  if (abs >= 100000) return sign + '₹' + (abs / 100000).toFixed(2) + ' L';
  return sign + '₹' + abs.toLocaleString('en-IN');
}

function fmtNum(n: number | null | undefined, digits = 2): string {
  if (n == null) return '-';
  return Number(n).toFixed(digits);
}

function tierBadge(tier: string): string {
  switch (tier) {
    case 'thriving': return 'background:#d1fae5;color:#065f46;';
    case 'healthy': return 'background:#dbeafe;color:#1e40af;';
    case 'at_risk': return 'background:#fef3c7;color:#92400e;';
    case 'critical': return 'background:#fee2e2;color:#991b1b;';
    default: return 'background:#e5e7eb;color:#374151;';
  }
}

function priorityBadge(p: string): string {
  switch (p) {
    case 'p0': return 'background:#fee2e2;color:#991b1b;';
    case 'p1': return 'background:#fed7aa;color:#9a3412;';
    case 'p2': return 'background:#fef3c7;color:#92400e;';
    default: return 'background:#e5e7eb;color:#374151;';
  }
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisR, chainsR, risksR, milestonesR, outcomesR, actionsR, tierR, upcomingR] = await Promise.all([
    supabase.rpc('founder_chain_qbr_kpis_r2687'),
    supabase.rpc('founder_chain_qbr_list_r2687'),
    supabase.rpc('founder_chain_qbr_risks_r2687'),
    supabase.rpc('founder_chain_qbr_milestones_r2687'),
    supabase.rpc('founder_chain_qbr_outcomes_r2687'),
    supabase.rpc('founder_chain_qbr_actions_r2687'),
    supabase.rpc('founder_chain_qbr_tier_rollup_r2687'),
    supabase.rpc('founder_chain_qbr_upcoming_r2687'),
  ]);

  const kpis: Kpis | null = (kpisR.data?.[0] ?? null) as Kpis | null;
  const chains: ChainRow[] = (chainsR.data ?? []) as ChainRow[];
  const risks: RiskRow[] = (risksR.data ?? []) as RiskRow[];
  const milestones: MilestoneRow[] = (milestonesR.data ?? []) as MilestoneRow[];
  const outcomes: OutcomeRow[] = (outcomesR.data ?? []) as OutcomeRow[];
  const actions: ActionRow[] = (actionsR.data ?? []) as ActionRow[];
  const tiers: TierRollupRow[] = (tierR.data ?? []) as TierRollupRow[];
  const upcoming: UpcomingRow[] = (upcomingR.data ?? []) as UpcomingRow[];

  return (
    <main style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '4px' }}>
          Hospital Chain Quarterly Customer Success Review
        </h1>
        <p style={{ color: '#6b7280', fontSize: '14px' }}>
          Round r2687 · chain × CS health × outcome metric × success milestone × risk × action
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <KpiCard label="Total Chains" value={String(kpis?.total_chains ?? 0)} />
        <KpiCard label="Thriving" value={String(kpis?.thriving_chains ?? 0)} accent="#10b981" />
        <KpiCard label="At Risk" value={String(kpis?.at_risk_chains ?? 0)} accent="#f59e0b" />
        <KpiCard label="Critical" value={String(kpis?.critical_chains ?? 0)} accent="#ef4444" />
        <KpiCard label="Total ARR" value={fmtRupees(kpis?.total_arr_rupees ?? 0)} />
        <KpiCard label="Avg Health" value={fmtNum(kpis?.avg_health_score, 1)} />
        <KpiCard label="Avg NRR %" value={fmtNum(kpis?.avg_net_retention, 1)} />
        <KpiCard label="Avg CSAT" value={fmtNum(kpis?.avg_csat, 2)} />
        <KpiCard label="Open P0 Risks" value={String(kpis?.open_p0_risks ?? 0)} accent="#dc2626" />
        <KpiCard label="ARR At Risk" value={fmtRupees(kpis?.total_impact_at_risk_rupees ?? 0)} accent="#dc2626" />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Health Tier Rollup</h2>
        <DataTable
          rows={tiers}
          columns={[
            { key: 'health_tier', header: 'Tier', render: (r: TierRollupRow) => (
              <span style={{ padding: '2px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 600 } as React.CSSProperties}>
                <span style={{ padding: '2px 8px', borderRadius: '4px', ...parseStyle(tierBadge(r.health_tier)) }}>{r.health_tier}</span>
              </span>
            ) },
            { key: 'chain_count', header: 'Chains', render: (r: TierRollupRow) => <span>{r.chain_count}</span> },
            { key: 'total_arr_rupees', header: 'ARR', render: (r: TierRollupRow) => <span>{fmtRupees(r.total_arr_rupees)}</span> },
            { key: 'avg_health', header: 'Avg Health', render: (r: TierRollupRow) => <span>{fmtNum(r.avg_health, 1)}</span> },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: TierRollupRow) => <span>{fmtNum(r.avg_csat, 2)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: TierRollupRow, i: number) => String(r.health_tier ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Chain Health Scorecard</h2>
        <DataTable
          rows={chains}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ChainRow) => <strong>{r.chain_name}</strong> },
            { key: 'cs_owner', header: 'CS Owner', render: (r: ChainRow) => <span>{r.cs_owner}</span> },
            { key: 'health_tier', header: 'Tier', render: (r: ChainRow) => (
              <span style={{ padding: '2px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 600, ...parseStyle(tierBadge(r.health_tier)) }}>{r.health_tier}</span>
            ) },
            { key: 'health_score', header: 'Health', render: (r: ChainRow) => <span>{fmtNum(r.health_score, 1)}</span> },
            { key: 'arr_rupees', header: 'ARR', render: (r: ChainRow) => <span>{fmtRupees(r.arr_rupees)}</span> },
            { key: 'net_retention_pct', header: 'NRR %', render: (r: ChainRow) => <span>{fmtNum(r.net_retention_pct, 1)}</span> },
            { key: 'uptime_pct', header: 'Uptime %', render: (r: ChainRow) => <span>{fmtNum(r.uptime_pct, 2)}</span> },
            { key: 'csat_score', header: 'CSAT', render: (r: ChainRow) => <span>{fmtNum(r.csat_score, 2)}</span> },
            { key: 'status', header: 'Status', render: (r: ChainRow) => <span>{r.status}</span> },
            { key: 'next_review_date', header: 'Next Review', render: (r: ChainRow) => <span>{r.next_review_date}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: ChainRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px', color: '#991b1b' }}>Open Risks (P0 / P1 first)</h2>
        <DataTable
          rows={risks}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: RiskRow) => <strong>{r.chain_name}</strong> },
            { key: 'title', header: 'Risk', render: (r: RiskRow) => <span>{r.title}</span> },
            { key: 'priority', header: 'Pri', render: (r: RiskRow) => (
              <span style={{ padding: '2px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 600, ...parseStyle(priorityBadge(r.priority)) }}>{r.priority}</span>
            ) },
            { key: 'owner', header: 'Owner', render: (r: RiskRow) => <span>{r.owner}</span> },
            { key: 'state', header: 'State', render: (r: RiskRow) => <span>{r.state}</span> },
            { key: 'due_date', header: 'Due', render: (r: RiskRow) => <span>{r.due_date ?? '-'}</span> },
            { key: 'impact_rupees', header: 'Impact', render: (r: RiskRow) => <span style={{ color: r.impact_rupees < 0 ? '#dc2626' : '#065f46' }}>{fmtRupees(r.impact_rupees)}</span> },
            { key: 'detail', header: 'Detail', render: (r: RiskRow) => <span style={{ fontSize: '12px', color: '#6b7280' }}>{r.detail}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: RiskRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px', color: '#065f46' }}>Success Milestones</h2>
        <DataTable
          rows={milestones}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: MilestoneRow) => <strong>{r.chain_name}</strong> },
            { key: 'title', header: 'Milestone', render: (r: MilestoneRow) => <span>{r.title}</span> },
            { key: 'target_value', header: 'Target', render: (r: MilestoneRow) => <span>{r.target_value ?? '-'}</span> },
            { key: 'actual_value', header: 'Actual', render: (r: MilestoneRow) => <span>{r.actual_value ?? '-'}</span> },
            { key: 'owner', header: 'Owner', render: (r: MilestoneRow) => <span>{r.owner}</span> },
            { key: 'state', header: 'State', render: (r: MilestoneRow) => <span>{r.state}</span> },
            { key: 'impact_rupees', header: 'Impact', render: (r: MilestoneRow) => <span>{fmtRupees(r.impact_rupees)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: MilestoneRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Outcome Metrics</h2>
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: OutcomeRow) => <strong>{r.chain_name}</strong> },
            { key: 'title', header: 'Metric', render: (r: OutcomeRow) => <span>{r.title}</span> },
            { key: 'target_value', header: 'Target', render: (r: OutcomeRow) => <span>{r.target_value ?? '-'}</span> },
            { key: 'actual_value', header: 'Actual', render: (r: OutcomeRow) => <span>{r.actual_value ?? '-'}</span> },
            { key: 'state', header: 'State', render: (r: OutcomeRow) => <span>{r.state}</span> },
            { key: 'impact_rupees', header: 'Impact', render: (r: OutcomeRow) => <span>{fmtRupees(r.impact_rupees)}</span> },
            { key: 'detail', header: 'Detail', render: (r: OutcomeRow) => <span style={{ fontSize: '12px', color: '#6b7280' }}>{r.detail}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Action Items</h2>
        <DataTable
          rows={actions}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ActionRow) => <strong>{r.chain_name}</strong> },
            { key: 'title', header: 'Action', render: (r: ActionRow) => <span>{r.title}</span> },
            { key: 'priority', header: 'Pri', render: (r: ActionRow) => (
              <span style={{ padding: '2px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 600, ...parseStyle(priorityBadge(r.priority)) }}>{r.priority}</span>
            ) },
            { key: 'owner', header: 'Owner', render: (r: ActionRow) => <span>{r.owner}</span> },
            { key: 'state', header: 'State', render: (r: ActionRow) => <span>{r.state}</span> },
            { key: 'due_date', header: 'Due', render: (r: ActionRow) => <span>{r.due_date ?? '-'}</span> },
            { key: 'detail', header: 'Detail', render: (r: ActionRow) => <span style={{ fontSize: '12px', color: '#6b7280' }}>{r.detail}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: ActionRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Upcoming Reviews</h2>
        <DataTable
          rows={upcoming}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: UpcomingRow) => <strong>{r.chain_name}</strong> },
            { key: 'cs_owner', header: 'CS Owner', render: (r: UpcomingRow) => <span>{r.cs_owner}</span> },
            { key: 'exec_sponsor', header: 'Exec Sponsor', render: (r: UpcomingRow) => <span>{r.exec_sponsor}</span> },
            { key: 'health_tier', header: 'Tier', render: (r: UpcomingRow) => (
              <span style={{ padding: '2px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 600, ...parseStyle(tierBadge(r.health_tier)) }}>{r.health_tier}</span>
            ) },
            { key: 'next_review_date', header: 'Next Review', render: (r: UpcomingRow) => <span>{r.next_review_date}</span> },
            { key: 'days_until', header: 'Days Until', render: (r: UpcomingRow) => <span style={{ color: r.days_until < 14 ? '#dc2626' : '#374151', fontWeight: r.days_until < 14 ? 600 : 400 }}>{r.days_until}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: UpcomingRow, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}

function KpiCard({ label, value, accent }: { label: string; value: string; accent?: string }) {
  return (
    <div style={{ padding: '16px', background: '#fff', border: '1px solid #e5e7eb', borderRadius: '8px', borderLeft: `4px solid ${accent ?? '#3b82f6'}` }}>
      <div style={{ fontSize: '12px', color: '#6b7280', marginBottom: '4px' }}>{label}</div>
      <div style={{ fontSize: '22px', fontWeight: 700, color: accent ?? '#111827' }}>{value}</div>
    </div>
  );
}

function parseStyle(css: string): React.CSSProperties {
  const out: Record<string, string> = {};
  css.split(';').forEach((part) => {
    const [k, v] = part.split(':');
    if (!k || !v) return;
    const key = k.trim().replace(/-([a-z])/g, (_m: string, c: string) => c.toUpperCase());
    out[key] = v.trim();
  });
  return out as React.CSSProperties;
}
