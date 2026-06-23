import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overrides, summary, byCategory, topCustomers, recurring, events, leakage] = await Promise.all([
    supabase.rpc('r2372_list_overrides'),
    supabase.rpc('r2372_summary'),
    supabase.rpc('r2372_by_category'),
    supabase.rpc('r2372_top_customers'),
    supabase.rpc('r2372_recurring_exceptions'),
    supabase.rpc('r2372_recent_events'),
    supabase.rpc('r2372_margin_leakage_by_month'),
  ]);

  const sum = (summary.data ?? [])[0] ?? {};

  const overrideCols: Column<any>[] = [
    { key: 'customer_name', header: 'Customer', render: (r: any) => r.customer_name },
    { key: 'service_name', header: 'Service', render: (r: any) => `${r.service_name} (${r.service_code})` },
    { key: 'rate_card_price_rupees', header: 'Rate Card', render: (r: any) => `₹${Number(r.rate_card_price_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'approved_price_rupees', header: 'Approved', render: (r: any) => `₹${Number(r.approved_price_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'discount_pct', header: 'Disc %', render: (r: any) => `${Number(r.discount_pct ?? 0).toFixed(2)}%` },
    { key: 'margin_impact_rupees', header: 'Margin', render: (r: any) => `₹${Number(r.margin_impact_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'category', header: 'Category', render: (r: any) => r.category },
    { key: 'recurring_exception', header: 'Recurring', render: (r: any) => (r.recurring_exception ? 'yes' : 'no') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'approved_by_email', header: 'Approver', render: (r: any) => r.approved_by_email },
    { key: 'approved_at', header: 'Approved', render: (r: any) => new Date(r.approved_at).toLocaleString('en-IN') },
  ];

  const categoryCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => r.category },
    { key: 'override_count', header: 'Overrides', render: (r: any) => r.override_count },
    { key: 'avg_discount_pct', header: 'Avg Disc %', render: (r: any) => `${Number(r.avg_discount_pct ?? 0).toFixed(2)}%` },
    { key: 'total_margin_impact_rupees', header: 'Margin Impact', render: (r: any) => `₹${Number(r.total_margin_impact_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const customerCols: Column<any>[] = [
    { key: 'customer_name', header: 'Customer', render: (r: any) => r.customer_name },
    { key: 'override_count', header: 'Count', render: (r: any) => r.override_count },
    { key: 'total_discount_rupees', header: 'Total Discount', render: (r: any) => `₹${Number(r.total_discount_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'avg_discount_pct', header: 'Avg %', render: (r: any) => `${Number(r.avg_discount_pct ?? 0).toFixed(2)}%` },
    { key: 'recurring_flag', header: 'Recurring?', render: (r: any) => (r.recurring_flag ? 'yes' : 'no') },
  ];

  const recurringCols: Column<any>[] = [
    { key: 'customer_name', header: 'Customer', render: (r: any) => r.customer_name },
    { key: 'service_name', header: 'Service', render: (r: any) => r.service_name },
    { key: 'approved_price_rupees', header: 'Price', render: (r: any) => `₹${Number(r.approved_price_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'discount_pct', header: 'Disc %', render: (r: any) => `${Number(r.discount_pct ?? 0).toFixed(2)}%` },
    { key: 'recurrence_window', header: 'Window', render: (r: any) => r.recurrence_window ?? '—' },
    { key: 'approved_by_email', header: 'Approver', render: (r: any) => r.approved_by_email },
    { key: 'approved_at', header: 'Approved', render: (r: any) => new Date(r.approved_at).toLocaleDateString('en-IN') },
  ];

  const eventCols: Column<any>[] = [
    { key: 'created_at', header: 'When', render: (r: any) => new Date(r.created_at).toLocaleString('en-IN') },
    { key: 'customer_name', header: 'Customer', render: (r: any) => r.customer_name },
    { key: 'service_name', header: 'Service', render: (r: any) => r.service_name },
    { key: 'event_type', header: 'Event', render: (r: any) => r.event_type },
    { key: 'actor_email', header: 'Actor', render: (r: any) => r.actor_email },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const leakageCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => new Date(r.month_start).toLocaleDateString('en-IN', { month: 'short', year: 'numeric' }) },
    { key: 'override_count', header: 'Overrides', render: (r: any) => r.override_count },
    { key: 'total_discount_rupees', header: 'Discount', render: (r: any) => `₹${Number(r.total_discount_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'total_margin_impact_rupees', header: 'Margin Impact', render: (r: any) => `₹${Number(r.total_margin_impact_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700 }}>Customer Service Pricing Tier Override Log</h1>
      <p style={{ color: '#555', marginTop: 8 }}>
        Every off-rate-card approval logged with justification, margin impact &amp; recurring-exception flag. Use this to spot leakage &gt;= 25% and customers who keep coming back for discounts.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginTop: 24 }}>
        <Stat label="Total overrides" value={sum.total_overrides ?? 0} />
        <Stat label="Active" value={sum.active_overrides ?? 0} />
        <Stat label="Recurring" value={sum.recurring_count ?? 0} />
        <Stat label="High-disc (>=25%)" value={sum.high_discount_count ?? 0} />
        <Stat label="Revoked" value={sum.revoked_count ?? 0} />
        <Stat label="Avg discount" value={`${Number(sum.avg_discount_pct ?? 0).toFixed(2)}%`} />
        <Stat label="Margin impact (₹)" value={`₹${Number(sum.total_margin_impact_rupees ?? 0).toLocaleString('en-IN')}`} />
      </section>

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 32 }}>Recent overrides</h2>
      <DataTable rows={overrides.data ?? []} emptyMessage="No overrides logged yet" rowKey={(r: any) => r.id} columns={overrideCols} />

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 32 }}>By category</h2>
      <DataTable rows={byCategory.data ?? []} emptyMessage="No category breakdown" rowKey={(r: any) => r.category} columns={categoryCols} />

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 32 }}>Top customers by override count</h2>
      <DataTable rows={topCustomers.data ?? []} emptyMessage="No customer data" rowKey={(r: any) => r.customer_name} columns={customerCols} />

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 32 }}>Recurring exceptions (active)</h2>
      <p style={{ color: '#777', fontSize: 13 }}>These need a rate-card review — repeat discount is no longer an exception.</p>
      <DataTable rows={recurring.data ?? []} emptyMessage="No recurring exceptions" rowKey={(r: any) => r.id} columns={recurringCols} />

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 32 }}>Margin leakage by month</h2>
      <DataTable rows={leakage.data ?? []} emptyMessage="No monthly data" rowKey={(r: any) => r.month_start} columns={leakageCols} />

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 32 }}>Audit trail (recent events)</h2>
      <DataTable rows={events.data ?? []} emptyMessage="No events yet" rowKey={(r: any) => r.id} columns={eventCols} />
    </main>
  );
}

function Stat({ label, value }: { label: string; value: any }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 12, color: '#666' }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}
