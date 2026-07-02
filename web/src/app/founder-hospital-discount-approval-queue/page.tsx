import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [reqsRes, topRes, expRes] = await Promise.all([
    sb.rpc('list_discount_requests_r1707'),
    sb.rpc('top_pending_discount_value_r1707'),
    sb.rpc('expired_discount_requests_r1707'),
  ]);

  const requests: any[] = Array.isArray(reqsRes.data) ? reqsRes.data : [];
  const topPending: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const expired: any[] = Array.isArray(expRes.data) ? expRes.data : [];

  const pendingCount = requests.filter((r) => r.status === 'pending').length;
  const approvedCount = requests.filter((r) => r.status === 'approved').length;
  const rejectedCount = requests.filter((r) => r.status === 'rejected').length;
  const totalPendingValue = requests
    .filter((r) => r.status === 'pending')
    .reduce((sum, r) => sum + Number(r.discount_value_rupees ?? 0), 0);

  const fmtRupees = (n: number | bigint | null | undefined) => {
    const v = Number(n ?? 0);
    return '₹' + v.toLocaleString('en-IN');
  };

  const reqColumns: Column<any>[] = [
    { key: 'requested_at', header: 'Requested', render: (r: any) => new Date(r.requested_at).toLocaleString() },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id?.slice(0, 8) },
    { key: 'request_type', header: 'Type', render: (r: any) => r.request_type },
    { key: 'list_price_rupees', header: 'List Price', render: (r: any) => fmtRupees(r.list_price_rupees) },
    { key: 'discount_pct', header: 'Discount %', render: (r: any) => `${Number(r.discount_pct).toFixed(2)}%` },
    { key: 'discount_value_rupees', header: 'Discount Value', render: (r: any) => fmtRupees(r.discount_value_rupees) },
    { key: 'requested_by_email', header: 'Requested By', render: (r: any) => r.requested_by_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'decided_by_email', header: 'Decided By', render: (r: any) => r.decided_by_email ?? '—' },
    { key: 'decided_at', header: 'Decided At', render: (r: any) => (r.decided_at ? new Date(r.decided_at).toLocaleString() : '—') },
    { key: 'note_count', header: 'Notes', render: (r: any) => String(r.note_count ?? 0) },
    { key: 'justification', header: 'Justification', render: (r: any) => (r.justification ?? '').slice(0, 120) },
  ];

  const topColumns: Column<any>[] = [
    { key: 'requested_at', header: 'Requested', render: (r: any) => new Date(r.requested_at).toLocaleString() },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id?.slice(0, 8) },
    { key: 'request_type', header: 'Type', render: (r: any) => r.request_type },
    { key: 'list_price_rupees', header: 'List Price', render: (r: any) => fmtRupees(r.list_price_rupees) },
    { key: 'discount_pct', header: 'Discount %', render: (r: any) => `${Number(r.discount_pct).toFixed(2)}%` },
    { key: 'discount_value_rupees', header: 'Discount Value', render: (r: any) => fmtRupees(r.discount_value_rupees) },
  ];

  const expColumns: Column<any>[] = [
    { key: 'requested_at', header: 'Requested', render: (r: any) => new Date(r.requested_at).toLocaleString() },
    { key: 'expires_at', header: 'Expired At', render: (r: any) => (r.expires_at ? new Date(r.expires_at).toLocaleString() : '—') },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id?.slice(0, 8) },
    { key: 'request_type', header: 'Type', render: (r: any) => r.request_type },
    { key: 'list_price_rupees', header: 'List Price', render: (r: any) => fmtRupees(r.list_price_rupees) },
    { key: 'discount_pct', header: 'Discount %', render: (r: any) => `${Number(r.discount_pct).toFixed(2)}%` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital Discount Approval Queue</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        AMC, repair, spare-part, and multi-year discount requests above the founder-only threshold. Decide each request and log notes.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Pending</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{pendingCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Approved</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{approvedCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Rejected</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{rejectedCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Pending Discount Value</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{fmtRupees(totalPendingValue)}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All requests</h2>
        <DataTable rows={requests} columns={reqColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top pending by discount value</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 14 }}>
          Highest rupee impact first — decide these before low-value pending requests.
        </p>
        <DataTable rows={topPending} columns={topColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Expired / past deadline</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 14 }}>
          Requests whose expires_at is in the past and status is still pending or expired.
        </p>
        <DataTable rows={expired} columns={expColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
