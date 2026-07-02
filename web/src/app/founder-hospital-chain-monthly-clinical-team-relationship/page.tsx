import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_relationships: number;
  champions: number;
  at_risk: number;
  avg_score: number;
  overdue_touchpoints: number;
  blocker_asks: number;
  pipeline_rupees: number;
};

type ByChain = {
  chain_name: string;
  contacts: number;
  champions: number;
  at_risk: number;
  avg_score: number;
  pipeline_rupees: number;
};

type ByRole = {
  clinical_role: string;
  contacts: number;
  avg_score: number;
  blockers: number;
};

type Overdue = {
  id: number;
  chain_name: string;
  hospital_unit: string;
  contact_name: string;
  clinical_role: string;
  relationship_strength: string;
  days_overdue: number;
  open_ask: string;
  next_action: string;
  owner_name: string;
};

type Blocker = {
  id: number;
  chain_name: string;
  hospital_unit: string;
  contact_name: string;
  relationship_strength: string;
  relationship_score: number;
  open_ask: string;
  next_action: string;
  owner_name: string;
};

type Champion = {
  chain_name: string;
  hospital_unit: string;
  contact_name: string;
  clinical_role: string;
  relationship_score: number;
  open_ask: string;
  last_touchpoint: string;
  last_touchpoint_at: string;
};

type RecentAction = {
  action_date: string;
  chain_name: string;
  contact_name: string;
  action_type: string;
  action_summary: string;
  outcome: string;
  arr_impact_rupees: number;
  owner_name: string;
};

