import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type QuoteRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  old_equipment_name: string;
  replacement_equipment_name: string;
  quoted_amount_rupees: number;
  discount_offered_pct: number;
  valid_until: string;
  status: string;
  decided_at: string | null;
  created_at: string;
};

type PipelineRow = {
  status: string;
  quote_count: number;
  total_rupees: number;
};

type ExpiringRow = {
  id: string;
  hospital_email: string | null;
  replacement_equipment_name: string;
  quoted_amount_rupees: number;
  valid_until: string;
  days_remaining: number;
  status: string;
};

function fmtRupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return v.toFixed(2) + '%';
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleDateString('en-IN');
  } catch {
    return s;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [quotesRes, pipelineRes, expiringRes] = await Promise.all([
    sb.rpc('list_quotes_r1735', { p_status: null, p_limit: 100 }),
    sb.rpc('total_pipeline_value_r1735'),
    sb.rpc('expiring_quotes_r1735', { p_days: 14 }),
  ]);

  const quotes: QuoteRow[] = (quotesRes.data as QuoteRow[] | null) ?? [];
  const pipeline: PipelineRow[] = (pipelineRes.data as PipelineRow[] | null) ?? [];
  const expiring: ExpiringRow[] = (expiringRes.data as ExpiringRow[] | null) ?? [];

  const totalPipeline = pipeline.reduce((sum, p) => sum + Number(p.total_rupees ?? 0), 0);
  const totalQuotes = pipeline.reduce((sum, p) => sum + Number(p.quote_count ?? 0), 0);
  const acceptedRow = pipeline.find((p) => p.status === 'accepted');
  const acceptedValue = acceptedRow ? Number(acceptedRow.total_rupees) : 0;

  const errors = [quotesRes.error, pipelineRes.error, expiringRes.error].filter(Boolean);

  const quoteCols: Column<QuoteRow>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => <span>{r.hospital_email ?? r.hospital_user_id?.slice(0, 8)}</span> },
    { key: 'old_equipment_name', header: 'Old Equipment', render: (r: any) => <span>{r.old_equipment_name}</span> },
    { key: 'replacement_equipment_name', header: 'Replacement', render: (r: any) => <span>{r.replacement_equipment_name}</span> },
    { key: 'quoted_amount_rupees', header: 'Amount', render: (r: any) => <span>{fmtRupees(r.quoted_amount_rupees)}</span> },
    { key: 'discount_offered_pct', header: 'Discount', render: (r: any) => <span>{fmtPct(r.discount_offered_pct)}</span> },
    { key: 'valid_until', header: 'Valid Until', render: (r: any) => <span>{fmtDate(r.valid_until)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span style={{ textTransform: 'capitalize' }}>{String(r.status).replace('_', ' ')}</span> },
    { key: 'decided_at', header: 'Decided', render: (r: any) => <span>{r.decided_at ? fmtDate(r.decided_at) : '-'}</span> },
    { key: 'created_at', header: 'Sent', render: (r: any) => <span>{fmtDate(r.created_at)}</span> },
  ];

  const pipelineCols: Column<PipelineRow>[] = [
    { key: 'status', header: 'Status', render: (r: any) => <span style={{ textTransform: 'capitalize' }}>{String(r.status).replace('_', ' ')}</span> },
    { key: 'quote_count', header: 'Quotes', render: (r: any) => <span>{r.quote_count}</span> },
    { key: 'total_rupees', header: 'Total Value', render: (r: any) => <span>{fmtRupees(r.total_rupees)}</span> },
    { key: 'share', header: 'Share', render: (r: any) => <span>{totalPipeline > 0 ? ((Number(r.total_rupees) / totalPipeline) * 100).toFixed(1) + '%' : '0%'}</span> },
  ];

  const expiringCols: Column<ExpiringRow>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => <span>{r.hospital_email ?? '-'}</span> },
    { key: 'replacement_equipment_name', header: 'Replacement', render: (r: any) => <span>{r.replacement_equipment_name}</span> },
    { key: 'quoted_amount_rupees', header: 'Amount', render: (r: any) => <span>{fmtRupees(r.quoted_amount_rupees)}</span> },
    { key: 'valid_until', header: 'Valid Until', render: (r: any) => <span>{fmtDate(r.valid_until)}</span> },
    {
      key: 'days_remaining',
      header: 'Days Left',
      render: (r: any) => {
        const d = Number(r.days_remaining ?? 0);
        const color = d <= 3 ? '#b91c1c' : d <= 7 ? '#b45309' : '#374151';
        return <span style={{ color, fontWeight: 600 }}>{d}d</span>;
      },
    },
    { key: 'status', header: 'Status', render: (r: any) => <span style={{ textTransform: 'capitalize' }}>{String(r.status).replace('_', ' ')}</span> },
  ];

  return (
    <main style={{ maxWidth: 1200, margin: '0 auto', padding: '24px 16px', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>Hospital Replacement Equipment Quotes</h1>
        <p style={{ color: '#6b7280', marginTop: 8 }}>
          Track equipment replacement quotes sent to hospitals, status changes, revisions, and expiring pipeline. Round r1735.
        </p>
      </header>

      {errors.length > 0 && (
        <div style={{ background: '#fef2f2', border: '1px solid #fecaca', color: '#991b1b', padding: 12, borderRadius: 8, marginBottom: 16 }}>
          <strong>Errors loading data:</strong>
          <ul style={{ marginTop: 6, marginBottom: 0 }}>
            {errors.map((e, i) => (
              <li key={i}>{e?.message ?? 'unknown error'}</li>
            ))}
          </ul>
        </div>
      )}

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ background: '#f9fafb', border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>Total Quotes</div>
          <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4 }}>{totalQuotes}</div>
        </div>
        <div style={{ background: '#f9fafb', border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>Total Pipeline Value</div>
          <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4 }}>{fmtRupees(totalPipeline)}</div>
        </div>
        <div style={{ background: '#ecfdf5', border: '1px solid #a7f3d0', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#065f46', textTransform: 'uppercase', letterSpacing: 0.5 }}>Accepted Value</div>
          <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4, color: '#065f46' }}>{fmtRupees(acceptedValue)}</div>
        </div>
        <div style={{ background: '#fef3c7', border: '1px solid #fde68a', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#92400e', textTransform: 'uppercase', letterSpacing: 0.5 }}>Expiring in 14 days</div>
          <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4, color: '#92400e' }}>{expiring.length}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Pipeline by Status</h2>
        <p style={{ color: '#6b7280', fontSize: 14, marginBottom: 12 }}>
          Distribution of quote value across status buckets. Status flow: sent → in_negotiation → accepted / declined / expired.
        </p>
        <DataTable
          rows={pipeline}
          columns={pipelineCols}
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Expiring Quotes (next 14 days)</h2>
        <p style={{ color: '#6b7280', fontSize: 14, marginBottom: 12 }}>
          Quotes with valid_until &lt;= 14 days from today and still in sent or in_negotiation. Days left &lt;= 3 highlighted red, &lt;= 7 amber.
        </p>
        <DataTable
          rows={expiring}
          columns={expiringCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Quotes (latest 100)</h2>
        <p style={{ color: '#6b7280', fontSize: 14, marginBottom: 12 }}>
          Full list of replacement-equipment quotes sent to hospitals, ordered by most recent first.
        </p>
        <DataTable
          rows={quotes}
          columns={quoteCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
