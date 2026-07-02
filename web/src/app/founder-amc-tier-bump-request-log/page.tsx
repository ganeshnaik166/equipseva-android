import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [requestsRes, eventsRes, pairsRes, aggRes] = await Promise.all([
    sb.rpc('list_tier_bump_requests_r2208'),
    sb.rpc('recent_actions_r2208'),
    sb.rpc('top_tier_pair_r2208'),
    sb.rpc('aggregate_or_search_r2208'),
  ]);

  const requests = (requestsRes.data ?? []) as any[];
  const events = (eventsRes.data ?? []) as any[];
  const pairs = (pairsRes.data ?? []) as any[];
  const agg = (aggRes.data ?? [])[0] ?? {};

  const reqCols: Column<any>[] = [
    { key: 'customer_email', header: 'Customer', render: (r: any) => r.customer_email },
    { key: 'current_tier', header: 'From', render: (r: any) => r.current_tier },
    { key: 'requested_tier', header: 'To', render: (r: any) => r.requested_tier },
    { key: 'monthly_delta_rupees', header: 'Delta (Rs/mo)', render: (r: any) => `Rs ${r.monthly_delta_rupees ?? 0}` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'reason', header: 'Reason', render: (r: any) => r.reason ?? '-' },
    { key: 'requested_at', header: 'Requested', render: (r: any) => r.requested_at ? new Date(r.requested_at).toLocaleString() : '-' },
    { key: 'converted_at', header: 'Converted', render: (r: any) => r.converted_at ? new Date(r.converted_at).toLocaleString() : '-' },
  ];

  const evtCols: Column<any>[] = [
    { key: 'event_type', header: 'Event', render: (r: any) => r.event_type },
    { key: 'actor_email', header: 'Actor', render: (r: any) => r.actor_email ?? '-' },
    { key: 'note', header: 'Note', render: (r: any) => r.note ?? '-' },
    { key: 'occurred_at', header: 'When', render: (r: any) => r.occurred_at ? new Date(r.occurred_at).toLocaleString() : '-' },
  ];

  const pairCols: Column<any>[] = [
    { key: 'tier_pair', header: 'Tier Pair', render: (r: any) => r.tier_pair },
    { key: 'request_count', header: 'Requests', render: (r: any) => r.request_count },
    { key: 'converted_count', header: 'Converted', render: (r: any) => r.converted_count },
    { key: 'total_delta_rupees', header: 'Total Delta (Rs/mo)', render: (r: any) => `Rs ${r.total_delta_rupees ?? 0}` },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <div>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>AMC Tier-Bump Request Log</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Customers asking to upgrade std → premium → elite. Approve, reject, track conversion.
        </p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
        <Stat label="Total Requests" value={agg.total_requests ?? 0} />
        <Stat label="Pending" value={agg.pending_count ?? 0} />
        <Stat label="Approved" value={agg.approved_count ?? 0} />
        <Stat label="Converted" value={agg.converted_count ?? 0} />
        <Stat label="Rejected" value={agg.rejected_count ?? 0} />
        <Stat label="Conversion %" value={`${agg.conversion_rate_pct ?? 0}%`} />
        <Stat label="Monthly Delta (converted)" value={`Rs ${agg.total_monthly_delta_rupees ?? 0}`} />
      </div>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Tier Pairs</h2>
        <DataTable columns={pairCols} rows={pairs} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Bump Requests</h2>
        <DataTable columns={reqCols} rows={requests} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Events</h2>
        <DataTable columns={evtCols} rows={events} rowKey={(_, i) => String(i)} />
      </section>
    </div>
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
