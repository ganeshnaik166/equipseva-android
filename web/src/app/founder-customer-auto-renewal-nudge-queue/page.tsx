import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [nudgesRes, actionsRes, bucketsRes, funnelRes] = await Promise.all([
    sb.rpc('list_customer_renewal_nudges_r2200'),
    sb.rpc('recent_actions_r2200'),
    sb.rpc('top_bucket_r2200'),
    sb.rpc('conversion_funnel_r2200'),
  ]);

  const nudges = (nudgesRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const buckets = (bucketsRes.data ?? []) as any[];
  const funnel = (funnelRes.data?.[0] ?? {}) as any;

  const nudgeCols: Column<any>[] = [
    { key: 'customer_name', header: 'Customer', render: (r: any) => String(r.customer_name ?? '') },
    { key: 'customer_email', header: 'Email', render: (r: any) => String(r.customer_email ?? '') },
    { key: 'amc_tier', header: 'Tier', render: (r: any) => String(r.amc_tier ?? '') },
    { key: 'monthly_fee_rupees', header: 'Monthly fee', render: (r: any) => String(r.monthly_fee_rupees ?? '') },
    { key: 'bucket', header: 'Bucket', render: (r: any) => String(r.bucket ?? '') },
    { key: 'days_to_expiry', header: 'Days left', render: (r: any) => String(r.days_to_expiry ?? '') },
    { key: 'nudge_status', header: 'Status', render: (r: any) => String(r.nudge_status ?? '') },
    { key: 'channel', header: 'Channel', render: (r: any) => String(r.channel ?? '') },
    { key: 'nudge_count', header: 'Nudges', render: (r: any) => String(r.nudge_count ?? '') },
    { key: 'last_nudged_at', header: 'Last nudge', render: (r: any) => String(r.last_nudged_at ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'channel', header: 'Channel', render: (r: any) => String(r.channel ?? '') },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
    { key: 'actor_email', header: 'Actor', render: (r: any) => String(r.actor_email ?? '') },
    { key: 'created_at', header: 'When', render: (r: any) => String(r.created_at ?? '') },
  ];

  const bucketCols: Column<any>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: any) => String(r.bucket ?? '') },
    { key: 'total_queued', header: 'Queued', render: (r: any) => String(r.total_queued ?? '') },
    { key: 'total_sent', header: 'Sent', render: (r: any) => String(r.total_sent ?? '') },
    { key: 'total_converted', header: 'Converted', render: (r: any) => String(r.total_converted ?? '') },
    { key: 'total_declined', header: 'Declined', render: (r: any) => String(r.total_declined ?? '') },
    { key: 'avg_days_to_expiry', header: 'Avg days left', render: (r: any) => String(r.avg_days_to_expiry ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Customer auto-renewal nudge queue
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        AMC contracts expiring in 30 / 60 / 90 days — nudge status & conversion track.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Total nudges</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{funnel.total_nudges ?? 0}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Converted</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{funnel.total_converted ?? 0}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Conversion rate</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{funnel.conversion_rate ?? 0}%</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Revenue secured (₹/yr)</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{funnel.total_revenue_secured_rupees ?? 0}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Bucket rollup (30 / 60 / 90)</h2>
        <DataTable columns={bucketCols} rows={buckets} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Nudge queue</h2>
        <DataTable columns={nudgeCols} rows={nudges} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent actions</h2>
        <DataTable columns={actionCols} rows={actions} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}
