import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [vendorsRes, recentRes, atRiskRes, aggRes] = await Promise.all([
    sb.rpc('list_vendor_scores_r2225'),
    sb.rpc('recent_actions_vendor_r2225', { p_limit: 50 }),
    sb.rpc('top_vendors_at_risk_r2225'),
    sb.rpc('aggregate_vendor_scores_r2225'),
  ]);

  const vendors: any[] = Array.isArray(vendorsRes.data) ? vendorsRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];
  const atRisk: any[] = Array.isArray(atRiskRes.data) ? atRiskRes.data : [];
  const agg: any = Array.isArray(aggRes.data) && aggRes.data.length > 0 ? aggRes.data[0] : {};

  const fmtRupees = (n: any) => {
    const v = Number(n ?? 0);
    if (v >= 10000000) return `Rs ${(v / 10000000).toFixed(2)} Cr`;
    if (v >= 100000) return `Rs ${(v / 100000).toFixed(2)} L`;
    return `Rs ${v.toLocaleString('en-IN')}`;
  };

  const scoreBadge = (score: number) => {
    if (score >= 80) return { bg: '#dcfce7', fg: '#166534', label: 'strong' };
    if (score >= 60) return { bg: '#fef9c3', fg: '#854d0e', label: 'okay' };
    return { bg: '#fee2e2', fg: '#991b1b', label: 'weak' };
  };

  const vendorCols: Column<any>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => String(r.vendor_name ?? '') },
    { key: 'vendor_category', header: 'Category', render: (r: any) => String(r.vendor_category ?? '') },
    {
      key: 'overall_score',
      header: 'Overall',
      render: (r: any) => {
        const s = Number(r.overall_score ?? 0);
        const b = scoreBadge(s);
        return (
          <span style={{ background: b.bg, color: b.fg, padding: '2px 8px', borderRadius: 4, fontWeight: 600 }}>
            {s} · {b.label}
          </span>
        );
      },
    },
    { key: 'responsiveness_score', header: 'Responsive', render: (r: any) => `${r.responsiveness_score ?? 0} / 100` },
    { key: 'quality_score', header: 'Quality', render: (r: any) => `${r.quality_score ?? 0} / 100` },
    { key: 'price_score', header: 'Price', render: (r: any) => `${r.price_score ?? 0} / 100` },
    { key: 'monthly_spend_rupees', header: 'Monthly Spend', render: (r: any) => fmtRupees(r.monthly_spend_rupees) },
    { key: 'contract_status', header: 'Status', render: (r: any) => String(r.contract_status ?? '') },
    {
      key: 'last_review_at',
      header: 'Last Review',
      render: (r: any) => (r.last_review_at ? new Date(r.last_review_at).toLocaleDateString('en-IN') : '-'),
    },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => String(r.vendor_name ?? '') },
    { key: 'overall_score', header: 'Score', render: (r: any) => String(r.overall_score ?? 0) },
    { key: 'monthly_spend_rupees', header: 'Spend', render: (r: any) => fmtRupees(r.monthly_spend_rupees) },
    { key: 'contract_status', header: 'Status', render: (r: any) => String(r.contract_status ?? '') },
    { key: 'open_issues', header: 'Open Issues', render: (r: any) => String(r.open_issues ?? 0) },
  ];

  const recentCols: Column<any>[] = [
    {
      key: 'logged_at',
      header: 'When',
      render: (r: any) => (r.logged_at ? new Date(r.logged_at).toLocaleString('en-IN') : '-'),
    },
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => String(r.vendor_name ?? '') },
    {
      key: 'event_type',
      header: 'Event',
      render: (r: any) => {
        const t = String(r.event_type ?? '');
        const isWin = t === 'win';
        const isIssue = t === 'issue';
        const bg = isWin ? '#dcfce7' : isIssue ? '#fee2e2' : '#e0e7ff';
        const fg = isWin ? '#166534' : isIssue ? '#991b1b' : '#3730a3';
        return <span style={{ background: bg, color: fg, padding: '2px 6px', borderRadius: 4 }}>{t}</span>;
      },
    },
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity ?? '') },
    { key: 'title', header: 'Title', render: (r: any) => String(r.title ?? '') },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.amount_rupees) },
    {
      key: 'resolved',
      header: 'Resolved',
      render: (r: any) => (r.resolved ? 'yes' : 'no'),
    },
  ];

  const totalVendors = Number(agg.total_vendors ?? 0);
  const activeVendors = Number(agg.active_vendors ?? 0);
  const atRiskCount = Number(agg.at_risk_vendors ?? 0);
  const avgOverall = Number(agg.avg_overall_score ?? 0);
  const avgResp = Number(agg.avg_responsiveness ?? 0);
  const avgQual = Number(agg.avg_quality ?? 0);
  const avgPrice = Number(agg.avg_price ?? 0);
  const totalSpend = Number(agg.total_monthly_spend ?? 0);
  const openIssues = Number(agg.open_issues ?? 0);
  const wins30d = Number(agg.wins_30d ?? 0);

  const tile = {
    background: '#fff',
    border: '1px solid #e5e7eb',
    borderRadius: 8,
    padding: 16,
  } as const;

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif', background: '#f9fafb', minHeight: '100vh' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Vendor Relationship Score</h1>
        <p style={{ color: '#6b7280' }}>
          Score key vendors on responsiveness, quality & price. Log issues & wins. Spot at-risk relationships
          before they bite.
        </p>
      </header>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: 12,
          marginBottom: 24,
        }}
      >
        <div style={tile}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Total vendors</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalVendors}</div>
          <div style={{ fontSize: 12, color: '#6b7280' }}>
            {activeVendors} active · {atRiskCount} at risk
          </div>
        </div>
        <div style={tile}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Avg overall score</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{avgOverall}</div>
          <div style={{ fontSize: 12, color: '#6b7280' }}>0 – 100 scale</div>
        </div>
        <div style={tile}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Avg responsiveness</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{avgResp}</div>
        </div>
        <div style={tile}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Avg quality</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{avgQual}</div>
        </div>
        <div style={tile}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Avg price</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{avgPrice}</div>
        </div>
        <div style={tile}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Total monthly spend</div>
          <div style={{ fontSize: 20, fontWeight: 700 }}>{fmtRupees(totalSpend)}</div>
        </div>
        <div style={tile}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Open issues</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: openIssues > 0 ? '#991b1b' : '#166534' }}>
            {openIssues}
          </div>
        </div>
        <div style={tile}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Wins (30d)</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#166534' }}>{wins30d}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>
          At-risk vendors — review before they cost us
        </h2>
        <DataTable<any> columns={atRiskCols} rows={atRisk} rowKey={(_, i) => String(i)} />
        {atRisk.length === 0 && (
          <p style={{ color: '#6b7280', padding: 12 }}>No vendors below 60 score & no at-risk flags. Clean.</p>
        )}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All vendor scores</h2>
        <DataTable<any> columns={vendorCols} rows={vendors} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent action log — issues & wins</h2>
        <DataTable<any> columns={recentCols} rows={recent} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}
