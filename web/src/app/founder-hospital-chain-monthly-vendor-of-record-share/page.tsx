import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function fmtINR(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  if (n >= 10000000) return `Rs ${(n / 10000000).toFixed(2)} Cr`;
  if (n >= 100000) return `Rs ${(n / 100000).toFixed(2)} L`;
  return `Rs ${n.toLocaleString('en-IN')}`;
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return `${Number(n).toFixed(2)}%`;
}

function fmtSigned(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  const v = Number(n);
  const sign = v > 0 ? '+' : '';
  return `${sign}${v.toFixed(2)}%`;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overview, rows, movement, causes, competitors, atRisk, actions, pipeline] = await Promise.all([
    supabase.rpc('f_r2707_chain_share_overview'),
    supabase.rpc('f_r2707_chain_share_rows'),
    supabase.rpc('f_r2707_share_movement_breakdown'),
    supabase.rpc('f_r2707_cause_breakdown'),
    supabase.rpc('f_r2707_top_competitors'),
    supabase.rpc('f_r2707_at_risk_chains'),
    supabase.rpc('f_r2707_increase_actions'),
    supabase.rpc('f_r2707_action_pipeline_summary'),
  ]);

  const ov = (overview.data ?? [])[0] ?? {
    chains_tracked: 0,
    total_addressable_inr: 0,
    total_our_share_inr: 0,
    weighted_share_pct: 0,
    vor_chains: 0,
    at_risk_chains: 0,
  };

  const shareRows = rows.data ?? [];
  const movementRows = movement.data ?? [];
  const causeRows = causes.data ?? [];
  const competitorRows = competitors.data ?? [];
  const atRiskRows = atRisk.data ?? [];
  const actionRows = actions.data ?? [];
  const pipelineRows = pipeline.data ?? [];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 6 }}>
          Hospital Chain Monthly Vendor-of-Record Share
        </h1>
        <p style={{ color: '#666', fontSize: 14 }}>
          Round r2707 · chain × our share × competitors × movement × cause × action
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        <KpiCard label="Chains tracked" value={String(ov.chains_tracked ?? 0)} />
        <KpiCard label="Total addressable" value={fmtINR(ov.total_addressable_inr)} />
        <KpiCard label="Our share" value={fmtINR(ov.total_our_share_inr)} />
        <KpiCard label="Weighted share" value={fmtPct(ov.weighted_share_pct)} />
        <KpiCard label="VOR chains" value={String(ov.vor_chains ?? 0)} accent="#10b981" />
        <KpiCard label="At-risk chains" value={String(ov.at_risk_chains ?? 0)} accent="#ef4444" />
      </section>

      <Section title="Chain share snapshot">
        <DataTable
          rows={shareRows}
          rowKey={(r: { id?: string }, i: number) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: { chain_name: string }) => r.chain_name },
            { key: 'vor_status', header: 'VOR status', render: (r: { vor_status: string }) => <StatusBadge s={r.vor_status} /> },
            { key: 'our_share_pct', header: 'Our %', render: (r: { our_share_pct: number }) => fmtPct(r.our_share_pct) },
            { key: 'our_share_inr', header: 'Our Rs', render: (r: { our_share_inr: number }) => fmtINR(r.our_share_inr) },
            { key: 'top_competitor', header: 'Top competitor', render: (r: { top_competitor: string; top_competitor_share_pct: number }) => `${r.top_competitor} (${fmtPct(r.top_competitor_share_pct)})` },
            { key: 'share_movement_pct', header: 'Movement', render: (r: { share_movement_pct: number; movement_direction: string }) => <MovementBadge dir={r.movement_direction} val={r.share_movement_pct} /> },
            { key: 'primary_cause', header: 'Primary cause', render: (r: { primary_cause: string }) => r.primary_cause.replace(/_/g, ' ') },
            { key: 'active_units', header: 'Units', render: (r: { active_units: number }) => String(r.active_units) },
            { key: 'monthly_jobs', header: 'Jobs/mo', render: (r: { monthly_jobs: number }) => String(r.monthly_jobs) },
            { key: 'csat_score', header: 'CSAT', render: (r: { csat_score: number | null }) => r.csat_score !== null ? r.csat_score.toFixed(1) : '-' },
          ]}
        />
      </Section>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(380px, 1fr))', gap: 24, marginBottom: 28 }}>
        <Section title="Share movement">
          <DataTable
            rows={movementRows}
            rowKey={(r: { movement_direction?: string }, i: number) => String(r.movement_direction ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'movement_direction', header: 'Direction', render: (r: { movement_direction: string }) => r.movement_direction.toUpperCase() },
              { key: 'chain_count', header: 'Chains', render: (r: { chain_count: number }) => String(r.chain_count) },
              { key: 'total_movement_pct', header: 'Total move', render: (r: { total_movement_pct: number }) => fmtSigned(r.total_movement_pct) },
              { key: 'total_our_share_inr', header: 'Share Rs', render: (r: { total_our_share_inr: number }) => fmtINR(r.total_our_share_inr) },
            ]}
          />
        </Section>

        <Section title="Cause breakdown">
          <DataTable
            rows={causeRows}
            rowKey={(r: { primary_cause?: string }, i: number) => String(r.primary_cause ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'primary_cause', header: 'Cause', render: (r: { primary_cause: string }) => r.primary_cause.replace(/_/g, ' ') },
              { key: 'chain_count', header: 'Chains', render: (r: { chain_count: number }) => String(r.chain_count) },
              { key: 'avg_movement_pct', header: 'Avg move', render: (r: { avg_movement_pct: number }) => fmtSigned(r.avg_movement_pct) },
              { key: 'total_share_impact_inr', header: 'Impact', render: (r: { total_share_impact_inr: number }) => fmtINR(r.total_share_impact_inr) },
            ]}
          />
        </Section>
      </div>

      <Section title="Top competitors landscape">
        <DataTable
          rows={competitorRows}
          rowKey={(r: { top_competitor?: string }, i: number) => String(r.top_competitor ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'top_competitor', header: 'Competitor', render: (r: { top_competitor: string }) => r.top_competitor },
            { key: 'chains_competing_in', header: 'Chains', render: (r: { chains_competing_in: number }) => String(r.chains_competing_in) },
            { key: 'avg_competitor_share_pct', header: 'Avg share', render: (r: { avg_competitor_share_pct: number }) => fmtPct(r.avg_competitor_share_pct) },
            { key: 'total_competitor_value_inr', header: 'Their Rs', render: (r: { total_competitor_value_inr: number }) => fmtINR(r.total_competitor_value_inr) },
          ]}
        />
      </Section>

      <Section title="At-risk chains (downward movement or at-risk VOR)">
        <DataTable
          rows={atRiskRows}
          rowKey={(r: { chain_name?: string }, i: number) => String(r.chain_name ?? i)}
          emptyMessage="No at-risk chains"
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: { chain_name: string }) => r.chain_name },
            { key: 'vor_status', header: 'VOR', render: (r: { vor_status: string }) => <StatusBadge s={r.vor_status} /> },
            { key: 'our_share_pct', header: 'Our %', render: (r: { our_share_pct: number }) => fmtPct(r.our_share_pct) },
            { key: 'share_movement_pct', header: 'Movement', render: (r: { share_movement_pct: number }) => fmtSigned(r.share_movement_pct) },
            { key: 'primary_cause', header: 'Cause', render: (r: { primary_cause: string }) => r.primary_cause.replace(/_/g, ' ') },
            { key: 'top_competitor', header: 'Competitor', render: (r: { top_competitor: string }) => r.top_competitor },
            { key: 'our_share_inr', header: 'At stake', render: (r: { our_share_inr: number }) => fmtINR(r.our_share_inr) },
            { key: 'notes', header: 'Notes', render: (r: { notes: string | null }) => r.notes ?? '-' },
          ]}
        />
      </Section>

      <Section title="Increase-share action pipeline">
        <DataTable
          rows={pipelineRows}
          rowKey={(r: { status?: string }, i: number) => String(r.status ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'status', header: 'Status', render: (r: { status: string }) => r.status },
            { key: 'action_count', header: 'Count', render: (r: { action_count: number }) => String(r.action_count) },
            { key: 'total_target_gain_pct', header: 'Target gain', render: (r: { total_target_gain_pct: number }) => fmtPct(r.total_target_gain_pct) },
            { key: 'total_revenue_lift_inr', header: 'Revenue lift', render: (r: { total_revenue_lift_inr: number }) => fmtINR(r.total_revenue_lift_inr) },
          ]}
        />
      </Section>

      <Section title="Action items to increase share">
        <DataTable
          rows={actionRows}
          rowKey={(r: { id?: string }, i: number) => String(r.id ?? i)}
          emptyMessage="No actions"
          columns={[
            { key: 'priority', header: 'Pri', render: (r: { priority: string }) => <PriorityBadge p={r.priority} /> },
            { key: 'chain_name', header: 'Chain', render: (r: { chain_name: string }) => r.chain_name },
            { key: 'action_title', header: 'Action', render: (r: { action_title: string }) => r.action_title },
            { key: 'action_category', header: 'Type', render: (r: { action_category: string }) => r.action_category.replace(/_/g, ' ') },
            { key: 'target_share_gain_pct', header: 'Target %', render: (r: { target_share_gain_pct: number }) => fmtPct(r.target_share_gain_pct) },
            { key: 'estimated_revenue_lift_inr', header: 'Lift', render: (r: { estimated_revenue_lift_inr: number }) => fmtINR(r.estimated_revenue_lift_inr) },
            { key: 'owner_name', header: 'Owner', render: (r: { owner_name: string }) => r.owner_name },
            { key: 'due_date', header: 'Due', render: (r: { due_date: string }) => r.due_date },
            { key: 'status', header: 'Status', render: (r: { status: string }) => r.status },
            { key: 'blocker_note', header: 'Blocker', render: (r: { blocker_note: string | null }) => r.blocker_note ?? '-' },
          ]}
        />
      </Section>

      <footer style={{ marginTop: 32, paddingTop: 16, borderTop: '1px solid #eee', fontSize: 12, color: '#888' }}>
        Founder-only console · r2707 · data refreshed monthly
      </footer>
    </main>
  );
}

