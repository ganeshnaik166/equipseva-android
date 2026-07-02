import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [holdbacksRes, eventsRes, topRes, aggRes] = await Promise.all([
    sb.rpc('list_customer_escrow_holdbacks_r2224'),
    sb.rpc('recent_actions_customer_escrow_holdback_r2224'),
    sb.rpc('top_customer_escrow_holdbacks_r2224'),
    sb.rpc('aggregate_customer_escrow_holdback_r2224'),
  ]);

  const holdbacks = (holdbacksRes.data ?? []) as any[];
  const events = (eventsRes.data ?? []) as any[];
  const top = (topRes.data ?? []) as any[];
  const agg = (aggRes.data?.[0] ?? {}) as any;

  const holdbackCols: Column<any>[] = [
    { key: 'customer_label', header: 'Customer', render: (r: any) => String(r.customer_label ?? '') },
    { key: 'repair_job_ref', header: 'Job ref', render: (r: any) => String(r.repair_job_ref ?? '') },
    { key: 'escrow_amount_rupees', header: 'Escrow Rs', render: (r: any) => String(r.escrow_amount_rupees ?? 0) },
    { key: 'holdback_amount_rupees', header: 'Holdback Rs', render: (r: any) => String(r.holdback_amount_rupees ?? 0) },
    { key: 'released_amount_rupees', header: 'Released Rs', render: (r: any) => String(r.released_amount_rupees ?? 0) },
    { key: 'resolution_status', header: 'Status', render: (r: any) => String(r.resolution_status ?? '') },
    { key: 'dispute_reason', header: 'Reason', render: (r: any) => String(r.dispute_reason ?? '') },
    { key: 'opened_at', header: 'Opened', render: (r: any) => r.opened_at ? new Date(r.opened_at).toLocaleString() : '' },
    { key: 'due_release_at', header: 'Due release', render: (r: any) => r.due_release_at ? new Date(r.due_release_at).toLocaleString() : '' },
  ];

  const eventCols: Column<any>[] = [
    { key: 'event_type', header: 'Event', render: (r: any) => String(r.event_type ?? '') },
    { key: 'amount_rupees', header: 'Amount Rs', render: (r: any) => String(r.amount_rupees ?? 0) },
    { key: 'actor_email', header: 'Actor', render: (r: any) => String(r.actor_email ?? '') },
    { key: 'recorded_at', header: 'When', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '' },
    { key: 'remark', header: 'Remark', render: (r: any) => String(r.remark ?? '') },
  ];

  const topCols: Column<any>[] = [
    { key: 'customer_label', header: 'Customer', render: (r: any) => String(r.customer_label ?? '') },
    { key: 'holdback_amount_rupees', header: 'Holdback Rs', render: (r: any) => String(r.holdback_amount_rupees ?? 0) },
    { key: 'resolution_status', header: 'Status', render: (r: any) => String(r.resolution_status ?? '') },
    { key: 'opened_at', header: 'Opened', render: (r: any) => r.opened_at ? new Date(r.opened_at).toLocaleString() : '' },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Customer escrow & holdback tracker</h1>
        <p style={{ color: '#555', marginTop: 4 }}>
          Disputed amounts held in escrow, partial & full holdback releases, resolution status per dispute.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(140px, 1fr))', gap: 12 }}>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total holdbacks</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{String(agg.total_holdbacks ?? 0)}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>In escrow</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{String(agg.in_escrow_count ?? 0)}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Resolved</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{String(agg.resolved_count ?? 0)}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Escalated</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{String(agg.escalated_count ?? 0)}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Escrow Rs</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{String(agg.total_escrow_rupees ?? 0)}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Holdback Rs</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{String(agg.total_holdback_rupees ?? 0)}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Released Rs</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{String(agg.total_released_rupees ?? 0)}</div>
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Active holdbacks</h2>
        <DataTable rows={holdbacks} columns={holdbackCols} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top open holdbacks by amount</h2>
        <DataTable rows={top} columns={topCols} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent release events</h2>
        <DataTable rows={events} columns={eventCols} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}
