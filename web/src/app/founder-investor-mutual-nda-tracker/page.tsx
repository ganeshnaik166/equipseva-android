import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type NdaRow = {
  id: string;
  investor_id: string;
  nda_label: string;
  signed_date: string | null;
  expires_at: string | null;
  status: string;
  captured_at: string;
};

type ExpiringRow = {
  id: string;
  investor_id: string;
  nda_label: string;
  expires_at: string | null;
  status: string;
  days_left: number | null;
};

type ActionRow = {
  id: string;
  nda_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [ndasRes, expiringRes, recentRes] = await Promise.all([
    sb.rpc('list_ndas_r2121'),
    sb.rpc('expiring_soon_r2121', { p_days: 30 }),
    sb.rpc('recent_actions_r2121', { p_limit: 50 }),
  ]);

  const ndas: NdaRow[] = (ndasRes.data as NdaRow[] | null) ?? [];
  const expiring: ExpiringRow[] = (expiringRes.data as ExpiringRow[] | null) ?? [];
  const recent: ActionRow[] = (recentRes.data as ActionRow[] | null) ?? [];

  const ndaColumns: Column<NdaRow>[] = [
    { key: 'nda_label', header: 'Label', render: (r: any) => r.nda_label ?? '—' },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'signed_date', header: 'Signed', render: (r: any) => r.signed_date ?? '—' },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '—' },
  ];

  const expiringColumns: Column<ExpiringRow>[] = [
    { key: 'nda_label', header: 'Label', render: (r: any) => r.nda_label ?? '—' },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ?? '—' },
    { key: 'days_left', header: 'Days left', render: (r: any) => r.days_left ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
  ];

  const actionColumns: Column<ActionRow>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'nda_id', header: 'NDA', render: (r: any) => String(r.nda_id ?? '').slice(0, 8) },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '—' },
  ];

  const activeCount = ndas.filter((n) => n.status === 'active' || n.status === 'extended').length;
  const expiredCount = ndas.filter((n) => n.status === 'expired').length;
  const terminatedCount = ndas.filter((n) => n.status === 'terminated').length;

  return (
    <main style={{ padding: 24, fontFamily: 'ui-sans-serif, system-ui' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700 }}>Investor Mutual NDA Tracker</h1>
      <p style={{ color: '#555', marginTop: 4 }}>
        Track mutual NDAs signed with investors, monitor expirations, and log every action against each agreement.
      </p>

      <section style={{ marginTop: 24, display: 'flex', gap: 12, flexWrap: 'wrap' }}>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8, minWidth: 160 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total NDAs</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{ndas.length}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8, minWidth: 160 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Active or extended</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{activeCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8, minWidth: 160 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Expired</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{expiredCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8, minWidth: 160 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Terminated</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{terminatedCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8, minWidth: 160 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Expiring within 30 days</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{expiring.length}</div>
        </div>
      </section>

      <section style={{ marginTop: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>All NDAs</h2>
        <DataTable
          rows={ndas}
          columns={ndaColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginTop: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Expiring soon (next 30 days)</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          NDAs in active or extended status whose expiry date falls within the next 30 days.
        </p>
        <DataTable
          rows={expiring}
          columns={expiringColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginTop: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent actions</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Most recent NDA action log entries across all tracked agreements.
        </p>
        <DataTable
          rows={recent}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
