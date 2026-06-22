import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Contact = {
  id: string;
  contact_name: string;
  contact_organization: string | null;
  contact_role: string | null;
  relationship_strength: string;
  last_interaction_at: string | null;
  next_followup_due_at: string | null;
  status: string;
  created_at: string;
};

type DueFollowup = {
  id: string;
  contact_name: string;
  contact_organization: string | null;
  relationship_strength: string;
  next_followup_due_at: string | null;
  days_overdue: number | null;
};

type RecentInteraction = {
  id: string;
  contact_id: string;
  contact_name: string;
  interaction_type: string;
  taken_at: string;
  by_email: string | null;
};

function fmtDate(s: string | null): string {
  if (!s) return '—';
  try {
    return new Date(s).toLocaleString();
  } catch {
    return s;
  }
}

export default async function FounderNetworkingTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [contactsRes, dueRes, recentRes] = await Promise.all([
    sb.rpc('list_contacts_r1962'),
    sb.rpc('due_followups_r1962'),
    sb.rpc('recent_interactions_r1962'),
  ]);

  const contacts: Contact[] = (contactsRes.data as Contact[] | null) ?? [];
  const due: DueFollowup[] = (dueRes.data as DueFollowup[] | null) ?? [];
  const recent: RecentInteraction[] = (recentRes.data as RecentInteraction[] | null) ?? [];

  const contactCols: Column<Contact>[] = [
    { key: 'contact_name', header: 'Contact', render: (r: any) => r.contact_name ?? '—' },
    { key: 'contact_organization', header: 'Organization', render: (r: any) => r.contact_organization ?? '—' },
    { key: 'contact_role', header: 'Role', render: (r: any) => r.contact_role ?? '—' },
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => r.relationship_strength ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'last_interaction_at', header: 'Last Interaction', render: (r: any) => fmtDate(r.last_interaction_at) },
    { key: 'next_followup_due_at', header: 'Next Follow-up', render: (r: any) => fmtDate(r.next_followup_due_at) },
  ];

  const dueCols: Column<DueFollowup>[] = [
    { key: 'contact_name', header: 'Contact', render: (r: any) => r.contact_name ?? '—' },
    { key: 'contact_organization', header: 'Organization', render: (r: any) => r.contact_organization ?? '—' },
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => r.relationship_strength ?? '—' },
    { key: 'next_followup_due_at', header: 'Due', render: (r: any) => fmtDate(r.next_followup_due_at) },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => (r.days_overdue == null ? '—' : String(r.days_overdue)) },
  ];

  const recentCols: Column<RecentInteraction>[] = [
    { key: 'contact_name', header: 'Contact', render: (r: any) => r.contact_name ?? '—' },
    { key: 'interaction_type', header: 'Type', render: (r: any) => r.interaction_type ?? '—' },
    { key: 'taken_at', header: 'When', render: (r: any) => fmtDate(r.taken_at) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
  ];

  return (
    <main style={{ padding: '1.5rem', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.5rem' }}>
        Founder Networking Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '1.5rem' }}>
        Track contacts, relationship strength, and follow-ups. Relationship strength ladder runs
        cold, warm, strong, very strong, and inner circle.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          Follow-ups Due
        </h2>
        <p style={{ color: '#666', marginBottom: '0.5rem' }}>
          Active contacts past their scheduled follow-up date. Aim to clear all with at least 1 day
          overdue.
        </p>
        <DataTable<DueFollowup>
          rows={due}
          columns={dueCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          Recent Interactions
        </h2>
        <p style={{ color: '#666', marginBottom: '0.5rem' }}>
          Latest 100 log entries across all contacts.
        </p>
        <DataTable<RecentInteraction>
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          All Contacts
        </h2>
        <p style={{ color: '#666', marginBottom: '0.5rem' }}>
          Total of {contacts.length} contacts on record.
        </p>
        <DataTable<Contact>
          rows={contacts}
          columns={contactCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
