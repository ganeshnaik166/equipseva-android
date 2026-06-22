import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ContactRow = {
  id: string;
  hospital_id: string | null;
  hospital_name: string | null;
  contact_name: string | null;
  contact_email: string | null;
  role: string | null;
  decision_power: string | null;
  status: string | null;
  last_contacted_at: string | null;
  created_at: string | null;
};

type TopRow = {
  contact_id: string;
  hospital_id: string | null;
  hospital_name: string | null;
  contact_name: string | null;
  contact_email: string | null;
  role: string | null;
  decision_power: string | null;
  outreach_count: number | null;
  last_contacted_at: string | null;
};

type RecentRow = {
  outreach_id: string;
  contact_id: string | null;
  contact_name: string | null;
  hospital_name: string | null;
  outreach_type: string | null;
  taken_at: string | null;
  by_email: string | null;
};

function fmt(ts: string | null): string {
  if (!ts) return 'never';
  try {
    return new Date(ts).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
  } catch {
    return ts;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [contactsRes, topRes, recentRes] = await Promise.all([
    sb.rpc('r1923_list_contacts', { p_limit: 200 }),
    sb.rpc('r1923_top_decision_makers', { p_limit: 50 }),
    sb.rpc('r1923_recent_outreach', { p_days: 14, p_limit: 100 }),
  ]);

  const contacts: ContactRow[] = (contactsRes.data as ContactRow[]) ?? [];
  const top: TopRow[] = (topRes.data as TopRow[]) ?? [];
  const recent: RecentRow[] = (recentRes.data as RecentRow[]) ?? [];

  const activeCount = contacts.filter((c) => c.status === 'active').length;
  const finalCount = contacts.filter((c) => c.decision_power === 'final').length;
  const recentCount = recent.length;

  const contactCols: Column<ContactRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'contact_name', header: 'Contact', render: (r: any) => r.contact_name ?? '-' },
    { key: 'contact_email', header: 'Email', render: (r: any) => r.contact_email ?? '-' },
    { key: 'role', header: 'Role', render: (r: any) => r.role ?? '-' },
    { key: 'decision_power', header: 'Power', render: (r: any) => r.decision_power ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'last_contacted_at', header: 'Last touch', render: (r: any) => fmt(r.last_contacted_at) },
    { key: 'created_at', header: 'Added', render: (r: any) => fmt(r.created_at) },
  ];

  const topCols: Column<TopRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'contact_name', header: 'Contact', render: (r: any) => r.contact_name ?? '-' },
    { key: 'contact_email', header: 'Email', render: (r: any) => r.contact_email ?? '-' },
    { key: 'role', header: 'Role', render: (r: any) => r.role ?? '-' },
    { key: 'decision_power', header: 'Power', render: (r: any) => r.decision_power ?? '-' },
    { key: 'outreach_count', header: 'Touches', render: (r: any) => String(r.outreach_count ?? 0) },
    { key: 'last_contacted_at', header: 'Last touch', render: (r: any) => fmt(r.last_contacted_at) },
  ];

  const recentCols: Column<RecentRow>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => fmt(r.taken_at) },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'contact_name', header: 'Contact', render: (r: any) => r.contact_name ?? '-' },
    { key: 'outreach_type', header: 'Type', render: (r: any) => r.outreach_type ?? '-' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '-' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>
          Hospital Procurement Contact Map
        </h1>
        <p style={{ color: '#555', fontSize: 14 }}>
          Round 1923 — map of buyer-side decision makers across hospitals plus outreach
          history. Filter by power tier to focus on final approvers and strong recommenders.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase' }}>Active contacts</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{activeCount}</div>
        </div>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase' }}>Final approvers</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{finalCount}</div>
        </div>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase' }}>Touches last 14d</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{recentCount}</div>
        </div>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase' }}>Total mapped</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{contacts.length}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top decision makers</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Active contacts with final or strong recommend power, ranked by touches.
        </p>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.contact_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent outreach (14 days)</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.outreach_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All contacts</h2>
        <DataTable rows={contacts} columns={contactCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