function KpiCard({ label, value, accent }: { label: string; value: string; accent?: string }) {
  return (
    <div style={{ background: '#fff', border: '1px solid #e5e7eb', borderRadius: 8, padding: 14 }}>
      <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: 0.6 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, color: accent ?? '#111', marginTop: 4 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 10, color: '#222' }}>{title}</h2>
      <div style={{ background: '#fff', border: '1px solid #e5e7eb', borderRadius: 8, padding: 4, overflowX: 'auto' }}>
        {children}
      </div>
    </section>
  );
}

function StatusBadge({ s }: { s: string }) {
  const colors: Record<string, string> = {
    vor: '#10b981',
    preferred: '#3b82f6',
    panel: '#6b7280',
    observation: '#f59e0b',
    at_risk: '#ef4444',
    lost: '#991b1b',
  };
  return (
    <span style={{ background: colors[s] ?? '#888', color: 'white', padding: '2px 8px', borderRadius: 4, fontSize: 11, fontWeight: 600 }}>
      {s.toUpperCase()}
    </span>
  );
}

function MovementBadge({ dir, val }: { dir: string; val: number }) {
  const color = dir === 'up' ? '#10b981' : dir === 'down' ? '#ef4444' : '#6b7280';
  const arrow = dir === 'up' ? '↑' : dir === 'down' ? '↓' : '→';
  return (
    <span style={{ color, fontWeight: 600 }}>
      {arrow} {fmtSigned(val)}
    </span>
  );
}

function PriorityBadge({ p }: { p: string }) {
  const colors: Record<string, string> = { p0: '#dc2626', p1: '#f59e0b', p2: '#3b82f6', p3: '#6b7280' };
  return (
    <span style={{ background: colors[p] ?? '#888', color: 'white', padding: '2px 6px', borderRadius: 4, fontSize: 10, fontWeight: 700 }}>
      {p.toUpperCase()}
    </span>
  );
}
