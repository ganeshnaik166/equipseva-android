import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, vendorRes, listRes, riskRes, uploadsRes, gapsRes, successRes] = await Promise.all([
    supabase.rpc('founder_r2339_portal_portfolio_summary'),
    supabase.rpc('founder_r2339_portal_vendor_breakdown'),
    supabase.rpc('founder_r2339_portal_list_all'),
    supabase.rpc('founder_r2339_portal_at_risk'),
    supabase.rpc('founder_r2339_portal_recent_uploads', { p_limit: 50 }),
    supabase.rpc('founder_r2339_portal_compliance_gaps'),
    supabase.rpc('founder_r2339_portal_success_rate_30d'),
  ]);

  const summary = (summaryRes.data?.[0] ?? {}) as any;
  const vendors = (vendorRes.data ?? []) as any[];
  const list = (listRes.data ?? []) as any[];
  const risks = (riskRes.data ?? []) as any[];
  const uploads = (uploadsRes.data ?? []) as any[];
  const gaps = (gapsRes.data ?? []) as any[];
  const success = (successRes.data ?? []) as any[];

  const inr = (n: number | null | undefined) =>
    n == null ? '-' : '₹' + Number(n).toLocaleString('en-IN');

  const vendorCols: Column<any>[] = [
    { key: 'portal_vendor', header: 'Vendor', render: (r: any) => r.portal_vendor },
    { key: 'chain_count', header: 'Chains', render: (r: any) => r.chain_count },
    { key: 'live_count', header: 'Live', render: (r: any) => r.live_count },
    { key: 'monthly_gmv_rupees', header: 'Monthly GMV', render: (r: any) => inr(r.monthly_gmv_rupees) },
    { key: 'avg_failure_count', header: 'Avg fails', render: (r: any) => r.avg_failure_count ?? '0' },
  ];

  const listCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'portal_name', header: 'Portal', render: (r: any) => r.portal_name },
    { key: 'portal_vendor', header: 'Vendor', render: (r: any) => r.portal_vendor },
    { key: 'integration_status', header: 'Status', render: (r: any) => r.integration_status },
    { key: 'monthly_volume_invoices', header: 'Inv/mo', render: (r: any) => r.monthly_volume_invoices },
    { key: 'monthly_gmv_rupees', header: 'GMV/mo', render: (r: any) => inr(r.monthly_gmv_rupees) },
    { key: 'consecutive_failure_count', header: 'Fails', render: (r: any) => r.consecutive_failure_count },
    { key: 'go_live_target_date', header: 'Go-live', render: (r: any) => r.go_live_target_date ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const riskCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'portal_name', header: 'Portal', render: (r: any) => r.portal_name },
    { key: 'integration_status', header: 'Status', render: (r: any) => r.integration_status },
    { key: 'risk_reason', header: 'Reason', render: (r: any) => r.risk_reason },
    { key: 'consecutive_failure_count', header: 'Fails', render: (r: any) => r.consecutive_failure_count },
    { key: 'days_overdue', header: 'Days overdue', render: (r: any) => r.days_overdue },
    { key: 'penalty_exposure_rupees', header: 'Penalty exposure', render: (r: any) => inr(r.penalty_exposure_rupees) },
  ];

  const uploadCols: Column<any>[] = [
    { key: 'attempted_at', header: 'When', render: (r: any) => new Date(r.attempted_at).toLocaleString('en-IN') },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'portal_name', header: 'Portal', render: (r: any) => r.portal_name },
    { key: 'document_type', header: 'Doc type', render: (r: any) => r.document_type },
    { key: 'document_ref', header: 'Doc ref', render: (r: any) => r.document_ref },
    { key: 'invoice_amount_rupees', header: 'Amount', render: (r: any) => inr(r.invoice_amount_rupees) },
    { key: 'upload_outcome', header: 'Outcome', render: (r: any) => r.upload_outcome },
    { key: 'failure_reason', header: 'Reason', render: (r: any) => r.failure_reason ?? '-' },
    { key: 'retry_count', header: 'Retries', render: (r: any) => r.retry_count },
  ];

  const gapsCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'portal_name', header: 'Portal', render: (r: any) => r.portal_name },
    { key: 'portal_vendor', header: 'Vendor', render: (r: any) => r.portal_vendor },
    { key: 'integration_status', header: 'Status', render: (r: any) => r.integration_status },
    { key: 'contract_clause_ref', header: 'Clause', render: (r: any) => r.contract_clause_ref ?? '-' },
    { key: 'monthly_gmv_at_risk_rupees', header: 'GMV at risk', render: (r: any) => inr(r.monthly_gmv_at_risk_rupees) },
    { key: 'days_until_go_live', header: 'Days to go-live', render: (r: any) => r.days_until_go_live ?? '-' },
  ];

  const successCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'portal_name', header: 'Portal', render: (r: any) => r.portal_name },
    { key: 'total_attempts', header: 'Attempts', render: (r: any) => r.total_attempts },
    { key: 'success_count', header: 'Success', render: (r: any) => r.success_count },
    { key: 'failed_count', header: 'Failed', render: (r: any) => r.failed_count },
    { key: 'success_rate_pct', header: 'Rate %', render: (r: any) => r.success_rate_pct + '%' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital chain procurement-portal integration</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track which chains require us to upload invoices & POs to their portals (GHX, SAP Ariba, etc),
          live status, compliance gaps & SLA risk.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Total chains</div>
          <div className="text-2xl font-semibold">{summary.total_chains ?? 0}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Live</div>
          <div className="text-2xl font-semibold text-green-700">{summary.live_count ?? 0}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">In progress</div>
          <div className="text-2xl font-semibold text-blue-700">{summary.in_progress_count ?? 0}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Not started</div>
          <div className="text-2xl font-semibold text-gray-700">{summary.not_started_count ?? 0}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Degraded/suspended</div>
          <div className="text-2xl font-semibold text-red-700">{summary.degraded_count ?? 0}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Invoices / month</div>
          <div className="text-2xl font-semibold">{summary.total_monthly_invoices ?? 0}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">GMV / month</div>
          <div className="text-2xl font-semibold">{inr(summary.total_monthly_gmv_rupees)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Penalty exposure</div>
          <div className="text-2xl font-semibold text-red-700">{inr(summary.total_penalty_exposure_rupees)}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By portal vendor</h2>
        <DataTable
          rows={vendors}
          columns={vendorCols}
          emptyMessage="No vendors tracked yet."
          rowKey={(r: any) => r.portal_vendor}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">At-risk integrations</h2>
        <DataTable
          rows={risks}
          columns={riskCols}
          emptyMessage="No at-risk integrations."
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Compliance gaps (upload required & not live)</h2>
        <DataTable
          rows={gaps}
          columns={gapsCols}
          emptyMessage="No compliance gaps."
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">30-day upload success rate</h2>
        <DataTable
          rows={success}
          columns={successCols}
          emptyMessage="No upload activity in the last 30 days."
          rowKey={(r: any) => r.chain_name + '::' + r.portal_name}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All integrations</h2>
        <DataTable
          rows={list}
          columns={listCols}
          emptyMessage="No integrations configured yet."
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent upload attempts</h2>
        <DataTable
          rows={uploads}
          columns={uploadCols}
          emptyMessage="No upload attempts yet."
          rowKey={(r: any) => r.id}
        />
      </section>
    </main>
  );
}
