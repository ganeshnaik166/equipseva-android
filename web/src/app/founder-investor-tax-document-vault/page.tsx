import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorTaxDocumentVaultPage() {
  const sb = await getSupabaseServerClient();

  const [docsRes, requestsRes, summaryRes, pendingRes] = await Promise.all([
    sb.rpc('list_documents_r1761'),
    sb.rpc('list_requests_r1761'),
    sb.rpc('docs_summary_per_investor_r1761'),
    sb.rpc('pending_requests_r1761'),
  ]);

  const docs = (docsRes.data ?? []) as any[];
  const requests = (requestsRes.data ?? []) as any[];
  const summary = (summaryRes.data ?? []) as any[];
  const pending = (pendingRes.data ?? []) as any[];

  const docCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'fiscal_year', header: 'FY', render: (r: any) => String(r.fiscal_year ?? '—') },
    { key: 'document_type', header: 'Type', render: (r: any) => r.document_type ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'generated_at', header: 'Generated', render: (r: any) => r.generated_at ? new Date(r.generated_at).toLocaleDateString() : '—' },
    { key: 'sent_at', header: 'Sent', render: (r: any) => r.sent_at ? new Date(r.sent_at).toLocaleDateString() : '—' },
    { key: 'document_url', header: 'URL', render: (r: any) => r.document_url ? 'link' : '—' },
  ];

  const reqCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'document_type', header: 'Doc Type', render: (r: any) => r.document_type ?? '—' },
    { key: 'request_type', header: 'Request', render: (r: any) => r.request_type ?? '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'requested_at', header: 'Requested', render: (r: any) => r.requested_at ? new Date(r.requested_at).toLocaleString() : '—' },
    { key: 'resolved_at', header: 'Resolved', render: (r: any) => r.resolved_at ? new Date(r.resolved_at).toLocaleDateString() : 'pending' },
    { key: 'response_summary', header: 'Response', render: (r: any) => r.response_summary ?? '—' },
  ];

  const sumCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'total_docs', header: 'Total', render: (r: any) => String(r.total_docs ?? 0) },
    { key: 'generated_count', header: 'Generated', render: (r: any) => String(r.generated_count ?? 0) },
    { key: 'sent_count', header: 'Sent', render: (r: any) => String(r.sent_count ?? 0) },
    { key: 'acknowledged_count', header: 'Acknowledged', render: (r: any) => String(r.acknowledged_count ?? 0) },
    { key: 'latest_fy', header: 'Latest FY', render: (r: any) => String(r.latest_fy ?? '—') },
  ];

  const pendCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'document_type', header: 'Doc Type', render: (r: any) => r.document_type ?? '—' },
    { key: 'request_type', header: 'Request', render: (r: any) => r.request_type ?? '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'requested_at', header: 'Requested', render: (r: any) => r.requested_at ? new Date(r.requested_at).toLocaleString() : '—' },
    { key: 'age_hours', header: 'Age (h)', render: (r: any) => r.age_hours != null ? Number(r.age_hours).toFixed(1) : '—' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700 }}>Investor Tax Document Vault</h1>
        <p style={{ color: '#666', marginTop: 8 }}>
          Per-investor tax docs (TDS certificates, Form 16A, Capital Gains, Dividend Vouchers, Buyback). Track generation, dispatch, acknowledgment plus copy / clarification / dispute requests.
        </p>
      </header>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Pending Requests ({pending.length})</h2>
        <DataTable rows={pending} columns={pendCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Per-Investor Summary</h2>
        <DataTable rows={summary} columns={sumCols} rowKey={(r: any, i: number) => String(r.investor_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Documents ({docs.length})</h2>
        <DataTable rows={docs} columns={docCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Requests ({requests.length})</h2>
        <DataTable rows={requests} columns={reqCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
