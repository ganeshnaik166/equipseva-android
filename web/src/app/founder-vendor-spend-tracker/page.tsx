import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderVendorSpendTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [vendorsRes, topRes, reviewsRes] = await Promise.all([
    sb.rpc('list_vendors_r1958'),
    sb.rpc('top_spenders_r1958'),
    sb.rpc('recent_reviews_r1958'),
  ]);

  const vendors: any[] = Array.isArray(vendorsRes.data) ? vendorsRes.data : [];
  const topSpenders: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const recentReviews: any[] = Array.isArray(reviewsRes.data) ? reviewsRes.data : [];

  const totalMonthlySpend = vendors.reduce(
    (sum, v) => sum + Number(v.monthly_spend_rupees ?? 0),
    0
  );
  const activeCount = vendors.filter((v) => v.status === 'active').length;
  const renegotiatingCount = vendors.filter((v) => v.status === 'renegotiating').length;
  const totalSavings = recentReviews.reduce(
    (sum, r) => sum + Number(r.cost_savings_rupees ?? 0),
    0
  );

  const fmtINR = (n: number) =>
    new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(n);

  const vendorCols: Column<any>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => String(r.vendor_name ?? '-') },
    { key: 'vendor_category', header: 'Category', render: (r: any) => String(r.vendor_category ?? '-') },
    {
      key: 'monthly_spend_rupees',
      header: 'Monthly Spend',
      render: (r: any) => fmtINR(Number(r.monthly_spend_rupees ?? 0)),
    },
    {
      key: 'contract_end_date',
      header: 'Contract Ends',
      render: (r: any) => (r.contract_end_date ? String(r.contract_end_date) : '-'),
    },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    {
      key: 'renewal_alert_days',
      header: 'Alert (days)',
      render: (r: any) => String(r.renewal_alert_days ?? 30),
    },
    {
      key: 'captured_at',
      header: 'Captured',
      render: (r: any) => (r.captured_at ? new Date(r.captured_at).toLocaleDateString('en-IN') : '-'),
    },
  ];

  const topCols: Column<any>[] = [
    { key: 'vendor_category', header: 'Category', render: (r: any) => String(r.vendor_category ?? '-') },
    { key: 'vendor_count', header: 'Vendors', render: (r: any) => String(r.vendor_count ?? 0) },
    {
      key: 'total_monthly_spend',
      header: 'Total Monthly',
      render: (r: any) => fmtINR(Number(r.total_monthly_spend ?? 0)),
    },
    { key: 'active_count', header: 'Active', render: (r: any) => String(r.active_count ?? 0) },
  ];

  const reviewCols: Column<any>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => String(r.vendor_name ?? '-') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '-') },
    {
      key: 'taken_at',
      header: 'When',
      render: (r: any) => (r.taken_at ? new Date(r.taken_at).toLocaleString('en-IN') : '-'),
    },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '-') },
    {
      key: 'cost_savings_rupees',
      header: 'Savings',
      render: (r: any) => fmtINR(Number(r.cost_savings_rupees ?? 0)),
    },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '24px', fontWeight: 700, margin: 0 }}>
          Founder Vendor Spend Tracker
        </h1>
        <p style={{ color: '#666', marginTop: '6px', fontSize: '14px' }}>
          Track SaaS, agency &amp; contractor spend. Flag renewals &gt;= 30 days out &amp; review high-cost vendors.
        </p>
      </header>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: '12px',
          marginBottom: '28px',
        }}
      >
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: '14px' }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Total monthly spend</div>
          <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{fmtINR(totalMonthlySpend)}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: '14px' }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Active vendors</div>
          <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{activeCount}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: '14px' }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Renegotiating</div>
          <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{renegotiatingCount}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: '14px' }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Savings logged (recent)</div>
          <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{fmtINR(totalSavings)}</div>
        </div>
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Spend by category</h2>
        <DataTable
          rows={topSpenders}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.vendor_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All vendors</h2>
        <DataTable
          rows={vendors}
          columns={vendorCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent reviews & actions</h2>
        <DataTable
          rows={recentReviews}
          columns={reviewCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