function rupees(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, byChainRes, byRoleRes, overdueRes, blockersRes, championsRes, actionsRes] = await Promise.all([
    supabase.rpc('founder_hcr_r2695_kpis'),
    supabase.rpc('founder_hcr_r2695_by_chain'),
    supabase.rpc('founder_hcr_r2695_by_role'),
    supabase.rpc('founder_hcr_r2695_overdue'),
    supabase.rpc('founder_hcr_r2695_blockers'),
    supabase.rpc('founder_hcr_r2695_champions'),
    supabase.rpc('founder_hcr_r2695_recent_actions'),
  ]);

  const kpis: Kpis = (kpisRes.data?.[0] as Kpis) ?? {
    total_relationships: 0,
    champions: 0,
    at_risk: 0,
    avg_score: 0,
    overdue_touchpoints: 0,
    blocker_asks: 0,
    pipeline_rupees: 0,
  };
  const byChain: ByChain[] = (byChainRes.data as ByChain[]) ?? [];
  const byRole: ByRole[] = (byRoleRes.data as ByRole[]) ?? [];
  const overdue: Overdue[] = (overdueRes.data as Overdue[]) ?? [];
  const blockers: Blocker[] = (blockersRes.data as Blocker[]) ?? [];
  const champions: Champion[] = (championsRes.data as Champion[]) ?? [];
  const actions: RecentAction[] = (actionsRes.data as RecentAction[]) ?? [];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Hospital Chain Monthly Clinical Team Relationship
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Chain × clinical role × relationship strength × touchpoint × ask × action. Track health of every clinical contact across chains; surface overdue touchpoints, blocker asks, and champions worth doubling down on.
      </p>

      {/* KPI cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <KpiCard label="Total Relationships" value={String(kpis.total_relationships)} />
        <KpiCard label="Champions" value={String(kpis.champions)} accent="#0a7d34" />
        <KpiCard label="At Risk" value={String(kpis.at_risk)} accent="#b91c1c" />
        <KpiCard label="Avg Score" value={String(kpis.avg_score)} />
        <KpiCard label="Overdue Touchpoints" value={String(kpis.overdue_touchpoints)} accent="#b91c1c" />
        <KpiCard label="Blocker Asks" value={String(kpis.blocker_asks)} accent="#b45309" />
        <KpiCard label="Pipeline" value={rupees(kpis.pipeline_rupees)} accent="#0a7d34" />
      </div>

      {/* By chain */}
      <Section title="Relationship Health by Chain" subtitle="Rolled-up score, champion count, at-risk count, and open pipeline per chain.">
        <DataTable
          rows={byChain}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ByChain) => r.chain_name },
            { key: 'contacts', header: 'Contacts', render: (r: ByChain) => r.contacts },
            { key: 'champions', header: 'Champions', render: (r: ByChain) => r.champions },
            { key: 'at_risk', header: 'At Risk', render: (r: ByChain) => r.at_risk },
            { key: 'avg_score', header: 'Avg Score', render: (r: ByChain) => r.avg_score },
            { key: 'pipeline_rupees', header: 'Pipeline', render: (r: ByChain) => rupees(r.pipeline_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByChain, i: number) => String(r.chain_name ?? i)}
        />
      </Section>

      {/* By role */}
      <Section title="Relationship Health by Clinical Role" subtitle="Where coverage is thin or scores lag, allocate more touchpoint capacity.">
        <DataTable
          rows={byRole}
          columns={[
            { key: 'clinical_role', header: 'Role', render: (r: ByRole) => r.clinical_role },
            { key: 'contacts', header: 'Contacts', render: (r: ByRole) => r.contacts },
            { key: 'avg_score', header: 'Avg Score', render: (r: ByRole) => r.avg_score },
            { key: 'blockers', header: 'Blockers', render: (r: ByRole) => r.blockers },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByRole, i: number) => String(r.clinical_role ?? i)}
        />
      </Section>

      {/* Overdue */}
      <Section title="Overdue Touchpoints" subtitle="Next touchpoint date already passed — reach out today.">
        <DataTable
          rows={overdue}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Overdue) => r.chain_name },
            { key: 'hospital_unit', header: 'Unit', render: (r: Overdue) => r.hospital_unit },
            { key: 'contact_name', header: 'Contact', render: (r: Overdue) => r.contact_name },
            { key: 'clinical_role', header: 'Role', render: (r: Overdue) => r.clinical_role },
            { key: 'relationship_strength', header: 'Strength', render: (r: Overdue) => r.relationship_strength },
            { key: 'days_overdue', header: 'Days Overdue', render: (r: Overdue) => r.days_overdue },
            { key: 'open_ask', header: 'Open Ask', render: (r: Overdue) => r.open_ask },
            { key: 'next_action', header: 'Next Action', render: (r: Overdue) => r.next_action },
            { key: 'owner_name', header: 'Owner', render: (r: Overdue) => r.owner_name },
          ]}
          emptyMessage="No overdue touchpoints"
          rowKey={(r: Overdue, i: number) => String(r.id ?? i)}
        />
      </Section>

      {/* Blockers */}
      <Section title="Blocker Asks" subtitle="Urgency = blocker. If unresolved, expect score drift downward.">
        <DataTable
          rows={blockers}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Blocker) => r.chain_name },
            { key: 'hospital_unit', header: 'Unit', render: (r: Blocker) => r.hospital_unit },
            { key: 'contact_name', header: 'Contact', render: (r: Blocker) => r.contact_name },
            { key: 'relationship_strength', header: 'Strength', render: (r: Blocker) => r.relationship_strength },
            { key: 'relationship_score', header: 'Score', render: (r: Blocker) => r.relationship_score },
            { key: 'open_ask', header: 'Open Ask', render: (r: Blocker) => r.open_ask },
            { key: 'next_action', header: 'Next Action', render: (r: Blocker) => r.next_action },
            { key: 'owner_name', header: 'Owner', render: (r: Blocker) => r.owner_name },
          ]}
          emptyMessage="No blocker asks"
          rowKey={(r: Blocker, i: number) => String(r.id ?? i)}
        />
      </Section>

      {/* Champions */}
      <Section title="Champions" subtitle="Score >= 80 and tagged champion. Double down: dinners, referrals, advisory.">
        <DataTable
          rows={champions}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Champion) => r.chain_name },
            { key: 'hospital_unit', header: 'Unit', render: (r: Champion) => r.hospital_unit },
            { key: 'contact_name', header: 'Contact', render: (r: Champion) => r.contact_name },
            { key: 'clinical_role', header: 'Role', render: (r: Champion) => r.clinical_role },
            { key: 'relationship_score', header: 'Score', render: (r: Champion) => r.relationship_score },
            { key: 'open_ask', header: 'Open Ask', render: (r: Champion) => r.open_ask },
            { key: 'last_touchpoint', header: 'Last Touchpoint', render: (r: Champion) => r.last_touchpoint },
            { key: 'last_touchpoint_at', header: 'When', render: (r: Champion) => r.last_touchpoint_at },
          ]}
          emptyMessage="No champions"
          rowKey={(r: Champion, i: number) => String((r.chain_name ?? '') + (r.contact_name ?? '') + i)}
        />
      </Section>

      {/* Recent actions */}
      <Section title="Recent Actions" subtitle="Every touchpoint logged with outcome and ARR impact.">
        <DataTable
          rows={actions}
          columns={[
            { key: 'action_date', header: 'Date', render: (r: RecentAction) => r.action_date },
            { key: 'chain_name', header: 'Chain', render: (r: RecentAction) => r.chain_name },
            { key: 'contact_name', header: 'Contact', render: (r: RecentAction) => r.contact_name },
            { key: 'action_type', header: 'Action', render: (r: RecentAction) => r.action_type },
            { key: 'action_summary', header: 'Summary', render: (r: RecentAction) => r.action_summary },
            { key: 'outcome', header: 'Outcome', render: (r: RecentAction) => r.outcome },
            { key: 'arr_impact_rupees', header: 'ARR Impact', render: (r: RecentAction) => rupees(r.arr_impact_rupees) },
            { key: 'owner_name', header: 'Owner', render: (r: RecentAction) => r.owner_name },
          ]}
          emptyMessage="No recent actions"
          rowKey={(r: RecentAction, i: number) => String((r.action_date ?? '') + (r.chain_name ?? '') + i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value, accent }: { label: string; value: string; accent?: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, color: accent ?? '#111827' }}>{value}</div>
    </div>
  );
}

function Section({ title, subtitle, children }: { title: string; subtitle?: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 4 }}>{title}</h2>
      {subtitle && <p style={{ color: '#6b7280', marginBottom: 12, fontSize: 13 }}>{subtitle}</p>}
      <div style={{ overflowX: 'auto' }}>{children}</div>
    </section>
  );
}