import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [prefsRes, channelsRes, optOutsRes, expiringRes] = await Promise.all([
    sb.rpc('list_preferences_r1833', { p_limit: 200 }),
    sb.rpc('top_channels_r1833'),
    sb.rpc('opt_out_investors_r1833', { p_limit: 200 }),
    sb.rpc('expiring_consents_r1833', { p_days: 30 }),
  ]);

  const prefs: any[] = Array.isArray(prefsRes.data) ? prefsRes.data : [];
  const channels: any[] = Array.isArray(channelsRes.data) ? channelsRes.data : [];
  const optOuts: any[] = Array.isArray(optOutsRes.data) ? optOutsRes.data : [];
  const expiring: any[] = Array.isArray(expiringRes.data) ? expiringRes.data : [];

  const totalPrefs = prefs.length;
  const activeCount = prefs.filter((p) => p.status === 'active').length;
  const optedOutCount = prefs.filter((p) => p.status === 'opted_out').length;
  const expiringCount = expiring.length;

  const prefCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id?.slice(0, 8) ?? '—' },
    { key: 'preferred_channel', header: 'Channel', render: (r: any) => r.preferred_channel ?? '—' },
    { key: 'preferred_frequency', header: 'Frequency', render: (r: any) => r.preferred_frequency ?? '—' },
    { key: 'time_zone', header: 'Time Zone', render: (r: any) => r.time_zone ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleDateString() : '—' },
  ];

  const channelCols: Column<any>[] = [
    { key: 'preferred_channel', header: 'Channel', render: (r: any) => r.preferred_channel ?? '—' },
    { key: 'investor_count', header: 'Total', render: (r: any) => r.investor_count ?? 0 },
    { key: 'active_count', header: 'Active', render: (r: any) => r.active_count ?? 0 },
    { key: 'opted_out_count', header: 'Opted Out', render: (r: any) => r.opted_out_count ?? 0 },
  ];

  const optOutCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id?.slice(0, 8) ?? '—' },
    { key: 'preferred_channel', header: 'Was Channel', render: (r: any) => r.preferred_channel ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'updated_at', header: 'Updated', render: (r: any) => r.updated_at ? new Date(r.updated_at).toLocaleDateString() : '—' },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id?.slice(0, 8) ?? '—' },
    { key: 'consent_type', header: 'Consent Type', render: (r: any) => r.consent_type ?? '—' },
    { key: 'granted', header: 'Granted', render: (r: any) => r.granted ? 'Yes' : 'No' },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '—' },
    { key: 'days_remaining', header: 'Days Left', render: (r: any) => r.days_remaining ?? 0 },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>
          Investor Communication Preferences
        </h1>
        <p style={{ color: '#666', fontSize: 14 }}>
          Per-investor preferred channel & frequency — respect do-not-contact windows & consent expiry.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 14 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total preferences</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalPrefs}</div>
        </div>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 14 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Active</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#0a7d3b' }}>{activeCount}</div>
        </div>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 14 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Opted out</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#b42318' }}>{optedOutCount}</div>
        </div>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 14 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Consents expiring &lt;= 30d</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#b54708' }}>{expiringCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 10 }}>Channel mix</h2>
        <DataTable<any>
          rows={channels}
          columns={channelCols}
          rowKey={(r: any, i: number) => String(r.preferred_channel ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 10 }}>All preferences</h2>
        <DataTable<any>
          rows={prefs}
          columns={prefCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 10 }}>Opted-out investors</h2>
        <DataTable<any>
          rows={optOuts}
          columns={optOutCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 10 }}>Consents expiring soon</h2>
        <DataTable<any>
          rows={expiring}
          columns={expiringCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <footer style={{ color: '#888', fontSize: 12, marginTop: 24 }}>
        Round 1833 · investor_comm_preferences_r1833 & investor_comm_consent_log_r1833 · founder-gated
      </footer>
    </main>
  );
}
