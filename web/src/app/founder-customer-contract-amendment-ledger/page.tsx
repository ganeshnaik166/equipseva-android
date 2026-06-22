import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [listRes, recentRes, topRes, aggRes] = await Promise.all([
    sb.rpc('list_amendments_r2213'),
    sb.rpc('recent_actions_r2213'),
    sb.rpc('top_amendment_types_r2213'),
    sb.rpc('aggregate_amendments_r2213'),
  ]);

  const rows: any[] = Array.isArray(listRes.data) ? listRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const agg: any = Array.isArray(aggRes.data) && aggRes.data[0] ? aggRes.data[0] : {};

  const amendCols: Column<any>[] = [
    { key: 'contract_ref', header: 'Contract', render: (r: any) => r.contract_ref ?? '' },
    { key: 'customer_org', header: 'Customer', render: (r: any) => r.customer_org ?? '' },
    { key: 'amendment_type', header: 'Type', render: (r: any) => r.amendment_type ?? '' },
    { key: 'diff_summary', header: 'Diff', render: (r: any) => r.diff_summary ?? '' },
    { key: 'effective_date', header: 'Effective', render: (r: any) => r.effective_date ?? '' },
    { key: 'amount_delta_rupees', header: 'Delta', render: (r: any) => `Rs ${Number(r.amount_delta_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'requested_by_email', header: 'Requested by', render: (r: any) => r.requested_by_email ?? '' },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString('en-IN') : '' },
  ];

  const topCols: Column<any>[] = [
    { key: 'amendment_type', header: 'Type', render: (r: any) => r.amendment_type ?? '' },
    { key: 'n', header: 'Count', render: (r: any) => String(r.n ?? 0) },
    { key: 'total_delta_rupees', header: 'Total delta', render: (r: any) => `Rs ${Number(r.total_delta_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'pending_n', header: 'Pending', render: (r: any) => String(r.pending_n ?? 0) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'actor_email', header: 'Actor', render: (r: any) => r.actor_email ?? '' },
    { key: 'op_name', header: 'Op', render: (r: any) => r.op_name ?? '' },
    { key: 'after_value', header: 'Payload', render: (r: any) => JSON.stringify(r.after_value ?? {}).slice(0, 120) },
    { key: 'created_at', header: 'When', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString('en-IN') : '' },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif', maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 6 }}>Customer contract amendment ledger</h1>
      <p style={{ color: '#555', marginBottom: 18 }}>
        AMC and service contract amendments — before/after diff, approval chain, effective date tracking.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 14, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total amendments</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{Number(agg.total_n ?? 0)}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Pending review</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{Number(agg.pending_n ?? 0)}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Approved</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{Number(agg.approved_n ?? 0)}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Executed</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{Number(agg.executed_n ?? 0)}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Rejected</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{Number(agg.rejected_n ?? 0)}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Net delta</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>Rs {Number(agg.total_delta_rupees ?? 0).toLocaleString('en-IN')}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Upcoming effective</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{Number(agg.upcoming_effective_n ?? 0)}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Amendments (latest 200)</h2>
        <DataTable<any> columns={amendCols} rows={rows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>By amendment type</h2>
        <DataTable<any> columns={topCols} rows={top} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Recent founder actions</h2>
        <DataTable<any> columns={actionCols} rows={recent} rowKey={(_, i) => String(i)} />
      </section>

      <p style={{ color: '#888', fontSize: 12 }}>
        Status flow: pending → legal_review → founder_review → approved → executed. Reject or revert anytime if scope & delta drift.
      </p>
    </main>
  );
}
