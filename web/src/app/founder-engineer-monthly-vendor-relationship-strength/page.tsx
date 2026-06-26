import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_relationships: number;
  strategic_count: number;
  strong_count: number;
  warm_count: number;
  cold_count: number;
  avg_strength_score: number;
  avg_response_minutes: number;
  avg_on_time_delivery_pct: number;
  total_interactions: number;
  total_orders_fulfilled: number;
};

type Relationship = {
  id: string;
  cycle_month: string;
  engineer_name: string;
  engineer_tier: string;
  vendor_name: string;
  vendor_category: string;
  interactions_count: number;
  orders_placed: number;
  orders_fulfilled: number;
  avg_response_minutes: number;
  median_response_minutes: number;
  on_time_delivery_pct: number;
  strength_score: number;
  relationship_tier: string;
  trend_direction: string;
  recommended_action: string;
  notes: string | null;
};

type Strategic = {
  engineer_name: string;
  vendor_name: string;
  strength_score: number;
  on_time_delivery_pct: number;
  recommended_action: string;
  trend_direction: string;
};

type AtRisk = {
  engineer_name: string;
  vendor_name: string;
  strength_score: number;
  avg_response_minutes: number;
  on_time_delivery_pct: number;
  recommended_action: string;
  notes: string | null;
};

type ByTier = {
  engineer_tier: string;
  relationship_count: number;
  avg_strength: number;
  avg_response_minutes: number;
  avg_on_time_delivery: number;
};

type ByCategory = {
  vendor_category: string;
  relationship_count: number;
  avg_strength: number;
  total_interactions: number;
  total_orders: number;
};

type ActionLog = {
  engineer_name: string;
  vendor_name: string;
  action_type: string;
  taken_by: string;
  taken_at: string;
  outcome: string;
  impact_score_delta: number;
  rupees_value: number;
  notes: string | null;
};

type ResponseLeader = {
  engineer_name: string;
  vendor_name: string;
  avg_response_minutes: number;
  median_response_minutes: number;
  interactions_count: number;
  strength_score: number;
};

