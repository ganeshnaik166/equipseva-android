import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ChainRow = {
  chain_name: string;
  contact_count: number;
  ap_owners: number;
  dispute_owners: number;
  tier1_contacts: number;
  last_interaction_date: string | null;
};

type ContactRow = {
  id: string;
  chain_name: string;
  contact_name: string;
  contact_role: string;
  contact_email: string | null;
  owns_ap: boolean;
  owns_dispute_resolution: boolean;
  escalation_tier: number;
  relationship_strength: string;
  touchpoint_email: string | null;
  last_contacted_at: string | null;
};

type InteractionRow = {
  id: string;
  contact_name: string;
  chain_name: string;
  interaction_type: string;
  interaction_date: string;
  outcome: string;
  amount_resolved_rupees: number | null;
  summary: string | null;
  logged_by_email: string | null;
};

type Summary = {
  total_chains: number;
  total_contacts: number;
  total_ap_owners: number;
  total_dispute_owners: number;
  chains_missing_ap_owner: number;
  chains_missing_dispute_owner: number;
  strong_relationships: number;
  weak_relationships: number;
  recent_interactions_30d: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [chainsRes, contactsRes, interactionsRes, summaryRes] = await Promise.all([
    supabase.rpc('r2335_list_chains'),
    supabase.rpc('r2335_list_contacts', { p_chain: null }),
    supabase.rpc('r2335_list_interactions', { p_contact_id: null, p_limit: 50 }),
    supabase.rpc('r2335_summary'),
  ]);

  const chains: ChainRow[] = (chainsRes.data ?? []) as ChainRow[];
  const contacts: ContactRow[] = (contactsRes.data ?? []) as ContactRow[];
  const interactions: InteractionRow[] = (interactionsRes.data ?? []) as InteractionRow[];
  const summary: Summary | null = (summaryRes.data?.[0] ?? null) as Summary | null;

  const chainCols: Column<ChainRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'contact_count', header: 'Contacts', render: (r) => String(r.contact_count) },
    { key: 'ap_owners', header: 'AP Owners', render: (r) => String(r.ap_owners) },
    { key: 'dispute_owners', header: 'Dispute Owners', render: (r) => String(r.dispute_owners) },
    { key: 'tier1_contacts', header: 'Tier-1', render: (r) => String(r.tier1_contacts) },
    { key: 'last_interaction_date', header: 'Last Touch', render: (r) => r.last_interaction_date ?? '—' },
  ];

  const contactCols: Column<ContactRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'contact_name', header: 'Name', render: (r) => r.contact_name },
    { key: 'contact_role', header: 'Role', render: (r) => r.contact_role },
    { key: 'contact_email', header: 'Email', render: (r) => r.contact_email ?? '—' },
    { key: 'owns_ap', header: 'AP', render: (r) => (r.owns_ap ? 'yes' : '—') },
    { key: 'owns_dispute_resolution', header: 'Dispute', render: (r) => (r.owns_dispute_resolution ? 'yes' : '—') },
    { key: 'escalation_tier', header: 'Tier', render: (r) => `T${r.escalation_tier}` },
    { key: 'relationship_strength', header: 'Strength', render: (r) => r.relationship_strength },
    { key: 'touchpoint_email', header: 'Our Touchpoint', render: (r) => r.touchpoint_email ?? '—' },
  ];

  const interactionCols: Column<InteractionRow>[] = [
    { key: 'interaction_date', header: 'Date', render: (r) => r.interaction_date },
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'contact_name', header: 'Contact', render: (r) => r.contact_name },
    { key: 'interaction_type', header: 'Type', render: (r) => r.interaction_type },
    { key: 'outcome', header: 'Outcome', render: (r) => r.outcome },
    { key: 'amount_resolved_rupees', header: 'Resolved (Rs)', render: (r) => (r.amount_resolved_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'summary', header: 'Summary', render: (r) => r.summary ?? '—' },
    { key: 'logged_by_email', header: 'Logged By', render: (r) => r.logged_by_email ?? '—' },
  ];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Finance Relationship Map</h1>
        <p className="text-sm text-gray-600 mt-1">
          Per-chain view of who in finance owns AP & dispute resolution, our internal touchpoint, and escalation tier. Strong relationships unlock faster collections & cleaner dispute exits.
        </p>
      </header>

      {summary && (
        <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Chains</div>
            <div className="text-xl font-semibold">{summary.total_chains}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Contacts</div>
            <div className="text-xl font-semibold">{summary.total_contacts}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Missing AP Owner</div>
            <div className="text-xl font-semibold text-red-600">{summary.chains_missing_ap_owner}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Missing Dispute Owner</div>
            <div className="text-xl font-semibold text-red-600">{summary.chains_missing_dispute_owner}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">30d Interactions</div>
            <div className="text-xl font-semibold">{summary.recent_interactions_30d}</div>
          </div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain Roll-up</h2>
        <DataTable
          rows={chains}
          columns={chainCols}
          rowKey={(r) => r.chain_name}
          emptyMessage="No chains tracked yet."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Finance Contacts</h2>
        <DataTable
          rows={contacts}
          columns={contactCols}
          rowKey={(r) => r.id}
          emptyMessage="No contacts logged."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Interactions</h2>
        <DataTable
          rows={interactions}
          columns={interactionCols}
          rowKey={(r) => r.id}
          emptyMessage="No interactions logged in last 50."
        />
      </section>
    </div>
  );
}
