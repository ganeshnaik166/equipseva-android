import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ContactRow = {
  id: string;
  contact_name: string;
  contact_role: string;
  organization: string | null;
  relationship_strength: number;
  city: string | null;
  is_active: boolean;
  last_interaction_at: string | null;
  days_since_contact: number | null;
  interaction_count: number;
};

type InteractionRow = {
  id: string;
  contact_id: string;
  contact_name: string;
  contact_role: string;
  interaction_type: string;
  interaction_at: string;
  summary: string;
  value_score: number | null;
  follow_up_needed: boolean;
};

type StaleRow = {
  id: string;
  contact_name: string;
  contact_role: string;
  organization: string | null;
  relationship_strength: number;
  last_interaction_at: string | null;
  days_since_contact: number;
};

type FollowUpRow = {
  id: string;
  contact_id: string;
  contact_name: string;
  contact_role: string;
  summary: string;
  follow_up_by: string;
  days_until: number;
};

type RollupRow = {
  contact_role: string;
  contact_count: number;
  avg_strength: number;
  active_count: number;
  stale_count: number;
};

type InfluencerRow = {
  id: string;
  contact_name: string;
  contact_role: string;
  organization: string | null;
  relationship_strength: number;
  interaction_count: number;
  last_interaction_at: string | null;
};

