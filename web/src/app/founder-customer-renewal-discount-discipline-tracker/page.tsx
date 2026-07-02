import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [reqsRes, topRes, byCatRes, escRes, auditRes] = await Promise.all([
    sb.rpc('list_renewal_discount_requests_r2320'),
    sb.rpc('top_pending_renewal_discount_r2320'),
    sb.rpc('discount_discipline_by_category_r2320'),
    sb.rpc('top_discount_escalators_r2320'),
    sb.rpc('recent_renewal_discount_audit_r2320'),
  ]);

  const requests: any[] = Array.isArray(reqsRes.data) ? reqsRes.data : [];
  const topPending: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const byCategory: any[] = Array.isArray(byCatRes.data) ? byCatRes.data : [];
  const escalators: any[] = Array.isArray(escRes.data) ? escRes.data : [];
  const audit: any[] = Array.isArray(auditRes.data) ? auditRes.data : [];

  const pendingCount = requests.filter((r) => r.status === 'pending').length;
  const approvedCount = requests.filter((r) => r.status === 'approved').length;
  const rejectedCount = requests.filter((r) => r.status === 'rejected').length;
  const totalPendingValue = requests
    .filter((r) => r.status === 'pending')
    .reduce((sum, r) => sum + Number(r.discount_value_rupees ?? 0), 0);
  const totalGivenValue = requests
    .filter((r) => r.status === 'approved')
    .reduce((sum, r) => sum + Number(r.discount_value_rupees ?? 0), 0);
  const avgApprovedPct = (() => {
    const approvedRows = requests.filter((r) => r.status === 'approved');
    if (approvedRows.length === 0) return 0;
    const sum = approvedRows.reduce((s, r) => s + Number(r.discount_pct ?? 0), 0);
    return sum / approvedRows.length;
  })();

  const fmtRupees = (n: number | bigint | null | undefined) => {
    const v = Number(n ?? 0);
    return '₹' + v.toLocaleString('en-IN');
  };

  const reqColumns: Column<any>[] = [
    { key: 'requested_at', header: 'Requested', render: (r: any) => new Date(r.requested_at).toLocaleString() },
    { key: 'customer_label', header: 'Customer', render: (r: any) => r.customer_label },
    { key: 'contract_ref', header: 'Contract', render: (r: any) => r.contract_ref },
    { key: 'product_category', header: 'Category', render: (r: any) => r.product_category },
    { key: 'original_price_rupees', header: 'Original', render: (r: any) => fmtRupees(r.original_price_rupees) },
    { key: 'proposed_price_rupees', header: 'Proposed', render: (r: any) => fmtRupees(r.proposed_price_rupees) },
    { key: 'discount_pct', header: 'Discount %', render: (r: any) => `${Number(r.discount_pct).toFixed(2)}%` },
    { key: 'discount_value_rupees', header: 'Discount Value', render: (r: any) => fmtRupees(r.discount_value_rupees) },
    { key: 'renewal_term_months', header: 'Term (mo)', render: (r: any) => String(r.renewal_term_months ?? '') },
    { key: 'prior_discount_pct', header: 'Prior %', render: (r: any) => `${Number(r.prior_discount_pct ?? 0).toFixed(2)}%` },
    { key: 'delta_vs_prior_pct', header: 'Delta vs Prior', render: (r: any) => `${Number(r.delta_vs_prior_pct ?? 0).toFixed(2)}%` },
    { key: 'requested_by_email', header: 'Requested By', render: (r: any) => r.requested_by_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'decided_by_email', header: 'Decided By', render: (r: any) => r.decided_by_email ?? '—' },
    { key: 'audit_count', header: 'Audit', render: (r: any) => String(r.audit_count ?? 0) },
    { key: 'justification_preview', header: 'Justification', render: (r: any) => r.justification_preview ?? '' },
  ];

  const topColumns: Column<any>[] = [
    { key: 'requested_at', header: 'Requested', render: (r: any) => new Date(r.requested_at).toLocaleString() },
    { key: 'customer_label', header: 'Customer', render: (r: any) => r.customer_label },
    { key: 'product_category', header: 'Category', render: (r: any) => r.product_category },
    { key: 'original_price_rupees', header: 'Original', render: (r: any) => fmtRupees(r.original_price_rupees) },
    { key: 'proposed_price_rupees', header: 'Proposed', render: (r: any) => fmtRupees(r.proposed_price_rupees) },
    { key: 'discount_pct', header: 'Discount %', render: (r: any) => `${Number(r.discount_pct).toFixed(2)}%` },
    { key: 'discount_value_rupees', header: 'Discount Value', render: (r: any) => fmtRupees(r.discount_value_rupees) },
    { key: 'delta_vs_prior_pct', header: 'Delta vs Prior', render: (r: any) => `${Number(r.delta_vs_prior_pct ?? 0).toFixed(2)}%` },
    { key: 'expires_at', header: 'Expires', render: (r: any) => (r.expires_at ? new Date(r.expires_at).toLocaleString() : '—') },
  ];

  const catColumns: Column<any>[] = [
    { key: 'product_category', header: 'Category', render: (r: any) => r.product_category },
    { key: 'total_requests', header: 'Total', render: (r: any) => String(r.total_requests ?? 0) },
    { key: 'approved_count', header: 'Approved', render: (r: any) => String(r.approved_count ?? 0) },
    { key: 'rejected_count', header: 'Rejected', render: (r: any) => String(r.rejected_count ?? 0) },
    { key: 'pending_count', header: 'Pending', render: (r: any) => String(r.pending_count ?? 0) },
    { key: 'approval_rate_pct', header: 'Approval Rate', render: (r: any) => (r.approval_rate_pct == null ? '—' : `${Number(r.approval_rate_pct).toFixed(2)}%`) },
    { key: 'avg_discount_pct', header: 'Avg %', render: (r: any) => `${Number(r.avg_discount_pct ?? 0).toFixed(2)}%` },
    { key: 'median_discount_pct', header: 'Median %', render: (r: any) => `${Number(r.median_discount_pct ?? 0).toFixed(2)}%` },
    { key: 'max_discount_pct', header: 'Max %', render: (r: any) => `${Number(r.max_discount_pct ?? 0).toFixed(2)}%` },
    { key: 'total_discount_given_rupees', header: 'Total Given', render: (r: any) => fmtRupees(r.total_discount_given_rupees) },
  ];

  const escColumns: Column<any>[] = [
    { key: 'customer_label', header: 'Customer', render: (r: any) => r.customer_label },
    { key: 'request_count', header: 'Requests', render: (r: any) => String(r.request_count ?? 0) },
    { key: 'approved_count', header: 'Approved', render: (r: any) => String(r.approved_count ?? 0) },
    { key: 'total_discount_given_rupees', header: 'Total Given', render: (r: any) => fmtRupees(r.total_discount_given_rupees) },
    { key: 'avg_discount_pct', header: 'Avg %', render: (r: any) => `${Number(r.avg_discount_pct ?? 0).toFixed(2)}%` },
    { key: 'latest_prior_discount_pct', header: 'Latest Prior %', render: (r: any) => `${Number(r.latest_prior_discount_pct ?? 0).toFixed(2)}%` },
    { key: 'latest_discount_pct', header: 'Latest %', render: (r: any) => `${Number(r.latest_discount_pct ?? 0).toFixed(2)}%` },
    { key: 'escalation_delta_pct', header: 'Escalation Delta', render: (r: any) => `${Number(r.escalation_delta_pct ?? 0).toFixed(2)}%` },
    { key: 'last_requested_at', header: 'Last Requested', render: (r: any) => new Date(r.last_requested_at).toLocaleString() },
  ];

  const auditColumns: Column<any>[] = [
    { key: 'at_ts', header: 'When', render: (r: any) => new Date(r.at_ts).toLocaleString() },
    { key: 'event_type', header: 'Event', render: (r: any) => r.event_type },
    { key: 'customer_label', header: 'Customer', render: (r: any) => r.customer_label },
    { key: 'product_category', header: 'Category', render: (r: any) => r.product_category },
    { key: 'actor_email', header: 'Actor', render: (r: any) => r.actor_email ?? '—' },
    { key: 'note_md', header: 'Note', render: (r: any) => (r.note_md ?? '').slice(0, 160) },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Customer Renewal-Discount Discipline Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Every renewal-time discount request &gt;= the founder-only threshold. Shows discount % vs original price, delta vs prior renewal, justification &amp; competitor quote, and founder decision trail. Approve, reject, or escalate each one and watch discount discipline by category &amp; by repeat-escalator customers.
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
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Discount Given</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{fmtRupees(totalGivenValue)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Avg Approved Discount %</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{avgApprovedPct.toFixed(2)}%</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All renewal-discount requests</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 14 }}>
          Shows discount % vs original price, delta vs the prior renewal's discount, and the decision trail.
        </p>
        <DataTable rows={requests} columns={reqColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top pending by rupee impact</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 14 }}>
          Decide these first — highest discount value comes off margin immediately.
        </p>
        <DataTable rows={topPending} columns={topColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Discount discipline by product category</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 14 }}>
          Approval rate, avg/median/max discount %, and total rupees given up — per category.
        </p>
        <DataTable rows={byCategory} columns={catColumns} rowKey={(r, i) => String(r.product_category ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top discount escalators (customers)</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 14 }}>
          Customers whose latest renewal-discount &gt; prior discount — sorted by escalation delta. These are the ones training us to discount harder each cycle.
        </p>
        <DataTable rows={escalators} columns={escColumns} rowKey={(r, i) => String(r.customer_label ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent audit trail</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 14 }}>
          Last 200 events — submissions, decisions, escalations, and notes.
        </p>
        <DataTable rows={audit} columns={auditColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
