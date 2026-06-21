import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Recall = {
  id: string;
  investor_id: string;
  investor_email: string | null;
  recall_amount_rupees: number;
  recall_reason: string;
  requested_at: string;
  status: string;
  decided_at: string | null;
  notes: string | null;
  document_count: number;
};

type RecentRecall = {
  id: string;
  investor_email: string | null;
  recall_amount_rupees: number;
  recall_reason: string;
  status: string;
  requested_at: string;
};

type Totals = {
  total_open_rupees: number;
  total_negotiating_rupees: number;
  total_refunded_rupees: number;
  total_declined_rupees: number;
  open_count: number;
  negotiating_count: number;
  refunded_count: number;
  declined_count: number;
  closed_count: number;
};

type RecallDocument = {
  id: string;
  recall_id: string;
  document_type: string;
  uploaded_at: string;
  document_url: string;
  uploaded_by_email: string | null;
};

function formatRupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return 'Rs ' + Number(n).toLocaleString('en-IN');
}

function formatDate(ts: string | null | undefined): string {
  if (!ts) return '-';
  try {
    return new Date(ts).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return ts;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [recallsRes, totalsRes, recentRes, documentsRes] = await Promise.all([
    sb.rpc('list_recalls_r1869'),
    sb.rpc('total_recall_value_r1869'),
    sb.rpc('recent_recalls_r1869'),
    sb.rpc('list_documents_r1869', { p_recall_id: null }),
  ]);

  const recalls: Recall[] = (recallsRes.data as Recall[]) ?? [];
  const totalsRow: Totals | null = Array.isArray(totalsRes.data) && totalsRes.data.length > 0
    ? (totalsRes.data[0] as Totals)
    : null;
  const recents: RecentRecall[] = (recentRes.data as RecentRecall[]) ?? [];
  const documents: RecallDocument[] = (documentsRes.data as RecallDocument[]) ?? [];

  const recallColumns: Column<Recall>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id ?? '-' },
    { key: 'recall_amount_rupees', header: 'Amount', render: (r: any) => formatRupees(r.recall_amount_rupees) },
    { key: 'recall_reason', header: 'Reason', render: (r: any) => String(r.recall_reason ?? '-') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'requested_at', header: 'Requested', render: (r: any) => formatDate(r.requested_at) },
    { key: 'decided_at', header: 'Decided', render: (r: any) => formatDate(r.decided_at) },
    { key: 'document_count', header: 'Docs', render: (r: any) => String(r.document_count ?? 0) },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const recentColumns: Column<RecentRecall>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '-' },
    { key: 'recall_amount_rupees', header: 'Amount', render: (r: any) => formatRupees(r.recall_amount_rupees) },
    { key: 'recall_reason', header: 'Reason', render: (r: any) => String(r.recall_reason ?? '-') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'requested_at', header: 'Requested', render: (r: any) => formatDate(r.requested_at) },
  ];

  const documentColumns: Column<RecallDocument>[] = [
    { key: 'recall_id', header: 'Recall', render: (r: any) => String(r.recall_id ?? '-').slice(0, 8) },
    { key: 'document_type', header: 'Type', render: (r: any) => String(r.document_type ?? '-') },
    { key: 'uploaded_at', header: 'Uploaded', render: (r: any) => formatDate(r.uploaded_at) },
    { key: 'uploaded_by_email', header: 'By', render: (r: any) => r.uploaded_by_email ?? '-' },
    {
      key: 'document_url',
      header: 'URL',
      render: (r: any) => {
        const url = String(r.document_url ?? '');
        if (!url) return '-';
        const short = url.length > 40 ? url.slice(0, 40) + '...' : url;
        return <a href={url} target="_blank" rel="noreferrer">{short}</a>;
      },
    },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Capital Recall Log</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track when investors request capital recall, refund, or dispute. Round r1869.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recall Pipeline Totals</h2>
        {totalsRow ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 6 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Open</div>
              <div style={{ fontSize: 18, fontWeight: 600 }}>{formatRupees(totalsRow.total_open_rupees)}</div>
              <div style={{ fontSize: 12, color: '#666' }}>{totalsRow.open_count} requests</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 6 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Negotiating</div>
              <div style={{ fontSize: 18, fontWeight: 600 }}>{formatRupees(totalsRow.total_negotiating_rupees)}</div>
              <div style={{ fontSize: 12, color: '#666' }}>{totalsRow.negotiating_count} requests</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 6 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Refunded</div>
              <div style={{ fontSize: 18, fontWeight: 600 }}>{formatRupees(totalsRow.total_refunded_rupees)}</div>
              <div style={{ fontSize: 12, color: '#666' }}>{totalsRow.refunded_count} requests</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 6 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Declined</div>
              <div style={{ fontSize: 18, fontWeight: 600 }}>{formatRupees(totalsRow.total_declined_rupees)}</div>
              <div style={{ fontSize: 12, color: '#666' }}>{totalsRow.declined_count} requests</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 6 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Closed</div>
              <div style={{ fontSize: 18, fontWeight: 600 }}>{totalsRow.closed_count}</div>
              <div style={{ fontSize: 12, color: '#666' }}>final dispositions</div>
            </div>
          </div>
        ) : (
          <div style={{ color: '#666' }}>No totals available.</div>
        )}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Recalls (last 60 days)</h2>
        <DataTable
          rows={recents}
          columns={recentColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Recalls</h2>
        <DataTable
          rows={recalls}
          columns={recallColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Attached Documents</h2>
        <DataTable
          rows={documents}
          columns={documentColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
