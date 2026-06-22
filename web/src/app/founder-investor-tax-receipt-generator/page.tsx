import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Receipt = {
  id: string;
  investor_id: string;
  fiscal_year: string;
  distribution_amount_rupees: number;
  tax_withheld_rupees: number;
  status: string;
  issued_at: string | null;
  captured_at: string;
};

type ActionRow = {
  id: string;
  receipt_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

const receiptColumns: Column<Receipt>[] = [
  { key: 'fiscal_year', header: 'Fiscal Year', render: (r: any) => r.fiscal_year ?? '-' },
  { key: 'investor_id', header: 'Investor', render: (r: any) => (r.investor_id ?? '').slice(0, 8) },
  { key: 'distribution_amount_rupees', header: 'Distribution (rupees)', render: (r: any) => String(r.distribution_amount_rupees ?? 0) },
  { key: 'tax_withheld_rupees', header: 'Tax Withheld (rupees)', render: (r: any) => String(r.tax_withheld_rupees ?? 0) },
  { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
  { key: 'issued_at', header: 'Issued', render: (r: any) => r.issued_at ? new Date(r.issued_at).toLocaleString() : 'pending' },
  { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '-' },
];

const actionColumns: Column<ActionRow>[] = [
  { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '-' },
  { key: 'receipt_id', header: 'Receipt', render: (r: any) => (r.receipt_id ?? '').slice(0, 8) },
  { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '-' },
  { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '-' },
  { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '-' },
];

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [{ data: receipts }, { data: actions }] = await Promise.all([
    sb.rpc('list_investor_tax_receipts_r2045', { p_limit: 100 }),
    sb.rpc('list_recent_investor_tax_receipt_actions_r2045', { p_limit: 50 }),
  ]);

  const receiptRows: Receipt[] = (receipts ?? []) as Receipt[];
  const actionRows: ActionRow[] = (actions ?? []) as ActionRow[];

  const issuedCount = receiptRows.filter((r) => r.status === 'issued').length;
  const draftCount = receiptRows.filter((r) => r.status === 'draft').length;
  const disputedCount = receiptRows.filter((r) => r.status === 'disputed').length;
  const totalDistribution = receiptRows.reduce((s, r) => s + (r.distribution_amount_rupees ?? 0), 0);
  const totalTax = receiptRows.reduce((s, r) => s + (r.tax_withheld_rupees ?? 0), 0);

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Investor Tax Receipt Generator</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Round 2045. Generate, issue, and track tax receipts per investor distribution.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Total Receipts</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{receiptRows.length}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Issued</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{issuedCount}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Draft</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{draftCount}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Disputed</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{disputedCount}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Total Distribution (rupees)</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{totalDistribution}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Total Tax Withheld (rupees)</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{totalTax}</div>
          </div>
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Receipts</h2>
        <DataTable
          rows={receiptRows}
          columns={receiptColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable
          rows={actionRows}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Notes</h2>
        <ul style={{ color: '#444', lineHeight: 1.7, paddingLeft: 20 }}>
          <li>Status values are draft, issued, disputed, and superseded.</li>
          <li>Action log captures generated, sent, disputed, reissued, and closed events.</li>
          <li>All write operations record an entry in founder_action_log for audit.</li>
          <li>Founder-only access. RPCs gated by is_founder.</li>
        </ul>
      </section>
    </div>
  );
}
