import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SafeRow = {
  id: string;
  investor_id: string;
  safe_label: string;
  principal_amount_rupees: number;
  valuation_cap_rupees: number;
  discount_pct: number;
  safe_type: string;
  status: string;
  issued_at: string;
  converted_at: string | null;
};

type ActionRow = {
  id: string;
  safe_id: string;
  safe_label: string | null;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  amount_rupees: number;
  notes_md: string | null;
};

type Totals = {
  active_count: number;
  active_principal_rupees: number;
  converted_count: number;
  converted_principal_rupees: number;
  total_principal_rupees: number;
};

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return 'Rs ' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return s;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [safesRes, totalsRes, recentRes] = await Promise.all([
    sb.rpc('list_safes_r1973'),
    sb.rpc('outstanding_total_r1973'),
    sb.rpc('recent_actions_r1973'),
  ]);

  const safes: SafeRow[] = (safesRes.data as SafeRow[] | null) ?? [];
  const totalsArr = (totalsRes.data as Totals[] | null) ?? [];
  const totals: Totals = totalsArr[0] ?? {
    active_count: 0,
    active_principal_rupees: 0,
    converted_count: 0,
    converted_principal_rupees: 0,
    total_principal_rupees: 0,
  };
  const recent: ActionRow[] = (recentRes.data as ActionRow[] | null) ?? [];

  const safeCols: Column<SafeRow>[] = [
    { key: 'safe_label', header: 'SAFE label', render: (r: any) => String(r.safe_label ?? '-') },
    { key: 'safe_type', header: 'Type', render: (r: any) => String(r.safe_type ?? '-') },
    { key: 'principal_amount_rupees', header: 'Principal', render: (r: any) => fmtRupees(r.principal_amount_rupees) },
    { key: 'valuation_cap_rupees', header: 'Valuation cap', render: (r: any) => fmtRupees(r.valuation_cap_rupees) },
    { key: 'discount_pct', header: 'Discount pct', render: (r: any) => String(r.discount_pct ?? 0) + '%' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'issued_at', header: 'Issued', render: (r: any) => fmtDate(r.issued_at) },
    { key: 'converted_at', header: 'Converted', render: (r: any) => fmtDate(r.converted_at) },
  ];

  const recentCols: Column<ActionRow>[] = [
    { key: 'safe_label', header: 'SAFE', render: (r: any) => String(r.safe_label ?? '-') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '-') },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.amount_rupees) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '-') },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => fmtDate(r.taken_at) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '-') },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor SAFE Notes Tracker</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track outstanding SAFE notes, convert events, repurchases, and MFN triggers.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Outstanding totals</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Active SAFEs</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{totals.active_count}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Active principal</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{fmtRupees(totals.active_principal_rupees)}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Converted SAFEs</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{totals.converted_count}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Converted principal</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{fmtRupees(totals.converted_principal_rupees)}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total principal</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{fmtRupees(totals.total_principal_rupees)}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All SAFE notes</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Up to 200 most recent SAFE notes. Status values are active, converted, repurchased, and written off.
        </p>
        <DataTable
          rows={safes}
          columns={safeCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent actions</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Last 50 actions across all SAFE notes including issued, MFN triggered, converted, repurchased, and extended.
        </p>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
