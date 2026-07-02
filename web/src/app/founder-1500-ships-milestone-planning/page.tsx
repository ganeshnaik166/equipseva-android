import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [
    plansRes,
    giftsRes,
    summaryRes,
    plansByCatRes,
    giftsByTypeRes,
    overdueRes,
    topPrioritiesRes,
  ] = await Promise.all([
    sb.rpc('founder_1500_list_plans_r2293'),
    sb.rpc('founder_1500_list_gifts_r2293'),
    sb.rpc('founder_1500_summary_r2293'),
    sb.rpc('founder_1500_plans_by_category_r2293'),
    sb.rpc('founder_1500_gifts_by_type_r2293'),
    sb.rpc('founder_1500_overdue_gifts_r2293'),
    sb.rpc('founder_1500_top_priorities_r2293'),
  ]);

  const plans = (plansRes.data ?? []) as any[];
  const gifts = (giftsRes.data ?? []) as any[];
  const summary = ((summaryRes.data ?? [])[0] ?? {}) as any;
  const plansByCat = (plansByCatRes.data ?? []) as any[];
  const giftsByType = (giftsByTypeRes.data ?? []) as any[];
  const overdue = (overdueRes.data ?? []) as any[];
  const topPriorities = (topPrioritiesRes.data ?? []) as any[];

  const planCols: Column<any>[] = [
    { key: 'plan_title', header: 'Plan Title', render: (r: any) => String(r.plan_title ?? '') },
    { key: 'signifies', header: 'Signifies', render: (r: any) => String(r.signifies ?? '').slice(0, 120) },
    { key: 'ship_to_celebrate', header: 'Ship To Celebrate', render: (r: any) => String(r.ship_to_celebrate ?? '').slice(0, 120) },
    { key: 'celebration_category', header: 'Category', render: (r: any) => String(r.celebration_category ?? '') },
    { key: 'priority', header: 'Priority', render: (r: any) => String(r.priority ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'target_date', header: 'Target Date', render: (r: any) => String(r.target_date ?? '—') },
    { key: 'effort_estimate_hours', header: 'Effort (hrs)', render: (r: any) => String(r.effort_estimate_hours ?? '—') },
  ];

  const giftCols: Column<any>[] = [
    { key: 'recipient_name', header: 'Recipient', render: (r: any) => String(r.recipient_name ?? '') },
    { key: 'recipient_type', header: 'Type', render: (r: any) => String(r.recipient_type ?? '') },
    { key: 'gift_description', header: 'Gift', render: (r: any) => String(r.gift_description ?? '').slice(0, 140) },
    { key: 'gift_category', header: 'Category', render: (r: any) => String(r.gift_category ?? '') },
    { key: 'estimated_value_rupees', header: 'Value (Rs)', render: (r: any) => String(r.estimated_value_rupees ?? '—') },
    { key: 'reason', header: 'Reason', render: (r: any) => String(r.reason ?? '').slice(0, 120) },
    { key: 'promised_deadline', header: 'Deadline', render: (r: any) => String(r.promised_deadline ?? '—') },
    { key: 'fulfilled', header: 'Fulfilled', render: (r: any) => (r.fulfilled ? 'yes' : 'no') },
    { key: 'is_public_commitment', header: 'Public', render: (r: any) => (r.is_public_commitment ? 'yes' : 'no') },
  ];

  const plansByCatCols: Column<any>[] = [
    { key: 'celebration_category', header: 'Category', render: (r: any) => String(r.celebration_category ?? '') },
    { key: 'total_count', header: 'Total', render: (r: any) => String(r.total_count ?? 0) },
    { key: 'shipped_count', header: 'Shipped', render: (r: any) => String(r.shipped_count ?? 0) },
    { key: 'planned_count', header: 'Planned', render: (r: any) => String(r.planned_count ?? 0) },
    { key: 'draft_count', header: 'Draft', render: (r: any) => String(r.draft_count ?? 0) },
    { key: 'total_effort_hours', header: 'Effort (hrs)', render: (r: any) => String(r.total_effort_hours ?? 0) },
  ];

  const giftsByTypeCols: Column<any>[] = [
    { key: 'recipient_type', header: 'Recipient Type', render: (r: any) => String(r.recipient_type ?? '') },
    { key: 'total_count', header: 'Total', render: (r: any) => String(r.total_count ?? 0) },
    { key: 'fulfilled_count', header: 'Fulfilled', render: (r: any) => String(r.fulfilled_count ?? 0) },
    { key: 'pending_count', header: 'Pending', render: (r: any) => String(r.pending_count ?? 0) },
    { key: 'public_count', header: 'Public', render: (r: any) => String(r.public_count ?? 0) },
    { key: 'total_value_rupees', header: 'Value (Rs)', render: (r: any) => String(r.total_value_rupees ?? 0) },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'recipient_name', header: 'Recipient', render: (r: any) => String(r.recipient_name ?? '') },
    { key: 'recipient_type', header: 'Type', render: (r: any) => String(r.recipient_type ?? '') },
    { key: 'gift_description', header: 'Gift', render: (r: any) => String(r.gift_description ?? '').slice(0, 120) },
    { key: 'promised_deadline', header: 'Deadline', render: (r: any) => String(r.promised_deadline ?? '') },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => String(r.days_overdue ?? 0) },
    { key: 'estimated_value_rupees', header: 'Value (Rs)', render: (r: any) => String(r.estimated_value_rupees ?? '—') },
    { key: 'is_public_commitment', header: 'Public', render: (r: any) => (r.is_public_commitment ? 'yes' : 'no') },
  ];

  const topPriorityCols: Column<any>[] = [
    { key: 'plan_title', header: 'Plan', render: (r: any) => String(r.plan_title ?? '') },
    { key: 'signifies', header: 'Signifies', render: (r: any) => String(r.signifies ?? '').slice(0, 100) },
    { key: 'ship_to_celebrate', header: 'Ship', render: (r: any) => String(r.ship_to_celebrate ?? '').slice(0, 100) },
    { key: 'celebration_category', header: 'Category', render: (r: any) => String(r.celebration_category ?? '') },
    { key: 'priority', header: 'Priority', render: (r: any) => String(r.priority ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'target_date', header: 'Target', render: (r: any) => String(r.target_date ?? '—') },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Founder 1500 SHIPS Milestone Planning
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Plan what the 1500-ship milestone signifies, what we ship to celebrate, and gift
        commitments to team &gt; investors &gt; customers. Tracks public vs private promises &amp;
        overdue deliveries.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, marginBottom: 32 }}>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Plans</div>
          <div style={{ fontSize: 24, fontWeight: 600 }}>{String(summary.total_plans ?? 0)}</div>
          <div style={{ fontSize: 12, color: '#666', marginTop: 4 }}>
            {String(summary.draft_plans ?? 0)} draft · {String(summary.planned_plans ?? 0)} planned · {String(summary.shipped_plans ?? 0)} shipped
          </div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>High Priority Plans</div>
          <div style={{ fontSize: 24, fontWeight: 600 }}>{String(summary.high_priority_plans ?? 0)}</div>
          <div style={{ fontSize: 12, color: '#666', marginTop: 4 }}>
            high & critical not yet shipped
          </div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Gift Commitments</div>
          <div style={{ fontSize: 24, fontWeight: 600 }}>{String(summary.total_gifts ?? 0)}</div>
          <div style={{ fontSize: 12, color: '#666', marginTop: 4 }}>
            {String(summary.fulfilled_gifts ?? 0)} fulfilled · {String(summary.pending_gifts ?? 0)} pending · Rs {String(summary.total_gift_value_rupees ?? 0)}
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Priorities</h2>
        <DataTable
          rows={topPriorities}
          columns={topPriorityCols}
          rowKey={(_, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Overdue Gift Commitments</h2>
        <DataTable
          rows={overdue}
          columns={overdueCols}
          rowKey={(_, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Milestone Plans</h2>
        <DataTable
          rows={plans}
          columns={planCols}
          rowKey={(_, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Gift Commitments</h2>
        <DataTable
          rows={gifts}
          columns={giftCols}
          rowKey={(_, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Plans By Category</h2>
        <DataTable
          rows={plansByCat}
          columns={plansByCatCols}
          rowKey={(_, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Gifts By Recipient Type</h2>
        <DataTable
          rows={giftsByType}
          columns={giftsByTypeCols}
          rowKey={(_, i) => String(i)}
        />
      </section>
    </main>
  );
}
