import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Valuation = {
  id: string;
  valuation_date: string;
  valuation_provider: string;
  fair_market_value_per_share_rupees: number;
  methodology: string;
  status: string;
  finalized_at: string | null;
  expires_on: string | null;
  created_at: string;
};

type Grant = {
  id: string;
  valuation_id: string;
  grant_type: string;
  grantee_email: string;
  grant_count: number;
  grant_at: string;
  fmv_per_share_rupees: number | null;
};

type CurrentVal = {
  id: string;
  valuation_date: string;
  valuation_provider: string;
  fair_market_value_per_share_rupees: number;
  methodology: string;
  status: string;
  finalized_at: string | null;
  expires_on: string | null;
};

function fmtRupees(v: number | null | undefined) {
  if (v === null || v === undefined) return '-';
  return '₹' + Number(v).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined) {
  if (!s) return '-';
  return new Date(s).toLocaleDateString();
}

function fmtDateTime(s: string | null | undefined) {
  if (!s) return '-';
  return new Date(s).toLocaleString();
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [vals, grants, current] = await Promise.all([
    sb.rpc('list_valuations_r1949', { p_limit: 100 }),
    sb.rpc('recent_grants_r1949', { p_limit: 50 }),
    sb.rpc('current_valuation_r1949'),
  ]);

  const valuationRows: Valuation[] = (vals.data as Valuation[] | null) ?? [];
  const grantRows: Grant[] = (grants.data as Grant[] | null) ?? [];
  const currentRow: CurrentVal | null =
    Array.isArray(current.data) && current.data.length > 0
      ? (current.data[0] as CurrentVal)
      : null;

  const errors = [vals.error, grants.error, current.error].filter(Boolean);

  const valuationColumns: Column<Valuation>[] = [
    { key: 'valuation_date', header: 'Date', render: (r: any) => fmtDate(r.valuation_date) },
    { key: 'valuation_provider', header: 'Provider', render: (r: any) => r.valuation_provider ?? '-' },
    { key: 'fmv', header: 'FMV per share', render: (r: any) => fmtRupees(r.fair_market_value_per_share_rupees) },
    { key: 'methodology', header: 'Methodology', render: (r: any) => r.methodology ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'finalized_at', header: 'Finalized', render: (r: any) => fmtDateTime(r.finalized_at) },
    { key: 'expires_on', header: 'Expires', render: (r: any) => fmtDate(r.expires_on) },
  ];

  const grantColumns: Column<Grant>[] = [
    { key: 'grant_at', header: 'Granted', render: (r: any) => fmtDateTime(r.grant_at) },
    { key: 'grant_type', header: 'Type', render: (r: any) => r.grant_type ?? '-' },
    { key: 'grantee_email', header: 'Grantee', render: (r: any) => r.grantee_email ?? '-' },
    { key: 'grant_count', header: 'Count', render: (r: any) => Number(r.grant_count ?? 0).toLocaleString('en-IN') },
    { key: 'fmv', header: 'FMV at grant', render: (r: any) => fmtRupees(r.fmv_per_share_rupees) },
    { key: 'valuation_id', header: 'Valuation', render: (r: any) => (r.valuation_id ? String(r.valuation_id).slice(0, 8) : '-') },
  ];

  const finalizedCount = valuationRows.filter((v) => v.status === 'finalized').length;
  const draftCount = valuationRows.filter((v) => v.status === 'draft').length;
  const supersededCount = valuationRows.filter((v) => v.status === 'superseded').length;
  const expiredCount = valuationRows.filter((v) => v.status === 'expired').length;
  const totalGranted = grantRows.reduce((acc, g) => acc + Number(g.grant_count || 0), 0);

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, margin: 0 }}>Investor 409A Valuation Tracker</h1>
        <p style={{ color: '#555', marginTop: 6 }}>
          Track 409A valuations and equity grant log. Founder-only view.
        </p>
      </header>

      {errors.length > 0 ? (
        <section
          style={{
            background: '#fff4f4',
            border: '1px solid #f5c2c2',
            padding: 12,
            borderRadius: 8,
            marginBottom: 16,
            color: '#7a1f1f',
          }}
        >
          <strong>Load errors:</strong>
          <ul style={{ margin: '6px 0 0 18px' }}>
            {errors.map((e, i) => (
              <li key={i}>{String(e?.message ?? e)}</li>
            ))}
          </ul>
        </section>
      ) : null}

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Current Active Valuation</h2>
        {currentRow ? (
          <div
            style={{
              background: '#f6fbf6',
              border: '1px solid #cfe6cf',
              borderRadius: 10,
              padding: 16,
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
              gap: 12,
            }}
          >
            <div>
              <div style={{ fontSize: 12, color: '#666' }}>Date</div>
              <div style={{ fontWeight: 600 }}>{fmtDate(currentRow.valuation_date)}</div>
            </div>
            <div>
              <div style={{ fontSize: 12, color: '#666' }}>Provider</div>
              <div style={{ fontWeight: 600 }}>{currentRow.valuation_provider}</div>
            </div>
            <div>
              <div style={{ fontSize: 12, color: '#666' }}>FMV per share</div>
              <div style={{ fontWeight: 600 }}>{fmtRupees(currentRow.fair_market_value_per_share_rupees)}</div>
            </div>
            <div>
              <div style={{ fontSize: 12, color: '#666' }}>Methodology</div>
              <div style={{ fontWeight: 600 }}>{currentRow.methodology}</div>
            </div>
            <div>
              <div style={{ fontSize: 12, color: '#666' }}>Expires</div>
              <div style={{ fontWeight: 600 }}>{fmtDate(currentRow.expires_on)}</div>
            </div>
          </div>
        ) : (
          <div
            style={{
              background: '#fffbe6',
              border: '1px solid #f5e6a0',
              padding: 12,
              borderRadius: 8,
              color: '#6b5500',
            }}
          >
            No finalized, non-expired 409A valuation on file.
          </div>
        )}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
            gap: 12,
          }}
        >
          <div style={{ background: '#fff', border: '1px solid #eee', borderRadius: 10, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Valuations</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{valuationRows.length}</div>
          </div>
          <div style={{ background: '#fff', border: '1px solid #eee', borderRadius: 10, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Finalized</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{finalizedCount}</div>
          </div>
          <div style={{ background: '#fff', border: '1px solid #eee', borderRadius: 10, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Draft</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{draftCount}</div>
          </div>
          <div style={{ background: '#fff', border: '1px solid #eee', borderRadius: 10, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Superseded</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{supersededCount}</div>
          </div>
          <div style={{ background: '#fff', border: '1px solid #eee', borderRadius: 10, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Expired</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{expiredCount}</div>
          </div>
          <div style={{ background: '#fff', border: '1px solid #eee', borderRadius: 10, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Recent grants units</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{totalGranted.toLocaleString('en-IN')}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Valuation Ledger</h2>
        <DataTable
          rows={valuationRows}
          columns={valuationColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
        {valuationRows.length === 0 ? (
          <div style={{ color: '#777', marginTop: 8 }}>No valuations recorded yet.</div>
        ) : null}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Grants</h2>
        <DataTable
          rows={grantRows}
          columns={grantColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
        {grantRows.length === 0 ? (
          <div style={{ color: '#777', marginTop: 8 }}>No grants logged yet.</div>
        ) : null}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Operator Notes</h2>
        <ul style={{ lineHeight: 1.7, color: '#333' }}>
          <li>Methodologies accepted: market approach, income approach, asset approach, option pricing.</li>
          <li>Grant types accepted: ISO, NSO, RSU, RSA, common stock.</li>
          <li>Mark a valuation finalized only after the provider report is countersigned.</li>
          <li>A valuation is considered active when status is finalized and expires-on date is in the future.</li>
          <li>Standard safe-harbor window is twelve months from the valuation date unless a material event occurs.</li>
        </ul>
      </section>
    </main>
  );
}