function fmtRupees(n: number): string {
  return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(n);
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, relRes, stratRes, riskRes, tierRes, catRes, logRes, leaderRes] = await Promise.all([
    supabase.rpc('founder_engineer_vendor_strength_kpis_r2802'),
    supabase.rpc('founder_engineer_vendor_relationships_r2802'),
    supabase.rpc('founder_engineer_vendor_strategic_r2802'),
    supabase.rpc('founder_engineer_vendor_at_risk_r2802'),
    supabase.rpc('founder_engineer_vendor_by_tier_r2802'),
    supabase.rpc('founder_engineer_vendor_by_category_r2802'),
    supabase.rpc('founder_engineer_vendor_action_log_r2802'),
    supabase.rpc('founder_engineer_vendor_response_leaders_r2802'),
  ]);

  const k: Kpis | null = kpisRes.data?.[0] ?? null;
  const relationships: Relationship[] = relRes.data ?? [];
  const strategic: Strategic[] = stratRes.data ?? [];
  const atRisk: AtRisk[] = riskRes.data ?? [];
  const byTier: ByTier[] = tierRes.data ?? [];
  const byCategory: ByCategory[] = catRes.data ?? [];
  const actionLog: ActionLog[] = logRes.data ?? [];
  const leaders: ResponseLeader[] = leaderRes.data ?? [];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-3xl font-bold">Engineer Monthly Vendor Relationship Strength</h1>
        <p className="text-gray-600 mt-2">
          Engineer × vendor × interactions × response time × strength & tier action. Round r2802.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <KpiCard label="Total Relationships" value={k?.total_relationships ?? 0} />
        <KpiCard label="Strategic" value={k?.strategic_count ?? 0} />
        <KpiCard label="Strong" value={k?.strong_count ?? 0} />
        <KpiCard label="Warm" value={k?.warm_count ?? 0} />
        <KpiCard label="Cold" value={k?.cold_count ?? 0} />
        <KpiCard label="Avg Strength" value={k?.avg_strength_score ?? 0} suffix=" / 100" />
        <KpiCard label="Avg Response (min)" value={k?.avg_response_minutes ?? 0} />
        <KpiCard label="Avg On-Time %" value={k?.avg_on_time_delivery_pct ?? 0} suffix="%" />
        <KpiCard label="Total Interactions" value={k?.total_interactions ?? 0} />
        <KpiCard label="Orders Fulfilled" value={k?.total_orders_fulfilled ?? 0} />
      </section>

      <Section title="Strategic Engineer-Vendor Pairs" description="Score >= 80, tier marked strategic.">
        <DataTable
          rows={strategic}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Strategic) => <span>{r.engineer_name}</span> },
            { key: 'vendor_name', header: 'Vendor', render: (r: Strategic) => <span>{r.vendor_name}</span> },
            { key: 'strength_score', header: 'Strength', render: (r: Strategic) => <span>{Number(r.strength_score).toFixed(2)}</span> },
            { key: 'on_time_delivery_pct', header: 'On-Time %', render: (r: Strategic) => <span>{Number(r.on_time_delivery_pct).toFixed(1)}%</span> },
            { key: 'trend_direction', header: 'Trend', render: (r: Strategic) => <span>{r.trend_direction}</span> },
            { key: 'recommended_action', header: 'Action', render: (r: Strategic) => <span>{r.recommended_action}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Strategic, i: number) => String(`${r.engineer_name}-${r.vendor_name}-${i}`)}
        />
      </Section>

      <Section title="At-Risk Relationships" description="Cold or warm pairs flagged for rotate or sunset.">
        <DataTable
          rows={atRisk}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: AtRisk) => <span>{r.engineer_name}</span> },
            { key: 'vendor_name', header: 'Vendor', render: (r: AtRisk) => <span>{r.vendor_name}</span> },
            { key: 'strength_score', header: 'Strength', render: (r: AtRisk) => <span>{Number(r.strength_score).toFixed(2)}</span> },
            { key: 'avg_response_minutes', header: 'Avg Resp (min)', render: (r: AtRisk) => <span>{Number(r.avg_response_minutes).toFixed(1)}</span> },
            { key: 'on_time_delivery_pct', header: 'On-Time %', render: (r: AtRisk) => <span>{Number(r.on_time_delivery_pct).toFixed(1)}%</span> },
            { key: 'recommended_action', header: 'Action', render: (r: AtRisk) => <span>{r.recommended_action}</span> },
            { key: 'notes', header: 'Notes', render: (r: AtRisk) => <span>{r.notes ?? '—'}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: AtRisk, i: number) => String(`${r.engineer_name}-${r.vendor_name}-${i}`)}
        />
      </Section>

      <Section title="By Engineer Tier" description="Bronze through platinum rollup.">
        <DataTable
          rows={byTier}
          columns={[
            { key: 'engineer_tier', header: 'Tier', render: (r: ByTier) => <span className="uppercase">{r.engineer_tier}</span> },
            { key: 'relationship_count', header: 'Count', render: (r: ByTier) => <span>{r.relationship_count}</span> },
            { key: 'avg_strength', header: 'Avg Strength', render: (r: ByTier) => <span>{Number(r.avg_strength).toFixed(2)}</span> },
            { key: 'avg_response_minutes', header: 'Avg Resp (min)', render: (r: ByTier) => <span>{Number(r.avg_response_minutes).toFixed(1)}</span> },
            { key: 'avg_on_time_delivery', header: 'Avg On-Time %', render: (r: ByTier) => <span>{Number(r.avg_on_time_delivery).toFixed(1)}%</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByTier, i: number) => String(`${r.engineer_tier}-${i}`)}
        />
      </Section>

      <Section title="By Vendor Category" description="Spare parts, consumables, calibration, tools, logistics.">
        <DataTable
          rows={byCategory}
          columns={[
            { key: 'vendor_category', header: 'Category', render: (r: ByCategory) => <span>{r.vendor_category}</span> },
            { key: 'relationship_count', header: 'Count', render: (r: ByCategory) => <span>{r.relationship_count}</span> },
            { key: 'avg_strength', header: 'Avg Strength', render: (r: ByCategory) => <span>{Number(r.avg_strength).toFixed(2)}</span> },
            { key: 'total_interactions', header: 'Interactions', render: (r: ByCategory) => <span>{r.total_interactions}</span> },
            { key: 'total_orders', header: 'Orders', render: (r: ByCategory) => <span>{r.total_orders}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByCategory, i: number) => String(`${r.vendor_category}-${i}`)}
        />
      </Section>

      <Section title="Response Time Leaders" description="Fastest engineer-vendor interaction pairs.">
        <DataTable
          rows={leaders}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: ResponseLeader) => <span>{r.engineer_name}</span> },
            { key: 'vendor_name', header: 'Vendor', render: (r: ResponseLeader) => <span>{r.vendor_name}</span> },
            { key: 'avg_response_minutes', header: 'Avg (min)', render: (r: ResponseLeader) => <span>{Number(r.avg_response_minutes).toFixed(1)}</span> },
            { key: 'median_response_minutes', header: 'Median (min)', render: (r: ResponseLeader) => <span>{Number(r.median_response_minutes).toFixed(1)}</span> },
            { key: 'interactions_count', header: 'Interactions', render: (r: ResponseLeader) => <span>{r.interactions_count}</span> },
            { key: 'strength_score', header: 'Strength', render: (r: ResponseLeader) => <span>{Number(r.strength_score).toFixed(2)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: ResponseLeader, i: number) => String(`${r.engineer_name}-${r.vendor_name}-${i}`)}
        />
      </Section>

      <Section title="All Relationships" description="Full monthly engineer-vendor matrix.">
        <DataTable
          rows={relationships}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Relationship) => <span>{r.engineer_name} <span className="text-xs text-gray-500">({r.engineer_tier})</span></span> },
            { key: 'vendor_name', header: 'Vendor', render: (r: Relationship) => <span>{r.vendor_name} <span className="text-xs text-gray-500">({r.vendor_category})</span></span> },
            { key: 'interactions_count', header: 'Interactions', render: (r: Relationship) => <span>{r.interactions_count}</span> },
            { key: 'orders_fulfilled', header: 'Fulfilled / Placed', render: (r: Relationship) => <span>{r.orders_fulfilled} / {r.orders_placed}</span> },
            { key: 'avg_response_minutes', header: 'Avg Resp (min)', render: (r: Relationship) => <span>{Number(r.avg_response_minutes).toFixed(1)}</span> },
            { key: 'on_time_delivery_pct', header: 'On-Time %', render: (r: Relationship) => <span>{Number(r.on_time_delivery_pct).toFixed(1)}%</span> },
            { key: 'strength_score', header: 'Strength', render: (r: Relationship) => <span>{Number(r.strength_score).toFixed(2)}</span> },
            { key: 'relationship_tier', header: 'Tier', render: (r: Relationship) => <span>{r.relationship_tier}</span> },
            { key: 'recommended_action', header: 'Action', render: (r: Relationship) => <span>{r.recommended_action}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Relationship, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Action Log" description="History of escalate, deepen, rotate, sunset actions.">
        <DataTable
          rows={actionLog}
          columns={[
            { key: 'taken_at', header: 'When', render: (r: ActionLog) => <span>{new Date(r.taken_at).toLocaleString()}</span> },
            { key: 'engineer_name', header: 'Engineer', render: (r: ActionLog) => <span>{r.engineer_name}</span> },
            { key: 'vendor_name', header: 'Vendor', render: (r: ActionLog) => <span>{r.vendor_name}</span> },
            { key: 'action_type', header: 'Action', render: (r: ActionLog) => <span>{r.action_type}</span> },
            { key: 'taken_by', header: 'By', render: (r: ActionLog) => <span>{r.taken_by}</span> },
            { key: 'outcome', header: 'Outcome', render: (r: ActionLog) => <span>{r.outcome}</span> },
            { key: 'impact_score_delta', header: 'Δ Score', render: (r: ActionLog) => <span>{Number(r.impact_score_delta).toFixed(2)}</span> },
            { key: 'rupees_value', header: 'Value', render: (r: ActionLog) => <span>{fmtRupees(Number(r.rupees_value))}</span> },
            { key: 'notes', header: 'Notes', render: (r: ActionLog) => <span>{r.notes ?? '—'}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: ActionLog, i: number) => String(`${r.engineer_name}-${r.action_type}-${i}`)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value, suffix }: { label: string; value: number | string; suffix?: string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-2 text-2xl font-semibold text-gray-900">
        {value}
        {suffix ? <span className="text-base text-gray-500">{suffix}</span> : null}
      </div>
    </div>
  );
}

function Section({ title, description, children }: { title: string; description?: string; children: React.ReactNode }) {
  return (
    <section className="space-y-3">
      <div>
        <h2 className="text-xl font-semibold">{title}</h2>
        {description ? <p className="text-sm text-gray-600">{description}</p> : null}
      </div>
      <div className="overflow-x-auto">{children}</div>
    </section>
  );
}
