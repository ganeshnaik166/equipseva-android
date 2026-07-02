import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Contact = {
  id: string;
  contact_name: string;
  relationship_type: string;
  last_touch_at: string | null;
  next_touch_due_at: string | null;
  status: string;
  captured_at: string;
};

type DueTouch = {
  id: string;
  contact_name: string;
  relationship_type: string;
  next_touch_due_at: string | null;
  days_overdue: number;
  status: string;
};

type RecentTouch = {
  id: string;
  contact_id: string;
  contact_name: string;
  touch_type: string;
  taken_at: string;
  by_email: string | null;
};

function fmtDate(s: string | null): string {
  if (!s) return 'never';
  try {
    return new Date(s).toLocaleString();
  } catch {
    return s;
  }
}

export default async function FounderPersonalCrmPage() {
  const sb = await getSupabaseServerClient();

  const [contactsRes, dueRes, recentRes] = await Promise.all([
    sb.rpc('list_contacts_r2114'),
    sb.rpc('due_touches_r2114'),
    sb.rpc('recent_touches_r2114'),
  ]);

  const contacts: Contact[] = (contactsRes.data as Contact[]) ?? [];
  const due: DueTouch[] = (dueRes.data as DueTouch[]) ?? [];
  const recent: RecentTouch[] = (recentRes.data as RecentTouch[]) ?? [];

  const contactCols: Column<Contact>[] = [
    { key: 'contact_name', header: 'Contact', render: (r: any) => r.contact_name },
    { key: 'relationship_type', header: 'Relationship', render: (r: any) => r.relationship_type },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'last_touch_at', header: 'Last Touch', render: (r: any) => fmtDate(r.last_touch_at) },
    { key: 'next_touch_due_at', header: 'Next Due', render: (r: any) => fmtDate(r.next_touch_due_at) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => fmtDate(r.captured_at) },
  ];

  const dueCols: Column<DueTouch>[] = [
    { key: 'contact_name', header: 'Contact', render: (r: any) => r.contact_name },
    { key: 'relationship_type', header: 'Relationship', render: (r: any) => r.relationship_type },
    { key: 'next_touch_due_at', header: 'Due At', render: (r: any) => fmtDate(r.next_touch_due_at) },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => String(r.days_overdue ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const recentCols: Column<RecentTouch>[] = [
    { key: 'contact_name', header: 'Contact', render: (r: any) => r.contact_name },
    { key: 'touch_type', header: 'Touch Type', render: (r: any) => r.touch_type },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => fmtDate(r.taken_at) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? 'unknown' },
  ];

  const activeCount = contacts.filter((c) => c.status === 'active').length;
  const dormantCount = contacts.filter((c) => c.status === 'dormant').length;
  const lostCount = contacts.filter((c) => c.status === 'lost').length;

  return (
    <div style={{ padding: '24px', maxWidth: '1200px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Founder Personal CRM
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Track relationships you cultivate: mentors, peer founders, investors, customer champions, friendly competitors, journalists, and family.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Snapshot</h2>
        <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
          <div style={{ padding: '12px 20px', background: '#f5f5f5', borderRadius: '8px', minWidth: '140px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Total contacts</div>
            <div style={{ fontSize: '22px', fontWeight: 700 }}>{contacts.length}</div>
          </div>
          <div style={{ padding: '12px 20px', background: '#e8f5e9', borderRadius: '8px', minWidth: '140px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Active</div>
            <div style={{ fontSize: '22px', fontWeight: 700 }}>{activeCount}</div>
          </div>
          <div style={{ padding: '12px 20px', background: '#fff8e1', borderRadius: '8px', minWidth: '140px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Dormant</div>
            <div style={{ fontSize: '22px', fontWeight: 700 }}>{dormantCount}</div>
          </div>
          <div style={{ padding: '12px 20px', background: '#ffebee', borderRadius: '8px', minWidth: '140px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Lost</div>
            <div style={{ fontSize: '22px', fontWeight: 700 }}>{lostCount}</div>
          </div>
          <div style={{ padding: '12px 20px', background: '#ffebee', borderRadius: '8px', minWidth: '140px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Due now</div>
            <div style={{ fontSize: '22px', fontWeight: 700 }}>{due.length}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          Due touches
        </h2>
        <p style={{ color: '#666', fontSize: '14px', marginBottom: '12px' }}>
          Active contacts whose next touch date has passed. Reach out today.
        </p>
        <DataTable rows={due} columns={dueCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All contacts</h2>
        <DataTable rows={contacts} columns={contactCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Recent touches</h2>
        <p style={{ color: '#666', fontSize: '14px', marginBottom: '12px' }}>
          Last 100 logged touches across all contacts.
        </p>
        <DataTable rows={recent} columns={recentCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
