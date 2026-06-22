import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerCustomerDirectTipTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [tipsRes, topRes, actionsRes] = await Promise.all([
    sb.rpc('list_tips_r2012'),
    sb.rpc('top_tipped_engineers_r2012'),
    sb.rpc('recent_tip_actions_r2012'),
  ]);

  const tips: any[] = Array.isArray(tipsRes.data) ? tipsRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const totalRupees = tips.reduce((acc, r) => acc + Number(r.tip_amount_rupees || 0), 0);
  const disputedCount = tips.filter((r) => r.status === 'disputed').length;
  const forwardedCount = tips.filter((r) => r.status === 'forwarded_to_co').length;

  const tipColumns: Column<any>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email || r.engineer_user_id || '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name || '—' },
    { key: 'tip_type', header: 'Type', render: (r: any) => r.tip_type },
    { key: 'tip_amount_rupees', header: 'Amount', render: (r: any) => `₹${Number(r.tip_amount_rupees || 0).toLocaleString('en-IN')}` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md || '—' },
  ];

  const topColumns: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email || r.engineer_user_id || '—' },
    { key: 'tip_count', header: 'Tips', render: (r: any) => Number(r.tip_count || 0).toLocaleString('en-IN') },
    { key: 'total_tips_rupees', header: 'Total', render: (r: any) => `₹${Number(r.total_tips_rupees || 0).toLocaleString('en-IN')}` },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email || '—' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md || '—' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>
          Engineer Customer-Direct Tip Tracker
        </h1>
        <p style={{ color: '#666', fontSize: 14 }}>
          Round 2012. Track direct customer tips to engineers (cash, digital, gift, postpaid).
          Forward to company or charity per policy.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total tips logged</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{tips.length}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Gross rupees</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>₹{totalRupees.toLocaleString('en-IN')}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Disputed</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{disputedCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Forwarded to Co</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{forwardedCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent tips</h2>
        <DataTable
          rows={tips}
          columns={tipColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top tipped engineers</h2>
        <DataTable
          rows={top}
          columns={topColumns}
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent actions</h2>
        <DataTable
          rows={actions}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <footer style={{ marginTop: 32, padding: 16, background: '#f9fafb', borderRadius: 8, fontSize: 12, color: '#666' }}>
        Founder-only. All writes audited via founder_action_log. Tips are not part of engineer payouts.
        Forward-to-company or charity actions follow direct-tip policy.
      </footer>
    </div>
  );
}