type TypeDistRow = {
  interaction_type: string;
  total_count: number;
  avg_value_score: number | null;
  last_30_days: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [contactsRes, recentRes, staleRes, followRes, rollupRes, topRes, typeRes] = await Promise.all([
    sb.rpc('list_network_contacts_r2353'),
    sb.rpc('recent_interactions_r2353'),
    sb.rpc('stale_contacts_r2353'),
    sb.rpc('follow_ups_due_r2353'),
    sb.rpc('network_rollup_by_role_r2353'),
    sb.rpc('top_influencers_r2353'),
    sb.rpc('interaction_type_distribution_r2353'),
  ]);

  const contacts: ContactRow[] = (contactsRes.data as ContactRow[] | null) ?? [];
  const recent: InteractionRow[] = (recentRes.data as InteractionRow[] | null) ?? [];
  const stale: StaleRow[] = (staleRes.data as StaleRow[] | null) ?? [];
  const followUps: FollowUpRow[] = (followRes.data as FollowUpRow[] | null) ?? [];
  const rollup: RollupRow[] = (rollupRes.data as RollupRow[] | null) ?? [];
  const top: InfluencerRow[] = (topRes.data as InfluencerRow[] | null) ?? [];
  const typeDist: TypeDistRow[] = (typeRes.data as TypeDistRow[] | null) ?? [];

  const strengthBadge = (n: number) => '★'.repeat(n) + '☆'.repeat(5 - n);

  const contactCols: Column<ContactRow>[] = [
    { key: 'contact_name', header: 'Name', render: (r: any) => r.contact_name },
    { key: 'contact_role', header: 'Role', render: (r: any) => r.contact_role },
    { key: 'organization', header: 'Org', render: (r: any) => r.organization ?? '—' },
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => strengthBadge(r.relationship_strength) },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
    { key: 'interaction_count', header: 'Touches', render: (r: any) => r.interaction_count },
    { key: 'days_since_contact', header: 'Days since', render: (r: any) => r.days_since_contact ?? 'never' },
    { key: 'is_active', header: 'Active', render: (r: any) => (r.is_active ? 'yes' : 'no') },
  ];

  const recentCols: Column<InteractionRow>[] = [
    { key: 'contact_name', header: 'Contact', render: (r: any) => r.contact_name },
    { key: 'contact_role', header: 'Role', render: (r: any) => r.contact_role },
    { key: 'interaction_type', header: 'Type', render: (r: any) => r.interaction_type },
    { key: 'interaction_at', header: 'When', render: (r: any) => new Date(r.interaction_at).toISOString().slice(0, 10) },
    { key: 'summary', header: 'Summary', render: (r: any) => r.summary },
    { key: 'value_score', header: 'Value', render: (r: any) => (r.value_score == null ? '—' : strengthBadge(r.value_score)) },
    { key: 'follow_up_needed', header: 'F/U', render: (r: any) => (r.follow_up_needed ? 'yes' : 'no') },
  ];

  const staleCols: Column<StaleRow>[] = [
    { key: 'contact_name', header: 'Name', render: (r: any) => r.contact_name },
    { key: 'contact_role', header: 'Role', render: (r: any) => r.contact_role },
    { key: 'organization', header: 'Org', render: (r: any) => r.organization ?? '—' },
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => strengthBadge(r.relationship_strength) },
    { key: 'last_interaction_at', header: 'Last touch', render: (r: any) => (r.last_interaction_at ? new Date(r.last_interaction_at).toISOString().slice(0, 10) : 'never') },
    { key: 'days_since_contact', header: 'Days stale', render: (r: any) => r.days_since_contact },
  ];

  const followUpCols: Column<FollowUpRow>[] = [
    { key: 'contact_name', header: 'Contact', render: (r: any) => r.contact_name },
    { key: 'contact_role', header: 'Role', render: (r: any) => r.contact_role },
    { key: 'summary', header: 'Re', render: (r: any) => r.summary },
    { key: 'follow_up_by', header: 'By', render: (r: any) => r.follow_up_by },
    { key: 'days_until', header: 'Days', render: (r: any) => r.days_until },
  ];

  const rollupCols: Column<RollupRow>[] = [
    { key: 'contact_role', header: 'Role', render: (r: any) => r.contact_role },
    { key: 'contact_count', header: 'Total', render: (r: any) => r.contact_count },
    { key: 'avg_strength', header: 'Avg strength', render: (r: any) => r.avg_strength },
    { key: 'active_count', header: 'Active', render: (r: any) => r.active_count },
    { key: 'stale_count', header: 'Stale', render: (r: any) => r.stale_count },
  ];

  const topCols: Column<InfluencerRow>[] = [
    { key: 'contact_name', header: 'Name', render: (r: any) => r.contact_name },
    { key: 'contact_role', header: 'Role', render: (r: any) => r.contact_role },
    { key: 'organization', header: 'Org', render: (r: any) => r.organization ?? '—' },
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => strengthBadge(r.relationship_strength) },
    { key: 'interaction_count', header: 'Touches', render: (r: any) => r.interaction_count },
    { key: 'last_interaction_at', header: 'Last touch', render: (r: any) => (r.last_interaction_at ? new Date(r.last_interaction_at).toISOString().slice(0, 10) : 'never') },
  ];

  const typeCols: Column<TypeDistRow>[] = [
    { key: 'interaction_type', header: 'Type', render: (r: any) => r.interaction_type },
    { key: 'total_count', header: 'Total', render: (r: any) => r.total_count },
    { key: 'avg_value_score', header: 'Avg value', render: (r: any) => r.avg_value_score ?? '—' },
    { key: 'last_30_days', header: 'Last 30d', render: (r: any) => r.last_30_days },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, marginBottom: 4 }}>Founder Personal Network & Influence Graph</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Advisors, mentors, customers, peer founders & press — strength rated 1–5, with last-touch & follow-up tracking.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>Network rollup by role</h2>
        <DataTable rows={rollup} emptyMessage="No contacts yet" rowKey={(r: any) => r.contact_role} columns={rollupCols} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>Top influencers (strength &gt;= 4)</h2>
        <DataTable rows={top} emptyMessage="No high-strength contacts" rowKey={(r: any) => r.id} columns={topCols} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>All contacts</h2>
        <DataTable rows={contacts} emptyMessage="No contacts" rowKey={(r: any) => r.id} columns={contactCols} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>Recent interactions</h2>
        <DataTable rows={recent} emptyMessage="No interactions logged" rowKey={(r: any) => r.id} columns={recentCols} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>Stale relationships (&gt;= 60 days, strength &gt;= 3)</h2>
        <DataTable rows={stale} emptyMessage="All warm contacts touched recently" rowKey={(r: any) => r.id} columns={staleCols} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>Follow-ups due</h2>
        <DataTable rows={followUps} emptyMessage="No follow-ups pending" rowKey={(r: any) => r.id} columns={followUpCols} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>Interaction-type distribution</h2>
        <DataTable rows={typeDist} emptyMessage="No interactions" rowKey={(r: any) => r.interaction_type} columns={typeCols} />
      </section>
    </main>
  );
}
