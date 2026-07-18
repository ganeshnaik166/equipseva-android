import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderVendorContractRiskRegisterPage() {
  const supabase = await getSupabaseServerClient();

  const [
    contractsRes,
    reviewsRes,
    expiringRes,
    highRiskRes,
    kindSummaryRes,
    costBreakdownRes,
    upcomingRes,
  ] = await Promise.all([
    supabase.rpc('list_contracts_r2449'),
    supabase.rpc('list_risk_reviews_r2449'),
    supabase.rpc('expiring_60d_r2449'),
    supabase.rpc('high_risk_focus_r2449'),
    supabase.rpc('vendor_kind_summary_r2449'),
    supabase.rpc('annual_cost_breakdown_r2449'),
    supabase.rpc('upcoming_reviews_r2449'),
  ]);

  const contracts = (contractsRes.data ?? []) as any[];
  const reviews = (reviewsRes.data ?? []) as any[];
  const expiring = (expiringRes.data ?? []) as any[];
  const highRisk = (highRiskRes.data ?? []) as any[];
  const kindSummary = (kindSummaryRes.data ?? []) as any[];
  const costBreakdown = (costBreakdownRes.data ?? []) as any[];
  const upcoming = (upcomingRes.data ?? []) as any[];

  const contractCols: Column<any>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => r.vendor_name },
    { key: 'vendor_kind', header: 'Kind', render: (r: any) => r.vendor_kind },
    { key: 'contract_summary', header: 'Summary', render: (r: any) => r.contract_summary },
    { key: 'signed_at', header: 'Signed', render: (r: any) => r.signed_at ? String(r.signed_at).slice(0, 10) : '-' },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? String(r.expires_at).slice(0, 10) : '-' },
    { key: 'auto_renew', header: 'Auto Renew', render: (r: any) => r.auto_renew ? 'yes' : 'no' },
    { key: 'notice_period_days', header: 'Notice (days)', render: (r: any) => r.notice_period_days },
    { key: 'annual_cost_rupees', header: 'Annual Cost (₹)', render: (r: any) => Number(r.annual_cost_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'exit_risk', header: 'Exit Risk', render: (r: any) => r.exit_risk },
    { key: 'contract_owner_email', header: 'Owner', render: (r: any) => r.contract_owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const reviewCols: Column<any>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => r.vendor_name },
    { key: 'reviewed_at', header: 'Reviewed', render: (r: any) => r.reviewed_at ? String(r.reviewed_at).slice(0, 10) : '-' },
    { key: 'exit_risk_at_review', header: 'Risk at Review', render: (r: any) => r.exit_risk_at_review },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'next_review_at', header: 'Next Review', render: (r: any) => r.next_review_at ? String(r.next_review_at).slice(0, 10) : '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => r.vendor_name },
    { key: 'vendor_kind', header: 'Kind', render: (r: any) => r.vendor_kind },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? String(r.expires_at).slice(0, 10) : '-' },
    { key: 'days_to_expire', header: 'Days to Expire', render: (r: any) => r.days_to_expire },
    { key: 'auto_renew', header: 'Auto Renew', render: (r: any) => r.auto_renew ? 'yes' : 'no' },
    { key: 'notice_period_days', header: 'Notice', render: (r: any) => r.notice_period_days },
    { key: 'exit_risk', header: 'Exit Risk', render: (r: any) => r.exit_risk },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const highRiskCols: Column<any>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => r.vendor_name },
    { key: 'vendor_kind', header: 'Kind', render: (r: any) => r.vendor_kind },
    { key: 'exit_risk', header: 'Exit Risk', render: (r: any) => r.exit_risk },
    { key: 'annual_cost_rupees', header: 'Annual Cost (₹)', render: (r: any) => Number(r.annual_cost_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? String(r.expires_at).slice(0, 10) : '-' },
    { key: 'replacement_options_md', header: 'Replacement', render: (r: any) => r.replacement_options_md ?? '-' },
    { key: 'contract_owner_email', header: 'Owner', render: (r: any) => r.contract_owner_email ?? '-' },
  ];

  const kindCols: Column<any>[] = [
    { key: 'vendor_kind', header: 'Kind', render: (r: any) => r.vendor_kind },
    { key: 'contracts', header: 'Contracts', render: (r: any) => r.contracts },
    { key: 'annual_cost_rupees', header: 'Annual Cost (₹)', render: (r: any) => Number(r.annual_cost_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'high_risk_count', header: 'High Risk', render: (r: any) => r.high_risk_count },
    { key: 'critical_risk_count', header: 'Critical Risk', render: (r: any) => r.critical_risk_count },
  ];

  const costCols: Column<any>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: any) => r.bucket },
    { key: 'contracts', header: 'Contracts', render: (r: any) => r.contracts },
    { key: 'annual_cost_rupees', header: 'Annual Cost (₹)', render: (r: any) => Number(r.annual_cost_rupees ?? 0).toLocaleString('en-IN') },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => r.vendor_name },
    { key: 'next_review_at', header: 'Next Review', render: (r: any) => r.next_review_at ? String(r.next_review_at).slice(0, 10) : '-' },
    { key: 'exit_risk_at_review', header: 'Risk at Review', render: (r: any) => r.exit_risk_at_review },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Vendor Contract Risk Register</h1>
      <p style={{ marginBottom: 24, color: '#555' }}>
        Vendor & contract & auto-renew & notice period & annual cost & exit risk & replacement option.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Contracts</h2>
        <DataTable
          rows={contracts}
          columns={contractCols}
          emptyMessage="No contracts on file."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Expiring in &lt;= 60 Days</h2>
        <DataTable
          rows={expiring}
          columns={expiringCols}
          emptyMessage="No contracts expiring in 60 days."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>High & Critical Risk Focus</h2>
        <DataTable
          rows={highRisk}
          columns={highRiskCols}
          emptyMessage="No high-risk contracts."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Vendor Kind Summary</h2>
        <DataTable
          rows={kindSummary}
          columns={kindCols}
          emptyMessage="No vendor kinds."
          rowKey={(r: any, i: number) => String(r.vendor_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Annual Cost Breakdown</h2>
        <DataTable
          rows={costBreakdown}
          columns={costCols}
          emptyMessage="No cost data."
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Risk Review Log</h2>
        <DataTable
          rows={reviews}
          columns={reviewCols}
          emptyMessage="No reviews logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Upcoming Reviews</h2>
        <DataTable
          rows={upcoming}
          columns={upcomingCols}
          emptyMessage="No upcoming reviews."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
